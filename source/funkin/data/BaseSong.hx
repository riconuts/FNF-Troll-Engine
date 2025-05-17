package funkin.data;

inline final DEFAULT_CHART_ID = "normal";

abstract class BaseSong
{
	public final songId:String;
	public final folder:String = '';

	public function new(songId:String, folder:String = '')
	{
		this.songId = songId;
		this.folder = folder;
	}

	public function toString()
		return '$folder:$songId';

	/**
	 * Returns metadata for the requested chartId. 
	 * If it doesn't exist, metadata for the default chart is returned instead
	 * 
	 * @param chartId The song chart for which you want to request metadata
	**/
	abstract public function getMetadata(chartId:String = DEFAULT_CHART_ID):SongMetadata;

	/**
	 * Returns chart data for the requested chartId. 
	 * If it doesn't exist, null is returned instead
	 * 
	 * @param chartId The song chart for which you want to request chart data
	**/
	abstract public function getSwagSong(chartId:String = DEFAULT_CHART_ID):Null<SwagSong>;

	/**
	 * Returns a path to a file of name fileName that belongs to this song
	**/
	abstract public function getSongFile(fileName:String):String;

	/**
	 * Returns an array of charts available for this song
	**/
	abstract public function getCharts():Array<String>;
}

typedef SongMetadata =
{
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
	@:optional var metadata:SongMetadata;

	//// internal
	@:optional var path:String;
	var validScore:Bool;
}

typedef SwagSection =
{
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