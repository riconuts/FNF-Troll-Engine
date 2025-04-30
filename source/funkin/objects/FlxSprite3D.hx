package funkin.objects;

import flixel.util.FlxColor;
import flixel.system.FlxAssets.FlxGraphicAsset;
import flixel.system.FlxAssets.FlxShader;
import flixel.graphics.frames.FlxFrame.FlxFrameType;
import flixel.math.FlxPoint;
import flixel.math.FlxAngle;
import math.Vector3;
import openfl.Vector;
import openfl.geom.ColorTransform;

using math.VectorHelpers;

class FlxSprite3D extends FlxSprite {
	public var z:Float = 0;

	public var yaw:Float = 0;
	public var pitch:Float = 0;
	public var roll(get, set):Float;
	function get_roll() return angle;
	function set_roll(val:Float) return angle = val;

	////
	private var _camPos = new Vector3();
	private var _camOrigin = new Vector3(); // vertex origin
	private var _sprPos = new Vector3();
	private var quad0 = new Vector3();
	private var quad1 = new Vector3();
	private var quad2 = new Vector3();
	private var quad3 = new Vector3();
	private var _vertices = new Vector<Float>(12, false);
	private var _indices = new Vector<Int>(12, false, [for (i in 0...12) i]);
	private var _uvData = new Vector<Float>(12, false);
	
	private var _triangleColorTransforms:Array<ColorTransform>;
	private var _3DColor = new ColorTransform();

	public function new(?x:Float, ?y:Float, ?z:Float, ?g:FlxGraphicAsset) {
		super(x, y, g);
		this.z = z;

		_triangleColorTransforms = [_3DColor, _3DColor]; 
	}

	public function setPos(x:Float, y:Float, z:Float) {
		this.x = x;
		this.y = y;
		this.z = z;
	}

