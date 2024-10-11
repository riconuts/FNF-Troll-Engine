package funkin.data;

import funkin.scripts.FunkinHScript;
using funkin.CoolerStringTools;
using StringTools;

typedef LevelJSON = {
	?id:String,
	name:String,
	levelAsset:String,
	
	// Might get replaced w/ a props array similar to V-Slice
	// Cus then you get more customizability w/ how it looks (i.e backgrounds like Psych, etc)
	player:String,
	girlfriend:String,
	opponent:String,

	songs:Array<String>,
	?displayedSongs:Array<String>
}

class Level
{
	var script:FunkinHScript;

	var id:String = 'week1';
	var data:LevelJSON = {
		name: 'Week 1',
		levelAsset: 'storymenu/week1',
		player: 'bf',
		girlfriend: 'gf',
		opponent: 'dad',
		songs: []
	};

	public static function fromId(id:String) {
		var newLevel:Level = new Level(id);
		var json = Paths.getFileWithExtensions('levels/$id', ["json"]);
		if (json == null) {
			trace("Level ID " + id + " isn't valid!");
			return newLevel;
		}
		newLevel.data = cast json;
		return newLevel;
	}

	public function new(id:String){
		var scriptPath:String = Paths.getHScriptPath('levels/$id');
		
		if(scriptPath != null){
			script = FunkinHScript.fromFile(scriptPath, scriptPath, [
				"this" => this,
				"getData" => (() -> return this.data)
			], false);
		}
	}

	// these are functions because scripts lol!!
	// TODO: generate with a macro
	public function getName():String
	{
		if(script != null && script.exists("getName"))
			return script.executeFunc("getName", []);

		return data.name;
	}

	public function getLevelAsset():String {
		if (script != null && script.exists("getLevelAsset"))
			return script.executeFunc("getLevelAsset", []);

		return data.levelAsset;
	}

	public function getPlayer():String {
		if (script != null && script.exists("getPlayer"))
			return script.executeFunc("getPlayer", []);

		return data.player;
	}

	public function getOpponent():String {
		if (script != null && script.exists("getOpponent"))
			return script.executeFunc("getOpponent", []);

		return data.opponent;
	}

	public function getGirlfriend():String {
		if (script != null && script.exists("getGirlfriend"))
			return script.executeFunc("getGirlfriend", []);

		return data.girlfriend;
	}

	public function getSongs():Array<String> {
		if (script != null && script.exists("getSongs"))
			return script.executeFunc("getSongs", []);

		return data.songs;
	}

	public function getDisplayedSongs():Array<String> {
		if (script != null && script.exists("getDisplayedSongs"))
			return script.executeFunc("getDisplayedSongs", []);

		if (data.displayedSongs == null || data.displayedSongs.length == 0){
			var displayedArray:Array<String> = [];

			for(song in data.songs)
				displayedArray.push(song.replace("-"," ").capitalize());
			
			return displayedArray;
		}
		
		return data.displayedSongs;
	}
}