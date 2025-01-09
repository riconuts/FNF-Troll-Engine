package funkin.states.scripting;

import funkin.input.PlayerSettings;
import funkin.scripts.Globals;
import funkin.scripts.FunkinHScript;

using StringTools;

@:noScripting // honestly we could prob use the scripting thing to override shit instead
class OldHScriptedSubstate extends MusicBeatSubstate
{
	public var stateScript:FunkinHScript;
	public var scriptPath:Null<String> = null;

	public function new(?script:FunkinHScript, ?doCreateCall:Bool = true)
	{
		super();

		if (script==null)
			this.stateScript = FunkinHScript.blankScript();
		else
			this.stateScript = script;

		// some shortcuts
		stateScript.set("this", this);
		stateScript.set("add", this.add);
		stateScript.set("remove", this.remove);
		stateScript.set("insert", this.insert);
		stateScript.set("members", this.members);
		stateScript.set("close", close);

		// TODO: use a macro to auto-generate code to variables.set all variables/methods of MusicBeatState

		stateScript.set("get_controls", () -> return PlayerSettings.player1.controls);
		stateScript.set("controls", PlayerSettings.player1.controls);

		if (doCreateCall != false)
			stateScript.call("onLoad");
	}

	public static function fromString(str:String, ?doCreateCall:Bool = true)
	{
		return new OldHScriptedSubstate(FunkinHScript.fromString(str, "HScriptedState", null, doCreateCall));
	}

	public static function fromFile(fileName:String, ?doCreateCall:Bool = true)
	{
		var scriptPath:Null<String> = null;

		var hasExtension = false;
		for (ext in Paths.HSCRIPT_EXTENSIONS) {
			if (fileName.endsWith('.$ext')) {
				hasExtension = true;
				break;
			}
		}

		if (!hasExtension)
			fileName += ".hscript";

		for (folderPath in Paths.getFolders("substates"))
		{
			var filePath = folderPath + fileName;

			if (Paths.exists(filePath)){
				scriptPath = filePath;
				break;
			}
		}

		var script:Null<FunkinHScript> = null;

		if (scriptPath != null){
			script = FunkinHScript.fromFile(scriptPath, scriptPath, null, false);			
		}else{
			trace('Script file "$fileName" not found!');
		}

		var state = new OldHScriptedSubstate(script, doCreateCall);
		state.scriptPath = scriptPath;
		return state;
	}

	override function update(e)
	{
		if (stateScript.call("onUpdate", [e]) == Globals.Function_Stop)
			return;

		super.update(e);

		stateScript.call("onUpdatePost", [e]);
	}

	override function close()
	{
		if (stateScript != null)
			stateScript.call("onClose");

		return super.close();
	}

	override function destroy()
	{
		if (stateScript != null)
		{
			stateScript.call("onDestroy");
			stateScript.stop();
		}
		stateScript = null;

		return super.destroy();
	}
}