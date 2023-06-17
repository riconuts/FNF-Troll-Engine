package proxies;

import flixel.graphics.frames.FlxFrame.FlxFrameAngle;

class ProxySprite extends FlxSprite {
    var proxiedSprite:FlxSprite;

    public function new(x:Float, y:Float, sprite:FlxSprite){
        super(x, y);
        proxiedSprite = sprite;
    }

	@:noCompletion
	override function drawSimple(camera:FlxCamera):Void
	{
		getScreenPosition(_point, camera).subtractPoint(offset);
		if (isPixelPerfectRender(camera))
			_point.floor();

		_point.copyToFlash(_flashPoint);
        @:privateAccess
		camera.copyPixels(proxiedSprite._frame, proxiedSprite.framePixels, _flashRect, _flashPoint, colorTransform, blend, antialiasing);
	}

	@:noCompletion
	override function drawComplex(camera:FlxCamera):Void
	{
		_frame.prepareMatrix(_matrix, FlxFrameAngle.ANGLE_0, checkFlipX(), checkFlipY());
		_matrix.translate(-origin.x, -origin.y);
		_matrix.translate(-proxiedSprite.origin.x, -proxiedSprite.origin.y);
		_matrix.scale(proxiedSprite.scale.x, proxiedSprite.scale.y);
		_matrix.scale(scale.x, scale.y);

		if (bakedRotationAngle <= 0)
		{
			updateTrig();

			if (angle != 0)
				_matrix.rotateWithTrig(_cosAngle, _sinAngle);
		}

		getScreenPosition(_point, camera).subtractPoint(offset).subtractPoint(proxiedSprite.offset);
		_point.add(origin.x, origin.y);
		_point.add(proxiedSprite.origin.x, proxiedSprite.origin.y);
		_matrix.translate(_point.x, _point.y);

		if (isPixelPerfectRender(camera))
		{
			_matrix.tx = Math.floor(_matrix.tx);
			_matrix.ty = Math.floor(_matrix.ty);
		}
		@:privateAccess
		camera.drawPixels(proxiedSprite._frame, proxiedSprite.framePixels, _matrix, colorTransform, blend, antialiasing, shader);
	}
    
}