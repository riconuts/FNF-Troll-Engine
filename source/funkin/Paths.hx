package funkin;

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

class Paths
{
	public static var globalContent:Array<String> = [];
	public static var preLoadContent:Array<String> = [];
	public static var postLoadContent:Array<String> = [];

	inline public static var SOUND_EXT = "ogg";
	inline public static var VIDEO_EXT = "mp4";
    public static final HSCRIPT_EXTENSIONS:Array<String> = ["hscript", "hxs", "hx"];
	public static final LUA_EXTENSIONS:Array<String> = ["lua"];
    
	public static final SCRIPT_EXTENSIONS:Array<String> = [
		"hscript",
		"hxs",
		"hx",
		#if LUA_ALLOWED "lua" #end]; // TODo: initialize this by combining the top 2 vars ^

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
	}

	static public var currentModDirectory:String = '';

	public static function getPath(key:String, ?ignoreMods:Bool = false)
	{
		#if MODS_ALLOWED
		if (ignoreMods != true){
			var modPath:String = Paths.modFolders(key);
			if (Paths.exists(modPath))
				return modPath;
		}
		#end

		return Paths.getPreloadPath(key);	
	}

	inline public static function getPreloadPath(file:String = '')
	{
		return 'assets/$file';
	}

	inline static public function file(file:String, type:AssetType = TEXT, ?library:String)
	{
		return getPreloadPath(file);
	}

	inline static public function txt(key:String, ?library:String)
	{
		return file('data/$key.txt', TEXT, library);
	}

	inline static public function png(key:String, ?library:String)
	{
		return file('images/$key.png', IMAGE, library);
	}

	inline static public function xml(key:String, ?library:String)
	{
		return file('images/$key.xml', TEXT, library);
	}

	inline static public function songJson(key:String, ?library:String)
	{
		return file('songs/$key.json', TEXT, library);
	}

	inline static public function shaderFragment(key:String, ?library:String)
	{
		return file('shaders/$key.frag', TEXT, library);
	}

	inline static public function shaderVertex(key:String, ?library:String)
	{
		return file('shaders/$key.vert', TEXT, library);
	}

	inline static public function lua(key:String, ?library:String)
	{
		return file('$key.lua', TEXT, library);
	}


