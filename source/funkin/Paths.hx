package funkin;

import haxe.io.Bytes;
import openfl.utils.ByteArray;
import haxe.ds.StringMap;
import funkin.data.LocalizationMap;
import funkin.data.WeekData;
import flixel.addons.display.FlxRuntimeShader;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.graphics.FlxGraphic;
import flixel.FlxG;
import openfl.media.Sound;
import openfl.display.BitmapData;
import openfl.utils.AssetType;
import openfl.utils.Assets;
import haxe.Json;

using StringTools;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

//// idgaf about libraries
@:access(openfl.display.BitmapData)
class Paths
{
	inline public static var IMAGE_EXT = "png";
	inline public static var SOUND_EXT = "ogg";
	inline public static var VIDEO_EXT = "mp4";

	public static final HSCRIPT_EXTENSIONS:Array<String> = ["hscript", "hxs", "hx"];
	public static final SCRIPT_EXTENSIONS:Array<String> = [
		"hscript",
		"hxs",
		"hx",
	];


	public static function getFileWithExtensions(scriptPath:String, extensions:Array<String>) {
		for (fileExt in extensions) {
			var baseFile:String = '$scriptPath.$fileExt';
			var file:String = getPath(baseFile);
			if (Paths.exists(file))
				return file;
		}

		return null;
	}

	public static function isHScript(file:String){
		for(ext in Paths.HSCRIPT_EXTENSIONS)
			if(file.endsWith('.$ext'))
				return true;
		
		return false;
	}
	public inline static function getHScriptPath(scriptPath:String)
	{
		#if HSCRIPT_ALLOWED
		return getFileWithExtensions(scriptPath, Paths.HSCRIPT_EXTENSIONS);
		#else
		return null;
		#end
	}

	public static var localTrackedAssets:Array<String> = [];
	public static var currentTrackedAssets:Map<String, FlxGraphic> = [];
	public static var currentTrackedSounds:Map<String, Sound> = [];

	public static var dumpExclusions:Array<String> = [
		'assets/music/freakyIntro.$SOUND_EXT',
		'assets/music/freakyMenu.$SOUND_EXT',
		'assets/music/breakfast.$SOUND_EXT',
		'content/global/music/freakyIntro.$SOUND_EXT',
		'content/global/music/freakyMenu.$SOUND_EXT',
		'content/global/music/breakfast.$SOUND_EXT',
		'assets/images/Garlic-Bread-PNG-Images.$IMAGE_EXT'
	];

	public static function excludeAsset(key:String)
	{
		if (!dumpExclusions.contains(key))
			dumpExclusions.push(key);
	}

