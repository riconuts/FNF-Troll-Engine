import flixel.FlxG;
import flixel.tweens.*;
import flixel.addons.transition.FlxTransitionableState;
import flixel.input.keyboard.FlxKey;

#if DO_AUTO_UPDATE
import Github.Release;
import sys.FileSystem;
#end

#if discord_rpc
import Discord.DiscordClient;
import lime.app.Application;
#end

using StringTools;

// Loads the title screen, alongside some other stuff.

class StartupState extends FlxState
{
	public static var muteKeys:Array<FlxKey> = [FlxKey.ZERO];
	public static var volumeDownKeys:Array<FlxKey> = [FlxKey.NUMPADMINUS, FlxKey.MINUS];
	public static var volumeUpKeys:Array<FlxKey> = [FlxKey.NUMPADPLUS, FlxKey.PLUS];
	public static var fullscreenKeys:Array<FlxKey> = [FlxKey.F11];

	#if final
	public static final nextState:Class<FlxState> = TitleState;
	#else
	@:allow(Main)
	private static var nextState:Class<FlxState> = TitleState;
	#end

    // vv wait this isnt a musicbeatstate LOL!
/* 
	public function new(canBeScripted:Bool = false)
	{
		super();
		this.canBeScripted = false; // << THIS SHOULD NEVER BE SCRIPTED!!!
	} */

	private static var loaded = false;
	public static function load():Void
	{
		if (loaded)
			return;
		loaded = true;

		PlayerSettings.init();

		ClientPrefs.initialize();
		ClientPrefs.load();

		#if DO_AUTO_UPDATE
		getRecentGithubRelease();
		checkOutOfDate();
		clearTemps("./");
		#end

		FlxG.fixedTimestep = false;
		FlxG.keys.preventDefaultKeys = [TAB];
		@:privateAccess
		FlxG.sound.loadSavedPrefs(); // why is flixel not doing this !!!

		#if (windows || linux) // No idea if this also applies to other targets
		FlxG.stage.addEventListener(
			openfl.events.KeyboardEvent.KEY_DOWN, 
			(e)->{
				// Prevent Flixel from listening to key inputs when switching fullscreen mode
				if (e.keyCode == FlxKey.ENTER && e.altKey)
					e.stopImmediatePropagation();

				// Also add F11 to switch fullscreen mode
				if (fullscreenKeys.contains(e.keyCode)){
					FlxG.fullscreen = !FlxG.fullscreen;
					e.stopImmediatePropagation();
				}
			}, 
			false, 
			100
		);

		FlxG.stage.addEventListener(
			openfl.events.FullScreenEvent.FULL_SCREEN, 
			(e)->{
				if(FlxG.save.data != null)
					FlxG.save.data.fullscreen = e.fullScreen;
			}
		);
		#end

		#if html5
		Paths.initPaths();
		#end
		#if hscript
		scripts.FunkinHScript.init();
		#end
		
		#if MODS_ALLOWED
		Paths.pushGlobalContent();
		Paths.getModDirectories();
		Paths.loadRandomMod();
		#end
		
		Highscore.load();

		if (FlxG.save.data.weekCompleted != null)
			StoryMenuState.weekCompleted = FlxG.save.data.weekCompleted;
		
		#if discord_rpc
		if (!DiscordClient.isInitialized){
			DiscordClient.initialize();
			Application.current.onExit.add(function(exitCode)
			{
				DiscordClient.shutdown();
			});
		}
		#end

		FlxTransitionableState.defaultTransIn = FadeTransitionSubstate;
		FlxTransitionableState.defaultTransOut = FadeTransitionSubstate;

		// this shit doesn't work
		Paths.sound("cancelMenu");
		Paths.sound("confirmMenu");
		Paths.sound("scrollMenu");

		Paths.music('freakyIntro');
		Paths.music('freakyMenu');

		/*
		if (nextState == PlayState || nextState == editors.ChartingState){
			Paths.currentModDirectory = "chapter1";
			PlayState.SONG = Song.loadFromJson("no-villains", "no-villains");
		}
		*/
	}

	#if DO_AUTO_UPDATE
	// gets the most recent release and returns it
	// if you dont have download betas on, then it'll exclude prereleases
	static var recentRelease:Release;

