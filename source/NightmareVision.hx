package;

import funkin.states.PlayState.RatingManager;
import funkin.states.scripting.HScriptedState;
import funkin.Paths;

class NightmareVision extends HScriptedState
{
	public function new()
	{
		var vars:Map<String, Dynamic> = [
			"RatingManager" => RatingManager
		];

		super('Test.hscript', vars);
	}
}