	public static function init() {
		#if html5
		HTML5Paths.initPaths();
		#end

		#if MODS_ALLOWED
		Paths.pushGlobalContent();
		Paths.getModDirectories();
		#end
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
					destroyGraphic(obj);
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
			destroyGraphic(obj);
			currentTrackedAssets.remove(key);		
		}
	}

	inline static function destroyGraphic(graphic:FlxGraphic)
	{
		// free some gpu memory
		if (graphic != null && graphic.bitmap != null && graphic.bitmap.__texture != null)
			graphic.bitmap.__texture.dispose();
		FlxG.bitmap.remove(graphic);
	}

	public static function clearStoredMemory()
	{
		// clear anything not in the tracked assets list
		@:privateAccess
		for (key => obj in FlxG.bitmap._cache) {
			if (obj != null && !currentTrackedAssets.exists(key)) {
				// trace('cleared $key');
				destroyGraphic(obj);
			}
		}

		// clear all sounds that are cached
		for (key => obj in currentTrackedSounds) {
			if (obj != null && !localTrackedAssets.contains(key) && !dumpExclusions.contains(key)) {
				Assets.cache.removeSound(key);
				currentTrackedSounds.remove(key);
			}
		}

		// flags everything to be cleared out next unused memory clear
		localTrackedAssets.resize(0);
	}

	public static function getPath(key:String, ignoreMods:Bool = false):String
	{
		#if MODS_ALLOWED
		if (ignoreMods != true) {
			var modPath:String = Paths.modFolders(key);
			if (Paths.exists(modPath)) return modPath;
		}
		#end

		return Paths.getPreloadPath(key);	
	}

	public static function _getPath(key:String, ignoreMods:Bool = false):Null<String>
	{
		var path:String = getPath(key, ignoreMods);
		return Paths.exists(path) ? path : null;
	}

	inline public static function getPreloadPath(file:String = '')
	{
		return 'assets/$file';
	}

	/*
	inline static public function txt(key:String):String
		return 'data/$key.txt';

	inline static public function png(key:String):String
		return 'images/$key.png';

	inline static public function xml(key:String):String
		return 'images/$key.xml';

	inline static public function songJson(key:String):String
		return 'songs/$key.json';

	inline static public function shaderFragment(key:String):String
		return 'shaders/$key.frag';

	inline static public function shaderVertex(key:String):String
		return 'shaders/$key.vert';
	*/

	inline static public function font(key:String)
	{
		return getPath('fonts/$key');
	}

	static public function video(key:String, ignoreMods:Bool = false):String
	{
		return getPath('videos/$key.$VIDEO_EXT', ignoreMods);
	}

	static public function getShaderFragment(name:String):Null<String>
	{
		return _getPath('shaders/$name.frag');
	}
	
	static public function getShaderVertex(name:String):Null<String>
	{
		return _getPath('shaders/$name.vert');
	}

	inline static public function sound(key:String, ?library:String):Null<Sound>
	{
		return returnFolderSound('sounds', key, library);
	}

	inline static public function soundRandom(key:String, min:Int, max:Int, ?library:String)
	{
		return sound(key + FlxG.random.int(min, max), library);
	}

	inline static public function music(key:String, ?library:String):Null<Sound>
	{
		return returnFolderSound('music', key, library);
	}

	inline static public function track(song:String, track:String):Null<Sound>
	{
		return returnFolderSound('songs', '${formatToSongPath(song)}/$track');
	}

	inline static public function voices(song:String):Null<Sound>
	{
		return track(song, "Voices");
	}

	inline static public function inst(song:String):Null<Sound>
	{
		return track(song, "Inst");
	}

	inline static public function withoutEndingSlash(path:String)
		return path.endsWith("/") ? path.substr(0, -1) : path;

	inline static public function exists(path:String, ?type:AssetType):Bool {
		#if sys 
		return FileSystem.exists(path);
		#else
		return Assets.exists(path, type);
		#end
	}
	inline static public function getContent(path:String):Null<String> {
		#if sys
		return FileSystem.exists(path) ? File.getContent(path) : null;
		#else
		return Assets.exists(path) ? Assets.getText(path) : null;
		#end
	}
	inline static public function getBytes(path:String):Null<haxe.io.Bytes> {
		#if sys
		return FileSystem.exists(path) ? File.getBytes(path) : null;
		#else
		return Assets.exists(path) ? Assets.getBytes(path) : null;
		#end
	}
	inline static public function isDirectory(path:String):Bool {
		#if sys
		return FileSystem.exists(path) && FileSystem.isDirectory(path);
		#else
		return HTML5Paths.isDirectory(path);
		#end
	}
	inline static public function getDirectoryFileList(path:String):Array<String> {
		#if sys
		return !isDirectory(path) ? [] : FileSystem.readDirectory(path);
		#else
		return HTML5Paths.getDirectoryFileList(path);
		#end
	}

	inline public static function getText(path:String):Null<String> {
		#if sys
		if (FileSystem.exists(path))
			return File.getContent(path);
		#end

		if (Assets.exists(path))
			return Assets.getText(path);

		return null;
	}
	inline public static function getBitmapData(path:String):Null<BitmapData> {
		#if sys
		if (FileSystem.exists(path))
			return BitmapData.fromFile(path);
		#end

		if (Assets.exists(path, IMAGE))
			return Assets.getBitmapData(path);

		return null;
	}
	inline public static function getSound(path:String):Null<Sound> {
		#if sys
		if (FileSystem.exists(path))
			return Sound.fromFile(path);
		#end

		if (Assets.exists(path))
			return Assets.getSound(path);

		return null;
	}
	static public function getJson(path:String):Null<Dynamic>
	{
		var ret:Null<Dynamic> = null;
		try{
			var raw = Paths.getContent(path);
			if (raw != null)
				ret = haxe.Json.parse(raw);
		}catch(e){
			haxe.Log.trace('$path: $e', null);
		}

		return ret;
	}
	inline static public function getSparrowAtlas(key:String, ?library:String):FlxAtlasFrames
	{
		var xmlPath = getPath('images/$key.xml');
		return FlxAtlasFrames.fromSparrow(
			image(key, library),
			Paths.exists(xmlPath) ? Paths.getContent(xmlPath) : xmlPath
		);
	}

	inline static public function getPackerAtlas(key:String, ?library:String):FlxAtlasFrames
	{
		var txtPath:String = getPath('images/$key.txt');
		return FlxAtlasFrames.fromSpriteSheetPacker(
			image(key, library),
			exists(txtPath) ? getContent(txtPath) : txtPath
		);
	}

	/** returns a FlxRuntimeShader but with file names lol **/ 
	public static function getShader(fragFile:String = null, vertFile:String = null, version:Int = 120):FlxRuntimeShader
	{
		try{
			var fragPath:Null<String> = fragFile==null ? null : getShaderFragment(fragFile);
			var vertPath:Null<String> = vertFile==null ? null : getShaderVertex(vertFile);

			return new FlxRuntimeShader(
				fragFile==null ? null : Paths.getContent(fragPath), 
				vertFile==null ? null : Paths.getContent(vertPath),
				//version
			);
		}catch(e:Dynamic){
			trace("Shader compilation error:" + e.message);
		}

		return null;		
	}

	/** 
		Iterates through a directory and calls a function with the name of each file contained within it
		Returns true if the directory was a valid folder and false if not.
	**/
	inline static public function iterateDirectory(path:String, func:haxe.Constraints.Function):Bool
	{
		#if sys
		if (!FileSystem.exists(path) || !FileSystem.isDirectory(path))
			return false;
		
		for (name in FileSystem.readDirectory(path))
			func(name);

		return true;
		
		#else
		return HTML5Paths.iterateDirectory(path, func);
		#end
	}

	inline static public function fileExists(key:String, ?type:AssetType, ?ignoreMods:Bool = false, ?library:String)
	{
		return Paths.exists(getPath(key, ignoreMods));
	}

	/** Returns the contents of a file as a string. **/
	inline public static function text(key:String, ?ignoreMods:Bool = false):Null<String>
		return getContent(getPath(key, ignoreMods));

	inline public static function bytes(key:String, ?ignoreMods:Bool = false):Null<Bytes>
		return getBytes(getPath(key, ignoreMods));

	inline static public function formatToSongPath(path:String) {
		var finalPath = "";

		for (idx in 0...path.length)
		{
			var char = path.charAt(idx);
			switch(char) {
				case '.' | '!' | '?' | '%' | '"' | "," | "'":
					continue;
				
				case ' ' | '#' | '>' | '<' | ':' | ';' | '\\' | '~' | '&':
					finalPath += "-";
				
				default:
					finalPath += char;
			}
		}

		return finalPath.toLowerCase();
	}

	public static function getGraphic(path:String, cache:Bool = true, gpu:Bool = true):Null<FlxGraphic>
	{
		var newGraphic:FlxGraphic;

		if (cache && currentTrackedAssets.exists(path)) {
			newGraphic = currentTrackedAssets.get(path);
			if (!localTrackedAssets.contains(path)) 
				localTrackedAssets.push(path);
		}
		else {
			var bitmap:BitmapData = getBitmapData(path);
			if (bitmap == null) return null;

			// GPU caching made by Raltyro
			if (gpu && ClientPrefs.cacheOnGPU && bitmap.image != null) {
				bitmap.lock();
				if (bitmap.__texture == null)
				{
					bitmap.image.premultiplied = true;
					bitmap.getTexture(FlxG.stage.context3D);
				}
				bitmap.getSurface();
				bitmap.disposeImage();
				bitmap.image.data = null;
				bitmap.image = null;
				bitmap.readable = true;
			}

			newGraphic = FlxGraphic.fromBitmapData(bitmap, false, path, cache);
			newGraphic.persist = true;
			newGraphic.destroyOnNoUse = false;

			if (cache) {
				localTrackedAssets.push(path);
				currentTrackedAssets.set(path, newGraphic);
			}
		}

		return newGraphic;
	}

	inline public static function cacheGraphic(path:String):Null<FlxGraphic>
		return getGraphic(path, true);

	inline public static function imagePath(key:String, ?folder:String):String
		return getPath('images/$key.$IMAGE_EXT');

	inline public static function imageExists(key:String):Bool
		return Paths.exists(imagePath(key));

	public static function image(key:String, ?folder:String = null, allowGPU:Bool = true):Null<FlxGraphic>
	{
		var path:String = imagePath(key, folder);

		var graphic = getGraphic(path, true, allowGPU);
		if (graphic==null && Main.showDebugTraces)
			trace('bitmap "$key" => "$path" returned null.');

		return graphic;
	}

	inline public static function soundPath(path:String, key:String, ?library:String)
	{
		return getPath('$path/$key.$SOUND_EXT');
	}

	inline public static function returnFolderSound(path:String, key:String, ?library:String)
		return returnSound(soundPath(path, key, library), library);

	public static function returnSound(path:String, ?library:String)
	{	
		if (currentTrackedSounds.exists(path)) {
			if (!localTrackedAssets.contains(path))
				localTrackedAssets.push(path);

			return currentTrackedSounds.get(path);
		}
		
		var sound = getSound(path);
		if (sound != null) {
			currentTrackedSounds.set(path, sound);
	
			if (!localTrackedAssets.contains(path))
				localTrackedAssets.push(path);	
			
			return sound;
		}
		
		if (Main.showDebugTraces)
			trace('sound $path returned null');
		
		return null;
	}

	/** Return the contents of a file, parsed as a JSON. **/
	static public function json(key:String, ?ignoreMods:Bool = false):Null<Dynamic>
	{
		var rawJSON:Null<String> = text(key, ignoreMods);
		if (rawJSON == null) 
			return null;
		
		try{
			return Json.parse(rawJSON);
		}catch(e){
			haxe.Log.trace('$key: $e', null);
		}
		
		return null;
	}

	public static inline function getFolderPath(folder:String = ""):String
		return (folder == "") ? getPreloadPath() : mods(folder);

	////	
	public static var currentModDirectory(default, set):String = '';
	static function set_currentModDirectory(v:String){
		if (currentModDirectory == v)
			return currentModDirectory;

		if (!contentMetadata.exists(v))
			return currentModDirectory = v;

		if (!contentDirectories.exists(v))return currentModDirectory = '';
		
		if (contentMetadata.get(v).dependencies != null)
			dependencies = contentMetadata.get(v).dependencies;
		else
			dependencies = [];

		//trace('set to $v with ${dependencies.length} dependencies');

		return currentModDirectory = v;
	}

	// TODO: Write all of this to be not shit and use just like a generic load order thing
	public static var globalContent:Array<String> = [];
	public static var dependencies:Array<String> = [];
	public static var preLoadContent:Array<String> = [];
	public static var postLoadContent:Array<String> = [];

	public static var modsList:Array<String> = [];
	public static var contentDirectories:Map<String, String> = [];
	public static var contentMetadata:Map<String, ContentMetadata> = [];

	#if MODS_ALLOWED
	inline static public function mods(key:String = '')
		return 'content/$key';

	inline static public function getGlobalContent(){
		return globalContent;
	}

	static public function pushGlobalContent(){
		globalContent = [];

		for (mod => json in getContentMetadata())
		{
			if (Reflect.field(json, "runsGlobally") == true) 
				globalContent.push(mod);
		}

		return globalContent;
	}
	
	static public function modFolders(key:String, ignoreGlobal:Bool = false)
	{
		var path:Null<String> = null;

		inline function check(mod:String) {
			var fileToCheck:String = contentDirectories.get(mod) + '/' + key;
			if (exists(fileToCheck)) path = fileToCheck;
		}

		if (Paths.currentModDirectory != null && Paths.currentModDirectory.length > 0) {
			check(Paths.currentModDirectory);
			if (path != null) return path;
		}

		for (mod in dependencies) {
			check(mod);
			if (path != null) return path;
		}

		if (ignoreGlobal != true) {
			for (mod in getGlobalContent()) {
				check(mod);
				if (path != null) return path;
			}
		}

		return mods(key);
	}

	// I might end up making this just return an array of loaded mods and require you to press a refresh button to reload content lol
	// mainly for optimization reasons, so its not going through the entire content folder every single time
	public static function updateContentLists()
	{
		var list:Array<String> = modsList = [];
		contentMetadata.clear();

		contentDirectories.clear();
		contentDirectories.set('', 'content');

		iterateDirectory('content', (folderName) -> {
			var folderPath = 'content/$folderName';

			if (isDirectory(folderPath) && !list.contains(folderName))
			{
				list.push(folderName);
				contentDirectories.set(folderName, folderPath);

				var rawJson:Null<String> = Paths.getContent('$folderPath/metadata.json');
				if (rawJson != null && rawJson.length > 0) {
					var data:Dynamic = Json.parse(rawJson);
					contentMetadata.set(folderName, updateContentMetadataStructure(data));
					return;
				}
			}
		});
	}
	
	inline static function updateContentMetadataStructure(data:Dynamic):ContentMetadata
	{
		if (Reflect.field(data, "weeks") != null)
			return data; // You are valid :)

		var chapters:Dynamic = Reflect.field(data, "chapters");
		if (chapters != null) { // TGT
			Reflect.setField(data, "weeks", chapters);
			Reflect.deleteField(data, "chapters");
			return data;
		}else { // Lets assume it's an old TGT metadata
			return {weeks: [data]};
		}
	}

	static public function getModDirectories():Array<String> 
	{
		updateContentLists();
		return modsList;
	}

	static public function getContentMetadata():Map<String, ContentMetadata>
	{
		updateContentLists();
		return contentMetadata;
	}
	#end

	inline static public function getFolders(dir:String, ?modsOnly:Bool = false){
		#if !MODS_ALLOWED
		return [Paths.getPreloadPath('$dir/')];
		
		#else
		var foldersToCheck:Array<String> = [
			Paths.mods(Paths.currentModDirectory + '/$dir/'),
			Paths.mods('$dir/'),
		];

		if(!modsOnly)
			foldersToCheck.push(Paths.getPreloadPath('$dir/'));
		
		for(mod in dependencies)foldersToCheck.insert(0, Paths.mods('$mod/$dir/'));
		for(mod in preLoadContent)foldersToCheck.push(Paths.mods('$mod/$dir/'));
		for(mod in getGlobalContent())foldersToCheck.insert(0, Paths.mods('$mod/$dir/'));
		for(mod in postLoadContent)foldersToCheck.insert(0, Paths.mods('$mod/$dir/'));


		return foldersToCheck;
		#end
	}
	
	public static function loadRandomMod()
	{
		Paths.currentModDirectory = '';
	}

	//// String stuff, should maybe move this to a diff class¿¿¿
	public static var locale(default, set):String;
	
	private static final currentStrings:Map<String, String> = [];
	
	@:noCompletion static function set_locale(l:String){
		if (l != locale) {
			locale = l;
			getAllStrings();
		}
		return locale;
	}

	public static function getAllStrings():Void {
		currentStrings.clear();
		// trace("refreshing strings");

		var checkFiles = ['lang/$locale.txt', 'lang/$locale.lang', "lang/en.txt", "strings.txt"]; 
		for (filePath in Paths.getFolders("data")) {
			for (fileName in checkFiles) {
				var path:String = filePath + fileName;
				if (!Paths.exists(path)) continue;
				
				var file = LocalizationMap.fromFile(path);
				for (k => v in file) {
					if (!currentStrings.exists(k))
						currentStrings.set(k, v);
				}
			}
		}
	}

	public static inline function hasString(key:String):Bool
		return currentStrings.exists(key);

	public static inline function _getString(key:String):Null<String>
		return currentStrings.get(key);

	public static inline function getString(key:String, ?defaultValue:String):String
		return hasString(key) ? _getString(key) : (defaultValue==null ? key : defaultValue);
}

