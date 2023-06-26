package;

import Paths.ContentMetadata;
import haxe.Json;
import haxe.format.JsonParser;

#if sys
import sys.FileSystem;
import sys.io.File;
#else
import openfl.utils.Assets;
#end


typedef ChapterMetadata = {
	/**
		Name of the chapter. 
	**/
	var name:String;
	
	/**
		Any chapter that isn't 'main' shouldn't be displayed in the story menus. 
	**/
	var category:String;

	/**
		Incase you want a main chapter to appear in a seperate freeplay category
	**/
	@:optional var freeplayCategory:String;
	
	/**
		This isn't implemented, and at this point I don't think it's going to. LOL.
		Could've been a Bool or a String, in case of being a string it would've been checked from a Map from your save file
		as FlxG.save.data.unlocks.get(unlockCondition kinda like psych's StoryMenuState.weeksCompleted???
		
		idk i fucking forgot how it was going to be done this so pointless and stupid, theres no point????????
	**/
	var unlockCondition:Any;
	
	/**
		Song names of this chapter.
	**/
	var songs:Array<String>;
	
	/**
		Name of the content folder containing this chapter
	**/
    @:optional var directory:String;
}

class ChapterData
{
	// public static var chaptersMap:Map<String, ChapterMetadata> = new Map();
	public static var chaptersList:Array<ChapterMetadata> = [];
	public static var curChapter:Null<ChapterMetadata> = null;

	public static function reloadChapterFiles():Array<ChapterMetadata>
	{
		var list:Array<ChapterMetadata> = [];

		#if MODS_ALLOWED
		for (mod in Paths.getModDirectories()){
			Paths.currentModDirectory = mod;
			var path = Paths.modFolders("metadata.json", true);
			var rawJson:Null<String> = Paths.getContent(path);

			if (rawJson != null && rawJson.length > 0)
            {
				var daJson:Dynamic = Json.parse(rawJson);
				if (Reflect.field(daJson, "chapters") != null){
					var data:ContentMetadata = cast daJson;
					for(chapter in data.chapters){
						chapter.directory = mod;
						list.push(chapter);
					}
				}else{
					// backwards compatibility
					var chapter:ChapterMetadata = cast daJson;
					chapter.directory = mod;
					list.push(chapter);
					
				}
			}
		}
		Paths.currentModDirectory = '';
        #end

		chaptersList = list;

		return list;
	}
}