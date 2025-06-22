package;

import funkin.*;
import funkin.states.MusicBeatState;
import funkin.states.FadeTransitionSubstate;

import funkin.data.Highscore;
import funkin.input.PlayerSettings;

import flixel.FlxG;
import flixel.FlxState;
import flixel.tweens.*;
import flixel.addons.transition.FlxTransitionableState;

#if sys
import Sys.time as getTime;
#else
import haxe.Timer.stamp as getTime;
#end

#if MULTICORE_LOADING
import sys.thread.Thread;
import sys.thread.Mutex;
#end

#if (DO_AUTO_UPDATE || display)
import funkin.states.UpdaterState;
#end

using StringTools;

// Loads the title screen, alongside some other stuff.

class StartupState extends FlxTransitionableState
{
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

		Paths.init();
		PlayerSettings.init();
		
		ClientPrefs.initialize();
		ClientPrefs.load();

		Highscore.load();

		FNFGame.specialKeysEnabled = true;
		FlxG.keys.preventDefaultKeys = [TAB];
		FlxG.fixedTimestep = false;

		#if (DO_AUTO_UPDATE || display)
		UpdaterState.getRecentGithubRelease();
		UpdaterState.checkOutOfDate();
		UpdaterState.clearTemps("./");
		#end
		
		#if DISCORD_ALLOWED
		FlxG.stage.application.onExit.add((exitCode) -> funkin.api.Discord.DiscordClient.shutdown(true));
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
				
			#if !tgt
			case 10:
				trace('loading lasted $loadingTime');
				step = 50;
			#end
			
			#if tgt
			case 10:
				trace('loading lasted $loadingTime');
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
				#if(DO_AUTO_UPDATE || display)
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