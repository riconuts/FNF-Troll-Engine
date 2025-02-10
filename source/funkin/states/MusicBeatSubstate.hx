package funkin.states;

import funkin.scripts.FunkinHScript;
import funkin.input.Controls;
import flixel.FlxSubState;

@:autoBuild(funkin.macros.ScriptingMacro.addScriptingCallbacks([
	"create",
	"update",
	"destroy",
	"close",
	"openSubState",
	"closeSubState",
	"stepHit",
	"beatHit",
], "substates"))
class MusicBeatSubstate extends FlxSubState
{
	public var canBeScripted(get, default):Bool = true;
	@:noCompletion function get_canBeScripted() return canBeScripted;

	//// To be defined by the scripting macro
	@:noCompletion public var _extensionScript:FunkinHScript;

	@:noCompletion public function _getScriptDefaultVars() 
		return new Map<String, Dynamic>();

	@:noCompletion public function _startExtensionScript(folder:String, scriptName:String) 
		return;

	////
	#if true
	private var curStep(get, set):Int;
	private var curBeat(get, set):Int;
	private var curDecStep(get, set):Float;
	private var curDecBeat(get, set):Float;
	@:noCompletion function get_curStep() return Conductor.curStep;
	@:noCompletion function get_curBeat() return Conductor.curBeat;
	@:noCompletion function get_curDecStep() return Conductor.curDecStep;
	@:noCompletion function get_curDecBeat() return Conductor.curDecBeat;
	@:noCompletion function set_curStep(v) return Conductor.curStep=v;
	@:noCompletion function set_curBeat(v) return Conductor.curBeat=v;
	@:noCompletion function set_curDecStep(v) return Conductor.curDecStep=v;
	@:noCompletion function set_curDecBeat(v) return Conductor.curDecBeat=v;
	#end

	private var controls(get, never):Controls;

	inline function get_controls():Controls
		return funkin.input.PlayerSettings.player1.controls;

	override function update(elapsed:Float)
	{		
		updateSteps();

		super.update(elapsed);
	}

	private function updateSteps() {
		var oldStep:Int = curStep;

		Conductor.updateSteps();

		if (oldStep != curStep && curStep > 0)
			stepHit();
	}

	public function stepHit():Void
	{
		if (curStep % 4 == 0)
			beatHit();
	}

	public function beatHit():Void
	{
		//do literally nothing dumbass
	}
}
