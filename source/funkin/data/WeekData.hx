package funkin.data;

import funkin.Paths.ContentMetadata;
using StringTools;

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
	var ?unlockCondition:Any;
	
	/**
		Song names of this week.
	**/
	var songs:Array<String>;

	/**
		Difficulties in this week.
		Mainly used for Psych weeks.
	**/
	var ?difficulties:Array<String>;
	
	/**
		Name of the content folder containing this week
	**/
	var ?directory:String;

	/**
	 *  Hides the week in freeplay
	 */
	var ?hideFreeplay:Bool;
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
}