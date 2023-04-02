// DO NOT FUCKING USE THIS IT GIVERS ME NIGHTMARES
package;

import flixel.math.FlxAngle;
import math.Vector3;
import openfl.Vector;
import flixel.system.FlxAssets.FlxShader;
import flixel.graphics.frames.FlxFrame.FlxFrameType;

class FlxSprite3D extends FlxSprite
{
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

		var shader = shader != null ? shader : new FlxShader();
		if (shader != shader)
			this.shader = shader;

		shader.bitmap.input = graphic.bitmap;
		shader.bitmap.filter = antialiasing ? LINEAR : NEAREST;
		var pos = new Vector3(x, y, z);
		var centeredOrigin = new Vector3((FlxG.width / 2), (FlxG.height / 2)); // vertex origin
		var fieldPos = new Vector3(0, 0, 1280);
		var width = frameWidth * scale.x;
		var height = frameHeight * scale.y;

		for (camera in cameras)
		{
			if (!camera.visible || !camera.exists || !isOnScreen(camera))
				continue;

			var alpha = alpha * camera.alpha;

			var quad = [
				new Vector3(-width / 2, -height / 2, 0), // top left
				new Vector3(width / 2, -height / 2, 0), // top right
				new Vector3(-width / 2, height / 2, 0), // bottom left
				new Vector3(width / 2, height / 2, 0) // bottom right
			];

			for (idx => vert in quad)
			{
				var originMod = VectorHelpers.rotateV3(vert, FlxAngle.TO_RAD * pitch, FlxAngle.TO_RAD * yaw, FlxAngle.TO_RAD * angle)
					.add(pos)
					.subtract(centeredOrigin); // moves the vertex to the appropriate position on screen based on origin

				var projected = VectorHelpers.getVector(originMod.subtract(fieldPos)); // perpsective projection
				var nuVert = projected.add(centeredOrigin); // puts the vertex back to default pos
				nuVert.x += frameWidth / 2;
				nuVert.y += frameHeight / 2;
				quad[idx] = nuVert;
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

			shader.alpha.value = [alpha * camera.alpha];
			camera.canvas.graphics.beginShaderFill(shader);
			camera.canvas.graphics.drawTriangles(vertices, null, uvData);
			camera.canvas.graphics.endFill();

			#if FLX_DEBUG
			FlxBasic.visibleCount++;
			#end
		}
	}
}