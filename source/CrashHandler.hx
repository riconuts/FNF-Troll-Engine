import haxe.CallStack;
import openfl.events.UncaughtErrorEvent;
import flixel.FlxG;

using StringTools;

#if (windows && cpp)
import funkin.api.Windows;
#end

#if linc_filedialogs
// class name is a bit misleading for the function used
// but it does also handle file dialogs, soooo
import filedialogs.FileDialogs;
#end

private enum abstract HandlerChoice(Int) {
	var NO;
	var YES;
	var CANCEL;
}

class CrashHandler {
	public static function init() {
		openfl.Lib.current.loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR, onFlashCrash);

		#if cpp
		untyped __global__.__hxcpp_set_critical_error_handler(onCrash);
		#end
	}

	private static function onFlashCrash(event:UncaughtErrorEvent) {
		// one of these oughta do it
		event.stopImmediatePropagation();
		event.stopPropagation();
		event.preventDefault();
		onCrash(event.error);
	}

	inline private static function getLogFilePath():String {
		return "crash.txt";
	}

	private static function onCrash(errorName:String):Void {
		print("\nCall stack starts below");

		var callstack:String = callstackToString(CallStack.exceptionStack(true));
		print('\n$callstack\n$errorName');

		////
		var boxMessage:String = '$callstack\n$errorName';

		#if SAVE_CRASH_LOGS
		final path:String = getLogFilePath();
		boxMessage += '\nCall stack was saved on $path';
		sys.io.File.saveContent(path, callstack);
		#end

		switch(showCrashBox(boxMessage)) {
			// Go back to the main menu
			case YES: return toMainMenu();
					
			// Continue with a possibly unstable state
			case CANCEL: return;
				
			// Close the game
			case NO:
		}

		#if sys
		lime.system.System.exit(1);
		#end
	}

	inline private static function showCrashBox(boxMessage:String):HandlerChoice {
		#if WINDOWS_CRASH_HANDLER
		boxMessage += "\nWould you like to go to the main menu?";
		final ret:MessageBoxReturnValue = Windows.msgBox(boxMessage, errorName, MessageBoxIcon.ERROR | MessageBoxOptions.YESNOCANCEL | MessageBoxDefaultButton.BUTTON3);
		return switch(ret) {
			case YES: YES;
			case CANCEL: CANCEL;
			default: NO;
		}
		#elseif (UNIX_CRASH_HANDLER && linc_filedialogs)
		boxMessage += "\nWould you like to go to the main menu?";
		final btn:Button = FileDialogs.message(errorName, boxMessage, Choice.Yes_No_Cancel, Icon.Error);
		return switch(btn) {
			case Yes: YES;
			case Cancel: CANCEL;
			default: NO;
		}
		#else
		application.window.alert(callstack, errorName); // this shit barely works on linux!
		return NO;
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