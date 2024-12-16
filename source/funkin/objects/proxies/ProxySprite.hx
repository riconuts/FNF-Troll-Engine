package funkin.objects.proxies;

import flixel.math.FlxRect;
import flixel.graphics.frames.FlxFrame.FlxFrameAngle;

class ProxySprite extends FlxSprite {
	var proxiedSprite:FlxSprite;

	public function new(x:Float, y:Float, sprite:FlxSprite){
		super(x, y);
		proxiedSprite = sprite;
	}

	override public function getScreenBounds(?newRect:FlxRect, ?camera:FlxCamera):FlxRect
	{
		if (newRect == null)
			newRect = FlxRect.get();

		if (camera == null)
			camera = FlxG.camera;

		var originX = proxiedSprite.origin.x + origin.x; 
		var originY = proxiedSprite.origin.y + origin.y;
		var scaleX = scale.x * proxiedSprite.scale.x;
		var scaleY = scale.y * proxiedSprite.scale.y;

		newRect.setPosition(x, y);
		if (pixelPerfectPosition)
			newRect.floor();
		_scaledOrigin.set(originX * scaleX, originY * scaleY);
		newRect.x += -Std.int(camera.scroll.x * scrollFactor.x) - offset.x + originX - _scaledOrigin.x;
		newRect.y += -Std.int(camera.scroll.y * scrollFactor.y) - offset.y + originY - _scaledOrigin.y;
		if (isPixelPerfectRender(camera))
			newRect.floor();
		newRect.setSize(proxiedSprite.frameWidth * Math.abs(scaleX), proxiedSprite.frameHeight * Math.abs(scaleY));
		return newRect.getRotatedBounds(angle, _scaledOrigin, newRect);
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