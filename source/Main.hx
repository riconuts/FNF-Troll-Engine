package;

import flixel.FlxG;
import flixel.FlxState;
import openfl.Lib;
import openfl.display.FPS;
import openfl.display.Sprite;
import openfl.display.StageScaleMode;
import openfl.system.Capabilities;
import openfl.events.Event;
import lime.app.Application;
import haxe.Constraints.Function;

import funkin.*;
import funkin.api.Github;
import funkin.macros.Sowy;
import funkin.data.SemanticVersion;
import funkin.objects.Bread;

using StringTools;

#if DISCORD_ALLOWED
import funkin.api.Discord.DiscordClient;
#end

#if CRASH_HANDLER
import openfl.events.UncaughtErrorEvent;
import haxe.CallStack;

#if sys
import sys.io.File;
#end

#if (windows && cpp)
import funkin.api.Windows;
#end
#end

final class Version
{
	public static final engineVersion:String = '0.2.0'; // Used for autoupdating n stuff
	public static final betaVersion:String = 'rc.1'; // beta version, set it to 0 if not on a beta version, otherwise do it based on semantic versioning (alpha.1, beta.1, rc.1, etc)
	public static final isBeta:Bool = betaVersion != '0';

	public static final buildCode:String = Sowy.getBuildDate();
	public static final githubRepo:RepoInfo = Github.getCompiledRepoInfo();
	
	public static final semanticVersion:SemanticVersion = isBeta ? '$engineVersion-$betaVersion' : engineVersion;
	public static final displayedVersion:String = 'v$semanticVersion';
}

class Main extends Sprite
{
	var gameWidth:Int = 1280; // Width of the game in pixels (might be less / more in actual pixels depending on your zoom).
	var gameHeight:Int = 720; // Height of the game in pixels (might be less / more in actual pixels depending on your zoom).
	var initialState:Class<FlxState> = StartupState; // The FlxState the game starts with.
	var nextState:Class<FlxState> = funkin.states.TitleState; 
	var zoom:Float = -1; // If -1, zoom is automatically calculated to fit the window dimensions.
	var framerate:Int = 60; // How many frames per second the game should run at.
	var skipSplash:Bool = true; // Whether to skip the flixel splash screen that appears in release mode.
	var startFullscreen:Bool = false; // Whether to start the game in fullscreen on desktop targets

	//// You can pretty much ignore everything from here on - your code should go in your states.

	////
	public static final UserAgent:String = 'TrollEngine/${Version.engineVersion}'; // used for http requests. if you end up forking the engine and making your own then make sure to change this!!
	public static final volumeChangedEvent = new lime.app.Event<Float->Void>();

	////
	public static var showDebugTraces:Bool = #if (debug || SHOW_DEBUG_TRACES) true #else false #end;
	public static var downloadBetas:Bool = Version.isBeta;
	public static var outOfDate:Bool = false;
	public static var recentRelease:Release;

	////
	public static var fpsVar:FPS;
	public static var bread:Bread;

	////
	public static function main():Void
	{
		Lib.current.addChild(new Main());
	}

