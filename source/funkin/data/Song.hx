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
import funkin.data.ChartData;
import funkin.data.BaseSong;
import haxe.io.Path;

using funkin.CoolerStringTools;
using StringTools;

#if USING_MOONCHART
typedef StepManiaDynamic = moonchart.formats.StepMania.StepManiaBasic<moonchart.parsers.StepManiaParser.StepManiaFormat>;
#end

final defaultDifficultyOrdering:Array<String>  = ["easy", "normal", "hard", "erect", "nightmare"];

class Song extends BaseSong
{
	public var songPath:String;

	private var _charts:Array<String> = null;
	private var metadataCache = new Map<String, SongMetadata>();

	public function new(songId:String, ?folder:String)
	{
		super(songId, folder);
		this.songPath = Paths.getFolderPath(this.folder) + 'songs/$songId';
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
		return ChartData.parseSongJson(path);
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

				// holds are too long when from v-slice
				var stepLength:Float = Conductor.calculateStepCrochet(converted.data.song.bpm);
				for (section in converted.data.song.notes){
					for(note in section.sectionNotes)
						if(note.length > stepLength * 2)
							note[2] -= stepLength * 2;
					
				}


				var chart:JsonSong = cast converted.data.song;
				chart._path = chartsFilePath;
				chart.song = songId;
				chart.tracks = null;
				return ChartData.onLoadJson(chart);
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
						return ChartData.parseSongJson(filePath);
						
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

						return ChartData.onLoadJson(chart);
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

			if (filePaths.length == 0){
				trace('$songPath has no charts! WHAT THE FUCK??');
				trace('Make sure $songId is formatted correctly lol');
				return [];
			}

			// Should probably return a Format.UNKNOWN or some shit instead of ERRORING
			// but o well
			var ALL_FILES_DETECTED_FORMAT = Format.FNF_LEGACY;
			try {
				ALL_FILES_DETECTED_FORMAT = FormatDetector.findFormat(filePaths);
			}
			catch(e:Dynamic){
				return [];
			}

			if (ALL_FILES_DETECTED_FORMAT == FNF_VSLICE) {
				var chartsFilePath:String = getSongFile('$songId-chart.json');
				var metadataPath:String = getSongFile('$songId-metadata.json');
				var chart = new FNFVSlice().fromFile(chartsFilePath, metadataPath);
				for (diff in chart.diffs) charts.set(diff, true);
				
			}else {
				for (i in 0...filePaths.length) {
					var filePath:String = filePaths[i];
					var fileFormat: Format = Format.FNF_LEGACY;
					try {
						fileFormat = FormatDetector.findFormat(filePath);
					} catch(e: Dynamic){
						trace("Couldn't find format probably?? Defaulting to FNF Legacy");
						trace(e);
					}
					
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