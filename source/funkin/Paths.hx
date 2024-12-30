package funkin;

import funkin.data.ContentData;
import funkin.data.LocalizationMap;
import flixel.addons.display.FlxRuntimeShader;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.graphics.FlxGraphic;
import flixel.FlxG;
import openfl.media.Sound;
import openfl.display.BitmapData;
import openfl.utils.AssetType;
import openfl.utils.Assets;
import haxe.io.Path;
import haxe.io.Bytes;
import haxe.Json;

using StringTools;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

//// idgaf about libraries

class Paths
{
	inline public static var IMAGE_EXT = "png";
	inline public static var SOUND_EXT = "ogg";
	inline public static var VIDEO_EXT = "mp4";

	public static final HSCRIPT_EXTENSIONS:Array<String> = ["hscript", "hxs", "hx"];
	public static final LUA_EXTENSIONS:Array<String> = ["lua"];
	public static final SCRIPT_EXTENSIONS:Array<String> = [
		"hscript",
		"hxs",
		"hx",
		#if LUA_ALLOWED "lua" #end]; // TODo: initialize this by combining the top 2 vars ^


	public static function getFileWithExtensions(scriptPath:String, extensions:Array<String>) {
		for (fileExt in extensions) {
			var baseFile:String = '$scriptPath.$fileExt';
			for (file in [#if MODS_ALLOWED Paths.modFolders(baseFile), #end Paths.getPreloadPath(baseFile)]) {
				if (Paths.exists(file))
					return file;
			}
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

	public inline static function getLuaPath(scriptPath:String) {
		#if LUA_ALLOWED
		return getFileWithExtensions(scriptPath, Paths.LUA_EXTENSIONS);
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
		Paths.updateContentList();
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
		if (obj != null) @:privateAccess {
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

	public static function clearStoredMemory()
	{
		// clear anything not in the tracked assets list
		@:privateAccess
		for (key => obj in FlxG.bitmap._cache) {
			if (obj != null && !currentTrackedAssets.exists(key)) {
				// trace('cleared $key');
				Assets.cache.removeBitmapData(key);
				FlxG.bitmap._cache.remove(key);
				obj.destroy();
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
		var path:String;

		#if MODS_ALLOWED
		if (ignoreMods != true) {
			path = Paths.modFolders(key);
			if (Paths.exists(path)) return path;
		}
		#end

		path = Paths.getPreloadPath(key);
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

	inline static public function lua(key:String, ?library:String)
	{
		for (ext in Paths.LUA_EXTENSIONS) {
			var r = getPreloadPath('$key.$ext');
			if (Paths.exists(r))
				return r;
		}
		return null;
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
	inline public static function getSound(key:String):Null<Sound> {
		#if sys
		if (FileSystem.exists(key))
			return Sound.fromFile(key);
		#end

		if (Assets.exists(key))
			return Assets.getSound(key);

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
				version
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

	public static function getGraphic(path:String, cache:Bool = true, gpu:Bool = false):Null<FlxGraphic>
	{
		var newGraphic:FlxGraphic = cache ? currentTrackedAssets.get(path) : null;
		if (newGraphic == null) {
			var bitmap:BitmapData = getBitmapData(path);
			if (bitmap == null) return null;

			if (gpu) {
				var texture = FlxG.stage.context3D.createRectangleTexture(bitmap.width, bitmap.height, BGRA, true);
				texture.uploadFromBitmapData(bitmap);
				bitmap.image.data = null;
				bitmap.dispose();
				bitmap = BitmapData.fromTexture(texture);
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

	inline public static function imagePath(key:String):String
		return getPath('images/$key.$IMAGE_EXT');

	inline public static function imageExists(key:String):Bool
		return Paths.exists(imagePath(key));

	inline static public function image(key:String, ?library:String):Null<FlxGraphic>
		return returnGraphic(key, library);

	public static function returnGraphic(key:String, ?library:String):Null<FlxGraphic>
	{
		var path:String = imagePath(key);

		if (currentTrackedAssets.exists(path)) {
			if (!localTrackedAssets.contains(path)) 
				localTrackedAssets.push(path);

			return currentTrackedAssets.get(path);
		}

		var graphic = getGraphic(path);
		if (graphic==null && Main.showDebugTraces)
			trace('bitmap "$key" => "$path" returned null.');

		return graphic;
	}

	inline public static function soundPath(path:String, key:String, ?library:String)
	{
		return getPath('$path/$key.$SOUND_EXT');
	}

	public static function returnSound(path:String, key:String, ?library:String)
	{
		var gottenPath:String = soundPath(path, key, library);
	
		if (currentTrackedSounds.exists(gottenPath)) {
			if (!localTrackedAssets.contains(gottenPath))
				localTrackedAssets.push(gottenPath);

			return currentTrackedSounds.get(gottenPath);
		}
		
		var sound = getSound(gottenPath);
		if (sound != null) {
			currentTrackedSounds.set(gottenPath, sound);
	
			if (!localTrackedAssets.contains(gottenPath))
				localTrackedAssets.push(gottenPath);	
			
			return sound;
		}
		
		if (Main.showDebugTraces)
			trace('sound $path, $key => $gottenPath returned null');
		
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

	////	
	private static final assetsContent = {
		var c = new ContentData("assets", "assets");
		c.runsGlobally = true;
		c;
	};
	private static final contentContent = {
		var c = new ContentData("content", "content");
		c.runsGlobally = true;
		c;
	}

	public static var contentRegistry:Map<String, ContentData> = [];
	
	public static var currentModDirectory(default, set):String = '';
	public static var currentContent(default, set):ContentData = null;
	public static var dependencies(default, null):Array<ContentData> = [];
	public static var globalContent(default, null):Array<ContentData> = [];

	public static var modsToLoad:Array<String> = [];

	static function set_currentContent(mod:ContentData) {
		dependencies.resize(0);

		if (mod != null) {
			for (name in mod.dependencies) {
				if (contentRegistry.exists(name))
					dependencies.push(contentRegistry.get(name));
			}
		}

		return currentContent = mod;
	}
	
	static function set_currentModDirectory(v:String){
		if (!contentRegistry.exists(v)) {
			currentContent = null;
			return currentModDirectory = '';
		}
		
		if (currentModDirectory == v)
			return currentModDirectory;
		
		currentContent = contentRegistry.get(v);
		return currentModDirectory = v;
	}

	// ContentData to get stuff from when calling Paths.image, Paths.sound, etc
	public static function getContentOrder(ignoreGlobal:Bool = false):Array<ContentData> {
		var order = [];

		if (currentContent != null)
			order.push(currentContent);
		
		for (mod in dependencies)
			order.push(mod);
		
		if (!ignoreGlobal)
			for (mod in globalContent)
				order.push(mod);
		
		return order;
	}

	inline public static function getModPath(mod:String, key:String = "") {
		return Paths.contentRegistry.get(mod).getPath(key);
	}

	public static function updateContentList() {
		
		var disabledList:Map<String, Bool> = [];
		var splitFucking:Array<String> = [];
		
		var rawFucking = Paths.getContent('modList.txt');
		if (rawFucking != null) {
			splitFucking = CoolUtil.listFromString(rawFucking);
			for (line in splitFucking) {
				var values = line.split(':');
				var id:String = values[0];
				var disabled:Bool = values[1] == 'false';
				disabledList.set(id, disabled);
			}
		}

		modsToLoad.resize(0);
		for (name in Paths.getDirectoryFileList('content')) {
			if (!isDirectory('content/$name')) continue;

			if (!disabledList.exists(name)) 
				splitFucking.push('$name:true');

			if (disabledList.get(name) != true) 
				modsToLoad.push(name);
		}

		#if sys
		// Update modList file
		rawFucking = splitFucking.join('\n');
		File.saveContent('modList.txt', rawFucking);
		#end

		// TODO: mod menu!
		reloadContent();
	}

	// I might end up making this just return an array of loaded mods and require you to press a refresh button to reload content lol
	// mainly for optimization reasons, so its not going through the entire content folder every single time
	public static function reloadContent()
	{
		trace("Reloading content!");

		var sowy:Array<ContentData> = [];
		inline function push(c:ContentData)
			sowy.push(c);
		
		/*
		add(assetsContent);
		add(contentContent);
		*/

		function loadContentMod(folderName) {
			var folderPath = 'content/$folderName';
			if (!Paths.isDirectory(folderPath)) {
				trace('Erm, $folderPath is not a valid content directory');
				return;
			}

			#if PE_MOD_COMPATIBILITY
			var packdataPath:String = '$folderPath/pack.json';
			var packdata:Dynamic = Paths.getJson(packdataPath);

			if (packdata != null) {
				trace('Psych mod found: $folderPath');

				var id = Paths.formatToSongPath(folderName);
				var cd = new PsychContentData(id, folderPath);
				push(cd);
				return;
			}
			#end

			var metadataPath:String = '$folderPath/metadata.json';
			var metadata:Dynamic = Paths.getJson(metadataPath);
			var metadata:ContentMetadata = updateContentMetadataStructure(metadata);

			if (metadata != null) {
				trace('content found: $folderPath');

				var id = Paths.formatToSongPath(folderName);
				var cd = new ContentData(id, folderPath);
				
				cd.runsGlobally = metadata.runsGlobally == true;
				cd.dependencies = metadata.dependencies ?? [];
				
				push(cd);
				return;
			}

			trace('Wtf! folder with no metadata: $folderPath', "will not load");
		}
		
		//Paths.iterateDirectory('content', loadContentMod);
		for (id in modsToLoad) {
			loadContentMod(id);
		}

		Paths.contentRegistry.clear();
		Paths.globalContent.resize(0);

		for (cd in sowy) {
			Paths.contentRegistry.set(cd.id, cd);
			if (cd.runsGlobally)
				Paths.globalContent.push(cd);
			
			trace(cd.id);
			cd.create();
		}

		Paths.currentModDirectory = Paths.currentModDirectory; // refresh dependencies and whatever

		trace("Content reloaded :D");
	}

	#if MODS_ALLOWED
	static public function modFolders(key:String, ignoreGlobal:Bool = false):Null<String>
	{
		var path:Null<String> = null;
		inline function existsOnMod(mod:ContentData):Bool {
			path = mod.getPath(key);
			return exists(path);
		}

		/*
		if (currentContent != null)
			if (existsOnMod(currentContent))
				return path;
		
		for (mod in dependencies) 
			if (existsOnMod(mod)) 
				return path;

		if (ignoreGlobal != true) {
			for (mod in globalContent) {
				if (existsOnMod(mod)) 
					return path;
			}

			if (existsOnMod(contentContent))
				return path;
		}
		*/
		for (mod in getContentOrder()) {
			if (existsOnMod(mod))
				return path;
		}

		// IT RETURNS NULL NOW!!! GRAHHHHH!!!!!
		return null;
	}
	
	inline static function updateContentMetadataStructure(data:Dynamic):ContentMetadata
	{
		if (data == null)
			return null;
		
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

	#end

	inline static public function getFolders(dir:String, ?modsOnly:Bool = false){
		#if !MODS_ALLOWED
		return modsOnly ? [] : [Paths.getPreloadPath('$dir/')];
		
		#else
		var foldersToCheck:Array<String> = [];
		inline function push(mod) return foldersToCheck.push(mod.getPath('$dir/'));

		if (currentContent != null)
			push(currentContent);

		for (mod in dependencies)
			push(mod);
		
		for (mod in globalContent) 
			push(mod);
		
		push(contentContent);
		if (!modsOnly) 
			push(assetsContent);

		return foldersToCheck;
		#end
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