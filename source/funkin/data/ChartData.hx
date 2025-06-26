package funkin.data;

import haxe.io.Path;
import haxe.Json;

using StringTools;

typedef SongMetadata = {
	/** The display name of this song **/
	var ?songName:String;
	
	@:optional var artist:String;
	@:optional var charter:String;
	@:optional var modcharter:String;
	@:optional var extraInfo:Array<String>;
	
	@:optional var freeplayIcon:String;
	@:optional var freeplayBgGraphic:String;
	@:optional var freeplayBgColor:String;
}

typedef SwagSong = {
	////
	var notes:Array<SwagSection>;
	
	var keyCount:Int;

	/** Offsets the chart notes **/
	var offset:Float;
	
	/** How spread apart the notes should be **/
	var speed:Float;

	////
	var song:String;

	/** Starting BPM of the song **/
	var bpm:Float;
	
	/** Song track data containing the file names of the song's tracks **/
	var tracks:SongTracks;

	////
	var player1:Null<String>;
	var player2:Null<String>;
	var gfVersion:Null<String>;
	var stage:String;
	var hudSkin:String;

	var arrowSkin:String;
	var splashSkin:String;

	////
	@:optional var events:Array<Array<Dynamic>>;
	
	//// internal
	@:optional var metadata:SongMetadata;
	var validScore:Bool;
}

typedef JsonSong = {
	> SwagSong,
	var _path:String; // for internal use
	@:optional var offset:Float;
	@:optional var keyCount:Int;

	@:optional var player3:String; // old psych
	@:optional var extraTracks:Array<String>; // old te
	@:optional var needsVoices:Bool; // fnf
	@:optional var mania:Int; // vs shaggy
}

typedef SwagSection = {
	var sectionNotes:Array<Array<Dynamic>>;
	//var lengthInSteps:Int;
	var typeOfSection:Int;
	var mustHitSection:Bool;
	var gfSection:Bool;
	var bpm:Float;
	var changeBPM:Bool;
	var altAnim:Bool;
	var sectionBeats:Float;
}

typedef SongTracks = {
	var inst:Array<String>;
	var ?player:Array<String>;
	var ?opponent:Array<String>;
}

typedef PsychEvent = {
	strumTime:Float,
	event:String,
	value1:String,
	value2:String
}

// Used for compatibility with Psych 0.1 - 0.3.2 charts, though, you should add your hardcoded custom note types here too.
final defaultNoteTypeList:Array<String> = [
	'',
	'Alt Animation',
	'Hey!',
	'Hurt Note', // We should replace this w/ Mine
	'GF Sing',
	'No Animation'
];

class ChartData
{
	//@:deprecated('loadFromJson is deprecated! Use BaseSong.getSwagSong instead!')
	public static function loadFromJson(jsonInput:String, folder:String, isChartJson:Bool = true):Null<SwagSong>
	{
		var path:String = Paths.formatToSongPath(folder) + '/' + Paths.formatToSongPath(jsonInput) + '.json';
		var fullPath = Paths.getPath('songs/$path', false);
		return parseSongJson(fullPath, isChartJson);
	}

	public static function parseSongJson(filePath:String, isChartJson:Bool = true):Null<SwagSong> {
		try {
			return _parseSongJson(filePath, isChartJson);
		}catch(e) {
			trace('ERROR parsing song JSON: $filePath', e.message);
			return null;
		}
	}

	public static function _parseSongJson(filePath:String, isChartJson:Bool = true):SwagSong {
		var rawJson:Null<String> = Paths.getContent(filePath);
		if (rawJson == null)
			throw 'song JSON file NOT FOUND: $filePath';

		// LOL GOING THROUGH THE BULLSHIT TO CLEAN IDK WHATS STRANGE
		rawJson = rawJson.trim();
		while (!rawJson.endsWith("}"))
			rawJson = rawJson.substr(0, rawJson.length - 1);

		var uncastedJson:Dynamic = Json.parse(rawJson);
		var songJson:JsonSong;
		if (isChartJson && uncastedJson.song is String){
			// PSYCH 1.0 FUCKING DUMBSHIT FIX IT RETARD
			// why did shadowmario make such a useless format change oh my god :sob:
			
			songJson = cast uncastedJson;
			var stepCrotchet = Conductor.calculateStepCrochet(songJson.bpm);

			for (section in songJson.notes){
				for (note in section.sectionNotes){
					note[1] = section.mustHitSection ? note[1] : (note[1] + 4) % 8;
					note[2] -= stepCrotchet;
					note[2] = note[2] > 0 ? note[2] : 0;
				}
			}
		}else
			songJson = cast uncastedJson.song;

		songJson._path = filePath;
		return isChartJson ? onLoadJson(songJson) : onLoadEvents(songJson);
	}

