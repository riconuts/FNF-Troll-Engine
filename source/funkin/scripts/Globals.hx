package funkin.scripts;

import funkin.states.PlayState;
import funkin.states.GameOverSubstate;

class Globals
{
	public static final Function_Stop:String = 'FUNC_STOP';
	public static final Function_Continue:String = 'FUNC_CONT'; // i take back what i said
	public static final Function_Halt:String = 'FUNC_HALT';

	public static final variables:Map<String, Dynamic> = new Map(); // it MAKES WAY MORE SENSE FOR THIS TO BE HERE THAN IN PLAYSTATE GRRR BARK BARK
	
	public static final persistentVariables:Map<String, Dynamic> = new Map(); // These don't get wiped on state change
	public static inline function getInstance()
	{
		return PlayState.instance.isDead ? GameOverSubstate.instance : PlayState.instance;
	}
}