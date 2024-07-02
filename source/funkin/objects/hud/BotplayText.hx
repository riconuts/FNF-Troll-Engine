package funkin.objects.hud;

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

	function optionsChanged() {
		this.y = (ClientPrefs.downScroll ? (FlxG.height-107) : 89);
	}

	override function draw(){
		if (PlayState.instance.cpuControlled){
			botplaySine += 180 * FlxG.elapsed;
			alpha = 1.0 - flixel.math.FlxMath.fastSin((Math.PI * botplaySine) / 180.0);
			super.draw();
		}else{
			botplaySine = 0.0;
		}
	}
}