	inline static public function exists(path:String, ?type:AssetType):Bool
	{
		#if sys 
		return FileSystem.exists(path);
		#else
		return Assets.exists(path, type);
		#end
	}
	inline static public function getContent(path:String):Null<String>{
		#if sys
		return FileSystem.exists(path) ? File.getContent(path) : null;
		#else
		return Assets.exists(path) ? Assets.getText(path) : null;
		#end
	}
	inline static public function isDirectory(path:String):Bool{
		#if sys
		return FileSystem.exists(path) && FileSystem.isDirectory(path);
		#else
		var path = path.endsWith("/") ? path.substr(0, -1) : path; // remove ending slash
		return dirMap.exists(path);
		#end
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

	#if html5
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
	
	/** 
		Iterates through a directory and calls a function with the name of each file contained within it
		Returns true if the directory was a valid folder and false if not.
	**/
	inline static public function iterateDirectory(Directory:String, Func:haxe.Constraints.Function)
	{
		var dir:String = Directory.endsWith("/") ? Directory.substr(0, -1) : Directory; // remove ending slash

		if (!dirMap.exists(dir)){
			trace('Directory $dir does not exist?');
			return false;
		}

		for (i in dirMap.get(dir))
			Func(i);
        
        return true;
	}

	#else

	/** 
		Iterates through a directory and calls a function with the name of each file contained within it
		Returns true if the directory was a valid folder and false if not.
	**/
	inline static public function iterateDirectory(path:String, func:haxe.Constraints.Function):Bool
	{
		if (!FileSystem.exists(path) || !FileSystem.isDirectory(path))
			return false;
		
		for (name in FileSystem.readDirectory(path))
			func(name);

		return true;
	}
	#end

	static public function video(key:String, ignoreMods:Bool = false):String
	{
		return getPath('videos/$key.$VIDEO_EXT', ignoreMods);
	}

	inline static public function sound(key:String, ?library:String):Null<Sound>
	{
		return returnSound('sounds', key, library);
	}

	inline static public function soundRandom(key:String, min:Int, max:Int, ?library:String)
	{
		return sound(key + FlxG.random.int(min, max), library);
	}

	inline static public function music(key:String, ?library:String):Null<Sound>
	{
		return returnSound('music', key, library);
	}

	inline static public function track(song:String, track:String):Null<Sound>
	{
		return returnSound('songs', '${formatToSongPath(song)}/$track');
	}

	inline static public function voices(song:String):Null<Sound>
	{
		return track(song, "Voices");
	}

	inline static public function inst(song:String):Null<Sound>
	{
		return track(song, "Inst");
	}

	/** Paths.image(key) != null **/
	inline public static function imageExists(key:String):Bool
		return Paths.exists(getPath('images/$key.png'));

	inline static public function image(key:String, ?library:String):Null<FlxGraphic>
	{
		return returnGraphic(key, library);
	}

	/** Returns the contents of a file as a string. **/
	inline public static function text(key:String, ?ignoreMods:Bool = false):Null<String>
		return getContent(getPath(key, ignoreMods));

	inline static public function font(key:String)
	{
		#if MODS_ALLOWED
		var file:String = modsFont(key);
		if (FileSystem.exists(file))
			return file;
		#end
		return 'assets/fonts/$key';
	}

	inline static public function fileExists(key:String, ?type:AssetType, ?ignoreMods:Bool = false, ?library:String)
	{
		return Paths.exists(getPath(key, ignoreMods));
	}

	inline static public function getSparrowAtlas(key:String, ?library:String):FlxAtlasFrames
	{
		#if MODS_ALLOWED
		var xmlPath = getPath('images/$key.xml');
		
		return FlxAtlasFrames.fromSparrow(
			image(key, library),
			Paths.exists(xmlPath) ? Paths.getContent(xmlPath) : xmlPath
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
		#if MODS_ALLOWED
		var path = Paths.modsShaderFragment(name);
		if (Paths.exists(path)) return path;
		#end
		var path = Paths.shaderFragment(name);
		if (Paths.exists(path)) return path;
		return null;
	}
	static function getShaderVertex(name:String):Null<String>{
		#if MODS_ALLOWED
		var path = Paths.modsShaderVertex(name);
		if (Paths.exists(path)) return path;
		#end
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

	public static function getGraphic(path:String):Null<FlxGraphic>
	{
		var graphic = FlxGraphic.fromAssetKey(path, false, path);
		
		#if sys
		if (graphic == null && FileSystem.exists(path))
			return FlxGraphic.fromBitmapData(BitmapData.fromFile(path), false, path);
		#end

		return graphic;
	}

	public static function returnGraphic(key:String, ?library:String):Null<FlxGraphic>
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

		var path = png(key, library);
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

	public static function getSound(key:String){
		#if sys
		if (FileSystem.exists(key))
			return Sound.fromFile(key);
		#end

		if (Assets.exists(key))
			return Assets.getSound(key);

		return null;
	}

	public static function returnSoundPath(path:String, key:String, ?library:String)
	{
		#if MODS_ALLOWED
		var file:String = modsSounds(path, key);
		if (FileSystem.exists(file))
			return file;
		
		#end
		var gottenPath:String = getPreloadPath('$path/$key.$SOUND_EXT');
		return gottenPath;
	}

	public static function returnSound(path:String, key:String, ?library:String)
	{
		#if MODS_ALLOWED
		var gottenPath:String = modsSounds(path, key);
		if (FileSystem.exists(gottenPath))
		{
			if (!currentTrackedSounds.exists(gottenPath))
				currentTrackedSounds.set(gottenPath, Sound.fromFile(gottenPath));
			
			if (!localTrackedAssets.contains(key))
				localTrackedAssets.push(key);
			
			return currentTrackedSounds.get(gottenPath);
		}
		#end

		var gottenPath:String = getPreloadPath('$path/$key.$SOUND_EXT');
		/*
		gottenPath = gottenPath.substring(gottenPath.indexOf(':') + 1, gottenPath.length);
		*/

		if (currentTrackedSounds.exists(gottenPath))
			return currentTrackedSounds.get(gottenPath);
		
		var sound = getSound(gottenPath);
		if (sound != null)
		{
			currentTrackedSounds.set(gottenPath, sound);
	
			if (!localTrackedAssets.contains(gottenPath))
				localTrackedAssets.push(gottenPath);	
			
			return sound;
		}
		
		trace('Sound file $gottenPath not found!');
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


	public static var modsList:Array<String> = [];
	public static var contentMetadata:Map<String, ContentMetadata> = [];

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
		// TODO: check skins
		if (Paths.currentModDirectory != null && Paths.currentModDirectory.length > 0)
		{
			var fileToCheck = mods(Paths.currentModDirectory + '/' + key);
			if (FileSystem.exists(fileToCheck))
				return fileToCheck;
		}

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

	public static function updateContentLists()
	{
		var list:Array<String> = modsList = [];
		contentMetadata.clear();

		if (FileSystem.exists(modFolderPath))
		{
			for (folder in FileSystem.readDirectory(modFolderPath))
			{
				var path = haxe.io.Path.join([modFolderPath, folder]);
				if (FileSystem.isDirectory(path) && !list.contains(folder))
				{
					list.push(folder);

					var path = Paths.mods('$folder/metadata.json');
					var rawJson:Null<String> = Paths.getContent(path);
		
					if (rawJson != null && rawJson.length > 0)
					{
						var data:Dynamic = Json.parse(rawJson);
						contentMetadata.set(folder, updateContentMetadataStructure(data));
						continue;
					}

					#if PE_MOD_COMPATIBILITY
					var psychModMetadata = getPsychModMetadata(folder);
					if (psychModMetadata != null)
						contentMetadata.set(folder, psychModMetadata);
					#end
				}
			}
		}
	}

	#if PE_MOD_COMPATIBILITY
	static function getPsychModMetadata(folder:String):ContentMetadata {
		var packJson:String = Paths.mods('$folder/pack.json');
		var packJson:Null<String> = Paths.getContent(packJson);
		var packJson:Dynamic = (packJson == null) ? packJson : Json.parse(packJson);

		var sowy:ContentMetadata = {
			runsGlobally: (packJson != null) && Reflect.field(packJson, 'runsGlobally') == true, 
			weeks: [],
			freeplaySongs: []
		}

		for (psychWeek in WeekData.getPsychModWeeks(folder))
			WeekData.addPsychWeek(sowy, psychWeek);

		return sowy;
	}
	#end
	
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

		for(mod in preLoadContent)foldersToCheck.push(Paths.mods('$mod/$dir/'));
		for(mod in getGlobalContent())foldersToCheck.insert(0, Paths.mods('$mod/$dir/'));
		for(mod in postLoadContent)foldersToCheck.insert(0, Paths.mods('$mod/$dir/'));

		return foldersToCheck;
		#end
	}
	
	public static function loadTheFirstEnabledMod()
	{
		Paths.currentModDirectory = '';
	}
	
	public static function loadRandomMod()
	{
		Paths.currentModDirectory = '';
	}

	//// Strings
	public static var locale(default, set):String;
	@:noCompletion static function set_locale(l:String){
		if (l != locale) {
			locale = l;
			getAllStrings();
		}
		return locale;
	}

	private static final currentStrings = new StringMap();

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