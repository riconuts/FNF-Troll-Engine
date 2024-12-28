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

	public var songs:Map<String, Song> = [];

	public var levels:Map<String, Level> = []; 

	public var vars:Map<String, Dynamic> = []; // scripts could store shit here to make up for the lack of static variables

	public function new(id:String, path:String) 
	{
		path = path.endsWith("/") ? path.substr(0, path.length-1) : path;

		this.id = id;
		this.path = path;
	}

	// For path code convenience
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

	public function scanSongs() {
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

	public function scanLevels() {
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
			for (ext in Paths.HSCRIPT_EXTENSIONS) {
				var path = '$basePath.$ext';
				if (Paths.exists(path)) {
					scriptPath = path;
					break;
				}
			}
			
			if (jsonData == null && scriptPath == null) {
				//trace('$basePath: no json or script to register level');
				return;
			}

			var level = new DataLevel(this, id, jsonData, scriptPath);
			this.levels.set(level.id, level);
		});

		return this.levels;
	}

	public var freeplaySonglist(get, null):Array<Song> = null;
	function get_freeplaySonglist():Array<Song> {
		if (freeplaySonglist != null)
			return freeplaySonglist;

		var rawFile = this.getContent('data/freeplaySonglist.txt');
		if (rawFile != null) {
			var list = [];

			for (line in rawFile.split('\n')) {
				var id = line.rtrim();
				var song = this.songs.get(id);
				if (song != null) list.push(song);
			}

			return list;
		}

		return [for (song in this.songs) song];
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

	override function get_freeplaySonglist():Array<Song> {
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