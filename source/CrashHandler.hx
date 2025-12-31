import haxe.CallStack;
import openfl.events.UncaughtErrorEvent;
import flixel.FlxG;

using StringTools;

#if SAVE_CRASH_LOGS
import sys.io.File;
#end

#if sys
import lime.system.System;
#end

#if (windows && cpp)
import funkin.api.Windows;
#end

#if linc_filedialogs
// class name is a bit misleading for the function used
// but it does also handle file dialogs, soooo
import filedialogs.FileDialogs;
#end

class CrashHandler {
	public static function init() {
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
	}

	private static function getLogFileName():String {
		return "crash.txt";
	}

	private static function onCrash(errorName:String):Void {
		print("\nCall stack starts below");

		var callstack:String = callstackToString(CallStack.exceptionStack(true));
		print('\n$callstack\n$errorName');

		////
		var boxMessage:String = '$callstack\n$errorName';

		#if SAVE_CRASH_LOGS
		final fileName:String = getLogFileName();
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
		#elseif (UNIX_CRASH_HANDLER && linc_filedialogs)
		boxMessage += "\nWould you like to goto the main menu?";
		final btn:Button = FileDialogs.message(
			errorName, boxMessage,
			Choice.Yes_No_Cancel, Icon.Error
		);
		switch(btn) {
			case Yes: 
				toMainMenu();
				return;
			case Cancel:
				// Continue with a possibly unstable state
				return;
			default:
				// Close the game
		}
		#else
		application.window.alert(callstack, errorName); // this shit barely works on linux!
		#end

		#if sys 
		System.exit(1);
		#end
	}

	#if (WINDOWS_CRASH_HANDLER || UNIX_CRASH_HANDLER)
	@:unreflective static inline function toMainMenu() @:privateAccess {
		try{
			if (FlxG.game._state != null) {
				FlxG.game._state.destroy();
				FlxG.game._state = null;
			}
		}catch(e){
			print("Error destroying state: ", e);
		}	
		
		FlxG.game._nextState = new funkin.states.MainMenuState();
		FlxG.game.switchState();
	}
	#end

	public static function callstackToString(callstack:Array<StackItem>):String {
		var buf = new StringBuf();
		for (stackItem in callstack) {
			switch (stackItem) {
				case FilePos(s, file, line, column):
					buf.add(switch(s) {
						case Method(className, methodName):
							'$file:$line [$methodName]';
						case LocalFunction(name):
							'$file:$line [$name]';
						default: '$s';
					});
					buf.add('\n');
				default:
					buf.add(stackItem);
					buf.add('\n');
			}
		}
		return buf.toString();
	}
}