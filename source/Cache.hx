package;

// thanks neb

import flixel.math.FlxMath;

import flixel.graphics.FlxGraphic;
import flash.media.Sound;

import openfl.display.BitmapData;
import openfl.Assets as OpenFlAssets;

#if sys
import sys.FileSystem;
#end

#if MULTICORE_LOADING
import sys.thread.Thread;

typedef PreloadResult =
{
	var thread:Thread;
	var asset:String;
	@:optional var terminated:Bool;
}
#end

typedef AssetPreload =
{
	var path:String;
	@:optional var type:String;
	@:optional var library:String; // useless
	@:optional var terminate:Bool;
}

class Cache
{
	// I believe the shit that causes the game to hang up while loading is writing stuff to the cache map
	// so, i'll only add it to the cache after all the loading is done i guess...

	// Considering the amount of shit you need to do for this to work this properly, is it even worth it?
	// Does this improve loading times or not?

	public static function returnUncachedGraphic(key:String, ?library:String)
	{
		#if MODS_ALLOWED
		var modKey:String = Paths.modsImages(key);
		if (FileSystem.exists(modKey))
		{
			if (Paths.currentTrackedAssets.exists(modKey))
				return null;

			var newGraphic:FlxGraphic = FlxGraphic.fromBitmapData(BitmapData.fromFile(modKey), false, modKey);
			newGraphic.persist = true;

			return {key: modKey, graphic: newGraphic};
		}
		#end

		var path = Paths.getPath('images/$key.png', IMAGE, library);
		if (OpenFlAssets.exists(path, IMAGE))
		{
			if (Paths.currentTrackedAssets.exists(modKey))
				return null;

			var newGraphic:FlxGraphic = FlxG.bitmap.add(path, false, path);
			newGraphic.persist = true;
					
			return {key: path, graphic: newGraphic};
		}
		
		return null;
	}

	inline static var SOUND_EXT = Paths.SOUND_EXT;

	public static function returnUncachedSound(path:String, ?library:String)
	{
		var daPath = '$path.$SOUND_EXT';
		
		#if MODS_ALLOWED
		var file:String = Paths.modFolders(daPath);

		if (Paths.currentTrackedSounds.exists(file))
			return null;
		if (FileSystem.exists(file))
			return {key: file, sound: Sound.fromFile(file)}
		#end
		
		var gottenPath:String = Paths.getPath(daPath, SOUND, library);
		
		if (Paths.currentTrackedSounds.exists(gottenPath))
			return null;
		
		#if (!html5)
		var leSound = Sound.fromFile(gottenPath);
		#else
		var leSound = OpenFlAssets.getSound(gottenPath); // dose this shit work idk
		#end

		if (leSound != null)
			return {key: gottenPath, sound: leSound};
		
		return null;
	}

	static public function load(toLoad:AssetPreload){
		switch (toLoad.type){
			case 'SOUND':
				Paths.returnSound("sounds", toLoad.path, toLoad.library);
			case 'MUSIC':
				Paths.returnSound("music", toLoad.path, toLoad.library);
			case 'SONG':
				Paths.returnSound("songs", toLoad.path, toLoad.library);
			default:
				Paths.returnGraphic(toLoad.path, toLoad.library);
		}
		
		// trace("loaded " + toLoad.path);
	}

	static public function loadWithList(shitToLoad:Array<AssetPreload>, ?multicoreOnly = false)
	{
		#if loadBenchmark
		var startTime = Sys.time();
		#end

		#if MULTICORE_LOADING
		var threadLimit:Int = FlxMath.minInt(shitToLoad.length, ClientPrefs.loadingThreads);
		
		if (threadLimit > 0){
			// clear duplicates
			var uniqueMap:Map<String, AssetPreload> = [];
			for (shit in shitToLoad){ 
				if (shit.type == null)
					shit.type = "IMAGE";
				uniqueMap.set(shit.type+" "+shit.path, shit);
			}
			var shitToLoad = [for (k => v in uniqueMap){/*trace(k);*/ v;}];
			trace('loading ${shitToLoad.length} items.');

			var mainThread = Thread.current();
			var makeThread = Thread.create.bind(function(){
				var loadedGraphics:Map<String, FlxGraphic> = [];
				var loadedSounds:Map<String, Sound> = [];

				var thisThread = Thread.current();

				while (true){
					var msg:Dynamic = Thread.readMessage(true);

					if (msg == false){ // time to die
						mainThread.sendMessage({thread: thisThread, terminate: true, loadedGraphics: loadedGraphics, loadedSounds: loadedSounds});
						break;
					}

					switch (msg.type){
						case 'SOUND':
							var result = returnUncachedSound('sounds/${msg.path}', msg.library);
							if (result != null) loadedSounds.set(result.key, result.sound);
						case 'MUSIC':
							var result = returnUncachedSound('music/${msg.path}', msg.library);
							if (result != null) loadedSounds.set(result.key, result.sound);
						case 'SONG':
							var result = returnUncachedSound('songs/${msg.path}', msg.library);
							if (result != null) loadedSounds.set(result.key, result.sound);
						default:
							var result = returnUncachedGraphic(msg.path, msg.library);
							if (result != null) loadedGraphics.set(result.key, result.graphic);
					}
					
					mainThread.sendMessage({thread: thisThread, terminate: false});
				}
			});

			var threadArray:Array<Thread> = [for (i in 0...threadLimit){
				var thread = makeThread();
				thread.sendMessage(shitToLoad.pop());
				thread;
			}];

			while (true)
			{
				var msg:Dynamic = Thread.readMessage(true);
				var daThread:Thread = msg.thread;

				if (shitToLoad.length > 0){
					daThread.sendMessage(shitToLoad.pop());
					//trace('shit left: ${shitToLoad.length}');
				}else if (msg.terminate != true){
					daThread.sendMessage(false); // kys

				}else{
					// you can't iterate through dynamic values blah blah blah
					var loadedGraphics:Map<String, FlxGraphic> = msg.loadedGraphics;
					var loadedSounds:Map<String, Sound> = msg.loadedSounds;

					for (key => value in loadedGraphics){
						Paths.localTrackedAssets.push(key);
						Paths.currentTrackedAssets.set(key, value);
						//trace('loaded:$key',value);
					}
					for (key => value in loadedSounds){
						Paths.localTrackedAssets.push(key);
						Paths.currentTrackedSounds.set(key, value);
						//trace('loaded:$key',value);
					}
					
					threadArray.remove(daThread);
					//trace('thread terminated, ${threadArray.length} left.');
					if (threadArray.length < 1)
						break;
				}
			}
		}
		else
		#end
		if (!multicoreOnly)
			for (shit in shitToLoad) load(shit);

		#if loadBenchmark
		trace('finished loading in ${Sys.time() - startTime} seconds.');
		#end
	}
}