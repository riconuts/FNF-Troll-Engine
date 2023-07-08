package;

import Github.Release;
import sowy.Sowy;
import openfl.system.Capabilities;
import flixel.FlxG;
import flixel.FlxGame;
import flixel.FlxState;
import openfl.Lib;
import openfl.display.FPS;
import openfl.display.Sprite;
import openfl.display.StageScaleMode;
import openfl.events.Event;
using StringTools;
#if CRASH_HANDLER
import haxe.CallStack;
import lime.app.Application;
import openfl.events.UncaughtErrorEvent;
import sys.io.File;
#end
#if discord_rpc
import Discord.DiscordClient;
#end

class Main extends Sprite
{
	public static var UserAgent:String = 'TrollEngine/${MainMenuState.engineVersion}'; // used for http requests. if you end up forking the engine and making your own then make sure to change this!!
	public static var githubRepo = Github.getCompiledRepoInfo();
	public static var downloadBetas:Bool = MainMenuState.beta;
	public static var outOfDate:Bool = false;
	public static var recentRelease:Release;
	
	public static var showDebugTraces:Bool = #if(SHOW_DEBUG_TRACES || debug) true #else false #end;
	var gameWidth:Int = 1280; // Width of the game in pixels (might be less / more in actual pixels depending on your zoom).
	var gameHeight:Int = 720; // Height of the game in pixels (might be less / more in actual pixels depending on your zoom).
	var initialState:Class<FlxState> = StartupState; // The FlxState the game starts with.
	var zoom:Float = -1; // If -1, zoom is automatically calculated to fit the window dimensions.
	var framerate:Int = 60; // How many frames per second the game should run at.
	var skipSplash:Bool = true; // Whether to skip the flixel splash screen that appears in release mode.
	var startFullscreen:Bool = false; // Whether to start the game in fullscreen on desktop targets
	public static var fpsVar:FPS;
	public static var bread:Bread;

	// You can pretty much ignore everything from here on - your code should go in your states.

	public static function checkOutOfDate(){
		if (recentRelease != null)
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
	
	public static function main():Void
	{
		Lib.current.addChild(new Main());
	}

	public function new()
	{
		super();

		if (stage != null)
		{
			init();
		}
		else
		{
			addEventListener(Event.ADDED_TO_STAGE, init);
		}
	}

	private function init(?E:Event):Void
	{
		if (hasEventListener(Event.ADDED_TO_STAGE))
			removeEventListener(Event.ADDED_TO_STAGE, init);

		setupGame();
	}

	public static function setScaleMode(scale:String){
		switch(scale){
			default:
				Lib.current.stage.scaleMode = StageScaleMode.NO_SCALE;
			case 'EXACT_FIT':
				Lib.current.stage.scaleMode = StageScaleMode.EXACT_FIT;
			case 'NO_BORDER':
				Lib.current.stage.scaleMode = StageScaleMode.NO_BORDER;
			case 'SHOW_ALL':
				Lib.current.stage.scaleMode = StageScaleMode.SHOW_ALL;
		}
	}

	private function setupGame():Void
	{
		//// Readjust the game size for smaller screens
		if (zoom == -1)
		{
			var screenWidth = Capabilities.screenResolutionX;
			var screenHeight = Capabilities.screenResolutionY;

			if (!(screenWidth > gameWidth || screenHeight > gameWidth)){
				var ratioX:Float = screenWidth / gameWidth;
				var ratioY:Float = screenHeight / gameHeight;
				
				zoom = Math.min(ratioX, ratioY);
				gameWidth = Math.ceil(screenWidth / zoom);
				gameHeight = Math.ceil(screenHeight / zoom);
			}
		}
	
		////
		ClientPrefs.loadDefaultKeys();
		
		var troll = false;
		#if sys
		for (arg in Sys.args()){
			switch(arg){
				case "troll":
					troll = true;
					break;
				
				case "debug":
					PlayState.chartingMode = true;
					initialState = SongSelectState;
				
				case "showdebugtraces":
					Main.showDebugTraces = true;
			}
		}
		#end

		if (troll){
			initialState = SinnerState;
			skipSplash = true;
		}else{
			@:privateAccess
			FlxG.initSave();

			if (FlxG.save.data != null && FlxG.save.data.fullscreen != null)
				startFullscreen = FlxG.save.data.fullscreen;
		}
		
		addChild(new FlxGame(gameWidth, gameHeight, initialState, #if(flixel < "5.0.0") zoom, #end framerate, framerate, skipSplash, startFullscreen));
		
		// 
		@:privateAccess
		FlxG.sound.loadSavedPrefs();

		FlxG.sound.muteKeys = StartupState.muteKeys;
		FlxG.sound.volumeDownKeys = StartupState.volumeDownKeys;
		FlxG.sound.volumeUpKeys = StartupState.volumeUpKeys;
		FlxG.keys.preventDefaultKeys = [TAB];

		FlxG.mouse.useSystemCursor = true;
		FlxG.mouse.visible = false;
		
		if (!troll){
			#if !mobile
			fpsVar = new FPS(10, 3, 0xFFFFFF);
			fpsVar.visible = false;
			addChild(fpsVar);
			
			Lib.current.stage.align = "tl";
			Lib.current.stage.scaleMode = StageScaleMode.NO_SCALE;
			#end

			bread = new Bread();
			bread.visible = false;
			addChild(bread);
		}
		
		#if CRASH_HANDLER
		Lib.current.loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR, onCrash);
		#end
	}

	// Original code was made by sqirra-rng, big props to them!!!
	#if CRASH_HANDLER
	function onCrash(e:UncaughtErrorEvent):Void
	{
		Sys.println("Call stack starts below");

		var errMsg:String = "";
		var callStack:Array<StackItem> = CallStack.exceptionStack(true);

		for (stackItem in callStack)
		{
			switch (stackItem)
			{
				case FilePos(s, file, line, column):
					errMsg += '$file:$line\n';
				default:
					Sys.println(stackItem);
			}
		}

		errMsg += "\nUncaught Error: " + e.error;

		Sys.println(" \n" + errMsg);
		File.saveContent("crash.txt", errMsg);
		
		Application.current.window.alert(errMsg, "Error!");

		DiscordClient.shutdown();
		Sys.exit(1);
	}
	#end
}