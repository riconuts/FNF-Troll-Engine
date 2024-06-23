package funkin.objects;

import flixel.util.FlxDestroyUtil;
import flixel.math.FlxPoint;

enum abstract ObjectType(#if cpp cpp.UInt8 #else Int #end)
{
	var UNKNOWN = -1;
	var NOTE;
	var STRUM;
	var SPLASH;
}

class NoteObject extends FlxSprite {
	public var objType:ObjectType = UNKNOWN;

    public var column:Int = 0;
    @:isVar
    public var noteData(get,set):Int; // backwards compat
    inline function get_noteData()return column;
    inline function set_noteData(v:Int)return column = v;

	public var offsetX:Float = 0;
	public var offsetY:Float = 0;
	public var defScale:FlxPoint = FlxPoint.get(); // for modcharts to keep the scaling
	public var handleRendering:Bool = true;
	
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