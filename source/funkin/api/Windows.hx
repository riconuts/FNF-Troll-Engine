package funkin.api;

// https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-messagebox

#if (windows && cpp)
enum abstract MessageBoxOptions(Int) to Int {
	var OK					= 0x00000000;
	var OKCANCEL			= 0x00000001;
	var ABORTRETRYIGNORE	= 0x00000002;
	var YESNOCANCEL			= 0x00000003;
	var YESNO				= 0x00000004;
	var RETRYCANCEL			= 0x00000005;
	var CANCELTRYCONTINUE	= 0x00000006;
	//var HELP				= 0x00004000;
}

enum abstract MessageBoxIcon(Int) to Int {
	var NONE		= 0x00000000;
	var STOP		= 0x00000010;
	var ERROR		= 0x00000010;
	var HAND		= 0x00000010;
	var QUESTION	= 0x00000020;
	var EXCLAMATION	= 0x00000030;
	var WARNING		= 0x00000030;
	var INFORMATION	= 0x00000040;
	var ASTERISK	= 0x00000040;
}

enum abstract MessageBoxDefaultButton(Int) to Int {
	var BUTTON1 = 0x00000000;
	var BUTTON2 = 0x00000100;
	var BUTTON3 = 0x00000200;
	var BUTTON4 = 0x00000300;
}

enum abstract MessageBoxReturnValue(Int) from Int to Int {
	var OK = 1;
	var CANCEL = 2;
	var ABORT = 3;
	var RETRY = 4;
	var IGNORE = 5;
	var YES = 6;
	var NO = 7;
	var TRYAGAIN = 10;
	var CONTINUE = 11;
}

@:cppFileCode('#include <windows.h>')
class Windows {
	public static function msgBox(message:String = "", title:String = "", sowyType:Int = 0):MessageBoxReturnValue
		return untyped MessageBox(NULL, message, title, sowyType | 0x00010000);
}
#end