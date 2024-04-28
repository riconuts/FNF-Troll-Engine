import flixel.FlxG;
import flixel.tweens.*;
import flixel.addons.transition.FlxTransitionableState;
import flixel.input.keyboard.FlxKey;

#if sys
import Sys.time as getTime;
#else
import haxe.Timer.stamp as getTime;
#end

#if MULTICORE_LOADING
import sys.thread.Thread;
import sys.thread.Mutex;
#end

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

class StartupState extends FlxTransitionableState
{
	public static var muteKeys:Array<FlxKey> = [FlxKey.ZERO];
	public static var volumeDownKeys:Array<FlxKey> = [FlxKey.NUMPADMINUS, FlxKey.MINUS];
	public static var volumeUpKeys:Array<FlxKey> = [FlxKey.NUMPADPLUS, FlxKey.PLUS];
	public static var fullscreenKeys:Array<FlxKey> = [FlxKey.F11];

	public static var nextState:Class<FlxState> = TitleState;

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

		FlxG.sound.volumeHandler = function(vol:Float)
            {
            ClientPrefs.masterVolume = vol;
			Main.volumeChangedEvent.dispatch(vol);
		}
		FlxG.sound.volume = ClientPrefs.masterVolume;

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
		
		#if discord_rpc
		Application.current.onExit.add((exitCode)->{
			DiscordClient.shutdown();
		});
		#end

		FlxTransitionableState.defaultTransIn = FadeTransitionSubstate;
		FlxTransitionableState.defaultTransOut = FadeTransitionSubstate;

		// this shit doesn't work
		Paths.sound("cancelMenu");
		Paths.sound("confirmMenu");
		Paths.sound("scrollMenu");

		Paths.music('freakyIntro');
		Paths.music('freakyMenu');

		Paths.getAllStrings();
        
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
            // hoping this works lol
			var tagName:SemanticVersion = recentRelease.tag_name;
			outOfDate = tagName > Main.semanticVersion;
			trace(tagName, Main.semanticVersion);
/* 			if (recentRelease.prerelease)
			{
                
				var tagName = recentRelease.tag_name;
				var split = tagName.split("-");
				var betaVersion = split.length == 1 ? "1" : split.pop();
				var versionName = split.pop();
				outOfDate = (versionName > Main.engineVersion && betaVersion > Main.betaVersion)
					|| (Main.beta && versionName == Main.engineVersion && betaVersion > Main.betaVersion)
					|| (versionName > Main.engineVersion);
			}
			else
			{
				var versionName = recentRelease.tag_name;
				// if you're in beta and version is the same as the engine version, but just not beta
				// then you should absolutely be prompted to update
				outOfDate = Main.beta && Main.engineVersion <= versionName || Main.engineVersion < versionName;
			} */
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

	override function create()
	{
		#if tgt
		this.transIn = FadeTransitionSubstate;
		//this.transOut = FadeTransitionSubstate;
		FlxTransitionableState.skipNextTransOut = true;

		warning = new FlxSprite(0, 0, Paths.image("warning"));
		warning.scale.set(0.65, 0.65);
		warning.updateHitbox();
		warning.screenCenter();
		add(warning);
		
		#else
		this.transIn = null;
		this.transOut = null;
		// TODO: Default Flixel Startup Animation :]
		#end

		super.create();
	}

	#if tgt
	private var warning:FlxSprite;
	#end

	private var step:Int = 0;
	private var loadingTime:Float = getTime();

	#if MULTICORE_LOADING
	private var loadingMutex:Null<Mutex> = null;
	#end

	inline private function doLoading()
	{
		load();
		final stateLoad:Dynamic = Reflect.getProperty(nextState, "load");
		if (stateLoad != null) Reflect.callMethod(null, stateLoad, []);

		loadingTime = getTime() - loadingTime;
	}

	var fadeTwn:FlxTween = null;
	override function update(elapsed:Float)
	{
		switch (step){
			case 0:
				#if !MULTICORE_LOADING
				doLoading();
				step = 10;

				#else
				if (loadingMutex == null){
					loadingMutex = new Mutex();
					Thread.create(() -> {
						loadingMutex.acquire();
						doLoading();
						loadingMutex.release();
					});
				}
				else if (loadingMutex.tryAcquire()){
					// is this necessary or at least favorable
					loadingMutex.release();
					loadingMutex = null;

					step = 10;
				}
				//else warning.angle += elapsed * 25;
				#end
				
			case 10:
				trace('loading lasted $loadingTime');

				#if !tgt
				step = 50;
				#else

				#if debug
				final waitTime:Float = 0.0;
				#else
				final waitTime:Float = (nextState == PlayState || nextState == editors.ChartingState) ? 0.0 : Math.max(0.0, 1.6 - loadingTime);
				#end

				step = 30;

				fadeTwn = FlxTween.tween(warning, {alpha: 0}, 1.0, {
					ease: FlxEase.expoIn,
					startDelay: waitTime,
					onStart: (twn)->{step = 40;},
					onComplete: (twn)->{step = 50;}
				});
				
			case 30:
				if (FlxG.keys.justPressed.ANY || FlxG.mouse.justPressed){
					fadeTwn.startDelay = 0;
					step = 40;
				}
			case 40:
				if (FlxG.keys.justPressed.ANY || FlxG.mouse.justPressed){
					fadeTwn.percent = (1.0 + fadeTwn.percent) * 0.5;
				}
				#end

			case 50:
				#if DO_AUTO_UPDATE
				if (Main.outOfDate)
					MusicBeatState.switchState(new UpdaterState(recentRelease)); // UPDATE!!
				else
				#end
				{
					/*
					FlxTransitionableState.skipNextTransIn = true;
					FlxTransitionableState.skipNextTransOut = true;
					*/
					MusicBeatState.switchState(Type.createInstance(nextState, []));
				}
		}

		super.update(elapsed);
	}
}