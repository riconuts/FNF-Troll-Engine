package;

// thanks neb

import flixel.math.FlxMath;

import flixel.graphics.FlxGraphic;
import flash.media.Sound;

import openfl.Assets;
import openfl.display.BitmapData;

#if sys
import sys.FileSystem;
#end

#if MULTICORE_LOADING
import sys.thread.Thread;

typedef LoadingThreadMessage = {
	var thread:Thread;
	var ?terminate:Bool;
	var ?loadedGraphics:Map<String, FlxGraphic>;
	var ?loadedSounds:Map<String, Sound>;
}
#end

typedef AssetPreload =
{
	var path:String;
	@:optional var type:String;
	@:optional var library:String; // heh
}

class Cache
{
	// nvm it still fuckign crashes

	public static function returnUncachedGraphic(key:String, ?library:String)
	{
		var path:String;

		#if MODS_ALLOWED
		path = Paths.modsImages(key);

		if (Paths.currentTrackedAssets.exists(path))
			return null;

		if (FileSystem.exists(path))
		{
			@:privateAccess
			var newGraphic:FlxGraphic = new FlxGraphic(null, BitmapData.fromFile(path));
			newGraphic.persist = true;

			return {key: path, graphic: newGraphic};
		}
		#end

		////
		path = Paths.getPath('images/$key.png', IMAGE, library);

		if (Paths.exists(path, IMAGE) && !Paths.currentTrackedAssets.exists(path))
		{
			#if (html5 || flash)
			var newGraphic:FlxGraphic = FlxGraphic.fromAssetKey(path, false, path, false);
			#else
			@:privateAccess
			var newGraphic:FlxGraphic = new FlxGraphic(null, BitmapData.fromFile(path));
			#end
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
		
		////
		var gottenPath:String = Paths.getPath(daPath, SOUND, library);
		
		if (Paths.currentTrackedSounds.exists(gottenPath))
			return null;
		
		#if (html5 || flash)
		if (Assets.exists(gottenPath, SOUND))
			return {key: gottenPath, sound: Assets.getSound(gottenPath)};
		#else
		var leSound = Sound.fromFile(gottenPath);
		if (leSound != null)
			return {key: gottenPath, sound: leSound};
		#end
		
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

			//
			var shitToLoad = [for (k => v in uniqueMap){/*trace(k);*/ v;}];
			trace('loading ${shitToLoad.length} items.');
			
			// TODO: figure out why this sometimes crashes

			var mainThread = Thread.current();
			var makeThread = Thread.create.bind(() -> {
				var loadedGraphics:Map<String, FlxGraphic> = [];
				var loadedSounds:Map<String, Sound> = [];

				var thisThread = Thread.current();

				while (true){
					var msg:Dynamic = Thread.readMessage(true);

					if (msg == null)
						continue;

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
				trace('creating thread $i');
				
				var thread = makeThread();
				thread.sendMessage(shitToLoad.pop());
				thread;
			}];

			while (true)
			{
				var msg:LoadingThreadMessage = Thread.readMessage(true);

				if (shitToLoad.length > 0) // send more shit
				{
					msg.thread.sendMessage(shitToLoad.pop());
					//trace('shit left: ${shitToLoad.length}');
				}
				else if (msg.terminate != true) // kys
				{
					msg.thread.sendMessage(false);
				}
				else // the end
				{ 
					for (key => value in msg.loadedGraphics){
						Paths.localTrackedAssets.push(key);
						Paths.currentTrackedAssets.set(key, value);
						//trace('loaded:$key',value);
					}
					for (key => value in msg.loadedSounds){
						Paths.localTrackedAssets.push(key);
						Paths.currentTrackedSounds.set(key, value);
						//trace('loaded:$key',value);
					}
					
					threadArray.remove(msg.thread);
					//trace('thread terminated, ${threadArray.length} left.');
					if (threadArray.length < 1)
						break;
				}
			}
		}
		else
		#end
		//if (!multicoreOnly)
		//	for (shit in shitToLoad) load(shit);

		#if loadBenchmark
		trace('finished loading in ${Sys.time() - startTime} seconds.');
		#end
	}
}