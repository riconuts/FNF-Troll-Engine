package funkin.data;

import funkin.data.Song;
import funkin.states.StoryModeState;
import funkin.scripts.FunkinHScript;
import funkin.scripts.Globals;
import flixel.group.FlxSpriteGroup;
import flixel.util.typeLimit.OneOfTwo;
import flixel.util.FlxColor;
import haxe.io.Path;
import haxe.Json;

using funkin.CoolerStringTools;
using StringTools;

class Level {
	var script:FunkinHScript;

	public static function fromFile(fileName:String, ?id:String, folder:String = "", index:Int = 0){
		var json:Null<JSONLevelData> = Paths.exists(fileName + ".json") ? Json.parse(Paths.getContent(fileName + ".json")) : null;


/* 		var scriptFile = Paths.getHScriptPath(fileName);
		if (hscriptFile != null) {
			var script = FunkinHScript.fromFile(hscriptFile, hscriptFile, defaultVars);
			pushScript(script);
			return this;
		} */

		var level:Level = new Level();
		level.bgColor = CoolUtil.colorFromString(json?.bgColor ?? "#F9CF51");
		
		level.id = id ?? json?.id;
		level.folder = folder;
		level.index = json?.index ?? index;
		level.name = json?.name ?? "NAME DOESNT EXIST IDIOT";
		level.asset = json?.asset ?? "storymenu/titles/week1";
		level.difficulties = json?.difficulties ?? level.difficulties;
		level.props = json?.props ?? level.props;
		level.songList = json?.songs ?? ["Test"];
		level.songs = [for (songId in level.songList) new Song(songId, folder)];

		for (ext in Paths.HSCRIPT_EXTENSIONS) {
			var scriptPath = '$fileName.$ext';
			if (Paths.exists(scriptPath))
				level.script = FunkinHScript.fromFile(scriptPath, level.name, ["this"=>level]);
		}

		return level;
	}

	function callScript(call:String, ?args:Array<Dynamic>):Null<Dynamic>
	{
		if(script != null && script.exists(call))
			return script.call(call, args);

		return null;
	}

	public function new(){}

	public var id:String = 'broken';
	public var folder:String = '';
	public var bgColor:FlxColor = 0xFFF9CF51;
	public var index:Int = 0;
	public var name:String = "PLACEHOLDER";
	public var asset:String = "storymenu/titles/week1";
	public var songList:Array<String> = [];
	public var songs:Array<Song> = [];
	public var difficulties:Array<String> = ["easy", "normal", "hard"];
	public var props:Array<LevelPropData> = [];

	/**
	 * Returns a file path to the title asset
	 */
	public function getAsset():String {
		return callScript("getAsset") ?? asset;
	}

	/**
	 * Returns an integer to decide placement of the level
	 */
	public function getIndex():Int {
		return callScript("getIndex") ?? index;
	}

	/**
	 * Returns an array of difficulties available to be played for the level
	 */
	public function getDifficulties():Array<String>
	{ 
		return callScript("getDifficulties") ?? difficulties;
	}

	/**
	 * Returns an array of props to show in the story menu
	 */
	public function getProps():Array<LevelPropData> {
		return callScript("getProps") ?? props;
	}

	/**
	 * Returns an array of songs to be played during the level
	 */
	public function getPlaylist(difficultyId:String = 'normal'):Array<Song>
		return cast callScript("getPlaylist", [difficultyId]) ?? songs;
	

	/**
	 * Returns an array of song names to be displayed in the story menu
	 */
	public function getDisplayedSongs(difficultyId:String = "normal"):Array<String>
		return cast callScript("getDisplayedSongs", [difficultyId]) ?? [for (song in songs) song==null ? "UNKNOWN" : song.getMetadata(difficultyId).songName];
	

	/**
	 * WIP (still gotta add to freeplay)
	 * Returns an array of song data to be shown in freeplay. 
	 */
	public function getFreeplaySongs():Array<Song> 
		return cast callScript("getFreeplaySongs") ?? songList;
	

	/**
	 * Returns a LevelTitle object for the story menu
	 */
	public function createTitle()
		return callScript("createTitle") ?? new LevelTitle(0, 0, getAsset());
	

	/**
	 * Creates the props for the visuals in the story menu.
	 * This is usually the main characters of the level (BF, GF, and Opponent)
	 * Sometimes includes a background in Psych Engine and similar engines
	 * @param group The group to be populated by props.
	 * @param bgGroup The background group to be populated by props. This group is automatically layered behind all props and fades when changing levels.
	 */

	public function populateGroup(group:FlxSpriteGroup, bgGroup:FlxSpriteGroup){
		if (callScript("prePopulateGroup", [group, bgGroup]) == Globals.Function_Stop)
			return;

		for(propData in getProps()){
			var prop = LevelStageProp.buildFromData(propData);
			var layer = propData.layer.toLowerCase();

			if (layer == 'background' || layer == 'bg')
				bgGroup.add(prop);
			else
				group.add(prop);
		}

		callScript("postPopulateGroup", [group, bgGroup]);
	}
}

// fuck structInit bro im doing it the way i already know
typedef JSONLevelData = {
	?id:String,
	?index:Int,
	name:String,
	asset:String,
	songs:Array<String>,
	?bgColor:String,
	?difficulties:Array<String>,
	?props:Array<LevelPropData>
}

// i know its v-slice core but bleeehh :P
// allows good customization


// TODO: Move all of these to a seperate proper Level class to allow for scripting etc
typedef LevelPropAnimation = {
	name:String,
	prefix:String,
	?looped:Bool,
	?fps:Int,
	?indices:Array<Int>,
	?offset:Array<Float>,
	?haltsDancing:Bool
}

typedef LevelPropData = {
	?template:String,
	?layer:String, // Used for fading out the background
	?characterId:Float,
	?x:Float,
	?y:Float,
	graphic:String,
	?alpha:Float,
	?scale:Array<Float>,
	?antialiasing:Bool,
	?animations:Array<LevelPropAnimation>,

	?danceSequence:Array<String>, // Cycles through this every dance
	?danceBeat:Float, // What beat to dance on. 0 = disabled
}