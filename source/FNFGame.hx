package;

#if SCRIPTABLE_STATES
import scripts.FunkinHScript;
import scripts.FunkinHScript.HScriptState;
#end

class FNFGame extends FlxGame {
	#if SCRIPTABLE_STATES
	override function switchState():Void
	{
		if (_requestedState is MusicBeatState){
			var state:MusicBeatState = cast _requestedState;
            if (state.canBeScripted){
                var className = Type.getClassName(Type.getClass(_requestedState));
                for (filePath in Paths.getFolders("states"))
                {
					var fileName = 'override/$className.hscript';
					if (Paths.exists(filePath + fileName)){
                        _requestedState.destroy();
                        _requestedState = new HScriptState(fileName);
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