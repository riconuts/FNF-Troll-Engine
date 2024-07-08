package;

import funkin.*;
import funkin.states.MusicBeatState;
import funkin.states.FadeTransitionSubstate;

import flixel.FlxG;
import flixel.FlxState;
import flixel.FlxSprite;
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
import funkin.states.UpdaterState;
#end

#if discord_rpc
import funkin.api.Discord.DiscordClient;
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
	public static var specialKeysEnabled(default, set):Bool;

	@:noCompletion inline public static function set_specialKeysEnabled(val)
	{
		if (val) {
			FlxG.sound.muteKeys = StartupState.muteKeys;
			FlxG.sound.volumeDownKeys = StartupState.volumeDownKeys;
			FlxG.sound.volumeUpKeys = StartupState.volumeUpKeys;
		}
		else {
			final emptyArr = [];
			FlxG.sound.muteKeys = emptyArr;
			FlxG.sound.volumeDownKeys = emptyArr;
			FlxG.sound.volumeUpKeys = emptyArr;
		}

		return specialKeysEnabled = val;
	}

	public function new()
	{
		super();
		// this.canBeScripted = false; // vv wait this isnt a musicbeatstate LOL!

		persistentDraw = true;
		persistentUpdate = true;
	}

	public static var nextState:Class<FlxState> = funkin.states.TitleState;
	private static var loaded = false;
	public static function load():Void
	{
		if (loaded)
			return;
		loaded = true;

		funkin.input.PlayerSettings.init();
		specialKeysEnabled = true;

		ClientPrefs.initialize();
		ClientPrefs.load();

		FlxG.sound.volume = ClientPrefs.masterVolume;
		FlxG.sound.volumeHandler = (vol:Float)->{
			ClientPrefs.masterVolume = vol;
			Main.volumeChangedEvent.dispatch(vol);
		}

		FlxG.fixedTimestep = false;
		FlxG.keys.preventDefaultKeys = [TAB];

		#if (windows || linux) // No idea if this also applies to any other targets
		FlxG.stage.addEventListener(
			openfl.events.KeyboardEvent.KEY_DOWN, 
			(e)->{
				// Prevent Flixel from listening to key inputs when switching fullscreen mode
				if (e.keyCode == FlxKey.ENTER && e.altKey)
					e.stopImmediatePropagation();

				// Also add F11 to switch fullscreen mode
				if (specialKeysEnabled && fullscreenKeys.contains(e.keyCode))
					FlxG.fullscreen = !FlxG.fullscreen;
			}, 
			false, 
			100
		);

		FlxG.stage.addEventListener(
			openfl.events.FullScreenEvent.FULL_SCREEN, 
			(e) -> FlxG.save.data.fullscreen = e.fullScreen
		);
		#end

		#if DO_AUTO_UPDATE
		UpdaterState.getRecentGithubRelease();
		UpdaterState.checkOutOfDate();
		UpdaterState.clearTemps("./");
		#end

		#if html5
		Paths.initPaths();
		#end
		
		#if MODS_ALLOWED
		Paths.pushGlobalContent();
		Paths.getModDirectories();
		Paths.loadRandomMod();
		#end

		Paths.getAllStrings();
		
		funkin.data.Highscore.load();

		#if hscript
		funkin.scripts.FunkinHScript.init();
		#end
		
		#if discord_rpc
		Application.current.onExit.add((exitCode)->{
			DiscordClient.shutdown();
		});
		#end

		FlxTransitionableState.defaultTransIn = FadeTransitionSubstate;
		FlxTransitionableState.defaultTransOut = FadeTransitionSubstate;
	}

	override function create()
	{
		this.transIn = null;
		this.transOut = null;

		#if tgt
		this.transIn = FadeTransitionSubstate;

		warning = new FlxSprite(0, 0, Paths.image("warning"));
		warning.scale.set(0.65, 0.65);
		warning.updateHitbox();
		warning.screenCenter();
		add(warning);
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
				#end
				
			case 10:
				trace('loading lasted $loadingTime');

				#if !tgt
				step = 50;
				#else

				#if debug
				final waitTime:Float = 0.0;
				#else
				final waitTime:Float = (nextState == funkin.states.PlayState || nextState == funkin.states.editors.ChartingState) ? 0.0 : Math.max(0.0, 1.6 - loadingTime);
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
					MusicBeatState.switchState(new UpdaterState(Main.recentRelease)); // UPDATE!!
				else
				#end
				{
					MusicBeatState.switchState(Type.createInstance(nextState, []));
				}
				step = 100000;
		}

		super.update(elapsed);
	}
}