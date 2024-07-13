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
	static function portPsychWeek(json:Dynamic, name):Null<WeekMetadata>
	{
		if (json == null)
			return null;

		var vChapter:WeekMetadata = {
			name: name,
			songs: [],
			category: 'psychengine', //'main',
			// freeplayCategory: '$mod - $name',
			unlockCondition: true,
			//directory: mod
		};

		if (json.hideStoryMode == true)
			vChapter.category = "hidden";

		var psychSongs:Null<Array<Dynamic>> = json.songs;
		if (psychSongs != null)
		{
			var songs:Array<String> = vChapter.songs;
			for (songData in psychSongs)
				songs.push(songData[0]);
		}

		vChapter.unlockCondition = json.startUnlocked != false; /* || (json.weekBefore!=null && weekCompleted.get(json.weekBefore)); */

		return vChapter;
	}

	public static function getPsychModWeeks(modName:String)
	{
		var modWeeksPath:String = Paths.mods('$modName/weeks');
		var modWeeksPushed:Map<String, WeekMetadata> = [];
		var modWeeks:Array<WeekMetadata> = [];

		function sowy(weekName:String, fileName:String) {
			if (modWeeksPushed.exists(weekName)) // no dupes
				return;

			var data = portPsychWeek(Paths.getJson('$modWeeksPath/$fileName'), weekName);
			if (data != null){
				modWeeksPushed.set(weekName, data); 
				modWeeks.push(data);
			}
		}

		//// Push weeks in the order of the weekList file first.
		var modWeekList:Array<String> = CoolUtil.coolTextFile('$modWeeksPath/weekList.txt');
		for (weekName in modWeekList)
			sowy(weekName, '$weekName.json');

		//// Push the rest of the weeks
		Paths.iterateDirectory(modWeeksPath, (fileName:String)->{
			if (StringTools.endsWith(fileName, ".json")) {
				var weekName:String = fileName.substr(0, fileName.length - 5);
				sowy(weekName, fileName);
			}
		});

		return modWeeks;
	}
	#end
}