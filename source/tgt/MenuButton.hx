package tgt;

import flixel.graphics.FlxGraphic;
import sowy.SowyBaseButton;

class MenuButton extends SowyBaseButton
{
	public var targetX:Float = 0;
	public var targetY:Float = 0;

	public function new(x:Float = 0, y:Float = 0, ?onClick:Void->Void, ?graphic:FlxGraphic)
	{
		targetX = x;
		targetY = y;
		super(x, y, onClick);
        if (graphic != null) loadGraphic(graphic);
	}

	override function update(elapsed:Float)
	{
		x += (targetX - x) * (1 - Math.exp(-10.2 * elapsed));
		y += (targetY - y) * (1 - Math.exp(-10.2 * elapsed));

		super.update(elapsed);
	}
}