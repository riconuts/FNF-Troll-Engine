package funkin;

#if SCRIPTABLE_STATES
import funkin.states.MusicBeatState;
import funkin.scripts.FunkinHScript.HScriptedState;
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
				var className = Type.getClassName(Type.getClass(_requestedState));
				for (filePath in Paths.getFolders("states"))
				{
					var fileName = 'override/$className.hscript';
					if (Paths.exists(filePath + fileName))
					{
						_requestedState.destroy();
						_requestedState = HScriptedState.fromFile(fileName);
						trace(fileName);
						return super.switchState();
					}
				}
			}
		}

		return super.switchState();
	}
	#end
}