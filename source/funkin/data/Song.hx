package funkin.data;

#if USING_MOONCHART
import moonchart.formats.fnf.legacy.FNFTroll as SupportedFormat;
import moonchart.formats.fnf.FNFVSlice;
import moonchart.formats.StepMania;
import moonchart.backend.FormatData.Format;
import moonchart.backend.FormatDetector;
#end

import funkin.states.LoadingState;
import funkin.states.PlayState;
import funkin.states.editors.ChartingState;
import funkin.data.BaseSong;
import haxe.io.Path;
import haxe.Json;

using funkin.CoolerStringTools;
using StringTools;

#if USING_MOONCHART
typedef StepManiaDynamic = moonchart.formats.StepMania.StepManiaBasic<moonchart.parsers.StepManiaParser.StepManiaFormat>;
#end

typedef PsychEvent = {
	strumTime:Float,
	event:String,
	value1:String,
	value2:String
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

final defaultDifficultyOrdering:Array<String>  = ["easy", "normal", "hard", "erect", "nightmare"];

class Song extends BaseSong
{
	public var songPath:String;

	private var _charts:Array<String> = null;
	private var metadataCache = new Map<String, SongMetadata>();

	public function new(songId:String, ?folder:String)
	{
		super(songId, folder);
		this.songPath = Paths.getFolderPath(this.folder) + '/songs/$songId';
	}

	/**
	 * Returns a path to a file of name fileName that belongs to this song
	**/
	public function getSongFile(fileName:String) {
		return '$songPath/$fileName';
	}

	public function play(chartId:String = '') {
		if (chartId == "") {
			var charts = getCharts();
			chartId = charts.contains(DEFAULT_CHART_ID) ? DEFAULT_CHART_ID : charts[0];
		}

		Song.playSong(this, chartId);
	}

	/** get uncached metadata **/
	private function _getMetadata(chartId:String):Null<SongMetadata> {
		var suffix = getDifficultyFileSuffix(chartId);
		var fileName:String = 'metadata' + suffix + '.json';
		var path:String = getSongFile(fileName);
		return Paths.getJson(path);
	}

	/**
	 * Returns metadata for the requested chartId. 
	 * If it doesn't exist, metadata for the default chart is returned instead
	 * 
	 * @param chartId The song chart for which you want to request metadata
	**/
	public function getMetadata(chartId:String = DEFAULT_CHART_ID):SongMetadata {
		if (chartId=="")
			chartId=DEFAULT_CHART_ID;

		if (metadataCache.exists(chartId)) {
			//trace('$this: Returning cached metadata for $chartId');
			return metadataCache.get(chartId);
		}

		var meta = _getMetadata(chartId);
		if (meta != null) {
			//trace('$this: Found metadata for $chartId');
		}
		else if (chartId != DEFAULT_CHART_ID) {
			if (Main.showDebugTraces)
				trace('$this: Metadata not found for [$chartId]. Using default');
			return getMetadata(DEFAULT_CHART_ID);
		}
		else {
			if (Main.showDebugTraces)
				trace('$this: No metadata found! Maybe add some?');
			meta = {};
		}
		meta.songName ??= songId.replace("-", " ").capitalize();

		metadataCache.set(chartId, meta);
		return meta;
	}

	/**
	 * Returns chart data for the requested chartId. 
	 * If it doesn't exist, null is returned instead
	 * 
	 * @param chartId The song chart for which you want to request chart data
	**/
	public function getSwagSong(chartId:String = DEFAULT_CHART_ID):Null<SwagSong> {
		if (chartId == '')
			chartId = DEFAULT_CHART_ID;

		#if !USING_MOONCHART
		var suffix = getDifficultyFileSuffix(chartId);
		var path = getSongFile(songId + suffix + ".json");
		return parseSongJson(path);
		#else
		
		// less strict v-slice format detection
		// cause it won't detect it if you place the audio files in the same folder
		var chartsFilePath = getSongFile('$songId-chart.json');
		var metadataPath = getSongFile('$songId-metadata.json');

		if (Paths.exists(chartsFilePath) && Paths.exists(metadataPath)) {
			var chart = new FNFVSlice().fromFile(chartsFilePath, metadataPath);
			if (chart.diffs.contains(chartId)) {
				trace("CONVERTING FROM VSLICE");
				
				var converted = new SupportedFormat().fromFormat(chart, chartId);
				var chart:JsonSong = cast converted.data.song;
				chart._path = chartsFilePath;
				chart.song = songId;
				chart.tracks = null;
				return onLoadJson(chart);
			}else{
				trace('VSLICE FILES DO NOT CONTAIN DIFFICULTY CHART: $chartId');
			}
		}
	
		// TODO: scan through the song folder and look for the first thing that has a supported extension (if json then check if it has diffSuffix cus FNF formats!!)
		// Or dont since this current method lets you do a dumb thing AKA have 2 diff chart formats in a folder LOL

		var files:Array<String> = [];
		var diffSuffix:String = getDifficultyFileSuffix(chartId);
		if (diffSuffix != '') files.push(songId + diffSuffix);
		files.push(songId);

		for (input in files) {
			for (ext in moonchartExtensions) {
				var filePath:String = getSongFile('$input.$ext');
				if (!Paths.exists(filePath)) continue;

				var fileFormat:Null<Format> = FormatDetector.findFormat([filePath]);
				if (fileFormat == null) continue;

				switch(fileFormat) {
					case FNF_LEGACY_PSYCH | FNF_LEGACY | FNF_LEGACY_TROLL:
						return parseSongJson(filePath);
						
					default:
						trace('Converting from format $fileFormat!');

						var instance = FormatDetector.createFormatInstance(fileFormat).fromFile(filePath);
						if (instance.formatMeta.supportsDiffs && !instance.diffs.contains(chartId))
							continue;

						var chart:JsonSong = cast (new SupportedFormat().fromFormat(instance, chartId)).data.song;
						chart._path = filePath;
						chart.song = songId;
						chart.tracks = null;

						if (instance is StepManiaBasic) @:privateAccess {
							var instance:StepManiaDynamic = cast instance;
							chart.tracks = {inst: [Path.withoutExtension(instance.data.MUSIC)]};
							#if (moonchart <= "0.5.0")
							chart.metadata ??= {};
							chart.metadata.songName ??= instance.data.TITLE;
							#end
						}

						return onLoadJson(chart);
				}
			}
		}

		return null;
		#end
	}

	/**
	 * Returns an array of charts available for this song
	**/
	public function getCharts():Array<String>
		return _charts ?? (_charts = _getCharts());

	#if USING_MOONCHART
	public static var moonchartExtensions(get, null):Array<String> = [];
	static function get_moonchartExtensions(){
		if (moonchartExtensions.length == 0){
			for (key => data in FormatDetector.formatMap)
				if (!moonchartExtensions.contains(data.extension))
					moonchartExtensions.push(data.extension);
		}
		return moonchartExtensions;
	}

	static function isAMoonchartRecognizedFile(fileName:String) {
		for (ext in moonchartExtensions)
			if (fileName.endsWith('.$ext'))
				return true;
		
		return false;
	}
	#end

	private function _getCharts():Array<String>
	{		
		final songPath = getSongFile("");
		final charts:Map<String, Bool> = [];

		function processFileName(fileName:String) {
			var woExtension:String = Path.withoutExtension(fileName);
			if (woExtension == songId) {
				charts.set("normal", true);
			}
			else if (woExtension.startsWith('$songId-')){
				var diff = woExtension.substr(songId.length + 1);
				charts.set(diff, true);
			}
		}

		#if USING_MOONCHART				
		{
			var filePaths:Array<String> = [];
			var fileNames:Array<String> = [];

			Paths.iterateDirectory(songPath, (fileName:String)->{
				if (fileName.startsWith(songId) && isAMoonchartRecognizedFile(fileName)){
					filePaths.push(songPath+fileName);
					fileNames.push(fileName);
				}
			});

			var ALL_FILES_DETECTED_FORMAT = FormatDetector.findFormat(filePaths);
			if (ALL_FILES_DETECTED_FORMAT == FNF_VSLICE) {
				var chartsFilePath:String = getSongFile('$songId-chart.json');
				var metadataPath:String = getSongFile('$songId-metadata.json');
				var chart = new FNFVSlice().fromFile(chartsFilePath, metadataPath);
				for (diff in chart.diffs) charts.set(diff, true);
				
			}else {
				for (i in 0...filePaths.length) {
					var filePath:String = filePaths[i];
					var fileFormat:Format = FormatDetector.findFormat(filePath);
					//trace(filePath, fileFormat);
					
					var instance = FormatDetector.createFormatInstance(fileFormat);
					if (instance.formatMeta.supportsDiffs) {
						instance = instance.fromFile(filePath);
						for (diff in instance.diffs)
							charts.set(diff, true);
						
					}else{
						var fileName:String = fileNames[i];
						processFileName(fileName);
					}
				}
			}
		}
		#else
		Paths.iterateDirectory(songPath, processFileName);		
		#end

		var chartNames:Array<String> = [for (name in charts.keys()) name];
		chartNames.sort(sortChartDifficulties);
		return chartNames;
	}

	public inline static function getDifficultyFileSuffix(diff:String) {
		diff = Paths.formatToSongPath(diff);
		return (diff=="" || diff=="normal") ? "" : '-$diff';
	}

	public static function sortChartDifficulties(a:String, b:String) {
		// stolen from v-slice lol!

		a = a.toLowerCase();
		b = b.toLowerCase();
		if(a==b)return 0;

		var aHasDefault = defaultDifficultyOrdering.contains(a);
		var bHasDefault = defaultDifficultyOrdering.contains(b);
		if (aHasDefault && bHasDefault)
			return defaultDifficultyOrdering.indexOf(a) - defaultDifficultyOrdering.indexOf(b);
		else if(aHasDefault)
			return 1;
		else if(bHasDefault)
			return -1;

		return a > b ? -1 : 1;
	}

	/** Return an array of strings related to the song's credits **/
	public static function getMetadataInfo(metadata:SongMetadata):Array<String> {
		var info:Array<String> = [];
		
		inline function pushInfo(str:String) {
			for (string in str.split('\n'))
				info.push(string);
		}

		if (metadata != null) {
			if (metadata.artist != null && metadata.artist.length > 0)		
				pushInfo("Artist: " + metadata.artist);

			if (metadata.charter != null && metadata.charter.length > 0)
				pushInfo("Chart: " + metadata.charter);

			if (metadata.modcharter != null && metadata.modcharter.length > 0)
				pushInfo("Modchart: " + metadata.modcharter);
		}

		if (metadata != null && metadata.extraInfo != null) {
			for (extraInfo in metadata.extraInfo)
				pushInfo(extraInfo);
		}

		return info;
	}

	private static function _parseSongJson(filePath:String, isChartJson:Bool = true):SwagSong {
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

	public static function parseSongJson(filePath:String, isChartJson:Bool = true):Null<SwagSong> {
		try {
			return _parseSongJson(filePath, isChartJson);
		}catch(e) {
			trace('ERROR parsing song JSON: $filePath', e.message);
			return null;
		}
	}

	public static function loadFromJson(jsonInput:String, folder:String, isChartJson:Bool = true):Null<SwagSong>
	{
		var path:String = Paths.formatToSongPath(folder) + '/' + Paths.formatToSongPath(jsonInput) + '.json';
		var fullPath = Paths.getPath('songs/$path', false);
		return parseSongJson(fullPath, isChartJson);
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

	private static function makeTrackData(songJson:JsonSong):SongTracks {
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

	private static function onLoadJson(songJson:JsonSong):SwagSong
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
						type = ChartingState.noteTypeList[type];
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

	/** Loads a singular song to be played on PlayState **/
	static public function loadSong(song:BaseSong, ?difficulty:String) {
		PlayState.loadPlaylist([song], difficulty);
	}

	/** Loads a singular song to be played on PlayState, then switches to it **/
	static public function playSong(song:BaseSong, ?difficulty:String)
	{
		loadSong(song, difficulty);
		switchToPlayState();
	}

	static public function switchToPlayState()
	{
		if (FlxG.sound.music != null)
			FlxG.sound.music.volume = 0;

		LoadingState.loadAndSwitchState(new PlayState());
	}
}