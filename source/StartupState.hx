import flixel.FlxG;
import flixel.input.keyboard.FlxKey;
import flixel.util.FlxTimer;
import flixel.addons.transition.FlxTransitionableState;

class StartupState extends MusicBeatState
{
    // idk why i did this

    public static var muteKeys:Array<FlxKey> = [FlxKey.ZERO];
	public static var volumeDownKeys:Array<FlxKey> = [FlxKey.NUMPADMINUS, FlxKey.MINUS];
	public static var volumeUpKeys:Array<FlxKey> = [FlxKey.NUMPADPLUS, FlxKey.PLUS];

    override public function create():Void
    {
        scripts.FunkinHScript.init();
		Paths.clearStoredMemory();
		Paths.clearUnusedMemory();

		#if LUA_ALLOWED
		Paths.pushGlobalMods();
		#end
		// Just to load a mod on start up if ya got one. For mods that change the menu music and bg
		WeekData.loadTheFirstEnabledMod();

        FlxG.game.focusLostFramerate = 60;
		FlxG.sound.muteKeys = muteKeys;
		FlxG.sound.volumeDownKeys = volumeDownKeys;
		FlxG.sound.volumeUpKeys = volumeUpKeys;
		FlxG.keys.preventDefaultKeys = [TAB];

		PlayerSettings.init();

        super.create();
        
        FlxG.save.bind('funkin', 'ninjamuffin99');

		ClientPrefs.loadPrefs();

		Highscore.load();

        CoolUtil.precacheMusic("freakyIntro");
        CoolUtil.precacheMusic("freakyMenu");
        CoolUtil.precacheSound("cancelMenu");
        CoolUtil.precacheSound("confirmMenu");
        CoolUtil.precacheSound("scrollMenu");

        FlxTransitionableState.defaultTransIn = FadeTransitionSubstate;
        FlxTransitionableState.defaultTransOut = FadeTransitionSubstate;

        if(FlxG.save.data != null && FlxG.save.data.fullscreen)
        {
            FlxG.fullscreen = FlxG.save.data.fullscreen;
        }

        if(FlxG.save.data.flashing == null && !FlashingState.leftState){
			MusicBeatState.switchState(new FlashingState());
        }else{
            new FlxTimer().start(1, function(tmr:FlxTimer)
            {
                MusicBeatState.switchState(new TitleState());
            });
        }
    }
}