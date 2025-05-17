package funkin;

import funkin.scripts.Globals;
import funkin.states.MusicBeatState;

import flixel.util.typeLimit.NextState;
import flixel.input.keyboard.FlxKey;

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
	public static var muteKeys:Array<FlxKey> = [FlxKey.ZERO];
	public static var volumeDownKeys:Array<FlxKey> = [FlxKey.NUMPADMINUS, FlxKey.MINUS];
	public static var volumeUpKeys:Array<FlxKey> = [FlxKey.NUMPADPLUS, FlxKey.PLUS];
	public static var fullscreenKeys:Array<FlxKey> = [FlxKey.F11];
	public static var specialKeysEnabled(default, set):Bool;

	@:noCompletion inline public static function set_specialKeysEnabled(val)
	{
		if (val) {
			FlxG.sound.muteKeys = muteKeys;
			FlxG.sound.volumeDownKeys = volumeDownKeys;
			FlxG.sound.volumeUpKeys = volumeUpKeys;
		}
		else {
			FlxG.sound.muteKeys = [];
			FlxG.sound.volumeDownKeys = [];
			FlxG.sound.volumeUpKeys = [];
		}

		return specialKeysEnabled = val;
	}

	public function new(gameWidth = 0, gameHeight = 0, ?initialState:InitialState, updateFramerate = 60, drawFramerate = 60, skipSplash = false, ?startFullscreen:Bool)
	{
		@:privateAccess FlxG.initSave();
		startFullscreen = startFullscreen ?? FlxG.save.data.fullscreen;

		super(gameWidth, gameHeight, initialState, updateFramerate, drawFramerate, skipSplash, startFullscreen);
		_customSoundTray = flixel.system.ui.DefaultFlxSoundTray;

		FlxG.sound.volume = FlxG.save.data.volume;
		FlxG.mouse.useSystemCursor = true;
		FlxG.mouse.visible = false;

		////
		FlxG.signals.gameResized.add((w, h) -> resetSpriteCache());
		FlxG.signals.focusGained.add(resetSpriteCache);

		////
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

		////
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
			if(FlxG.keys.pressed.SHIFT)
				FlxG.switchState(new funkin.states.MainMenuState());
			else
				MusicBeatState.resetState();
	}

	/*
	public var f_ticks:Float = 0;
	var f_startTime:Float = 0;
	var f_total:Float = 0;

	inline function f_getTicks():Float
		return Main.getTime() - f_startTime;

	override function create(_) {
		f_startTime = Main.getTime();
		f_total = f_getTicks();
		return super.create(_);
	}

	override function onEnterFrame(_):Void
	{
		ticks = Math.floor(f_ticks = f_getTicks());
		_elapsedMS = f_ticks - f_total;
		_total = Math.floor(f_total = f_ticks);

		#if FLX_SOUND_TRAY
		if (soundTray != null && soundTray.active)
			soundTray.update(_elapsedMS);
		#end

		if (!_lostFocus || !FlxG.autoPause)
		{
			if (FlxG.vcr.paused)
			{
				if (FlxG.vcr.stepRequested)
				{
					FlxG.vcr.stepRequested = false;
				}
				else if (_nextState == null) // don't pause a state switch request
				{
					#if FLX_DEBUG
					debugger.update();
					// If the interactive debug is active, the screen must
					// be rendered because the user might be doing changes
					// to game objects (e.g. moving things around).
					if (debugger.interaction.isActive())
					{
						draw();
					}
					#end
					return;
				}
			}

			if (FlxG.fixedTimestep)
			{
				_accumulator += _elapsedMS;
				_accumulator = (_accumulator > _maxAccumulation) ? _maxAccumulation : _accumulator;

				while (_accumulator >= _stepMS)
				{
					step();
					_accumulator -= _stepMS;
				}
			}
			else
			{
				step();
			}

			#if FLX_DEBUG
			FlxBasic.visibleCount = 0;
			#end

			draw();

			#if FLX_DEBUG
			debugger.stats.visibleObjects(FlxBasic.visibleCount);
			debugger.update();
			#end
		}
	}
	*/

	override function switchState():Void
	{
		#if SCRIPTABLE_STATES
		if (_nextState is MusicBeatState)
		{
			var ogState:MusicBeatState = cast _nextState;
			var nuState = HScriptOverridenState.requestOverride(ogState);
			
			if (nuState != null) {
				ogState.destroy();
				_nextState = nuState;
			}
		}
		#end

		Globals.variables.clear();
		super.switchState();
	}

	// shader coords fix
	private function resetSpriteCache() {
		for (cam in FlxG.cameras.list) {
			if (cam != null && cam.filters != null)
				Main.resetSpriteCache(cam.flashSprite);
		}
		Main.resetSpriteCache(this);
	}

	#if CRASH_HANDLER
	private function onCrash(errorName:String):Void {
		print("\nCall stack starts below");

		var callstack:String = Main.callstackToString(CallStack.exceptionStack(true));
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
		
		FlxG.game._nextState = new funkin.states.MainMenuState();
		FlxG.game.switchState();
	}
	#end
}