package sowy;

import flixel.text.FlxText;
import flixel.ui.FlxButton;
import flixel.util.FlxColor;

class SowyTextButton extends SowyBaseButton
{
	var labelColors:Array<FlxColor> = [FlxColor.YELLOW, 0xFF00AAFF, FlxColor.YELLOW];

	public function new(X:Float = 0, Y:Float = 0, FieldWidth:Float = 0, ?Text:String, Size:Int = 8, ?OnClick:Void->Void)
	{
		super(X, Y, OnClick);

		label = new FlxText(X, Y, FieldWidth, Text, Size, true);

		width = label.frameWidth;
		height = label.frameHeight;

		labelAlphas = [1, 1, 1];
	}

	override function loadDefaultGraphic():Void
	{
		makeGraphic(80, 20, 0x00000000);
	}

	override function updateStatusAnimation():Void
	{
		label.color = labelColors[status];
	}
}