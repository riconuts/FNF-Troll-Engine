package funkin.data;

import funkin.data.Song;

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