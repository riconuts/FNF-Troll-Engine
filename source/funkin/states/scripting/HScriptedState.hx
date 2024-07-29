package funkin.states.scripting;

import funkin.scripts.FunkinHScript;

#if !SCRIPTABLE_STATES
@:build(funkin.macros.ScriptingMacro.addScriptingCallbacks([
	"create",
	"update",
	"destroy",
	"openSubState",
	"closeSubState",
	"stepHit",
	"beatHit",
	"sectionHit"
]))
#end
class HScriptedState extends MusicBeatState 
{
	public var scriptPath:String;

	public function new(scriptFullPath:String, ?scriptVars:Map<String, Dynamic>)
	{
		super(false); // false because the whole point of this state is its scripted lol

		scriptPath = scriptFullPath;

		var vars = _getScriptDefaultVars();

		if (scriptVars != null) {
			for (k => v in scriptVars)
				vars[k] = v;
		}

		_extensionScript = FunkinHScript.fromFile(scriptPath, scriptPath, vars, false);
		_extensionScript.call("new", []);
	}

	static public function fromFile(name:String, ?scriptVars)
	{
		for (filePath in Paths.getFolders("states"))
		{
			var fullPath = filePath + '$name.hscript';
			if (Paths.exists(fullPath))
				return new HScriptedState(fullPath, scriptVars);
		}

		return null;
	}
}