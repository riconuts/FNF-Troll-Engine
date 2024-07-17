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
	private var lastBeat:Float = 0;
	private var lastStep:Float = 0;

	private var curStep:Int = 0;
	private var curBeat:Int = 0;

	private var curDecStep:Float = 0;
	private var curDecBeat:Float = 0;
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

		updateCurStep();
		updateBeat();

		if (oldStep != curStep && curStep > 0)
			stepHit();
	}

	private function updateBeat():Void
	{
		curBeat = Math.floor(curStep / 4);
		curDecBeat = curDecStep/4;
	}

	private function updateCurStep():Void
	{
		var lastChange = Conductor.getBPMFromSeconds(Conductor.songPosition);

		var shit = ((Conductor.songPosition - ClientPrefs.noteOffset) - lastChange.songTime) / lastChange.stepCrochet;
		curDecStep = lastChange.stepTime + shit;
		curStep = lastChange.stepTime + Math.floor(shit);
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
