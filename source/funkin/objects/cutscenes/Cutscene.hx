package funkin.objects.cutscenes;

import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.util.FlxSignal.FlxTypedSignal;

class Cutscene extends FlxTypedGroup<FlxBasic> {
	public var onEnd:FlxTypedSignal<Bool->Void> = new FlxTypedSignal<Bool->Void>(); // (wasSkipped:Bool)->{}

	public function pause() {}

	public function resume() {}

	public function restart() {}

	public function createCutscene() // gets called by state or w/e
	{
		
	}

	public function new(){
		super();
	}
}