package funkin.data;

import funkin.data.Song.SongMetadata;
import sys.io.File;
import haxe.Json;
import funkin.scripts.FunkinHScript;

using funkin.CoolerStringTools;
using StringTools;

enum abstract SongListState(String) from String to String {
	var STORY = "storymode";
	var FREEPLAY = "freeplay";
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

class Level
{
	public final id:String;
	private final data:LevelJSON;
	private final script:FunkinHScript;

	public static function fromId(id:String) {
		var jsonPath:String = Paths.getFileWithExtensions('levels/$id', ["json"]);
		var jsonData:LevelJSON = jsonPath == null ? null : cast Json.parse(File.getContent(jsonPath));

		return new Level(id, jsonData);
	}

	public function new(id:String, ?data:LevelJSON){
		this.id = id;
		this.data = data;

		var scriptPath:String = Paths.getHScriptPath('levels/$id');
		if (scriptPath != null){
			script = FunkinHScript.fromFile(scriptPath, scriptPath, [
				"this" => this,
				"getData" => (() -> return this.data),
				"STORY" => SongListState.STORY,
				"FREEPLAY" => SongListState.FREEPLAY,
			], false);

			this.data = script.executeFunc("getData") ?? data;
		}else {
			script = null;
		}
		
		if (this.data == null) {
			throw ("Level ID " + id + " isn't valid!");
		}
		if (this.data.difficulties == null)
			this.data.difficulties = ["easy", "normal", "hard"];
	}

	// these are functions because scripts lol!!
	// TODO: generate with a macro
	public function getName():String
	{
		if(script != null && script.exists("getName"))
			return script.executeFunc("getName", []);

		return data.name;
	}

	public function getSongs(?state:String = SongListState.STORY):Array<String> 
	{
		if (script != null && script.exists("getSongs"))
			return script.executeFunc("getSongs", [state]);

		return data.songs;
	}

	public function getDifficulties():Array<String>
	{
		if (script != null && script.exists("getDifficulties"))
			return script.executeFunc("getDifficulties", []);

		return data.difficulties;
	}

	public function getDisplayedSongs(?state:String = SongListState.STORY):Array<String> 
	{
		if (script != null && script.exists("getDisplayedSongs"))
			return script.executeFunc("getDisplayedSongs", [state]);

		if (data.displayedSongs == null || data.displayedSongs.length == 0){
			var displayedArray:Array<String> = [];

			for(song in getSongs())
				displayedArray.push(song.replace("-"," ").capitalize());
			
			return displayedArray;
		}
		
		return data.displayedSongs;
	}

	public function getLevelAsset():String 
	{
		if (script != null && script.exists("getLevelAsset"))
			return script.executeFunc("getLevelAsset", []);

		return data.levelAsset;
	}

	public function getTitle():String
	{
		if (script != null && script.exists("getTitle"))
			return script.executeFunc("getTitle", []);

		return data.title;
	}

	public function getPlayer():String 
	{
		if (script != null && script.exists("getPlayer"))
			return script.executeFunc("getPlayer", []);

		return data.player;
	}

	public function getOpponent():String 
	{
		if (script != null && script.exists("getOpponent"))
			return script.executeFunc("getOpponent", []);

		return data.opponent;
	}

	public function getGirlfriend():String 
	{
		if (script != null && script.exists("getGirlfriend"))
			return script.executeFunc("getGirlfriend", []);

		return data.girlfriend;
	}
}