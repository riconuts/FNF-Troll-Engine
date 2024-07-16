package funkin.states.scripting;

import funkin.scripts.FunkinHScript;

class HScriptOverridenState extends MusicBeatState 
{
	public var scriptPath:String = '';
	public var parentClass:Class<MusicBeatState> = null;

	inline private static function getShortClassName(cl):String
		return Type.getClassName(cl).split('.').pop();

	override function _startExtensionScript(folder:String, scriptName:String) 
		return;

	public function new(parentClass:Class<MusicBeatState>, scriptFullPath:String) 
	{
		super(false); // false because the whole point of this state is its scripted lol
		
		if (parentClass == null || scriptFullPath == null) {
			trace("Uh oh");
			return;
		}

		scriptPath = scriptFullPath;

		var defaultVars = _getScriptDefaultVars();
		defaultVars.set(getShortClassName(parentClass), parentClass);

		_extensionScript = FunkinHScript.fromFile(scriptPath, scriptPath, defaultVars, false);
		_extensionScript.call("new", []);
	}
}