package funkin.api;

/**
 * https://stackoverflow.com/questions/51334674/how-to-detect-windows-10-light-dark-mode-in-win32-application
 */
@:buildXml('<include name="../../../../source/funkin/api/build.xml" />')
@:include("darkmode.hpp")
extern class Darkfriend {
	/**
		@see https://github.com/TBar09/hxWindowColorMode-main/
	**/ 
	@:native("setDarkMode")
	static function setDarkMode(isDark:Bool):Void;

	@:native("isLightTheme")
	static function isLightTheme():Bool;
}