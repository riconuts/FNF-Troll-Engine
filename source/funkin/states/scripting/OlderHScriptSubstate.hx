package funkin.states.scripting;

import sys.FileSystem;
import funkin.scripts.Globals;
import funkin.scripts.FunkinHScript;

class OlderHScriptSubstate extends funkin.states.MusicBeatSubstate 
{
	public var script:FunkinHScript;

	public function new(ScriptName:String, ?additionalVars:Map<String, Any>) {
		super();

		var filePath:String = Paths.getHScriptPath('substates/$ScriptName');
		trace(filePath);
		if (filePath == null) {
			trace('Substate $ScriptName is not real!!');
			return close();
		}

		// some shortcuts
		var variables = new Map<String, Dynamic>();
		variables.set("this", this);
		variables.set("add", this.add);
		variables.set("remove", this.remove);
		variables.set("getControls", function() {
			return controls;
		}); // i get it now
		variables.set("close", this.close);
		variables.set('members', this.members);
		variables.set('cameras', this.cameras);
		variables.set('insert', this.insert);

		if (additionalVars != null) {
			for (key in additionalVars.keys())
				variables.set(key, additionalVars.get(key));
		}

		script = FunkinHScript.fromFile(filePath, variables);
		script.scriptName = ScriptName;

		if (script == null) {
			trace('Script file "$ScriptName" not found!');
			return close();
		}

		script.call("onLoad");
	}

	override function update(e:Float) {
		if (script.call("update", [e]) == Globals.Function_Stop)
			return;

		super.update(e);
		script.call("updatePost", [e]);
	}

	override function close() {
		if (script != null)
			script.call("onClose");

		return super.close();
	}

	override function destroy() {
		if (script != null) {
			script.call("onDestroy");
			script.stop();
		}
		script = null;

		return super.destroy();
	}
}