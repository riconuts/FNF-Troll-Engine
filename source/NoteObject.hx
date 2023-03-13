package;

import flixel.math.FlxPoint;

class NoteObject extends FlxSprite {
    public var noteData:Int = 0;
	public var offsetX:Float = 0;
	public var offsetY:Float = 0;
	public var defScale:FlxPoint = FlxPoint.get(); // for modcharts to keep the scaling
}