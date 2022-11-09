import flixel.FlxG;
import flixel.addons.transition.FlxTransitionableState;
import flixel.input.keyboard.FlxKey;
import flixel.util.FlxTimer;

// A state that starts up most of the variables that the game uses
// would add a loading screen here if there was anything that needed a considerable amount to load

class StartupState extends MusicBeatState
{
	public static var muteKeys:Array<FlxKey> = [FlxKey.ZERO];
	public static var volumeDownKeys:Array<FlxKey> = [FlxKey.NUMPADMINUS, FlxKey.MINUS];
	public static var volumeUpKeys:Array<FlxKey> = [FlxKey.NUMPADPLUS, FlxKey.PLUS];

	override public function create():Void
	{
		scripts.FunkinHScript.init();
		Paths.clearStoredMemory();
		Paths.clearUnusedMemory();
		
		Paths.getModDirectories();
		Paths.loadRandomMod();
		
		//FlxG.game.focusLostFramerate = 60;
		FlxG.sound.muteKeys = muteKeys;
		FlxG.sound.volumeDownKeys = volumeDownKeys;
		FlxG.sound.volumeUpKeys = volumeUpKeys;
		FlxG.keys.preventDefaultKeys = [TAB];
		
		PlayerSettings.init();
		
		FlxG.save.bind('funkin', 'ninjamuffin99');
		
		ClientPrefs.loadPrefs();
		
		Highscore.load();

		super.create();

		FlxTransitionableState.defaultTransIn = FadeTransitionSubstate;
		FlxTransitionableState.defaultTransOut = FadeTransitionSubstate;
		
		// this shit doesn't work
		CoolUtil.precacheMusic("freakyIntro");
		CoolUtil.precacheMusic("freakyMenu");
		
		CoolUtil.precacheSound("cancelMenu");
		CoolUtil.precacheSound("confirmMenu");
		CoolUtil.precacheSound("scrollMenu");

		//
		Paths.music('freakyIntro');
		Paths.music('freakyMenu');

		/*
		if(FlxG.save.data != null && FlxG.save.data.fullscreen){
			FlxG.fullscreen = FlxG.save.data.fullscreen;
		}
		*/
		
		MusicBeatState.switchState(new TitleState());
	}
}