	override public function draw():Void
	{
		checkEmptyFrame();

		if (alpha == 0 || _frame.type == FlxFrameType.EMPTY)
			return;

		if (dirty) // rarely
			calcFrame(useFramePixels);

		if (this.shader == null)
			this.shader =  new FlxShader();

		shader.bitmap.input = graphic.bitmap;
		shader.bitmap.filter = antialiasing ? LINEAR : NEAREST;

		// TODO: take origin into consideration properly
		var wid = frameWidth;
		var hei = frameHeight;

		var halfW = wid * 0.5;
		var halfH = hei * 0.5;

		var radPitch = FlxAngle.TO_RAD * pitch;
		var radYaw = FlxAngle.TO_RAD * yaw;
		var radRoll = FlxAngle.TO_RAD * roll;

		var spriteOrigin = FlxPoint.weak();
		spriteOrigin.set(origin.x - halfW, origin.y - halfH);

		for (camera in cameras) {
			if (!camera.visible || !camera.exists || camera.canvas == null || camera.canvas.graphics == null)
				continue;

			/*
			getScreenPosition(_point, camera).subtractPoint(offset);
			//_point.add(spriteOrigin.x, spriteOrigin.y);
			_sprPos.setTo(_point.x, _point.y, z - camera.scrollZ);
			*/

			_sprPos.setTo(this.x - this.offset.x, this.y - this.offset.y, this.z - camera.scrollZ);
			_point.set(_sprPos.x, _sprPos.y);

			var cameraMaxSize = Math.max(camera.width, camera.height);
			_camPos.setTo( // scrollfactor in 3D is kinda dumb
				camera.scroll.x * this.scrollFactor.x, 
				camera.scroll.y * this.scrollFactor.y, 
				cameraMaxSize
			);
			_camOrigin.setTo(camera.width / 2, camera.height / 2, 0);
			
			quad0.setTo(-halfW, -halfH, 0); // LT
			quad1.setTo(halfW, -halfH, 0); // RT
			quad2.setTo(-halfW, halfH, 0); // LB
			quad3.setTo(halfW, halfH, 0); // RB

			for (i in 0...4) {
				var vert = switch(i) {
					case 0: quad0;
					case 1: quad1;
					case 2: quad2;
					case 3: quad3;
					default: null;
				};

				if (flipX) vert.x *= -1;
				if (flipY) vert.y *= -1;
				vert.x -= spriteOrigin.x;
				vert.y -= spriteOrigin.y;
				vert.x *= scale.x;
				vert.y *= scale.y;

				//
				vert.rotateV3(radPitch, radYaw, radRoll, vert);
				
				// origin mod
				vert.add(_sprPos, vert);
				vert.subtract(_camOrigin, vert);
				vert.subtract(_camPos, vert);

				//
				vert.project(vert, cameraMaxSize);
				
				// puts the vertex back to default pos
				vert.subtract(_sprPos, vert);
				vert.add(_camOrigin, vert);
				
				//
				vert.x += spriteOrigin.x;
				vert.y += spriteOrigin.y;
			}

			// LT RT LB RB
			// 0  1  2  3

			// order should be LT, RT, RB | LT, LB, RB
			// R is right L is left T is top B is bottom
			// order matters! so LT is left, top because they're represented as x, y
			_vertices[0] = quad0.x;		_vertices[1] = quad0.y; // LT
			_vertices[2] = quad1.x;		_vertices[3] = quad1.y; // RT
			_vertices[4] = quad3.x;		_vertices[5] = quad3.y; // RB

			_vertices[6] = quad0.x;		_vertices[7] = quad0.y; // LT
			_vertices[8] = quad2.x;		_vertices[9] = quad2.y; // LB
			_vertices[10] = quad3.x;	_vertices[11] = quad3.y; // RB

			var sourceBitmap = graphic.bitmap;
			var frameRect = frame.frame;

			var leftUV = frameRect.left / sourceBitmap.width;
			var rightUV = frameRect.right / sourceBitmap.width;
			var topUV = frameRect.top / sourceBitmap.height;
			var bottomUV = frameRect.bottom / sourceBitmap.height;

			_uvData[0] = leftUV;	_uvData[1] = topUV;
			_uvData[2] = rightUV;	_uvData[3] = topUV;
			_uvData[4] = rightUV;	_uvData[5] = bottomUV;

			_uvData[6] = leftUV;	_uvData[7] = topUV;
			_uvData[8] = leftUV;	_uvData[9] = bottomUV;
			_uvData[10] = rightUV;	_uvData[11] = bottomUV;
			
			_3DColor.redMultiplier = colorTransform.redMultiplier;
			_3DColor.greenMultiplier = colorTransform.greenMultiplier;
			_3DColor.blueMultiplier = colorTransform.blueMultiplier;
			_3DColor.redOffset = colorTransform.redOffset;
			_3DColor.greenOffset = colorTransform.greenOffset;
			_3DColor.blueOffset = colorTransform.blueOffset;
			_3DColor.alphaOffset = colorTransform.alphaOffset;
			_3DColor.alphaMultiplier = colorTransform.alphaMultiplier * camera.alpha;

			var drawItem = camera.startTrianglesBatch(graphic, antialiasing, true, blend, true, shader);
			@:privateAccess drawItem.addTrianglesColorArray(_vertices, _indices, _uvData, null, _point, camera._bounds, _triangleColorTransforms);

			#if FLX_DEBUG
			FlxBasic.visibleCount++;
			#end
		}
		spriteOrigin.putWeak();

		#if FLX_DEBUG
		if (FlxG.debugger.drawDebug)
			drawDebug();
		#end
	}

	override function makeGraphic(width:Int, height:Int, color = FlxColor.WHITE, unique = false, ?key:String):FlxSprite3D
	{
		super.makeGraphic(width, height, color, unique, key);
		return this;
	}

	override function loadGraphic(graphic:FlxGraphicAsset, animated = false, frameWidth = 0, frameHeight = 0, unique = false, ?key:String):FlxSprite3D
	{
		super.loadGraphic(graphic, animated, frameWidth, frameHeight, unique, key);
		return this;
	}
}