class HTML5Paths {
	#if !sys 
	// Directory => Array with file/sub-directory names
	static var dirMap = new Map<String, Array<String>>();

	public static function initPaths(){	
		dirMap.clear();
		dirMap.set("", []);

		for (path in Assets.list())
		{
			//trace("WORKING WITH PATH:", path);

			var file:String = path.split("/").pop();
			var parent:String = path.substr(0, path.length - (file.length + 1)); // + 1 to remove the ending slash

			var parentTree = parent.split("/");
			for (totality in 1...parentTree.length+1)
			{
				var totality = parentTree.length - totality;
				var dirPathSplit = [for (i in 0...totality+1) {parentTree[i];}];
				var dirPath = dirPathSplit.join("/");
				
				if (!dirMap.exists(dirPath)){
					dirMap.set(dirPath, []);
					//trace("reg folder", dirPath, "from", path);
				//}else{
					//trace("did NOT reg folder", dirPath, "from", path);
				}
			}
			
			dirMap.get(parent).push(file);
			//trace("END");
		}
		
		////
		for (path => dir in dirMap)
		{
			var name:String = path.split("/").pop();
			var parent:String = path.substr(0, path.length - (name.length + 1)); // + 1 to remove the ending slash

			if (dirMap.exists(parent)){
				var parentDir = dirMap.get(parent);
				if (!parentDir.contains(name)){
					parentDir.push(name);
				}
			}
		}

		// trace(dirMap["assets/songs"]);

		return dirMap;
	}

	inline static public function withoutEndingSlash(path:String)
		return path.endsWith("/") ? path.substr(0, -1) : path;

	inline static public function isDirectory(path:String):Bool {
		return dirMap.exists(withoutEndingSlash(path));
	}

	inline static public function getDirectoryFileList(path:String):Array<String> {
		var dir:String = withoutEndingSlash(path);
		return !dirMap.exists(dir) ? [] : [for (i in dirMap.get(dir)) i];
	}

	/** 
		Iterates through a directory and calls a function with the name of each file contained within it
		Returns true if the directory was a valid folder and false if not.
	**/
	inline static public function iterateDirectory(path:String, Func:haxe.Constraints.Function)
	{
		var dir:String = withoutEndingSlash(path);

		if (!dirMap.exists(dir)){
			trace('Directory $dir does not exist?');
			return false;
		}

		for (i in dirMap.get(dir))
			Func(i);
		
		return true;
	}
	#end
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
		Weeks to be added to the story mode
	**/
	var weeks:Array<funkin.data.WeekData.WeekMetadata>;
	
	/**
		Content that will load before this content.
	**/
	@:optional var dependencies:Array<String>;

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