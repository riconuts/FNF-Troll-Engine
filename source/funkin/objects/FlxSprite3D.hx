package funkin.objects;

import flixel.system.FlxAssets.FlxShader;
import flixel.graphics.frames.FlxFrame.FlxFrameType;
import flixel.math.FlxPoint;
import flixel.math.FlxAngle;
import math.VectorHelpers;
import math.Vector3;
import openfl.Vector;
import openfl.geom.ColorTransform;

class FlxSprite3D extends FlxSprite {
	public var z:Float = 0;

	public var yaw:Float = 0;
	public var pitch:Float = 0;
	@:isVar
	public var roll(get, set):Float = 0;

	function get_roll()
		return angle;

	function set_roll(val:Float)
		return angle = val;

	override public function draw():Void
	{
		checkEmptyFrame();

		if (alpha == 0 || _frame.type == FlxFrameType.EMPTY)
			return;

		if (dirty) // rarely
			calcFrame(useFramePixels);

        // TODO: take origin into consideration properly
		var wid = frameWidth;
		var hei = frameHeight;

		var halfW = wid * 0.5;
		var halfH = hei * 0.5;

		var camPos = new Vector3();
		var camOrigin = new Vector3(); // vertex origin

        // TODO: take origin into account properly without this bandaid fix vv

        var bandaidOrigin = FlxPoint.weak();
		bandaidOrigin.set(origin.x - halfW, origin.y - halfH);
		for (camera in cameras)
		{
			if (!camera.visible || !camera.exists || camera.canvas == null || camera.canvas.graphics == null)
				continue;
			
			camPos.setTo(camera.scroll.x, camera.scroll.y, Math.max(camera.width, camera.height));
			camOrigin.setTo(camera.width / 2, camera.height / 2, 0);

			var quad = [
				new Vector3(-halfW, -halfH, 0),
				new Vector3(halfW, -halfH, 0),
				new Vector3(-halfW, halfH, 0),
				new Vector3(halfW, halfH, 0)
			];
            
			getScreenPosition(_point, camera).subtractPoint(offset);
            //_point.add(bandaidOrigin.x, bandaidOrigin.y);
			var pos = new Vector3(_point.x, _point.y, z);

			for (idx => vert in quad)
			{
				if (flipX)
					vert.x *= -1;
				if (flipY)
					vert.y *= -1;
                vert.x -= bandaidOrigin.x;
                vert.y -= bandaidOrigin.y;
                vert.x *= scale.x;
                vert.y *= scale.y;
				
                var vert = VectorHelpers.rotateV3(vert, FlxAngle.TO_RAD * pitch, FlxAngle.TO_RAD * yaw, FlxAngle.TO_RAD * roll);
				var originMod = vert.add(pos).subtract(camOrigin);
				var projected = VectorHelpers.project(originMod.subtract(camPos));
				vert = projected.subtract(pos).add(camOrigin); // puts the vertex back to default pos

                vert.x += bandaidOrigin.x;
                vert.y += bandaidOrigin.y;

				quad[idx] = vert;
                
            }
			var frameRect = frame.frame;
			var sourceBitmap = graphic.bitmap;

			var leftUV = frameRect.left / sourceBitmap.width;
			var rightUV = frameRect.right / sourceBitmap.width;
			var topUV = frameRect.top / sourceBitmap.height;
			var bottomUV = frameRect.bottom / sourceBitmap.height;

			// order should be LT, RT, RB, LT, LB, RB
			// R is right L is left T is top B is bottom
			// order matters! so LT is left, top because they're represented as x, y
			var vertices = new Vector<Float>(12, false, [
				quad[0].x, quad[0].y,
				quad[1].x, quad[1].y,
				quad[3].x, quad[3].y,

				quad[0].x, quad[0].y,
				quad[2].x, quad[2].y,
				quad[3].x, quad[3].y
			]);

			var uvData = new Vector<Float>(12, false, [
				 leftUV,    topUV,
				rightUV,    topUV,
				rightUV, bottomUV,

				 leftUV,    topUV,
				 leftUV, bottomUV,
				rightUV, bottomUV,
			]);

			var shader = this.shader != null ? this.shader : new FlxShader();
			if (this.shader != shader)
				this.shader = shader;

			shader.bitmap.input = graphic.bitmap;
			shader.bitmap.filter = antialiasing ? LINEAR : NEAREST;

			var transforms:Array<ColorTransform> = [];
            var transfarm:ColorTransform = new ColorTransform();
			transfarm.redMultiplier = colorTransform.redMultiplier;
			transfarm.greenMultiplier = colorTransform.greenMultiplier;
			transfarm.blueMultiplier = colorTransform.blueMultiplier;
			transfarm.redOffset = colorTransform.redOffset;
			transfarm.greenOffset = colorTransform.greenOffset;
			transfarm.blueOffset = colorTransform.blueOffset;
            transfarm.alphaOffset = colorTransform.alphaOffset;
            transfarm.alphaMultiplier = colorTransform.alphaMultiplier * camera.alpha;

			for (n in 0...Std.int(vertices.length / 3))
				transforms.push(transfarm);
    

			var indices = new Vector<Int>(vertices.length, false, cast [for (i in 0...vertices.length) i]);
			var drawItem = camera.startTrianglesBatch(graphic, antialiasing, true, blend, true, shader);

			@:privateAccess
			{
				drawItem.addTrianglesColorArray(vertices, indices, uvData, null, _point, camera._bounds, transforms);
			}


			#if FLX_DEBUG
			FlxBasic.visibleCount++;
			#end
		}
		bandaidOrigin.putWeak();
        

		#if FLX_DEBUG
		if (FlxG.debugger.drawDebug)
			drawDebug();
		#end
	}
}