package funkin.data;

import funkin.data.Highscore.weekCompleted;
import funkin.data.ContentData;
import funkin.data.Song;
import funkin.scripts.FunkinHScript;

using funkin.CoolerStringTools;
using StringTools;


@:autoBuild(funkin.macros.Sowy.inheritFieldDocs())
/** Class to get data for the Story Mode menu **/ 
// Freeplay song list and order will be independent from these
abstract class Level
{
	public final id:String;
	public final content:ContentData;

	public function new(content:ContentData, id:String)
	{
		this.content = content;
		this.id = id;
	}

	/** Returns the name of this level **/
	abstract public function getName():String;

	/** Returns song keys that belong to this Level **/
	abstract public function getSongs():Array<String>;

	/** Returns a song array to be passed to PlayState when playing this Level **/
	abstract public function getPlaylist(?difficulty:String):Array<Song>;

	/** Returns whether this Level should appear on the Story Mode menu**/
	abstract public function getVisible():Bool;

	/** Returns whether this Level should be playable through the Story Mode menu**/
	abstract public function getUnlocked():Bool;

	/** Returns song names to be displayed on the menu **/
	abstract public function getDisplayedSongs():Array<String>;

	/** Returns difficulty keys available for this Level **/
	abstract public function getDifficulties():Array<String>;

	/** Returns this Level's story title**/
	abstract public function getTitle():String;

	/** Returns the asset key for this Level's option graphic on the Story Mode menu**/
	abstract public function getLevelAsset():String;

	abstract public function getPlayer():String;

	abstract public function getOpponent():String;

	abstract public function getGirlfriend():String;
	
	private function getSongInstances(keys:Array<String>):Array<Song> {
		var list = [];
		
		for (id in keys) {
			var song = content.songs.get(id);
			if (song != null) list.push(song);
		}
		
		return list;
	}
}

class DataLevel extends Level
{
	private final data:LevelJSON;
	private final script:FunkinHScript;

	public function new(content:ContentData, id:String, ?data:LevelJSON, ?scriptPath:String){
		super(content, id);
		this.data = data;

		if (scriptPath != null){
			this.script = FunkinHScript.fromFile(scriptPath, scriptPath, [
				"this" => this,
				"getData" => (() -> return this.data)
			], false);

			this.data = script.executeFunc("getData") ?? data;
		}else {
			this.script = null;
		}
		
		if (this.data == null && this.script == null) {
			throw ("Level ID " + id + " isn't valid!");
		}
		if (this.data.difficulties == null)
			this.data.difficulties = ["easy", "normal", "hard"];
	}

	public function getName():String
	{
		return data.name;
	}

	public function getSongs():Array<String> 
	{
		return data.songs;
	}

	public function getPlaylist(?difficulty:String):Array<Song> {
		return getSongInstances(getSongs());
	}

	public function getDifficulties():Array<String>
	{
		return data.difficulties;
	}

	public function getDisplayedSongs():Array<String> 
	{
		if (data.displayedSongs == null || data.displayedSongs.length == 0) {
			var displayedArray:Array<String> = [];

			for(song in getSongs())
				displayedArray.push(song.replace("-"," ").capitalize());
			
			return displayedArray;
		}
		
		return data.displayedSongs;
	}

	public function getUnlocked():Bool 
	{
		return true;
	}

	public function getVisible():Bool
	{
		return true;
	}

	public function getLevelAsset():String 
	{
		return data.levelAsset;
	}

	public function getTitle():String
	{
		return data.title;
	}

	public function getPlayer():String 
	{
		return data.player;
	}

	public function getOpponent():String 
	{
		return data.opponent;
	}

	public function getGirlfriend():String 
	{
		return data.girlfriend;
	}
}

typedef LevelJSON = {
	?id:String,
	name:String,
	title:String,
	levelAsset:String,
	
	songs:Array<String>,
	?displayedSongs:Array<String>,

	?difficulties:Array<String>,

	// Might get replaced w/ a props array similar to V-Slice
	// Cus then you get more customizability w/ how it looks (i.e backgrounds like Psych, etc)
	player:String,
	girlfriend:String,
	opponent:String,
}

#if PE_MOD_COMPATIBILITY
class PsychLevel extends Level
{
	var data(default, set):PsychWeekFile;
	function set_data(data) {
		name = data.weekName;
		title = data.storyName;

		levelAsset = data.name;
		girlfriend = data.weekCharacters[2];
		opponent = data.weekCharacters[0];
		player = data.weekCharacters[1];
	
		songs = [];
		displayedSongs = [];
		difficulties = [];

		if (data.songs != null) {
			for (songData in ((data.songs):Array<Dynamic>)) {
				var songName = songData[0];
				displayedSongs.push(songName);
				songs.push(Paths.formatToSongPath(songName));
			}
		}

		if (data.difficulties != null) {
			for (piece in data.difficulties.split(",")) {
				difficulties.push(piece.trim().toLowerCase());
			}
		}
		if (difficulties.length == 0)
			difficulties = ["easy", "normal", "hard"];

		return this.data = data;
	}

	var name:String;
	var title:String;
	
	var songs:Array<String>;
	var displayedSongs:Array<String>;
	var difficulties:Array<String>;
	
	var levelAsset:String;
	var girlfriend:String;
	var opponent:String;
	var player:String;

	public function new(content:ContentData, id:String, data:PsychWeekFile)
	{
		data.name = id;
		this.data = data;

		super(content, id);
	}

	function getSongs()
		return songs;

	function getPlaylist(?difficulty:String):Array<Song>
		return getSongInstances(songs);
	
	function getDisplayedSongs()
		return displayedSongs;

	function getDifficulties()
		return difficulties;

	function getTitle()
		return title;

	function getName()
		return name;

	function getLevelAsset()
		return levelAsset;

	function getGirlfriend()
		return girlfriend;

	function getPlayer()
		return player;

	function getOpponent()
		return opponent;

	function getUnlocked()
		return (data.startUnlocked != false) || (data.weekBefore != null && weekCompleted.get(data.weekBefore) == true);

	function getVisible()
		return (data.hiddenUntilUnlocked==true) ? getUnlocked() : (data.hideStoryMode!=true);
}

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