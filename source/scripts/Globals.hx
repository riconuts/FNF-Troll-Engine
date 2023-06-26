package scripts;

using StringTools;

class Globals {
	public static var Function_Stop:Dynamic = '#FUNC_STOP';
	public static var Function_Continue:Dynamic = '#FUNC_CONT'; // i take back what i said
	public static var Function_Halt:Dynamic = '#FUNC_HALT';

	public static inline function getInstance()
	{
		return PlayState.instance.isDead ? GameOverSubstate.instance : PlayState.instance;
	}
}