	public static function getRecentGithubRelease()
	{
		if (ClientPrefs.checkForUpdates)
		{
			var github:Github = new Github(); // leaving the user and repo blank means it'll derive it from the repo the mod is compiled from
			// if it cant find the repo you compiled in, it'll just default to troll engine's repo
			recentRelease = github.getReleases((release:Release) ->
			{
				return (Main.downloadBetas || !release.prerelease);
			})[0];
			if (FlxG.save.data.ignoredUpdates == null)
			{
				FlxG.save.data.ignoredUpdates = [];
				FlxG.save.flush();
			}
			if (recentRelease != null && FlxG.save.data.ignoredUpdates.contains(recentRelease.tag_name))
				recentRelease = null;

		}else{
			recentRelease = null;
		}

		return Main.recentRelease = recentRelease;
	}

	public static function checkOutOfDate(){
		var outOfDate = false;

		if (ClientPrefs.checkForUpdates && recentRelease != null)
		{
			if (recentRelease.prerelease)
			{
				var tagName = recentRelease.tag_name;
				var split = tagName.split("-");
				var betaVersion = split.length == 1 ? "1" : split.pop();
				var versionName = split.pop();
				outOfDate = (versionName > MainMenuState.engineVersion && betaVersion > MainMenuState.betaVersion)
					|| (MainMenuState.beta && versionName == MainMenuState.engineVersion && betaVersion > MainMenuState.betaVersion)
					|| (versionName > MainMenuState.engineVersion);
			}
			else
			{
				var versionName = recentRelease.tag_name;
				// if you're in beta and version is the same as the engine version, but just not beta
				// then you should absolutely be prompted to update
				outOfDate = MainMenuState.beta && MainMenuState.engineVersion <= versionName || MainMenuState.engineVersion < versionName;
			}
		}

		Main.outOfDate = outOfDate;
		return outOfDate;
	}

	private static function clearTemps(dir:String)
	{
		#if desktop
		for(file in FileSystem.readDirectory(dir)){
			var file = './$dir/$file';
			if(FileSystem.isDirectory(file))
				clearTemps(file);
			else if (file.endsWith(".tempcopy"))
				FileSystem.deleteFile(file);
		}
		#end
	}
	#else
	public static function getRecentGithubRelease()
	{
		Main.recentRelease = null;
		Main.outOfDate = false;
		return null;
	}

	public static function checkOutOfDate(){
		Main.outOfDate = false;
		return false;
	}
	#end


	public function new()
	{
		super();

		persistentDraw = true;
		persistentUpdate = true;
	}

	private var warning:FlxSprite;
	private var step = 0;

	var fadeTwn:FlxTween = null;
	override function update(elapsed)
	{
		// this is kinda stupid but i couldn't find any other way to display the warning while the title screen loaded 
		// could be worse lol
		switch (step){
			case 0:
				warning = new FlxSprite(0, 0, Paths.image("warning"));
				warning.scale.set(0.65, 0.65);
				warning.updateHitbox();
				warning.screenCenter();
				add(warning);

				step = 1;
			case 1:
				var startTime = Sys.cpuTime();

				load();
				if (Reflect.getProperty(nextState, "load") != null)
					Reflect.callMethod(null, Reflect.getProperty(nextState, "load"), []);

				#if debug
				var waitTime:Float = 0;
				#elseif sys
				var waitTime:Float = (nextState == PlayState || nextState == editors.ChartingState) ? 0 : Math.max(0, 1.6 - (startTime - Sys.cpuTime()));
				#else
				var waitTime:Float = 0;
				#end

				fadeTwn = FlxTween.tween(warning, {alpha: 0}, 1, {
					ease: FlxEase.expoIn,
					startDelay: waitTime,
					onComplete: (twn)->{
						step = 5;
					}
				});

				step = 3;
			case 3:
				if ((FlxG.keys.justPressed.ANY || FlxG.mouse.justPressed) && fadeTwn.percent <= 0){
					fadeTwn.startDelay = 0;
					step = 4;
				}

			case 5:
				#if DO_AUTO_UPDATE
				if (Main.outOfDate)
					MusicBeatState.switchState(new UpdaterState(recentRelease)); // UPDATE!!
				else
				#end
				{
					FlxTransitionableState.skipNextTransIn = true;
					FlxTransitionableState.skipNextTransOut = true;
					MusicBeatState.switchState(Type.createInstance(nextState, []));
				}
		}

		super.update(elapsed);
	}
}