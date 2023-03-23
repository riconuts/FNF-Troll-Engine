package;

import Section.SwagSection;
import haxe.Json;
import haxe.format.JsonParser;
import lime.utils.Assets;

using StringTools;
#if sys
import sys.FileSystem;
import sys.io.File;
#end


typedef SwagSong =
{
	@:optional var song:String;
	@:optional var bpm:Float;
	@:optional var speed:Float;
	@:optional var notes:Array<SwagSection>;
	@:optional var events:Array<Dynamic>;
	
	@:optional var needsVoices:Bool;
	@:optional var validScore:Bool;

	@:optional var player1:String;
	@:optional var player2:String;
	@:optional var player3:String;
	@:optional var gfVersion:String;
	@:optional var stage:String;

	@:optional var arrowSkin:String;
	@:optional var splashSkin:String;

	@:optional var extraTracks:Array<String>;
	@:optional var info:Array<String>;
}

class Song
{
	public var song:String;
	public var bpm:Float;
	public var speed:Float = 1;
	public var notes:Array<SwagSection>;
	public var events:Array<Dynamic>;
	
	public var needsVoices:Bool = true;
	public var arrowSkin:Null<String> = null;
	public var splashSkin:Null<String> = null;

	public var player1:String = 'bf';
	public var player2:String = 'dad';
	public var gfVersion:String = 'gf';
	public var stage:String;

	public var extraTracks:Array<String> = [];

	private static function onLoadJson(songJson:Dynamic) // Convert old charts to newest format
	{
		if(songJson.gfVersion == null){
			if (songJson.player3 != null){
				songJson.gfVersion = songJson.player3;
				songJson.player3 = null;
			}
			else
				songJson.gfVersion = "gf";
		}

		if (songJson.extraTracks == null){
			songJson.extraTracks = [];
		}

		if(songJson.events == null)
		{
			songJson.events = [];
			for (secNum in 0...songJson.notes.length)
			{
				var sec:SwagSection = songJson.notes[secNum];

				var i:Int = 0;
				var notes:Array<Dynamic> = sec.sectionNotes;
				var len:Int = notes.length;
				while(i < len)
				{
					var note:Array<Dynamic> = notes[i];
					if(note[1] < 0)
					{
						songJson.events.push([note[0], [[note[2], note[3], note[4]]]]);
						notes.remove(note);
						len = notes.length;
					}
					else i++;
				}
			}
		}
	}

	public function new(song, notes, bpm)
	{
		this.song = song;
		this.notes = notes;
		this.bpm = bpm;
	}

	public static function loadFromJson(jsonInput:String, ?folder:String):SwagSong
	{
		var path = Paths.formatToSongPath(folder) + '/' + Paths.formatToSongPath(jsonInput);
		var rawJson = Paths.getText('songs/$path.json', false);
		
		#if PE_MOD_COMPATIBILITY
		if (rawJson == null){
			rawJson = Paths.getText('data/$path.json', false);

			if (rawJson == null){
				trace('JSON file not found: $path');
				return null;
			}
		}
		#else
		if (rawJson == null){
			trace('JSON file not found: $path');
			return null;
		}
		#end

		rawJson = rawJson.trim();

		// LOL GOING THROUGH THE BULLSHIT TO CLEAN IDK WHATS STRANGE
		while (!rawJson.endsWith("}"))
			rawJson = rawJson.substr(0, rawJson.length - 1);

		var songJson:Dynamic = parseJSONshit(rawJson);
		if(jsonInput != 'events') Stage.StageData.loadDirectory(songJson);
		onLoadJson(songJson);

		return songJson;
	}

	public static function parseJSONshit(rawJson:String):SwagSong
	{
		var swagShit:SwagSong = cast Json.parse(rawJson).song;
		swagShit.validScore = true;
		return swagShit;
	}
}
