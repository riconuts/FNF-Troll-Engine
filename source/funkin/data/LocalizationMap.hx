package funkin.data;

import haxe.ds.StringMap;
using StringTools;

final bedrockComments:EReg = ~/(##).+/;
final normalComments:EReg = ~/(\/\/).+/;
// could add lua-style comments though honestly dont think i need to

class LocalizationMap {
	public static function fromFile(path:String) {
		var fileContent:Null<String> = Paths.getContent(path);
		if (fileContent == null)
			throw 'Could not get string file from path: $path';
		
		return fromString(fileContent);
	}

	public static function fromString(rawContent:String) {
		var strings = new StringMap();

		var isInComment:Bool = false;
		for (rawLine in rawContent.trim().split("\n")) {
			var trimmedShit:String = rawLine.trim();

			// Allow comment blocks if a line starts with /* and escape block if line starts with */
			if (trimmedShit.startsWith("*/") && isInComment) {
				isInComment = false;
				continue;
			}
			if (trimmedShit.startsWith("/*") && !isInComment) {
				isInComment = true;
				continue;
			}

			// Allow in-line comments
			var noComments:String = bedrockComments.replace(normalComments.replace(trimmedShit, ""), "");
			if (noComments.length == 0)
				continue;

			var splitted = noComments.split("=");
			if (splitted.length <= 1)
				continue; // likely not a localization key

			strings.set(splitted.shift(), splitted.join("=").trim().replace('\\n', '\n'));
		}

		return strings;
	}
}