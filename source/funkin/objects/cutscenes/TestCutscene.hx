package funkin.objects.cutscenes;

import flixel.tweens.FlxEase;

class TestCutscene extends TimelineCutscene {
	override function createCutscene(){
		super.createCutscene();
		var cummies = new FlxSprite();
		cummies.frames = Paths.getSparrowAtlas("characters/BOYFRIEND");
		cummies.animation.addByPrefix("hey", "BF HEY", 24, false);
		cummies.animation.addByPrefix("idle", "BF idle dance", 24, true);
		cummies.animation.play("idle", true);
		add(cummies);

		var tf = timeline.secToFrame;

		timeline.easeProperties(0, tf(1), cummies, {x: 100, y: 300}, FlxEase.backOut);
		timeline.playAnimation(tf(1), cummies, "hey");

		timeline.easeCallback(tf(1), tf(3), (p:Float, f:Float) -> {
			cummies.alpha = 1 - p;
		}, FlxEase.quadOut);

		timeline.until(tf(0.5), tf(1), (frame:Int) -> {
			trace(frame);
		});

		timeline.once(tf(0.75), (frame:Int) -> {
			trace("penis");
		});

		timeline.on(tf(1), (frame:Int) -> {
			var done = FlxG.random.bool(5); // 5% chance this stops
			trace(frame + " " + done);
			return done;
		});
	}
}