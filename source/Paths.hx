package;

import flixel.FlxG;
import flixel.graphics.FlxGraphic;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.addons.display.FlxRuntimeShader;
import openfl.utils.Assets as Assets;
import openfl.display.BitmapData;
import openfl.utils.AssetType;
import openfl.media.Sound;
import haxe.Json;
import ChapterData.ChapterMetadata;

using StringTools;
#if sys
import sys.FileSystem;
import sys.io.File;
#end

/*
#if tgt
typedef FreeplayCategoryMetadata = FreeplayState.FreeplayCategoryMetadata;
typedef FreeplaySongMetadata = FreeplayState.FreeplaySongMetadata;
#end
*/

class Paths
{
	public static var globalContent:Array<String> = [];
	public static var preLoadContent:Array<String> = [];
	public static var postLoadContent:Array<String> = [];

	inline public static var SOUND_EXT = "ogg";
	inline public static var VIDEO_EXT = "mp4";

	public static var dumpExclusions:Array<String> = [
		'assets/music/freakyIntro.$SOUND_EXT',
		'assets/music/freakyMenu.$SOUND_EXT',
		'assets/music/breakfast.$SOUND_EXT',
		'content/global/music/freakyIntro.$SOUND_EXT',
		'content/global/music/freakyMenu.$SOUND_EXT',
		'content/global/music/breakfast.$SOUND_EXT',
		"assets/images/Garlic-Bread-PNG-Images.png"
	];

	public static function excludeAsset(key:String)
	{
		if (!dumpExclusions.contains(key))
			dumpExclusions.push(key);
	}

	/// haya I love you for the base cache dump I took to the max
	public static function clearUnusedMemory()
	{
		// clear non local assets in the tracked assets list
		for (key in currentTrackedAssets.keys())
		{
			// if it is not currently contained within the used local assets
			if (!localTrackedAssets.contains(key) && !dumpExclusions.contains(key))
			{
				// get rid of it
				var obj = currentTrackedAssets.get(key);
				@:privateAccess
				if (obj != null)
				{
					Assets.cache.removeBitmapData(key);
					FlxG.bitmap._cache.remove(key);
					obj.destroy();
					currentTrackedAssets.remove(key);

					// trace('cleared $key');
				}
			}
		}
		// run the garbage collector for good measure lmfao
		openfl.system.System.gc();
	}

	/** removeBitmap(FlxSprite.graphic.key); **/
	public static function removeBitmap(key:String)
	{
		var obj = currentTrackedAssets.get(key);
		@:privateAccess
		if (obj != null)
		{
			localTrackedAssets.remove(key);

			Assets.cache.removeBitmapData(key);
			FlxG.bitmap._cache.remove(key);
			obj.destroy();
			currentTrackedAssets.remove(key);
			
			//trace('removed $key');
			//return true;
		}

		//trace('did not remove $key');
		//return false;
	}

	// define the locally tracked assets
	public static var localTrackedAssets:Array<String> = [];

	public static function clearStoredMemory()
	{
		// clear anything not in the tracked assets list
		@:privateAccess
		for (key in FlxG.bitmap._cache.keys())
		{
			var obj = FlxG.bitmap._cache.get(key);
			if (obj != null && !currentTrackedAssets.exists(key))
			{
				Assets.cache.removeBitmapData(key);
				FlxG.bitmap._cache.remove(key);
				obj.destroy();
			}
		}

		// clear all sounds that are cached
		for (key in currentTrackedSounds.keys())
		{
			if (!localTrackedAssets.contains(key) && !dumpExclusions.contains(key) && key != null)
			{
				// trace('test: ' + dumpExclusions, key);
				Assets.cache.clear(key);
				currentTrackedSounds.remove(key);
			}
		}
		// flags everything to be cleared out next unused memory clear
		localTrackedAssets = [];
		Assets.cache.clear("songs");
		// remove the cached strings
		currentStrings.clear();
	}

	static public var currentStrings:Map<String,String> = [];

