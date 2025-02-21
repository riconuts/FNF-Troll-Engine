package funkin.data;

#if USING_MOONCHART
import funkin.data.FNFTroll as SupportedFormat;
import moonchart.formats.BasicFormat;
import moonchart.backend.FormatData;
import moonchart.backend.FormatData.Format;
import moonchart.backend.FormatDetector;
#end

import funkin.states.LoadingState;
import funkin.states.PlayState;
import funkin.states.editors.ChartingState;
import funkin.data.Section.SwagSection;
import haxe.io.Path;
import haxe.Json;

using funkin.CoolerStringTools;
using StringTools;

typedef SwagSong = {
	//// internal
	@:optional var path:String;
	var validScore:Bool;

	////
	var song:String;
	var bpm:Float;
	var tracks:SongTracks; // currently used
	
	var speed:Float;
	var keyCount:Int;
	var notes:Array<SwagSection>;
	var events:Array<Array<Dynamic>>;
	var offset:Float; // Offsets the chart

	var player1:Null<String>;
	var player2:Null<String>;
	var gfVersion:Null<String>;
	var stage:String;
	var hudSkin:String;

	var arrowSkin:String;
	var splashSkin:String;
	
	//// Used for song info showed on the pause menu
	@:optional var metadata:SongMetadata;
}

typedef EventNote = {
	strumTime:Float,
	event:String,
	value1:String,
	value2:String
}

typedef JsonSong = {
	> SwagSong,

	@:optional var player3:String; // old psych
	@:optional var extraTracks:Array<String>; // old te
	@:optional var needsVoices:Bool; // fnf
	@:optional var mania:Int; // vs shaggy
	@:optional var keyCount:Int;
	@:optional var offset:Float;

	// @:optional var info:Array<String>; // old te
}

typedef SongTracks = {
	var inst:Array<String>;
	var ?player:Array<String>;
	var ?opponent:Array<String>;
} 

typedef SongMetadata =
{
	?songName:String,
	?artist:String,
	?charter:String,
	?modcharter:String,
	?extraInfo:Array<String>,
}

class Song
{
	public final songId:String;
	public final folder:String = '';

	public var songPath(get, default):String;
	public var charts(get, null):Array<String>;
	private var metadataCache = new Map<String, SongMetadata>();

	#if PE_MOD_COMPATIBILITY
	private final defaultSongPath:String;
	private final dataPath:String;

	inline function isUsingDefaultSongPath():Bool {
		@:bypassAccessor
		return this.songPath == null;
	}
	#end

	public function new(songId:String, ?folder:String)
	{
		this.songId = songId;
		this.folder = folder ?? '';
		#if !PE_MOD_COMPATIBILITY
		this.songPath = Paths.getFolderPath(this.folder) + '/songs/$songId';
		#else
		var contentFolder = Paths.getFolderPath(this.folder);
		this.defaultSongPath = '$contentFolder/songs/$songId';
		this.dataPath = '$contentFolder/data/$songId';
		#end
	}

	public function getSongFile(fileName:String) {
		var path = '$songPath/$fileName';

		#if PE_MOD_COMPATIBILITY
		if (isUsingDefaultSongPath() && !Paths.exists(path)) {
			var pp = '$dataPath/$fileName';
			if (Paths.exists(pp)) path = pp;
		}
		#end

		return path;
	}

	public function play(?chartName:String = ''){
		Song.playSong(this, chartName);
	}

	public function toString()
		return '$folder:$songId';

	/** get uncached metadata **/
	private function _getMetadata(chart:String):Null<SongMetadata> {
		var suffix = getDifficultyFileSuffix(chart);
		var fileName:String = 'metadata' + suffix + '.json';
		var path:String = getSongFile(fileName);
		return Paths.getJson(path);
	}

