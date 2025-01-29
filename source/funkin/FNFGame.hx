package funkin;

import Main.resetSpriteCache;
import funkin.scripts.Globals;
import funkin.states.MusicBeatState;

#if CRASH_HANDLER
import haxe.CallStack;
import openfl.events.UncaughtErrorEvent;

#if SAVE_CRASH_LOGS
import sys.io.File;
#end

#if sys
import lime.system.System;
#end

#if (windows && cpp)
import funkin.api.Windows;
#end

#end

#if SCRIPTABLE_STATES
import funkin.states.scripting.HScriptOverridenState;
#end

class FNFGame extends FlxGame
{
	public function new(gameWidth = 0, gameHeight = 0, ?initialState:Class<FlxState>, updateFramerate = 60, drawFramerate = 60, skipSplash = false, ?startFullscreen:Bool)
	{
		@:privateAccess FlxG.initSave();
		startFullscreen = startFullscreen ?? FlxG.save.data.fullscreen;

		super(gameWidth, gameHeight, initialState, updateFramerate, drawFramerate, skipSplash, startFullscreen);
		_customSoundTray = flixel.system.ui.DefaultFlxSoundTray;

		FlxG.sound.volume = FlxG.save.data.volume;
		FlxG.mouse.useSystemCursor = true;
		FlxG.mouse.visible = false;

		// shader coords fix
		function resetSpriteCaches() {
			for (cam in FlxG.cameras.list) {
				if (cam != null && cam.filters != null)
					resetSpriteCache(cam.flashSprite);
			}
			resetSpriteCache(this);
		}

		FlxG.signals.gameResized.add((w, h) -> resetSpriteCaches());
		FlxG.signals.focusGained.add(resetSpriteCaches);

		#if CRASH_HANDLER
		openfl.Lib.current.loaderInfo.uncaughtErrorEvents.addEventListener(
			UncaughtErrorEvent.UNCAUGHT_ERROR, 
			function(event:UncaughtErrorEvent) {
				// one of these oughta do it
				event.stopImmediatePropagation();
				event.stopPropagation();
				event.preventDefault();
				onCrash(event.error);
			}
		);

		#if cpp
		untyped __global__.__hxcpp_set_critical_error_handler(onCrash);
		#end
		#end
	}

	override function update():Void
	{
		super.update();

		if (FlxG.keys.justPressed.F5)
			MusicBeatState.resetState();
	}

	override function switchState():Void
	{
		#if SCRIPTABLE_STATES
		if (_requestedState is MusicBeatState)
		{
			var ogState:MusicBeatState = cast _requestedState;
			var nuState = HScriptOverridenState.requestOverride(ogState);
			
			if (nuState != null) {
				ogState.destroy();
				_requestedState = nuState;
			}
		}
		#end

		Globals.variables.clear();
		super.switchState();
	}

	#if CRASH_HANDLER
	private function onCrash(errorName:String):Void {
		print("\nCall stack starts below");

		var callstack:String = "";
		for (stackItem in CallStack.exceptionStack(true)) {
			switch (stackItem) {
				case FilePos(s, file, line, column):
					callstack += '$file:$line\n';
				default:
			}
		}

		print('\n$callstack\n$errorName');

		////
		var boxMessage:String = '$callstack\n$errorName';

		#if SAVE_CRASH_LOGS
		final fileName:String = "crash.txt";
		boxMessage += '\nCall stack was saved as $fileName';
		File.saveContent(fileName, callstack);
		#end

		#if WINDOWS_CRASH_HANDLER
		boxMessage += "\nWould you like to goto the main menu?";
		var ret = Windows.msgBox(boxMessage, errorName, ERROR | MessageBoxOptions.YESNOCANCEL | MessageBoxDefaultButton.BUTTON3);
		
		switch(ret) {
			case YES: 
				toMainMenu();
				return;
			case CANCEL: 
				// Continue with a possibly unstable state
				return;
			default:
				// Close the game
		}
		#else
		lime.app.Application.current.window.alert(callstack, errorName);
		#end

		#if sys 
		System.exit(1);
		#end
	}

	@:unreflective private function toMainMenu() {
		try{
			if (_state != null) {
				_state.destroy();
				_state = null;
			}
		}catch(e){
			print("Error destroying state: ", e);
		}	
		
		_requestedState = new funkin.states.MainMenuState();
		switchState();
	}
	#end
}