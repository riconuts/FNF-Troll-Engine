package funkin.states.scripting;

import funkin.scripts.FunkinHScript;

class HScriptedSubstate extends MusicBeatSubstate
{
	public var scriptPath:String;

	public function new(scriptFullPath:String, ?scriptVars:Map<String, Dynamic>)
	{
		super();

		scriptPath = scriptFullPath;

		var vars = _getScriptDefaultVars();

		if (scriptVars != null) {
			for (k => v in scriptVars)
				vars[k] = v;
		}

		_extensionScript = FunkinHScript.fromFile(scriptPath, scriptPath, vars, false);
		_extensionScript.call("new", []);
	}

	static public function fromFile(name:String, ?scriptVars:Map<String, Dynamic>)
	{
		for (filePath in Paths.getFolders("substates"))
		{
			var fullPath = filePath + '$name.hscript';
			if (Paths.exists(fullPath))
				return new HScriptedSubstate(fullPath, scriptVars);
		}

		return null;
	}
}