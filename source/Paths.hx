package;

import FreeplayState.FreeplayCategoryMetadata;
import FreeplayState.FreeplaySongMetadata;
import haxe.Json;
import ChapterData.ChapterMetadata;
import openfl.media.Sound;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.graphics.FlxGraphic;
import flixel.graphics.frames.FlxAtlasFrames;
import openfl.display.BitmapData;
import openfl.geom.Rectangle;
import openfl.system.System;
import openfl.utils.AssetType;
import openfl.utils.Assets as Assets;
import haxe.CallStack;

using StringTools;
#if sys
import sys.FileSystem;
import sys.io.File;
#end


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

class Paths
{
	public static var globalContent:Array<String> = [];

	inline public static var SOUND_EXT = "ogg";
	inline public static var VIDEO_EXT = "mp4";

	#if MODS_ALLOWED
	public static var ignoreModFolders:Array<String> = [
		'characters', 'events', 'notetypes', 'data', 'songs', 'music', 'sounds', 'shaders', 'videos', 'images', 'stages', 'weeks', 'fonts',
		'scripts', 'achievements', 'global'
	];
	#end

	public static function excludeAsset(key:String)
	{
		if (!dumpExclusions.contains(key))
			dumpExclusions.push(key);
	}

	public static var dumpExclusions:Array<String> = [
		'assets/music/freakyIntro.$SOUND_EXT',
		'assets/music/freakyMenu.$SOUND_EXT',
		'assets/music/breakfast.$SOUND_EXT',
		'content/global/music/freakyIntro.$SOUND_EXT',
		'content/global/music/freakyMenu.$SOUND_EXT',
		'content/global/music/breakfast.$SOUND_EXT',
		"assets/images/Garlic-Bread-PNG-Images.png"
	];

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
		System.gc();
	}

	// fuckin around ._.
	public static function removeBitmap(key)
	{
		var obj = currentTrackedAssets.get(key);
		@:privateAccess
		if (obj != null)
		{
			Assets.cache.removeBitmapData(key);
			FlxG.bitmap._cache.remove(key);
			obj.destroy();
			currentTrackedAssets.remove(key);
		}
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
	}

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

	inline static public function iterateDirectory(Directory:String, Func):Bool
	{
		if (!FileSystem.exists(Directory) || !FileSystem.isDirectory(Directory))
			return false;
		
		for (i in FileSystem.readDirectory(Directory))
			Func(i);

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

	inline static public function fileExists(key:String, type:AssetType, ?ignoreMods:Bool = false, ?library:String)
	{
		#if MODS_ALLOWED
		if (FileSystem.exists(mods(currentModDirectory + '/' + key)) || FileSystem.exists(mods(key)))
			return true;
		#end

		return Paths.exists(getPath(key, type));
	}

	inline static public function getSparrowAtlas(key:String, ?library:String):FlxAtlasFrames
	{
		#if MODS_ALLOWED
		var imageLoaded:FlxGraphic = returnGraphic(key);

		return FlxAtlasFrames.fromSparrow(
			(imageLoaded != null ? imageLoaded : image(key, library)),
			(FileSystem.exists(modsXml(key)) ? File.getContent(modsXml(key)) : file('images/$key.xml', library))
		);
		#else
		return FlxAtlasFrames.fromSparrow(image(key, library), file('images/$key.xml', library));
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

		/* finalPath = [
			for (s in finalPath.split("-")) {
				(s == "") ?continue:s;
			}
		].join("-"); */		

		return finalPath.toLowerCase();

		/*
		var invalidChars = ~/[~&\\;:<>#]/;
		var hideChars = ~/[.,'"%?!]/;

		var path = invalidChars.split(path.replace(' ', '-')).join("-");
		return hideChars.split(path).join("").toLowerCase();
		*/
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
			localTrackedAssets.push(modKey);
			return currentTrackedAssets.get(modKey);
		}
		#end

		var path = getPath('images/$key.png', IMAGE, library);
		if (Assets.exists(path, IMAGE))
		{
			if (!currentTrackedAssets.exists(path))
			{
				var newGraphic:FlxGraphic = getGraphic(path);
				newGraphic.persist = true;
				currentTrackedAssets.set(path, newGraphic);
			}
			localTrackedAssets.push(path);
			return currentTrackedAssets.get(path);
		}
		if(Main.showDebugTraces)trace('image "$key" returned null.');
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
			
			localTrackedAssets.push(key);
			return currentTrackedSounds.get(file);
		}
		#end
		// I hate this so god damn much
		var gottenPath:String = getPath('$path/$key.$SOUND_EXT', SOUND, library);
		gottenPath = gottenPath.substring(gottenPath.indexOf(':') + 1, gottenPath.length);
		// trace(gottenPath);
		if (!currentTrackedSounds.exists(gottenPath))
			#if MODS_ALLOWED
			currentTrackedSounds.set(gottenPath, Sound.fromFile('./' + gottenPath));
			#else
				currentTrackedSounds.set(
					gottenPath, 
					Assets.getSound((path == 'songs' ? folder = 'songs:' : '') + getPath('$path/$key.$SOUND_EXT', SOUND, library))
				);
			#end
		localTrackedAssets.push(gottenPath);
		return currentTrackedSounds.get(gottenPath);
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
		for(mod in getGlobalContent())foldersToCheck.push(Paths.mods('$mod/$dir/'));
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
				if (sys.FileSystem.isDirectory(path) && !ignoreModFolders.contains(folder) && !list.contains(folder))
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