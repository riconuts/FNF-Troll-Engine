package funkin.objects.cutscenes;

import funkin.states.CutscenePauseSubstate;
import flixel.tweens.FlxEase;
import funkin.states.MusicBeatState;

class CutsceneTestState extends MusicBeatState
{
	var cutscene: Cutscene;
	var camGame:FlxCamera;
	var camOther:FlxCamera;

	override function create(){
		Paths.currentModDirectory = 'base-game';

		camGame = new FlxCamera();
		camOther = new FlxCamera();
		camOther.bgColor = 0;

		FlxG.cameras.reset(camGame);
		FlxG.cameras.add(camOther, false);

		FlxG.cameras.setDefaultDrawTarget(camGame, true);

		cutscene = new TimelineCutscene('teststress');
		add(cutscene);
		cutscene.createCutscene();
		cutscene.onEnd.add((skipped:Bool) -> {
			remove(cutscene);
			cutscene = null;
			MusicBeatState.switchState(new funkin.states.MainMenuState());
		});
		super.create();
	}

	override function update(elapsed:Float){
		super.update(elapsed);
		if(FlxG.keys.justPressed.ENTER && cutscene != null && subState == null){
			persistentUpdate = false;
			cutscene.pause();
			openSubState(new CutscenePauseSubstate(cutscene));
		}
	}
}