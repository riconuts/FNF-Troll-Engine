import flixel.FlxG;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.addons.transition.FlxTransitionableState;
import flixel.input.keyboard.FlxKey;

#if desktop
import Discord.DiscordClient;
import lime.app.Application;
#end

// Loads the title screen, alongside some other stuff.

class StartupState extends FlxState
{
	public static var muteKeys:Array<FlxKey> = [FlxKey.ZERO];
	public static var volumeDownKeys:Array<FlxKey> = [FlxKey.NUMPADMINUS, FlxKey.MINUS];
	public static var volumeUpKeys:Array<FlxKey> = [FlxKey.NUMPADPLUS, FlxKey.PLUS];

	static var loaded = false;

	public static function load():Void
	{
		if (loaded)
			return;

		loaded = true;

		#if html5
		Paths.initPaths();
		#end
		#if hscript
		scripts.FunkinHScript.init();
		#end
		
		#if MODS_ALLOWED
		Paths.getModDirectories();
		Paths.loadRandomMod();
		#end
		
		PlayerSettings.init();
		
		Highscore.load();

		FlxTransitionableState.defaultTransIn = FadeTransitionSubstate;
		FlxTransitionableState.defaultTransOut = FadeTransitionSubstate;
		
		// this shit doesn't work
		#if desktop
		Paths.sound("cancelMenu");
		Paths.sound("confirmMenu");
		Paths.sound("scrollMenu");

		Paths.music('freakyIntro');
		Paths.music('freakyMenu');
		#end

		ClientPrefs.initialize();
		ClientPrefs.load();

		if (Main.fpsVar != null)
			Main.fpsVar.visible = ClientPrefs.showFPS;

		if (FlxG.save.data.weekCompleted != null)
			StoryMenuState.weekCompleted = FlxG.save.data.weekCompleted;

		#if desktop
		if (!DiscordClient.isInitialized){
			DiscordClient.initialize();
			Application.current.onExit.add(function(exitCode)
			{
				DiscordClient.shutdown();
			});
		}
		#end
	}

	public function new(){
		super();
		
		FlxTransitionableState.skipNextTransIn = true;
		FlxTransitionableState.skipNextTransOut = true;

		persistentDraw = true;
		persistentUpdate = true;

		FlxG.fixedTimestep = false;
	}

	private var warning:FlxSprite;
	private var step = 0;

	override function update(elapsed)
	{
		// this is kinda stupid but i couldn't find any other way to display the warning while the title screen loaded 
		// could be worse lol
 		switch (step){
			case 0:
 				warning = new FlxSprite().loadGraphic(Paths.image("warning"));
				warning.scale.set(0.65, 0.65);
				warning.updateHitbox();
				warning.screenCenter();
				add(warning); 

				//MusicBeatState.switchState(new editors.StageBuilderState());
				step = 1;
			case 1:
 				load();
				TitleState.load();
				
				var waitTime = 1.5 - Sys.cpuTime();
				if (waitTime > 0) Sys.sleep(waitTime);
				
				step = 2;
			case 2:
 				FlxTween.tween(warning, {alpha: 0}, 1, {ease: FlxEase.expoIn, onComplete: function(twn){
					MusicBeatState.switchState(new TitleState());
				}});
				step = 3; 

		}

		super.update(elapsed);
	}
}