if (!PlayState.isStoryMode){
	script.stop();
	return;
}

function onEndSong(){
	game.camHUD.visible = false;

	var blackScreen:FlxSprite = new FlxSprite(0, 0).makeGraphic(1, 1, FlxColor.BLACK);
	blackScreen.scale.set(FlxG.width * 2, FlxG.height * 2);
	blackScreen.scrollFactor.set();
	blackScreen.screenCenter();
	game.add(blackScreen);

	var daSound;
	daSound = FlxG.sound.play(
		Paths.sound('Lights_Shut_off'),
		1,
		false,
		null,
		true,
		()->{ daSound.destroy(true); }
	);
	daSound.persist = true;
}