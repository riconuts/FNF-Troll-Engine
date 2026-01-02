package funkin.data;

import funkin.scripts.ScriptedClassShit.InstanceInterp;
import funkin.data.BaseSong;
import funkin.data.Song;
import funkin.states.StoryModeState;
import funkin.scripts.FunkinHScript;
import funkin.scripts.Globals;
import flixel.group.FlxSpriteGroup;
import flixel.util.FlxColor;
import haxe.io.Path;
import haxe.Json;

using funkin.CoolerStringTools;
using StringTools;

class Level {
	public static function fromFile(fileName:String, ?id:String, folder:String = "", index:Int = 0){
		var json:Null<JSONLevelData> = Paths.exists(fileName + ".json") ? Json.parse(Paths.getContent(fileName + ".json")) : null;


/* 		var scriptFile = Paths.getHScriptPath(fileName);
		if (hscriptFile != null) {
			var script = FunkinHScript.fromFile(hscriptFile, hscriptFile, defaultVars);
			pushScript(script);
			return this;
		} */

		var scriptedLevel:ScriptedLevel = null;
		var scriptPath:Null<String> = null;

		for (ext in Paths.HSCRIPT_EXTENSIONS) {
			var _scriptPath = '$fileName.$ext';
			if (Paths.exists(_scriptPath)) {
				scriptPath = _scriptPath;
				scriptedLevel = new ScriptedLevel();
				break;
			}
		}

		var level = scriptedLevel ?? new Level();

		level.id = id ?? json?.id;
		level.folder = folder;
		level.songList = json?.songs ?? ["Test"];
		level.songs = [for (songId in level.songList) new Song(songId, folder)];
		level.difficulties = json?.difficulties ?? level.difficulties;
		level.name = json?.name ?? "NAME DOESNT EXIST IDIOT";
		level.asset = json?.asset ?? "storymenu/titles/week1";
		level.props = json?.props ?? level.props;
		level.appearsInStory = json?.appearsInStory ?? true;
		level.index = json?.index ?? index;
		level.bgColor = CoolUtil.colorFromString(json?.bgColor ?? "#F9CF51");

		if (scriptedLevel != null) {
			scriptedLevel.script = FunkinHScript.fromFile(scriptPath, 'level/'+level.id, null, false, new InstanceInterp(level));
		}

		return level;
	}

	public function new(){}

	public function toString()
		return '$folder:$id';

	public var id:String = 'broken';
	public var folder:String = '';
	public var bgColor:FlxColor = 0xFFF9CF51;
	public var index:Int = 0;
	public var name:String = "PLACEHOLDER";
	public var asset:String = "storymenu/titles/week1";
	public var songList:Array<String> = [];
	public var songs:Array<BaseSong> = [];
	public var difficulties:Array<String> = ["easy", "normal", "hard"];
	public var props:Array<LevelPropData> = [];
	public var appearsInStory:Bool = true;

	/**
	 * Returns a file path to the title asset
	**/
	public function getAsset():String
	{
		return asset;
	}

	/**
	 * Returns an integer to decide placement of the level
	**/
	public function getIndex():Int
	{
		return index;
	}

	/**
	 * Returns an array of difficulties available to be played for the level
	**/
	public function getDifficulties():Array<String>
	{ 
		return difficulties;
	}

	/**
	 * Returns an array of props to show in the story menu
	**/
	public function getProps():Array<LevelPropData>
	{
		return props;
	}

	/**
	 * Returns an array of songs to be played during the level
	**/
	public function getPlaylist(difficultyId:String = 'normal'):Array<BaseSong>
	{
		return songs;
	}
	

	/**
	 * Returns an array of song names to be displayed in the story menu
	**/
	public function getDisplayedSongs(difficultyId:String = "normal"):Array<String>
	{
		return isUnlocked() ? [for (song in songs) song==null ? "Unknown" : song.getMetadata(difficultyId).songName] : [];
	}
	

	/**
	 * Returns an array of song data to be shown in freeplay. 
	**/
	public function getFreeplaySongs():Array<BaseSong>
	{
		return songs;
	}
	

	/**
		Whether this level is unlocked.  
		A locked level will be shown with a lock on the story mode menu, and its songs won't be added to freeplay.
	**/
	public function isUnlocked():Bool
	{
		return true;
	}


	/**
		Returns true if the level should be shown on the story menu.  
		Does not hide the level's songs from freeplay.
	**/
	public function isVisible():Bool
	{
		return appearsInStory;
	}


	/**
	 * Returns a LevelTitle object for the story menu
	**/
	public function createTitle()
	{
		return new LevelTitle(0, 0, getAsset());
	}
	

	/**
	 * Creates the props for the visuals in the story menu.
	 * This is usually the main characters of the level (BF, GF, and Opponent)
	 * Sometimes includes a background in Psych Engine and similar engines
	 * @param group The group to be populated by props.
	 * @param bgGroup The background group to be populated by props. This group is automatically layered behind all props and fades when changing levels.
	**/
	public function populateGroup(group:FlxSpriteGroup, bgGroup:FlxSpriteGroup)
	{
		for (propData in getProps()) {
			var prop = LevelStageProp.buildFromData(propData);
			var layer = propData.layer.toLowerCase();

			if (layer == 'background' || layer == 'bg')
				bgGroup.add(prop);
			else
				group.add(prop);
		}
	}
}

class ScriptedLevel extends Level implements funkin.scripts.ScriptedClassShit.IScriptedClass
{
	public var script:FunkinHScript;

	public function callOnScript(call:String, ?args:Array<Dynamic>):Dynamic
	{
		return script.call(call, args);
	}

	public function existsOnScript(call:String):Bool
	{
		return script != null && script.exists(call);
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
	?appearsInStory:Bool,
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
	?haltsDancing:Bool,
	?flipX:Bool,
	?flipY:Bool
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