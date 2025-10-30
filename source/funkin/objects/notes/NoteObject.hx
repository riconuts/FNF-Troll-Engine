package funkin.objects.notes;

import flixel.util.FlxDestroyUtil;
import flixel.math.FlxPoint;
import math.Vector3;

import funkin.objects.shaders.NoteColorSwap;

enum abstract ObjectType(#if cpp cpp.UInt8 #else Int #end)
{
	var UNKNOWN = -1;
	var NOTE;
	var STRUM;
	var SPLASH;
}

class NoteObject extends FlxSprite {
	public var extraData:Map<String, Dynamic> = [];

	public var objType:ObjectType;
	public var zIndex:Float = 0;
	public var column:Int = 0;

	public var colorSwap:NoteColorSwap;
	public var offsetX:Float = 0;
	public var offsetY:Float = 0;
	public var defScale:FlxPoint = FlxPoint.get(); // for modcharts to keep the scaling

	public var handleRendering:Bool = true;
	public var vec3Cache:Vector3 = new Vector3(); // for vector3 operations in modchart code

	#if ALLOW_DEPRECATION
	@:deprecated("noteData is deprecated! Use `column` instead.")
	public var noteData(get, set):Int; // backwards compat
	inline function get_noteData() return column;
	inline function set_noteData(v) return column = v;
	#end
	
	public function new(objType:ObjectType = UNKNOWN)
	{
		this.objType = objType;
		super();
	}
	
	override function toString()
	{
		return '(column: $column | visible: $visible)';
	}

	override function draw()
	{
		if (handleRendering)
			return super.draw();
	}

	override function drawComplex(camera:FlxCamera):Void
	{
		prepareMatrix(camera);
		camera.drawPixels(_frame, framePixels, _matrix, colorTransform, blend, antialiasing, shader, colorSwap);
	}

	override function destroy()
	{
		defScale = FlxDestroyUtil.put(defScale);
		super.destroy();
	}
}