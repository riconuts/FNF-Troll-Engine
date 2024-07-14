package funkin.data;

import funkin.Paths.ContentMetadata;
import haxe.io.Path;

typedef WeekMetadata = {
	/**
		Name of the week. 
	**/
	var name:String;
	
	/**
		Any week that isn't 'main' shouldn't be displayed in the story menus. 
	**/
	var category:String;

	/**
		Incase you want a main week to appear in a seperate freeplay category
	**/
	@:optional var freeplayCategory:String;
	
	/**
		Not implemented!
		In case of being a string it would've been checked from a Map from your save file
		as FlxG.save.data.unlocks.get(unlockCondition) maybe
	**/
	var unlockCondition:Any;
	
	/**
		Song names of this week.
	**/
	var songs:Array<String>;
	
	/**
		Name of the content folder containing this week
	**/
    var ?directory:String;
}

class WeekData
{
	// public static var chaptersMap:Map<String, WeekMetadata> = new Map();
	public static var weekList:Array<WeekMetadata> = [];
	public static var curWeek:Null<WeekMetadata> = null;

	public static var weekCompleted(get, null):Map<String, Bool>;
	@:noCompletion static function get_weekCompleted() return Highscore.weekCompleted;

	public static function reloadWeekFiles():Array<WeekMetadata>
	{
		var list:Array<WeekMetadata> = weekList = [];

		#if MODS_ALLOWED
		for (mod => daJson in Paths.getContentMetadata()) {
			if (daJson != null && daJson.weeks != null) {
				for (week in daJson.weeks) {
					week.directory = mod;
					list.push(week);
				}
			}
		}
        #end

		return list;
	}

	#if PE_MOD_COMPATIBILITY
	public static function addPsychWeek(data:ContentMetadata, weekFile:PsychWeekFile)
	{
		var vChapter:WeekMetadata = {
			name: weekFile.name,
			songs: [],
			category: 'psychengine', //'main',
			// freeplayCategory: '$mod - $name',
			unlockCondition: true,
			//directory: mod
		};

		//vChapter.unlockCondition = weekFile.startUnlocked != false; /* || (json.weekBefore!=null && weekCompleted.get(json.weekBefore)); */

		if (Reflect.field(weekFile, "hideStoryMode") == true)
			vChapter.category = "hidden";

		if (Reflect.hasField(weekFile, "songs")) {
			for (songData in weekFile.songs)
				vChapter.songs.push(songData[0]);
		}

		if (Reflect.field(weekFile, "hideFreeplay") != true) {
			for (songName in vChapter.songs)
				data.freeplaySongs.push({name: songName, category: data.defaultCategory});
		}

		data.weeks.push(vChapter);
	}

	public static function getPsychModWeeks(modName:String):Array<PsychWeekFile>
	{
		var modWeeksPath:String = Paths.mods('$modName/weeks');
		var modWeeksPushed:Map<String, PsychWeekFile> = [];
		var modWeeks:Array<PsychWeekFile> = [];

		function sowy(weekName:String) {
			if (modWeeksPushed.exists(weekName)) // no dupes
				return;

			var data:PsychWeekFile = Paths.getJson('$modWeeksPath/$weekName.json');
			if (data != null) {
				data.name = weekName;

				modWeeksPushed.set(weekName, data); 
				modWeeks.push(data);
			}
		}

		//// Push weeks in the order of the weekList file first.
		var modWeekList:Array<String> = CoolUtil.coolTextFile('$modWeeksPath/weekList.txt');
		for (weekName in modWeekList)
			sowy(weekName);

		//// Push the rest of the weeks
		Paths.iterateDirectory(modWeeksPath, (fileName:String)->{
			if (StringTools.endsWith(fileName, ".json")) {
				var weekName:String = fileName.substr(0, fileName.length - 5);
				sowy(weekName);
			}
		});

		return modWeeks;
	}
	#end
}

#if PE_MOD_COMPATIBILITY
typedef PsychWeekFile =
{
	var name:String; // Not part of the JSON
	
	var songs:Array<Dynamic>;
	var weekCharacters:Array<String>;
	var weekBackground:String;
	var weekBefore:String;
	var storyName:String;
	var weekName:String;
	var freeplayColor:Array<Int>;
	var startUnlocked:Bool;
	var hiddenUntilUnlocked:Bool;
	var hideStoryMode:Bool;
	var hideFreeplay:Bool;
	var difficulties:String;
}
#end