package scripts;

using StringTools;

class Globals {
	public static var Function_Stop:Dynamic = '#FUNC_STOP';
	public static var Function_Continue:Dynamic = '#FUNC_CONT'; // apparently if this is anything other than 0 the entire engine kills itself
	// fun
	// god psych lua is like they/them blue hair with pro nouns liberals.. FRAGILE.. SNOWFLAKES...
	public static var Function_Halt:Dynamic = '#FUNC_HALT';

	public static inline function getInstance()
	{
		return PlayState.instance.isDead ? GameOverSubstate.instance : PlayState.instance;
	}
}