	static public var currentModAddons:Array<String> = [];
	static public var currentModDirectory:String = '';
	static public var currentModLibraries:Array<String> = [];
	public static function getPath(file:String, ?type:AssetType, ?library:Null<String> = null)
	{
		return getPreloadPath(file);
	}

	inline public static function getPreloadPath(file:String = '')
	{
		return 'assets/$file';
	}

	inline static public function file(file:String, type:AssetType = TEXT, ?library:String)
	{
		return getPath(file, type, library);
	}

	inline static public function txt(key:String, ?library:String)
	{
		return getPath('data/$key.txt', TEXT, library);
	}

	inline static public function xml(key:String, ?library:String)
	{
		return getPath('data/$key.xml', TEXT, library);
	}

	inline static public function songJson(key:String, ?library:String)
	{
		return getPath('songs/$key.json', TEXT, library);
	}

	inline static public function shaderFragment(key:String, ?library:String)
	{
		return getPath('shaders/$key.frag', TEXT, library);
	}

	inline static public function shaderVertex(key:String, ?library:String)
	{
		return getPath('shaders/$key.vert', TEXT, library);
	}

	inline static public function lua(key:String, ?library:String)
	{
		return getPath('$key.lua', TEXT, library);
	}


	inline static public function exists(asset:String, ?type:lime.utils.AssetType)
	{
		#if sys 
		return FileSystem.exists(asset);
		#else
		return Assets.exists(asset, type);
		#end
	}
	inline static public function getContent(asset:String):Null<String>{
		#if sys
		if (FileSystem.exists(asset))
			return File.getContent(asset);
		#else
		if (Assets.exists(asset))
			return Assets.getText(asset);
		#end

		return null;
	}

	#if html5
	// Directory => Array with file names
	static var pathMap = new Map<String, Array<String>>();

	public static function initPaths(){	
		pathMap.clear();

		for (path in Assets.list())
		{
			var file = path.split("/").pop();
			var parent = path.substr(0, path.length - (file.length + 1)); // + 1 to remove the ending slash

			if (pathMap.exists(parent))
				pathMap.get(parent).push(file);
			else
				pathMap.set(parent, [file]);
		}

		return pathMap;
	}
	
	inline static public function iterateDirectory(Directory:String, Func)
	{
		var dir:String = Directory.endsWith("/") ? Directory.substr(0, -1) : Directory; // remove ending slash

		if (!pathMap.exists(dir))
			return;

		for (i in pathMap.get(dir))
			Func(i);
	}

	#else

	/** Iterates through a directory and call a function with the name of each file contained within it**/
	inline static public function iterateDirectory(Directory:String, Func):Bool
	{
		if (!FileSystem.exists(Directory) || !FileSystem.isDirectory(Directory))
			return false;
		
		for (name in FileSystem.readDirectory(Directory))
			Func(name);

		return true;
	}
	#end

	static public function video(key:String)
	{
		#if MODS_ALLOWED
		var file:String = modsVideo(key);
		if (FileSystem.exists(file))
			return file;

		/*
		var file:String = modsVideo(key, "webm");
		if (FileSystem.exists(file))
			return file;
		*/
		#end

		/*
		var file = 'assets/videos/$key.webm';
		if (exists(file))
			return file;
		*/

		return 'assets/videos/$key.$VIDEO_EXT';
	}

	inline static public function sound(key:String, ?library:String):Sound
	{
		var sound:Sound = returnSound('sounds', key, library);
		return sound;
	}

	inline static public function soundRandom(key:String, min:Int, max:Int, ?library:String)
	{
		return sound(key + FlxG.random.int(min, max), library);
	}

	inline static public function music(key:String, ?library:String):Sound
	{
		var file:Sound = returnSound('music', key, library);
		return file;
	}

	inline static public function track(song:String, track:String):Any
	{
		return returnSound('songs', '${formatToSongPath(song)}/$track');
	}

	inline static public function voices(song:String):Any
	{
		return track(song, "Voices");
	}

	inline static public function inst(song:String):Any
	{
		return track(song, "Inst");
	}

