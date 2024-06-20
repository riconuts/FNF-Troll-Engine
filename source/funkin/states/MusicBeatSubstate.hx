package funkin.states;

import flixel.FlxSubState;
import funkin.input.Controls;

#if SCRIPTABLE_STATES
import funkin.scripts.FunkinHScript;

@:autoBuild(funkin.scripts.Macro.addScriptingCallbacks([
	"create",
	"update",
	"destroy",
	"close",
	"stepHit",
	"beatHit",
], "substates"))
#end
class MusicBeatSubstate extends FlxSubState
{
	#if SCRIPTABLE_STATES
	public var script:FunkinHScript;
	#end

	private var lastBeat:Float = 0;
	private var lastStep:Float = 0;

	private var curStep:Int = 0;
	private var curBeat:Int = 0;

	private var curDecStep:Float = 0;
	private var curDecBeat:Float = 0;
	private var controls(get, never):Controls;

	inline function get_controls():Controls
		return funkin.input.PlayerSettings.player1.controls;
    
	override public function destroy()
	{
		#if SCRIPTABLE_STATES
		if (script != null){
			script.stop();
			script = null;
		}
		#end
		return super.destroy();
	}


	override function update(elapsed:Float)
	{
		var oldStep:Int = curStep;

		updateCurStep();
		updateBeat();

		if (oldStep != curStep && curStep > 0)
			stepHit();


		super.update(elapsed);
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
