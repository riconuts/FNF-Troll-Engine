package funkin.objects.hud;

import flixel.math.FlxMath.fastSin as sin;
import flixel.math.FlxAngle.TO_RAD;
import flixel.text.FlxText;

class BotplayText extends FlxText
{
	public var botplaySine:Float = 0.0;

	public function new(){
		super(0, (ClientPrefs.downScroll ? (FlxG.height - 107) : 89), FlxG.width, Paths.getString("botplayMark"), 32);
		this.setFormat(Paths.font("vcr.ttf"), 32, 0xFFFFFFFF, CENTER);
		this.setBorderStyle(OUTLINE, 0xFF000000, 1.25);
		this.scrollFactor.set();
		this.active = false;
	}

	override function update(elapsed:Float) {
		if (PlayState.instance.cpuControlled)
			botplaySine += 180 * elapsed;
		else
			botplaySine = 0.0;
		
		super.update(elapsed);
	}

	override function draw(){
		alpha = 1.0 - sin(botplaySine * TO_RAD);
		super.draw();
	}
}