package funkin.data;

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