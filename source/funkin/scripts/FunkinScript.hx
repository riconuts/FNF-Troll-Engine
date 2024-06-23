package funkin.scripts;

import funkin.states.PlayState;

using StringTools;

/** This is a base class meant to be overridden so you can easily implement custom script types **/
class FunkinScript {
	public var scriptName:String = '';
	public var scriptType:String = '';
	
	/**
		Called when the script should be stopped
	**/
	public function stop(){
		throw new haxe.exceptions.NotImplementedException();
	}

	/**
		Called to set a variable defined in the script
	**/
	public function set(variable:String, data:Dynamic):Void
	{
		throw new haxe.exceptions.NotImplementedException();
	}

	/**
		Called to get a variable defined in the script
	**/
	public function get(key:String):Dynamic
	{
		throw new haxe.exceptions.NotImplementedException();
	}

	/**
		Called to call a function within the script
	**/
	public function call(func:String, ?args:Array<Dynamic>, ?extraVars:Map<String,Dynamic>):Dynamic
	{
		throw new haxe.exceptions.NotImplementedException();
	}

	/**
		Helper function
		Sets a bunch of basic variables for the script depending on the state
	**/
	function setDefaultVars(){
		var currentState = flixel.FlxG.state;

		if (currentState is PlayState && currentState == PlayState.instance)
		{
			set("inPlaystate", true);
			
			set('bpm', PlayState.SONG.bpm);
			set('scrollSpeed', PlayState.SONG.speed);
			set('songName', PlayState.SONG.song);
			set('isStoryMode', PlayState.isStoryMode);
			set('weekRaw', PlayState.storyWeek);
			set('seenCutscene', PlayState.seenCutscene);
			// set('week', WeekData.weeksList[PlayState.storyWeek]);
			
			set('healthGainMult', PlayState.instance.healthGain);
			set('healthLossMult', PlayState.instance.healthLoss);
			set('instakillOnMiss', PlayState.instance.instakillOnMiss);
			set('botPlay', PlayState.instance.cpuControlled);
			set('disableModcharts', PlayState.instance.disableModcharts);
			set('practice', PlayState.instance.practiceMode);
			set('opponentPlay', PlayState.instance.playOpponent);
			set("showDebugTraces", PlayState.instance.showDebugTraces);

			set('mustHitSection', false);
			set('altAnim', false);
			set('gfSection', false);

			set("curSection", null);
			set("sectionNumber", 0);

			set('songLength', null);
			set('startedCountdown', false);
		}else{
			set("inPlaystate", false);
			set("showDebugTraces", Main.showDebugTraces);
		}

		set("scriptName", scriptName);

		set('Function_Halt', Globals.Function_Halt);
		set('Function_Stop', Globals.Function_Stop);
		set('Function_Continue', Globals.Function_Continue);

		set("difficulty", PlayState.difficulty);
		set("difficultyName", PlayState.difficultyName);

		set('inGameOver', false);
		
		set('downscroll', ClientPrefs.downScroll);
		set('middlescroll', ClientPrefs.midScroll);
		set('framerate', ClientPrefs.framerate);
		set('ghostTapping', ClientPrefs.ghostTapping);
		set('hideHud', ClientPrefs.hudOpacity > 0);
		set('timeBarType', ClientPrefs.timeBarType);
		set('scoreZoom', ClientPrefs.scoreZoom);
		set('cameraZoomOnBeat', ClientPrefs.camZoomP > 0);
		set('flashingLights', ClientPrefs.flashing);
		set('noteOffset', ClientPrefs.noteOffset);
		set('healthBarAlpha', ClientPrefs.hpOpacity);
		set('lowQuality', ClientPrefs.lowQuality);
		set("trollEngine", true); // so if any psych mods wanna add troll engine specific stuff well there they go

		
		set('curBpm', Conductor.bpm);
		set('crochet', Conductor.crochet);
		set('stepCrochet', Conductor.stepCrochet);

		set('curBeat', 0);
		set('curStep', 0);
		set('curDecBeat', 0);
		set('curDecStep', 0);

		set('version', "0.5.2h"); // version of psych troll engine is based on
		set('teVersion', Main.displayedVersion.trim());
	}
}