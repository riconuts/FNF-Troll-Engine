package funkin.objects;

import flixel.util.FlxDestroyUtil;
import flixel.math.FlxPoint;
import math.Vector3;

enum abstract ObjectType(#if cpp cpp.UInt8 #else Int #end)
{
	var UNKNOWN = -1;
	var NOTE;
	var STRUM;
	var SPLASH;
}

interface IColorable
{
	var colorSwap:funkin.objects.shaders.ColorSwap;
}

class NoteObject extends FlxSprite {
	public var isQuant:Bool = false;
	
	public var objType:ObjectType = UNKNOWN;
	public var assetKey:String = ''; // Used for the NoteStyle system, so custom NoteObjects can define their own NoteStyle asset key (scripted hold covers or whatever)
    public var column:Int = 0;
    @:isVar
    public var noteData(get,set):Int; // backwards compat
    inline function get_noteData()return column;
    inline function set_noteData(v:Int)return column = v;

	public var offsetX:Float = 0;
	public var offsetY:Float = 0;
	public var defScale:FlxPoint = FlxPoint.get(); // for modcharts to keep the scaling
	public var handleRendering:Bool = true;

	public var vec3Cache:Vector3 = new Vector3(); // for vector3 operations in modchart code
	
	override function toString()
	{
		return '(column: $column | visible: $visible)';
	}

	override function draw()
	{
		if (handleRendering)
			return super.draw();
	}

	public function new(?x:Float, ?y:Float){
		super(x, y);
	}

	override function destroy()
	{
		defScale = FlxDestroyUtil.put(defScale);
		super.destroy();
	}
}