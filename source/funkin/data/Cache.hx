package funkin.data;

import flixel.math.FlxMath.minInt;
import flixel.graphics.FlxGraphic;
import openfl.media.Sound;
import openfl.display.BitmapData;

#if MULTICORE_LOADING
import sys.thread.Thread;

enum MasterMessage {
	Load(asset:AssetPreload);
	Finish();
}
enum SlaveMessage {
	Loaded(thread:Thread);
	Finished(thread:Thread, ?loadedGraphics:Map<String, FlxGraphic>, ?loadedSounds:Map<String, Sound>);
}
#end

enum abstract AssetPreloadType(String) from String to String{
	var IMAGE;
	var SOUND;
	var MUSIC;
	var SONG;
}

typedef AssetPreload = {
	var path:String;
	@:optional var type:AssetPreloadType;
	@:optional var library:Null<String>; // unused
}

class Cache
{
	public static function loadWithList(shitToLoad:Array<AssetPreload>, ?multicoreOnly = false):Void
	{
		#if loadBenchmark
		var startTime = Sys.time();
		#end

		#if MULTICORE_LOADING
		final threadLimit:Int = minInt(processorCores, shitToLoad.length);
		
		if (ClientPrefs.multicoreLoading && threadLimit > 1){
			//// clear duplicates
			var uniqueMap:Map<String, AssetPreload> = [
				for(shit in shitToLoad)
					shit.path + "_" + shit.type => shit
			];

			//
			var shitToLoad = new List<AssetPreload>(); // idk what advantages this brings over just using arrays but yolo lol
			for (k => v in uniqueMap){
				/*trace(k);*/ 
				shitToLoad.push(v);
			}
			
			////
			final mainThread = Thread.current();
			final makeThread = Thread.create.bind(_loadingThreadFunc.bind(mainThread));

			trace('Loading ${shitToLoad.length} items with $threadLimit threads.');
			
			var threadArray:Array<Thread> = [for (_ in 0...threadLimit){				
				var thread = makeThread();
				thread.sendMessage(Load(shitToLoad.pop()));
				thread;
			}];
			
			while (true)
			{
				var msg:SlaveMessage = Thread.readMessage(true);

				switch (msg){
					case Loaded(thread):
						if (shitToLoad.length > 0)
						{
							thread.sendMessage(Load(shitToLoad.pop()));
							//trace('shit left: ${shitToLoad.length}');
						}
						else
						{
							//trace('terminating thread ${threadArray.indexOf(thread) + 1}');
							thread.sendMessage(Finish);
						}
					case Finished(thread, loadedGraphics, loadedSounds):
						if (loadedGraphics != null)
							for (key => value in loadedGraphics){
								Paths.localTrackedAssets.push(key);
								Paths.currentTrackedAssets.set(key, value);
	
								#if traceLoading
								trace('loaded:$key',value);
								#end
							}
						
						if (loadedSounds != null)
							for (key => value in loadedSounds){
								Paths.localTrackedAssets.push(key);
								Paths.currentTrackedSounds.set(key, value);
	
								#if traceLoading
								trace('loaded:$key',value);
								#end
							}
						
						threadArray.remove(thread);
						//trace('thread terminated, ${threadArray.length} left.');
						if (threadArray.length < 1)
							break;
					default:
				}
			}
		}
		else
		#end
		if (!multicoreOnly){
			trace('Loading ${shitToLoad.length} items.');
			for (shit in shitToLoad) 
				load(shit);
		}

		#if loadBenchmark
		trace('finished loading in ${Sys.time() - startTime} seconds.');
		#end
	}

	#if MULTICORE_LOADING
	private static function _loadingThreadFunc(mainThread:Thread)
	{
		var loadedGraphics:Map<String, FlxGraphic> = [];
		var loadedSounds:Map<String, Sound> = [];

		var thisThread = Thread.current();

		while (true){
			var msg:MasterMessage = Thread.readMessage(true);

			switch(msg) {
				case Load(ass):
					switch (ass.type){
						default:
							var result = returnUncachedGraphic(ass.path, ass.library);
							if (result != null) loadedGraphics.set(result.path, result.graphic);
						case SOUND:
							var result = returnUncachedSound('sounds/${ass.path}', ass.library);
							if (result != null) loadedSounds.set(result.path, result.sound);
						case MUSIC:
							var result = returnUncachedSound('music/${ass.path}', ass.library);
							if (result != null) loadedSounds.set(result.path, result.sound);
						case SONG:
							var result = returnUncachedSound('songs/${ass.path}', ass.library);
							if (result != null) loadedSounds.set(result.path, result.sound);
					}
					mainThread.sendMessage(Loaded(thisThread));

				case Finish:
					// send back everything loaded by this thread
					mainThread.sendMessage(Finished(thisThread, loadedGraphics, loadedSounds));
					break;
				default:
			}
		}
	}
	#end

	inline static var IMAGE_EXT = Paths.IMAGE_EXT;

	/** Returns an uncached image graphic, returns null if the image is already cached **/
	private static function returnUncachedGraphic(key:String, ?library:String)
	{
		var path:String = Paths.getPath('images/$key.$IMAGE_EXT');

		if (Paths.currentTrackedAssets.exists(path))
			return null;
		
		var newGraphic = Paths.getGraphic(path, false, false);
		return (newGraphic==null) ? null : {path: path, graphic: newGraphic};
	}

	inline static var SOUND_EXT = Paths.SOUND_EXT;

	/** Returns an uncached sound, returns null if the sound is already cached **/
	public static function returnUncachedSound(key:String, ?library:String):{path:String, sound:Sound}
	{
		var path:String = Paths.getPath('$key.$SOUND_EXT');

		if (Paths.currentTrackedSounds.exists(path))
			return null;
		
		var newSnd = Paths.getSound(path);
		return (newSnd==null) ? null : {path: path, sound: newSnd};
	}

	private static function load(toLoad:AssetPreload){
		switch (toLoad.type){
			default:
				Paths.image(toLoad.path, toLoad.library);
			case SOUND:
				Paths.returnFolderSound("sounds", toLoad.path, toLoad.library);
			case MUSIC:
				Paths.returnFolderSound("music", toLoad.path, toLoad.library);
			case SONG:
				Paths.returnFolderSound("songs", toLoad.path, toLoad.library);
		}
		
		#if traceLoading
		trace("loaded " + toLoad.path);
		#end
	}

	public static final processorCores:Int = {	
		var result:Null<String> = null;

		#if !MULTICORE_LOADING

		#elseif windows
		result = Sys.getEnv("NUMBER_OF_PROCESSORS");
			
		#elseif linux
		result = Main.runProcess("nproc", []);
		
		if (result == null) {
			var cpuinfo = Main.runProcess("cat", [ "/proc/cpuinfo" ]);
			
			if (cpuinfo != null) {
				var split = cpuinfo.split("processor");
				result = Std.string(split.length - 1);
			}
		}
			
		#elseif mac
		var cores = ~/Total Number of Cores: (\d+)/;
		var output = Main.runProcess("/usr/sbin/system_profiler", ["-detailLevel", "full", "SPHardwareDataType"]);
		
		if (cores.match(output))
			result = cores.matched(1);
		#end

		var n:Null<Int> = (result == null) ? null : Std.parseInt(result);
		(n == null) ? 1 : n;
	}
}