	inline static public function image(key:String, ?library:String):FlxGraphic
	{
		// streamlined the assets process more
		var returnAsset:FlxGraphic = returnGraphic(key, library);
		return returnAsset;
	}

	static public function getTextFromFile(key:String, ?ignoreMods:Bool = false):String
	{
		#if sys
		#if MODS_ALLOWED
		if (!ignoreMods && FileSystem.exists(modFolders(key)))
			return File.getContent(modFolders(key));
		#end

		if (FileSystem.exists(getPreloadPath(key)))
			return File.getContent(getPreloadPath(key));
		#end

		return Assets.getText(getPath(key, TEXT));
	}

	inline static public function font(key:String)
	{
		#if MODS_ALLOWED
		var file:String = modsFont(key);
		if (FileSystem.exists(file))
			return file;
		#end
		return 'assets/fonts/$key';
	}

    public static var locale(default, set):String = 'en-us';
    static function set_locale(l:String){
        locale = l.toLowerCase();
		getAllStrings();
/*         
        if(locale != l){
			for (idx => string in currentStrings){
                var newString = getString(idx, true);
				currentStrings.set(idx, newString);
            }
        } */
        return l;
    }

	// TODO: maybe these should be cached when starting a song
    // once we add a resource (mod/skin) menu we can do caching there for some things
    // we can populate the entire string map when reloading mods and skins
	public static function getAllStrings()
	{
		currentStrings.clear();

		for (filePath in Paths.getFolders("data"))
		{
            var checkFiles = ["lang/" + locale + ".txt", "lang/en-us.txt", "strings.txt"];
			var file = filePath + checkFiles.shift();
			while (checkFiles.length > 0 && !exists(file))
                file = filePath + checkFiles.shift();
			
			if (!exists(file))continue;


			var stringsText = getContent(file);
			var daLines = stringsText.trim().split("\n");

			for(shit in daLines){
				var splitted = shit.split("=");
				var thisKey = splitted.shift();

				if (!currentStrings.exists(thisKey))
					currentStrings.set(thisKey, splitted.join("=").trim().replace('\\n', '\n'));
			}
		}
	}

	public inline static function hasString(key:String)return getString(key) != key;

	public static function getString(key:String, force:Bool = false):String
	{
		if (!force && currentStrings.exists(key))
			return currentStrings.get(key);
	

		for (filePath in Paths.getFolders("data"))
		{
			var checkFiles = ["lang/" + locale + ".txt", "lang/en-us.txt", "strings.txt"];
			var file = filePath + checkFiles.shift();
			while (checkFiles.length > 0 && !exists(file))
				file = filePath + checkFiles.shift();

			//trace(filePath);
			var stringsText = getContent(file);
			var daLines = stringsText.trim().split("\n");

			for(shit in daLines){
				var splitted = shit.split("=");
				var thisKey = splitted.shift();
				if (thisKey == key){
					currentStrings.set(key, splitted.join("=").trim().replace('\\n', '\n'));
					return currentStrings.get(key);
				}
			}
		}

		trace('$key has no attached value');
		return key;
	}

	inline static public function fileExists(key:String, type:AssetType, ?ignoreMods:Bool = false, ?library:String)
	{
		return #if MODS_ALLOWED (ignoreMods!=true && FileSystem.exists(modFolders(key))) || #end Paths.exists(getPath(key, type));
	}

	inline static public function getSparrowAtlas(key:String, ?library:String):FlxAtlasFrames
	{
		#if MODS_ALLOWED
		var imageLoaded:FlxGraphic = returnGraphic(key);
		var xmlLoaded:Any = null;

		var xmlPath = modsXml(key);
		if (FileSystem.exists(xmlPath))
			xmlLoaded = File.getContent(xmlPath);
		else{
			xmlPath = file('images/$key.xml', library);
			if (FileSystem.exists(xmlPath))
				xmlLoaded = File.getContent(xmlPath);
		}

		return FlxAtlasFrames.fromSparrow(
			imageLoaded != null ? imageLoaded : image(key, library),
			xmlLoaded != null ? xmlLoaded : xmlPath
		);
		#else
		return FlxAtlasFrames.fromSparrow(
			image(key, library), 
			file('images/$key.xml', library)
		);
		#end
	}

