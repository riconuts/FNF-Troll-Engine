package funkin;

import funkin.scripts.Globals;
import funkin.states.MusicBeatState;

#if SCRIPTABLE_STATES
import funkin.states.scripting.HScriptOverridenState;
#end

class FNFGame extends FlxGame
{
	public function new(gameWidth = 0, gameHeight = 0, ?initialState:Class<FlxState>, updateFramerate = 60, drawFramerate = 60, skipSplash = false, startFullscreen = false)
	{
		super(gameWidth, gameHeight, initialState, updateFramerate, drawFramerate, skipSplash, startFullscreen);
		_customSoundTray = flixel.system.ui.DefaultFlxSoundTray;
	}

	override function update():Void
	{
		super.update();

		if (FlxG.keys.justPressed.F5)
			MusicBeatState.resetState();
	}

	override function switchState():Void
	{
		#if SCRIPTABLE_STATES
		if (_requestedState is MusicBeatState)
		{
			var ogState:MusicBeatState = cast _requestedState;
			var nuState = HScriptOverridenState.requestOverride(ogState);
			
			if (nuState != null) {
				_requestedState.destroy();
				_requestedState = nuState;
			}
		}
		#end

		Globals.variables.clear();
		super.switchState();
	}
}