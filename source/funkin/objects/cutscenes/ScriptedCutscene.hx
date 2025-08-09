package funkin.objects.cutscenes;

import funkin.scripts.FunkinHScript;


class ScriptedCutscene extends Cutscene 
{
	public var script:FunkinHScript;

	function callScript(call:String, ?args:Array<Dynamic>):Null<Dynamic> {
		if (script != null && script.exists(call))
			return script.call(call, args);

		return null;
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

	override function createCutscene() // gets called by state or w/e
		callScript("onCreateCutscene", []);

	override function update(elapsed:Float){
		callScript("onUpdate", [elapsed]);
		super.update(elapsed);
		callScript("onUpdatePost", [elapsed]);
	}

	public function new(?id:String){
		super();
		if(id != null){
			var scriptPath = Paths.getHScriptPath('cutscenes/$id');
			if(scriptPath != null)
				script = FunkinHScript.fromFile(scriptPath, id, ["this" => this, "add" => this.add, "remove" => this.remove, "insert" => this.insert]);
		}
		onEnd.addOnce((_:Bool) -> {
			callScript("onCutsceneEnd");
		});
	}
	
}