	inline static public function getPackerAtlas(key:String, ?library:String)
	{
		#if MODS_ALLOWED
		var imageLoaded:FlxGraphic = returnGraphic(key);
		var txtExists:Bool = FileSystem.exists(modFolders('images/$key.txt'));
		
		return FlxAtlasFrames.fromSpriteSheetPacker((imageLoaded != null ? imageLoaded : image(key, library)),
			(txtExists ? File.getContent(modFolders('images/$key.txt')) : file('images/$key.txt', library)));
		#else
		return FlxAtlasFrames.fromSpriteSheetPacker(image(key, library), file('images/$key.txt', library));
		#end
	}

	static function getShaderFragment(name:String):Null<String>{
		var path = Paths.modsShaderFragment(name);
		if (Paths.exists(path)) return path;
		var path = Paths.shaderFragment(name);
		if (Paths.exists(path)) return path;
		return null;
	}
	static function getShaderVertex(name:String):Null<String>{
		var path = Paths.modsShaderVertex(name);
		if (Paths.exists(path)) return path;
		var path = Paths.shaderVertex(name);
		if (Paths.exists(path)) return path;
		return null;
	}

	/** returns a FlxRuntimeShader but with file names lol **/ 
	public static function getShader(fragFile:String = null, vertFile:String = null, ?version:Int):FlxRuntimeShader
	{
		try{
			var fragPath:Null<String> = fragFile==null ? null : getShaderFragment(fragFile);
			var vertPath:Null<String> = fragFile==null ? null : getShaderVertex(vertFile);

			return new FlxRuntimeShader(
				fragFile==null ? null : Paths.getContent(fragPath), 
				vertFile==null ? null : Paths.getContent(vertPath),
                version
			);
		}catch(e:Dynamic){
			trace("Shader compilation error:" + e.message);
		}

		return null;		
	}

	private static final hideChars = ['.','!','?','%','"',",","'"];
	private static final invalidChars = [' ','#','>','<',':',';','\\','~','&'];

	inline static public function formatToSongPath(path:String) {
		var finalPath = "";

		for (idx in 0...path.length)
		{
			var char = path.charAt(idx);   

			if (hideChars.contains(char))
				continue;
			else if (invalidChars.contains(char))
				finalPath += "-";
			else 
				finalPath += char;
		}

		return finalPath.toLowerCase();
	}

	// completely rewritten asset loading? fuck!
	public static var currentTrackedAssets:Map<String, FlxGraphic> = [];

	public static function getGraphic(path:String):FlxGraphic
	{
		#if html5
		return FlxG.bitmap.add(path, false, path);
		#elseif sys
		return FlxGraphic.fromBitmapData(BitmapData.fromFile(path), false, path);
		#end
	}

	public static function returnGraphic(key:String, ?library:String)
	{
		#if MODS_ALLOWED
		var modKey:String = modsImages(key);
		if (FileSystem.exists(modKey))
		{
			if (!currentTrackedAssets.exists(modKey)){
				var newGraphic:FlxGraphic = getGraphic(modKey);
				newGraphic.persist = true;
				currentTrackedAssets.set(modKey, newGraphic);
			}
			if (!localTrackedAssets.contains(modKey))localTrackedAssets.push(modKey);
			return currentTrackedAssets.get(modKey);
		}
		#end

		var path = getPath('images/$key.png', IMAGE, library);
		if (Paths.exists(path, IMAGE))
		{
			if (!currentTrackedAssets.exists(path)){
				var newGraphic:FlxGraphic = getGraphic(path);
				newGraphic.persist = true;
				currentTrackedAssets.set(path, newGraphic);
			}
			if (!localTrackedAssets.contains(path))localTrackedAssets.push(path);
			return currentTrackedAssets.get(path);
		}

		if (Main.showDebugTraces) trace('image "$key" returned null.');
		return null;
	}

