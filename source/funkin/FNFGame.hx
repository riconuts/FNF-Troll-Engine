package funkin;

#if SCRIPTABLE_STATES
import funkin.scripts.FunkinHScript;
import funkin.states.MusicBeatState;
import funkin.states.scripting.HScriptOverridenState;
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
			var state:MusicBeatState = cast _requestedState;
			if (state.canBeScripted)
			{
				var cl = Type.getClass(state);
				var fullName = Type.getClassName(cl);
				for (filePath in Paths.getFolders("states"))
				{
					var fileName = 'override/$fullName.hscript';
					var fullPath = filePath + fileName;
					if (Paths.exists(fullPath))
					{
						_requestedState.destroy();
						_requestedState = new HScriptOverridenState(cl, fullPath);

						return super.switchState();
					}
				}
			}
		}

		return super.switchState();
	}
	#end
}