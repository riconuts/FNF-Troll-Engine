package funkin.data;

import funkin.data.Level;
import funkin.data.Level.Level as Level;
import funkin.data.Level.PsychWeekFile;
import funkin.data.Song;
import openfl.display.BitmapData;
import openfl.media.Sound;
import haxe.io.Path;

using StringTools;

class ContentData
{
	/** Content folder identificator*/
	public var id:String;

	/** Content folder path */
	public var path:String;

	public var runsGlobally:Bool = false;

	public var dependencies:Array<String> = [];

	////
	public var songs:Map<String, Song> = [];

	public var levels:Map<String, Level> = []; 

	public var stageList:Array<String> = [];

	public var vars:Map<String, Dynamic> = []; // scripts could store shit here to make up for the lack of static variables

	////
	public function new(id:String, path:String) 
	{
		path = path.endsWith("/") ? path.substr(0, path.length-1) : path;

		this.id = id;
		this.path = path;
	}

	public function create() 
	{
		this.scanSongs();
		this.scanLevels();
		this.scanStages();
	}

	////
	public function getPath(key:String):String 
	{
		return '$path/$key';
	}

	public function getBitmapData(key:String):BitmapData
	{
		return Paths.getBitmapData(this.getPath(key));
	}

	public function getSound(key:String):Sound
	{
		return Paths.getSound(this.getPath(key));
	}

	public function getContent(key:String):String
	{
		return Paths.getContent(this.getPath(key));
	}

	////

	public function getFreeplaySongList():Array<Song> {
		// TODO: FreeplaySong class
		// For opponent icons, bg colors, and possibly different bg's per song instead of per mod
		
		return fileFreeplaySongList;
	}

	public function getStoryModeLevelList():Array<Level> {
		return fileStoryModeLevelList;
	}

	public function getTitleStages():Array<String> {
		return stageList;
	}

	//// 
	private function scanSongs() {
		this.songs.clear();

		scanFolderForSongs('songs');

		return this.songs;
	}

	private function scanFolderForSongs(folderKey) {
		var path = getPath(folderKey);

		Paths.iterateDirectory(path, (name) -> {
			if (this.songs.exists(name))
				return;

			var song = new Song(name, this.id);
			if (song.charts.length > 0)
				this.songs.set(name, song);
			else
				trace('No charts found for $name');
		});
	}

	private function scanLevels() {
		this.levels.clear();

		var folderPath:String = getPath("levels");
		Paths.iterateDirectory(folderPath, function(fileName) {
			var p = new Path(Path.join([folderPath, fileName]));
			var id = p.file;

			if (levels.exists(id))
				return;

			p.ext = null;
			var basePath:String = p.toString();
			
			var jsonPath:String = '$basePath.json';
			var jsonData:Dynamic = Paths.getJson(jsonPath);

			var scriptPath:Null<String> = null;
			/*for (ext in Paths.HSCRIPT_EXTENSIONS) {
				var path = '$basePath.$ext';
				if (Paths.exists(path)) {
					scriptPath = path;
					break;
				}
			}*/
			
			if (jsonData == null && scriptPath == null) {
				//trace('$basePath: no json or script to register level');
				return;
			}

			var level = new DataLevel(this, id, jsonData);
			this.levels.set(level.id, level);
		});

		return this.levels;
	}

	private function scanStages():Array<String> {
		if (stageList != null)
			return stageList;

		var map:Map<String, Bool> = [];
		var folderPath = this.getPath("stages");
		Paths.iterateDirectory(folderPath, (fileName:String) -> {			
			if (fileName.endsWith(".json") || Paths.isHScript(fileName)) 
				map.set(Path.withoutExtension(fileName), true);
		});
		
		return [for (k in map.keys()) k];
	}

	private var fileFreeplaySongList(get, null):Array<Song> = null;
	private function get_fileFreeplaySongList():Array<Song> {
		if (fileFreeplaySongList != null)
			return fileFreeplaySongList;

		var rawFile = this.getContent('data/freeplaySonglist.txt');
		if (rawFile != null) {
			var list = [];

			for (line in rawFile.split('\n')) {
				var lineSplit = line.rtrim().split(':');
				var songId = lineSplit[0];	
				var iconId = lineSplit[1];
				var bgColor = lineSplit[2];
				//var bgGraphic = lineSplit[3];

				if (this.songs.exists(songId)) {
					list.push(this.songs.get(songId));
				}
			}

			return list;
		}

		return [for (song in this.songs) song];
	}

	private var fileStoryModeLevelList(get, null):Array<Level> = null;
	private function get_fileStoryModeLevelList():Array<Level> {
		if (fileStoryModeLevelList != null)
			return fileStoryModeLevelList;

		var rawFile = this.getContent('data/levelList.txt');
		if (rawFile != null) {
			var list = [];

			for (line in rawFile.split('\n')) {
				var levelId = line.rtrim();
				if (this.levels.exists(levelId)) {
					list.push(this.levels.get(levelId));
				}
			}

			return list;
		}

		return [for (level in this.levels) level];
	}
}

class PsychContentData extends ContentData 
{
	public function new(id:String , path:String) {
		super(id, path);
	}

	override function scanSongs() {
		// super.scanSongs();

		scanFolderForSongs("data");
		
		return this.songs;
	}

	override function scanLevels() {
		this.levels.clear();

		var folderPath = this.getPath("weeks");
		Paths.iterateDirectory(folderPath, (fileName:String) -> {
			if (!fileName.endsWith(".json"))
				return;

			var levelId = fileName.substr(0, fileName.length-5);
			var filePath = '$folderPath/$fileName';
			var jsonData:PsychWeekFile = Paths.getJson(filePath);
			
			var level = new PsychLevel(this, levelId, jsonData);
			this.levels.set(level.id, level);
		});

		return this.levels;
	}

	override function get_fileFreeplaySongList():Array<Song> {
		var list = [];

		for (level in this.levels) {
			trace(level.id);

			if (!level.getUnlocked()) {
				trace('is hidden');
				continue;
			}

			for (song in level.getPlaylist()) {
				trace(song);
				list.push(song);
			}
		}

		return list;
	}
}