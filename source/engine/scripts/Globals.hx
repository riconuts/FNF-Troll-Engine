package scripts;

class Globals
{
	public static var Function_Stop:String = 'FUNC_STOP';
	public static var Function_Continue:String = 'FUNC_CONT'; // i take back what i said
	public static var Function_Halt:String = 'FUNC_HALT';

	public static inline function getInstance()
	{
		return PlayState.instance.isDead ? GameOverSubstate.instance : PlayState.instance;
	}

	public static var variables:Map<String, Dynamic> = new Map(); // it MAKES WAY MORE SENSE FOR THIS TO BE HERE THAN IN PLAYSTATE GRRR BARK BARK
}