	public static function onLoadJson(songJson:JsonSong):SwagSong
	{
		var swagJson:SwagSong = songJson;

		swagJson.validScore = true;

		songJson.stage ??= 'stage';
		/*
		songJson.player1 ??= "bf";
		songJson.player2 ??= "dad";
		songJson.gfVersion ??= songJson.player3 ?? "gf";
		*/

		// If gfVersion isn't set on the json file, use player3 or default to gf
		songJson.gfVersion = !Reflect.hasField(songJson, 'gfVersion') ? (songJson.player3 ?? "gf") : songJson.gfVersion;
		
		if (swagJson.arrowSkin == null || swagJson.arrowSkin.trim().length == 0)
			swagJson.arrowSkin = "NOTE_assets";

		if (swagJson.splashSkin == null || swagJson.splashSkin.trim().length == 0)
			swagJson.splashSkin = "noteSplashes";

		songJson.hudSkin ??= 'default';

		songJson.offset ??= 0.0;
		songJson.keyCount ??= switch(songJson.mania) {
			case 3: 9;
			case 2: 7;
			case 1: 6;
			default: 4;
		}

		if (swagJson.notes == null || swagJson.notes.length == 0) {		
			//// must have at least one section
			swagJson.notes = [{
				sectionNotes: [],
				typeOfSection: 0,
				mustHitSection: true,
				gfSection: false,
				bpm: 0,
				changeBPM: false,
				altAnim: false,
				sectionBeats: 4
			}];
			
		}else {
			onLoadEvents(swagJson);

			////
			for (section in swagJson.notes) {
				for (note in section.sectionNotes) {
					var type:Dynamic = note[3];
					
					if (Std.isOfType(type, String))
					{
						if (type == 'Hurt Note')
							type = 'Mine';
					}
					else if (Std.isOfType(type, Int) && type > 0)
						type = defaultNoteTypeList[type];
					else if (type == true)
						type = "Alt Animation";
					else
						type = '';
						
					note[3] = type;
				}
			}
		}		
		
		//// new tracks system
		if (swagJson.tracks == null) {
			swagJson.tracks = makeTrackData(songJson);
			trace(swagJson.tracks);
		}

		return swagJson;
	}

	public static function onLoadEvents(songJson:SwagSong) {
		if (songJson.events == null){
			songJson.events = [];
		}

		//// convert ancient psych event notes
		if (songJson.notes != null) {
			for (secNum in 0...songJson.notes.length) {
				var sec:SwagSection = songJson.notes[secNum];
				var notes:Array<Dynamic> = sec.sectionNotes;
				var len:Int = notes.length;
				var i:Int = 0;
				while(i < len)
				{
					var note:Array<Dynamic> = notes[i];
					if (note[1] < 0)
					{
						songJson.events.push([note[0], [[note[2], note[3], note[4]]]]);
						notes.remove(note);
						len = notes.length;
					}
					else i++;
				}
			}
		}	

		return songJson;
	}

	public static function getEventNotes(rawEventsData:Array<Array<Dynamic>>, ?resultArray:Array<PsychEvent>):Array<PsychEvent>
	{
		if (resultArray==null) resultArray = [];
		
		var eventsData:Array<Array<Dynamic>> = [];
		
		for (event in rawEventsData) {
			// TODO: Probably just add a button in the chart editor to consolidate events, instead of automatically doing it
			// As automatically doing this breaks some charts vv

/* 			var last = eventsData[eventsData.length-1];
			
			if (last != null && Math.abs(last[0] - event[0]) <= Conductor.jackLimit){
				var fuck:Array<Array<Dynamic>> = event[1];
				for (shit in fuck) eventsData[eventsData.length - 1][1].push(shit);
			}else */
				eventsData.push(event);
		}

		for (event in eventsData) //Event Notes
		{
			var eventTime:Float = event[0] + ClientPrefs.noteOffset;
			var subEvents:Array<Array<Dynamic>> = event[1];

			for (eventData in subEvents) {
				var eventNote:PsychEvent = {
					strumTime: eventTime,
					event: eventData[0],
					value1: eventData[1],
					value2: eventData[2]
				};
				resultArray.push(eventNote);
			}
		}

		return resultArray;
	}

	public static function makeTrackData(songJson:JsonSong):SongTracks {
		var instTracks:Array<String> = ["Inst"];
		if (songJson.extraTracks != null) {
			for (name in songJson.extraTracks)
				instTracks.push(name);
		}

		if (songJson.needsVoices == false) {
			// Song doesn't play vocals
			return {inst: instTracks, player: [], opponent: []};
		}
		else if (songJson._path == null) {
			// Default
			return {inst: instTracks, player: ["Voices-Player"], opponent: ["Voices-Opponent"]};
		}
		else {
			var folderPath:String = new Path(songJson._path).dir;
			inline function check(name:String):Null<String> // returns name if it exists, and null if not
				return Paths.exists(Path.join([folderPath, name + "." + Paths.SOUND_EXT])) ? name : null;

			inline function getVariantless(str):String
				return str.split('-')[0];

			var playerTrack:String = check('Voices-' + songJson.player1) ?? check('Voices-' + getVariantless(songJson.player1)) ?? check("Voices-Player") ?? 'Voices';
			var opponentTrack:String =  check('Voices-' + songJson.player2) ?? check('Voices-' + getVariantless(songJson.player2)) ?? check("Voices-Opponent") ?? 'Voices';			
			return {inst: instTracks, player: [playerTrack], opponent: [opponentTrack]};
		}
	}
}