	public static var currentTrackedSounds:Map<String, Sound> = [];

	public static function returnSoundPath(path:String, key:String, ?library:String)
	{
		#if MODS_ALLOWED
		var file:String = modsSounds(path, key);
		if (FileSystem.exists(file))
			return file;
		
		#end
		var gottenPath:String = getPath('$path/$key.$SOUND_EXT', SOUND, library);
		return gottenPath;
	}

	public static function returnSound(path:String, key:String, ?library:String)
	{
		#if MODS_ALLOWED
		var file:String = modsSounds(path, key);
		if (FileSystem.exists(file))
		{
			if (!currentTrackedSounds.exists(file))
				currentTrackedSounds.set(file, Sound.fromFile(file));
			
			if (!localTrackedAssets.contains(key))localTrackedAssets.push(key);
			return currentTrackedSounds.get(file);
		}
		#end

		var gottenPath:String = getPath('$path/$key.$SOUND_EXT', SOUND, library);
		#if html
		gottenPath = gottenPath.substring(gottenPath.indexOf(':') + 1, gottenPath.length);
		#end

		var toReturn = currentTrackedSounds.get(gottenPath);

		if (toReturn == null)
			currentTrackedSounds.set(
				gottenPath, 
				toReturn = (
				#if !html
				Sound.fromFile('./' + gottenPath)
				#else
				Assets.getSound((path == 'songs' ? folder = 'songs:' : '') + getPath('$path/$key.$SOUND_EXT', SOUND, library))
				#end
				)
			);
			
		if (!localTrackedAssets.contains(gottenPath))
			localTrackedAssets.push(gottenPath);

		return toReturn;
	}

	// i just fucking realised there's already a function for this wtfff
	static public function getText(key:String, ?ignoreMods:Bool = false):Null<String>
	{
		#if MODS_ALLOWED
		if (ignoreMods != true){
			var modPath:String = Paths.modFolders(key);
			if (FileSystem.exists(modPath))
				return File.getContent(modPath);
		}
		#end

		return getContent(Paths.getPreloadPath(key));
	}

	static public function getJson(path:String):Null<Dynamic>
	{
		try{
			return Json.parse(Paths.getContent(path));
		}catch(e){
			Sys.println('$path: $e');
		}

		return null;
	}

	public static var modsList:Array<String> = [];
	#if MODS_ALLOWED
	static final modFolderPath:String = "content/";

	inline static public function mods(key:String = '')
		return modFolderPath + key;

	inline static public function modsFont(key:String)
		return modFolders('fonts/' + key);

	inline static public function modsSongJson(key:String)
		return modFolders('songs/' + key + '.json');

	inline static public function modsVideo(key:String, extension:String = VIDEO_EXT)
		return modFolders('videos/' + key + '.' + extension);

	inline static public function modsSounds(path:String, key:String)
		return modFolders(path + '/' + key + '.' + SOUND_EXT);

	inline static public function modsImages(key:String)
		return modFolders('images/' + key + '.png');

	inline static public function modsXml(key:String)
		return modFolders('images/' + key + '.xml');

	inline static public function modsTxt(key:String)
		return modFolders('data/' + key + '.txt');

	inline static public function modsJson(key:String)
		return modFolders('data/' + key + '.json');

	inline static public function modsShaderFragment(key:String, ?library:String)
		return modFolders('shaders/'+key+'.frag');
	
	inline static public function modsShaderVertex(key:String, ?library:String)
		return modFolders('shaders/'+key+'.vert');

	inline static public function getFolders(dir:String, ?modsOnly:Bool = false){
		var foldersToCheck:Array<String> = [
			#if MODS_ALLOWED
			Paths.mods(Paths.currentModDirectory + '/$dir/'),
			Paths.mods('global/$dir/'),
			Paths.mods('$dir/'),
			#end
		];

		if(!modsOnly)
			foldersToCheck.push(Paths.getPreloadPath('$dir/'));

		#if MODS_ALLOWED
		for(mod in preLoadContent)foldersToCheck.push(Paths.mods('$mod/$dir/'));
		for(mod in getGlobalContent())foldersToCheck.insert(0, Paths.mods('$mod/$dir/'));
        for(mod in postLoadContent)foldersToCheck.insert(0, Paths.mods('$mod/$dir/'));
		#end

		return foldersToCheck;
	}

