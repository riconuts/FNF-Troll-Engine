package funkin.objects.cutscenes;

import funkin.scripts.FunkinHScript;
import funkin.scripts.ScriptedClassShit.InstanceInterp;

class ScriptedCutscene extends Cutscene
{
	public var script:FunkinHScript;

	function callScript(call:String, ?args:Array<Dynamic>):Null<Dynamic> {
		if (script != null && script.exists(call))
			return script.call(call, args);

		return null;
	}

	public function new(?id:String){
		super();
		if (id != null) {
			var scriptPath = Paths.getHScriptPath('cutscenes/$id');
			if (scriptPath != null)
				script = FunkinHScript.fromFile(scriptPath, id, null, true, new InstanceInterp(this));
		}
		onEnd.addOnce((_:Bool) -> {
			callScript("onCutsceneEnd");
		});
	}

	override function createCutscene() // gets called by state or w/e
		callScript("onCreateCutscene", []);

	override function update(elapsed:Float){
		callScript("onUpdate", [elapsed]);
		super.update(elapsed);
		callScript("onUpdatePost", [elapsed]);
	}

	override function pause(){
		super.pause();
		callScript("onPause", []);
	}

	override function resume(){
		super.resume();
		callScript("onResume", []);
	}

	override function restart(){
		super.restart();
		callScript("onRestart", []);
	}
}