	/**
	 * Returns metadata for the requested chart. 
	 * If it doesn't exist, metadata for the 'normal' chart is returned instead
	 * 
	 * @param chartId The song chart for which you want to request metadata
	**/
	public function getMetadata(chartId:String = "normal"):SongMetadata {
		if (chartId=="")
			chartId="normal";

		if (metadataCache.exists(chartId)) {
			//trace('$this: Returning cached metadata for $chartId');
			return metadataCache.get(chartId);
		}

		var meta = _getMetadata(chartId);
		if (meta != null) {
			//trace('$this: Found metadata for $chartId');
		}
		else if (chartId != "normal") {
			if (Main.showDebugTraces)
				trace('$this: Metadata not found for [$chartId]. Using default');
			return getMetadata("normal");
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

	public function getSwagSong(chartId:String):Null<SwagSong> {
		if (chartId == '')
			chartId = 'normal';

		#if !USING_MOONCHART
		var suffix = getDifficultyFileSuffix(chartId);
		var path = getSongFile(songId + suffix);
		return parseSongJson(path);
		#else
		
		// less strict v-slice format detection
		// cause it won't detect it if you place the audio files in the same folder
		var chartsFilePath = getSongFile('$songId-chart.json');
		var metadataPath = getSongFile('$songId-metadata.json');

		if (Paths.exists(chartsFilePath) && Paths.exists(metadataPath)) {
			var chart = new moonchart.formats.fnf.FNFVSlice().fromFile(chartsFilePath, metadataPath);
			if (chart.diffs.contains(chartId)) {
				trace("CONVERTING FROM VSLICE");
				
				var converted = new SupportedFormat().fromFormat(chart, chartId);
				var chart:JsonSong = cast converted.data.song;
				chart.path = chartsFilePath;
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

		for (ext in moonchartExtensions) {
			for (input in files) {
				var filePath:String = getSongFile('$input.$ext');
				var fileFormat:Null<Format> = findFormat([filePath]);

				switch(fileFormat) {
					case null:
						continue;

					case FNF_LEGACY_PSYCH | FNF_LEGACY | "FNF_TROLL":
						return parseSongJson(filePath);
						
					default:
						trace('Converting from format $fileFormat!');

						var formatInfo:Null<FormatData> = FormatDetector.getFormatData(fileFormat);
						var chart:moonchart.formats.BasicFormat<{}, {}>;
						chart = cast Type.createInstance(formatInfo.handler, []);
						chart = chart.fromFile(filePath);

						if (chart.formatMeta.supportsDiffs && !chart.diffs.contains(chartId))
							continue;

						var converted = new SupportedFormat().fromFormat(chart, chartId);
						var chart:JsonSong = cast converted.data.song;
						chart.path = filePath;
						chart.song = songId;
						return onLoadJson(chart);
				}
			}
		}

		return null;
		#end
	}

	//
	function get_charts() 
		return charts ?? (charts = Song.getCharts(this));

	function get_songPath()
		return songPath #if PE_MOD_COMPATIBILITY ?? defaultSongPath #end;

	////

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

	#if USING_MOONCHART
	private static function findFormat(filePaths:Array<String>) {
		var files:Array<String> = [];
		for (path in filePaths) {
			if (Paths.exists(path)) 
				files.push(path);
		}

		if (files.length == 0)
			return null;
		
		var data:Null<Format> = null;
		try{
			data = FormatDetector.findFormat(files);
		}catch(e:Any){
			data = null;
		}
		return data;
	}

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

	public static function getCharts(song:Song):Array<String>
	{
		Paths.currentModDirectory = song.folder;
		
		final songId:String = song.songId;
		final charts:Map<String, Bool> = [];

		#if USING_MOONCHART
		var folder:String = '';
		
		function processFileName(unprocessedName:String) {
			var fileName:String = unprocessedName.toLowerCase();
			var filePath:String = folder + unprocessedName;

			if (!isAMoonchartRecognizedFile(fileName))
				return;

			var fileFormat:Format = findFormat([filePath]);
			if (fileFormat == null) return;

			switch (fileFormat) {
				case FNF_LEGACY_PSYCH | FNF_LEGACY:
					if (fileName == '$songId.json') {
						charts.set("normal", true);
						return;
					} 
					else if (fileName.startsWith('$songId-')) {
						final extension_dot = songId.length + 1;
						charts.set(fileName.substr(extension_dot, fileName.length - extension_dot - 5), true);
						return;
					}
					
				default:
					var formatInfo:FormatData = FormatDetector.getFormatData(fileFormat);
					var chart:moonchart.formats.BasicFormat<{}, {}>;
					chart = cast Type.createInstance(formatInfo.handler, []).fromFile(filePath);

					if (chart.formatMeta.supportsDiffs || chart.diffs.length > 0){
						for (diff in chart.diffs)
							charts.set(diff, true);
						
					}else{
						var woExtension:String = Path.withoutExtension(filePath);
						if (woExtension == songId){
							charts.set("normal", true);
							return;
						}
						if (woExtension.startsWith('$songId-')){
							var split = woExtension.split("-");
							split.shift();
							var diff = split.join("-");
							if(diff == 'DEFAULT_DIFF')
								diff = 'Moonchart';
							
							charts.set(diff, true);
							return;
						}
					}

			}
		}

		if (song.folder == "") {
			folder = Paths.getPreloadPath('songs/$songId/');
			Paths.iterateDirectory(folder, processFileName);
		}
		#if MODS_ALLOWED
		else {
			////
			var spoon:Array<String> = [];
			var crumb:Array<String> = [];

			folder = Paths.mods('${song.folder}/songs/$songId/');
			Paths.iterateDirectory(folder, (fileName)->{
				if (isAMoonchartRecognizedFile(fileName)){
					spoon.push(folder+fileName);
					crumb.push(fileName);
				}
			});

			var ALL_FILES_DETECTED_FORMAT = findFormat(spoon);
			if (ALL_FILES_DETECTED_FORMAT == FNF_VSLICE) {
				var chartsFilePath:String = folder + songId + '-chart.json';
				var metadataPath:String = folder + songId + '-metadata.json';
				var chart = new moonchart.formats.fnf.FNFVSlice().fromFile(chartsFilePath, metadataPath);
				for (diff in chart.diffs) charts.set(diff, true);
				
			}else {
				for (fileName in crumb) processFileName(fileName);
			}

			////
			#if PE_MOD_COMPATIBILITY
			folder = Paths.mods('${song.folder}/data/$songId/');
			Paths.iterateDirectory(folder, processFileName);
			#end
		}
		#end

		var allCharts:Array<String> = [for (name in charts.keys()) name];
		var chartNames:Array<String> = [];

		for (name in allCharts)
			chartNames.push(name);

		return chartNames;
		#else
		
		function processFileName(unprocessedName:String)
		{		
			var fileName:String = unprocessedName.toLowerCase();
			if (fileName == '$songId.json'){
				charts.set("normal", true);
				return;
			}
			else if (!fileName.startsWith('$songId-') || !fileName.endsWith('.json')){
				return;
			}

			final extension_dot = songId.length + 1;
			charts.set(fileName.substr(extension_dot, fileName.length - extension_dot - 5), true);
		}

		var contentPath = Paths.getFolderPath(song.folder);
		#if PE_MOD_COMPATIBILITY
		Paths.iterateDirectory('$contentPath/data/$songId/', processFileName);
		#end
		Paths.iterateDirectory('$contentPath/songs/$songId/', processFileName);
		
		return [for (name in charts.keys()) name];
		#end
	}

	// TODO: GEt rid of this, just save the charts as "-normal" grrrr
	public inline static function getDifficultyFileSuffix(diff:String) {
		diff = Paths.formatToSongPath(diff);
		return (diff=="" || diff=="normal") ? "" : '-$diff';
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

		songJson.path = filePath;
		return isChartJson ? onLoadJson(songJson) : onLoadEvents(songJson);
	}

	private static function parseSongJson(filePath:String, isChartJson:Bool = true):Null<SwagSong> {
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

		#if PE_MOD_COMPATIBILITY
		if (!Paths.exists(fullPath))
			fullPath = Paths.getPath('data/$path', false);
		#end

		return parseSongJson(fullPath);
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

		/**
			`null` gfVersion means no girlfriend character will be created, 
			but if gfVersion isn't defined in the json then gfVersion will default to `gf`
			This is done so that old base game charts still show a girlfriend character
		**/
		if (songJson.gfVersion==null && songJson.player3 != null)
			songJson.gfVersion = songJson.player3;
		else if (!Reflect.hasField(songJson, 'gfVersion'))
			songJson.gfVersion = 'gf';
		
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
					
					if (Std.isOfType(type, String)) {
						if (type == 'Hurt Note')
							type = 'Mine';
					}else if (type == true)
						type = "Alt Animation";
					else if (Std.isOfType(type, Int) && type > 0)
						type = ChartingState.noteTypeList[type];
						
					note[3] = type;
				}
			}
		}		
		
		//// new tracks system
		if (swagJson.tracks == null) {
			var instTracks:Array<String> = ["Inst"];

			if (songJson.extraTracks != null) {
				for (name in songJson.extraTracks)
					instTracks.push(name);
			}

			////
			var playerTracks:Array<String> = null;
			var opponentTracks:Array<String> = null;

			/**
			 * 2. If the chart folder couldn't be retrieved then "Voices-Player" and "Voices-Opponent" are used
			 * 3. Define the first one existing in ['Voices-$player1', 'Voices-Player', 'Voices'] as a player track;
			 * 4. Define the first one existing in ['Voices-$player2', 'Voices-Opponent', 'Voices'] as an opponent track;
			 */
			inline function sowy() {
				//// 1
				if (songJson.needsVoices == false) {
					playerTracks = [];
					opponentTracks = [];
					return false;
				}

				//// 2
				if (swagJson.path==null) return true;
				var jsonPath:Path = new Path(swagJson.path
					#if PE_MOD_COMPATIBILITY
					.replace("data/", "songs/")
					#end);

				var folderPath = jsonPath.dir;
				if (folderPath == null) return true; // could mean that it's somehow on the same folder as the exe but fuck it

				//// 3 and 4
				inline function existsInFolder(name)
					return Paths.exists(Path.join([folderPath, name]));

				var defaultVoices = existsInFolder('Voices.ogg') ? ["Voices"] : [];

				inline function voiceTrack(name)
					return existsInFolder('$name.ogg') ? [name] : defaultVoices;
				
				var trackName = 'Voices-${swagJson.player1}';
				playerTracks = existsInFolder('$trackName.ogg') ? [trackName] : voiceTrack("Voices-Player");

				var trackName = 'Voices-${swagJson.player2}';
				opponentTracks =  existsInFolder('$trackName.ogg') ? [trackName] : voiceTrack("Voices-Opponent");

				return false;
			}
			if (sowy()) {
				playerTracks = ["Voices-Player"];
				opponentTracks = ["Voices-Opponent"];
			}

			////
			swagJson.tracks = {inst: instTracks, player: playerTracks, opponent: opponentTracks};
			trace(swagJson.tracks);
		}

		return swagJson;
	}

	public static function getEventNotes(rawEventsData:Array<Array<Dynamic>>, ?resultArray:Array<EventNote>):Array<EventNote>
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
				var eventNote:EventNote = {
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

	static public function loadSong(toPlay:Song, ?difficulty:String) {
		Paths.currentModDirectory = toPlay.folder;

		if (difficulty == "") {
			difficulty = "normal";
		}
		else if (difficulty == null) {
			if (toPlay.charts.contains("normal"))
				difficulty = "normal";
			else
				difficulty = toPlay.charts[0];
		}

		if (Main.showDebugTraces)
			trace('loadSong', toPlay, difficulty);

		PlayState.SONG = toPlay.getSwagSong(difficulty);
		PlayState.difficulty = toPlay.charts.indexOf(difficulty);
		PlayState.difficultyName = difficulty;
		PlayState.isStoryMode = false;

		PlayState.songPlaylist = [toPlay];
		PlayState.songPlaylistIdx = 0;
	}

	static public function switchToPlayState()
	{
		if (FlxG.sound.music != null)
			FlxG.sound.music.volume = 0;

		LoadingState.loadAndSwitchState(new PlayState());	
	}

	static public function playSong(song:Song, ?difficulty:String)
	{
		loadSong(song, difficulty);
		switchToPlayState();
	} 
}