	inline static public function getGlobalContent(){
		return globalContent;
	}

	static public function pushGlobalContent(){
		globalContent = [];
		for (mod in Paths.getModDirectories())
		{
			var path = Paths.mods('$mod/metadata.json');
			var rawJson:Null<String> = Paths.getContent(path);

			if (rawJson != null && rawJson.length > 0)
			{
				var json:Dynamic = Json.parse(rawJson);
				var fuck:Bool = Reflect.field(json, "runsGlobally");
				if (fuck){
					globalContent.push(mod);
				}
			}
		}

		return globalContent;
	}
	
	static public function modFolders(key:String, ignoreGlobal:Bool = false)
	{
		// TODO: check skins
		if (Paths.currentModDirectory != null && Paths.currentModDirectory.length > 0)
		{
			var fileToCheck = mods(Paths.currentModDirectory + '/' + key);
			if (FileSystem.exists(fileToCheck))
				return fileToCheck;
		}

		var fileToCheck = mods('global/' + key);
		if (FileSystem.exists(fileToCheck))
			return fileToCheck;

		if (!ignoreGlobal)
		{
			for (mod in getGlobalContent())
			{
				var fileToCheck = mods(mod + '/' + key);
				if (FileSystem.exists(fileToCheck)){
					return fileToCheck;
				}
			}
		}

		return mods(key);
	}

	// I might end up making this just return an array of loaded mods and require you to press a refresh button to reload content lol
	// mainly for optimization reasons, so its not going through the entire content folder every single time

	static public function getModDirectories():Array<String> 
	{
		var list:Array<String> = [];
		if (FileSystem.exists(modFolderPath))
		{
			for (folder in FileSystem.readDirectory(modFolderPath))
			{
				var path = haxe.io.Path.join([modFolderPath, folder]);
				if (sys.FileSystem.isDirectory(path) && !list.contains(folder))
				{
					list.push(folder);
				}
			}
		}
		modsList = list;

		return list;
	}
	#end
	
	public static function loadTheFirstEnabledMod()
	{
		Paths.currentModDirectory = '';
	}
	
	public static function loadRandomMod()
	{
		Paths.currentModDirectory = '';
	}
}

typedef FreeplaySongMetadata = {
	/**
		Name of the song to be played
	**/
	var name:String;

	/**
		Category ID for the song to be placed into (main, side, remix)
	**/
	var category:String;

	/**
		Displayed name of the song.
		Does not have to be the same as name.
	**/
	@:optional var displayName:String;
}

typedef FreeplayCategoryMetadata = {
	/**
		Displayed Name of the category
		This is used to show the category in the freeplay list
	**/
	var name:String;

	/**
		ID of the category
		This gets used when adding songs to the category
		(Defaults are main, side and remix)
	**/
	var id:String;
}

typedef ContentMetadata = {
	/**
		Chapters to be added to the story mode
	**/
	var chapters:Array<ChapterMetadata>;
	/**
		Stages that can appear in the title menu
	**/
	@:optional var titleStages:Array<String>;

	/**
		Songs to be placed into the freeplay menu
	**/
	@:optional var freeplaySongs:Array<FreeplaySongMetadata>;

	/**
		Categories to be placed into the freeplay menu
	**/
	@:optional var freeplayCategories:Array<FreeplayCategoryMetadata>;
	
	/**
	If this is specified, then songs don't have to be added to freeplaySongs to have them appear
	As anything in the songs folder will appear in this category instead
	**/
	@:optional var defaultCategory:String;
	/**
		This mod will always run, regardless of whether it's currently being played or not.
		(Custom HUDs, etc, will find this useful, as you can have stuff run across every song without adding to the global folder)
	**/
	@:optional var runsGlobally:Bool;
}