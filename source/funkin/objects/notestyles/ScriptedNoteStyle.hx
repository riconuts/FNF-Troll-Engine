package funkin.objects.notestyles;

import funkin.scripts.FunkinHScript;
import funkin.objects.notestyles.BaseNoteStyle;

// todooooooooo
class ScriptedNoteStyle extends BaseNoteStyle
{
	public static function fromPath(path:String):Null<ScriptedNoteStyle> {
		return Paths.exists(path) ? new ScriptedNoteStyle(FunkinHScript.fromFile(path)) : null;
	}

	public static function fromName(name:String):Null<ScriptedNoteStyle> {
		return fromPath(Paths.getPath('notestyles/$name'));
	}
	
	final script:FunkinHScript;

	private function new(script:FunkinHScript) {
		this.script = script;
		super(script.scriptName); 
	}
}