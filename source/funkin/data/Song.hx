package funkin.data;

import funkin.states.LoadingState;
import funkin.states.PlayState;
import funkin.data.ChartData;
import funkin.data.BaseSong;
import haxe.io.Path;

using funkin.CoolerStringTools;
using StringTools;

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

		var suffix = getDifficultyFileSuffix(chartId);
		var path = getSongFile(songId + suffix + ".json");
		return ChartData.parseSongJson(path);
	}

	/**
	 * Returns an array of charts available for this song
	**/
	public function getCharts():Array<String>
		return _charts ?? (_charts = _getCharts());

	@:deprecated
	public function play(chartId:String = '')
		Song.playSong(this, getChartId(chartId));


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

		Paths.iterateDirectory(songPath, processFileName);		

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