	public function new()
	{	
		super();

		////
		#if sys
		var args = Sys.args();
		trace(args);
		for (arg in args){
			switch(arg){
				case "troll":
					#if tgt
					initialState = funkin.tgt.SinnerState;
					#end

				case "songselect":
					nextState = funkin.states.SongSelectState;

				case "debug":
					funkin.states.PlayState.chartingMode = true;

				case "showdebugtraces":
					Main.showDebugTraces = true;

				default:
					/*
					if (arg.startsWith('song:')) {
						var split = arg.split(':');
						var metadata = new funkin.data.Song.SongMetadata(split[1], split[2]);
						var playSongFunc = funkin.data.Song.playSong.bind(metadata, split[3], Std.parseInt(split[4]));

						trace("starting w song: "+split);

						initialState = flixel.FlxState;
						FlxG.signals.postStateSwitch.add(()->{
							StartupState.load();
							playSongFunc();			
						});
					}
					*/
			}
		}
		#end

		{
			final screenWidth = Capabilities.screenResolutionX;
			final screenHeight = Capabilities.screenResolutionY;
	
			//// Readjust the game size for smaller screens
			if (zoom == -1)
			{
				if (!(screenWidth > gameWidth || screenHeight > gameWidth)){
					var ratioX:Float = screenWidth / gameWidth;
					var ratioY:Float = screenHeight / gameHeight;
					
					zoom = Math.min(ratioX, ratioY);
					gameWidth = Math.ceil(screenWidth / zoom);
					gameHeight = Math.ceil(screenHeight / zoom);
				}
			}

			//// Readjust the window size for larger screens 
			var scaleFactor:Int = Math.floor((screenWidth > screenHeight) ? (screenHeight / gameHeight) : (screenWidth / gameWidth));
			if (scaleFactor < 1) scaleFactor = 1;

			final windowWidth:Int = scaleFactor * gameWidth;
			final windowHeight:Int = scaleFactor * gameHeight;

			Application.current.window.resize(
				windowWidth, 
				windowHeight
			);
			Application.current.window.move(
				Std.int((screenWidth - windowWidth) / 2),
				Std.int((screenHeight - windowHeight) / 2)
			);

			////
			@:privateAccess
			FlxG.initSave();
			startFullscreen = FlxG.save.data.fullscreen;
		}
		
		StartupState.nextState = nextState;
		addChild(new FNFGame(gameWidth, gameHeight, initialState, #if(flixel < "5.0.0") zoom, #end framerate, framerate, skipSplash, startFullscreen));

		FlxG.mouse.useSystemCursor = true;
		FlxG.mouse.visible = false;

		fpsVar = new FPS(10, 3, 0xFFFFFF);
		fpsVar.visible = false;
		addChild(fpsVar);

		bread = new Bread();
		bread.visible = false;
		addChild(bread);

		#if CRASH_HANDLER
		// Original code was made by sqirra-rng, big props to them!!!
		Lib.current.loaderInfo.uncaughtErrorEvents.addEventListener(
			UncaughtErrorEvent.UNCAUGHT_ERROR, 
			(event:UncaughtErrorEvent) -> {
				// one of these oughta do it
				event.stopImmediatePropagation();
				event.stopPropagation();
				event.preventDefault();
				onCrash(event.error);
			}
		);

		#if cpp
		// Thank you EliteMasterEric, very cool!
		untyped __global__.__hxcpp_set_critical_error_handler(onCrash);
		#end
		#end
	}

	#if (!no_traces && (js || lua || sys))
	private inline static function _printStr(str){
		#if js
		if (js.Syntax.typeof(untyped console) != "undefined" && (untyped console).log != null)
			(untyped console).log(str);
		#elseif lua
		untyped __define_feature__("use._hx_print", _hx_print(str));
		#elseif sys
		Sys.println(str);
		#end
	}
	private static function _printArgsArray(args:Array<Dynamic>)
		_printStr(args.join(', '));

	public static final print:Function = Reflect.makeVarArgs(_printArgsArray);
	#else
	public static final print:Function = ()->{};
	#end

	#if CRASH_HANDLER
	private static function onCrash(errorName:String):Void
	{
		////
		print("\nCall stack starts below");

		var callstack:String = "";

		for (stackItem in CallStack.exceptionStack(true))
		{
			switch (stackItem)
			{
				case FilePos(s, file, line, column):
					callstack += '$file:$line\n';
				default:
			}
		}

		callstack += '\n$errorName';

		print('\n$callstack\n');

		#if (windows && cpp)
		var ret = Windows.msgBox(callstack, errorName, ERROR | MessageBoxOptions.YESNOCANCEL);
		switch(ret){
			default: // Close program.

			case NO: // Return to Main Menu.
			@:privateAccess{
				FlxG.game._requestedState = new funkin.states.MainMenuState();
				FlxG.game.switchState();
				return;
			}
			case CANCEL: // Continue with a possibly unstable state
				return;
		}
		#else
		Application.current.window.alert(callstack, errorName);
		#end

		#if DISCORD_ALLOWED
		DiscordClient.shutdown(true);
		#end

		#if sys
		File.saveContent("crash.txt", callstack);
		Sys.exit(1);
		#end
	}
	#end
}
