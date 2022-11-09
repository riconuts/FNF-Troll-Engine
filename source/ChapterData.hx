package;

import haxe.Json;
import haxe.format.JsonParser;

#if sys
import sys.FileSystem;
import sys.io.File;
#else
import openfl.utils.Assets;
#end

typedef ChapterMetadata = {
	var name:String;
	var category:String;
	var unlockCondition:Dynamic;
	var songs:Array<String>;
}

class ChapterData{
	/*
	public var name:String;
	public var category:String;
	public var unlockCondition:Dynamic;
	public var songs:Array<String>;
	*/

	public static function reloadChapterFiles():Array<ChapterMetadata>
	{
		var chaptersList:Array<ChapterMetadata> = [];
		var modDirs = Paths.getModDirectories(); 

		for (mod in modDirs){
			Paths.currentModDirectory = mod;
			var path = Paths.modFolders("metadata.json");
			var rawJson:Dynamic = null;
			
			#if sys
			if (FileSystem.exists(path))
				rawJson = File.getContent(path);
			#else
			if (Assets.exists(path))
				rawJson = Assets.getText(path);
			#end

			if (rawJson != null && rawJson.length > 0)
				chaptersList.push(cast Json.parse(rawJson));
		}

		return chaptersList;
	}
}