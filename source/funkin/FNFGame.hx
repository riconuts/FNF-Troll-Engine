package funkin;

#if SCRIPTABLE_STATES
import funkin.states.scripting.HScriptOverridenState;
import funkin.states.MusicBeatState;
#end

class FNFGame extends FlxGame
{
	public function new(gameWidth = 0, gameHeight = 0, ?initialState:Class<FlxState>, updateFramerate = 60, drawFramerate = 60, skipSplash = false, startFullscreen = false)
	{
		super(gameWidth, gameHeight, initialState, updateFramerate, drawFramerate, skipSplash, startFullscreen);
		_customSoundTray = flixel.system.ui.DefaultFlxSoundTray;
	}

	#if SCRIPTABLE_STATES
	override function switchState():Void
	{
		if (_requestedState is MusicBeatState)
		{
			var ogState:MusicBeatState = cast _requestedState;
			var nuState = HScriptOverridenState.requestOverride(ogState);
			
			if (nuState != null) {
				_requestedState.destroy();
				_requestedState = nuState;
			}
		}

		return super.switchState();
	}
	#end
}