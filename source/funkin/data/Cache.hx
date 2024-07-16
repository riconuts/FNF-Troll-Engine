package funkin.data;

import flixel.math.FlxMath.minInt;
import flixel.graphics.FlxGraphic;
import openfl.Assets;
import openfl.media.Sound;
import openfl.display.BitmapData;
import haxe.ds.List;

#if sys
import sys.FileSystem;
import sys.io.Process;
import haxe.io.BytesOutput;
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

typedef AssetPreload = {
	var path:String;
	@:optional var type:String;
	@:optional var library:String; // heh
}

class Cache
{
	public static function loadWithList(shitToLoad:Array<AssetPreload>, ?multicoreOnly = false):Void
	{
		#if loadBenchmark
		var startTime = Sys.time();
		#end

		#if MULTICORE_LOADING
		final threadLimit:Int = minInt(threadLimit, shitToLoad.length);
		
		if (ClientPrefs.multicoreLoading && threadLimit > 1){
			//// clear duplicates
			var uniqueMap:Map<String, AssetPreload> = [];
			
			for (shit in shitToLoad){ 
				if (shit.type == null)
					shit.type = "IMAGE";
				uniqueMap.set(shit.type + ": " + shit.path, shit);
			}

			//
			var shitToLoad = new List<AssetPreload>();
			for (k => v in uniqueMap){
				/*trace(k);*/ 
				shitToLoad.add(v);
			}
			
			////
			final mainThread = Thread.current();
			final makeThread = Thread.create.bind(_loadingThreadFunc.bind(mainThread));

			trace('Loading ${shitToLoad.length} items with $threadLimit threads.');
			
			var threadArray:Array<Thread> = [for (i in 0...threadLimit){				
				var thread = makeThread();
				thread.sendMessage(shitToLoad.pop());
				thread;
			}];
			
			while (true)
			{
				var msg:LoadingThreadMessage = Thread.readMessage(true);
				// trace(msg);

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
					if (msg.loadedGraphics != null)
						for (key => value in msg.loadedGraphics){
							Paths.localTrackedAssets.push(key);
							Paths.currentTrackedAssets.set(key, value);

							#if traceLoading
							trace('loaded:$key',value);
							#end
						}
					
					if (msg.loadedSounds != null)
						for (key => value in msg.loadedSounds){
							Paths.localTrackedAssets.push(key);
							Paths.currentTrackedSounds.set(key, value);

							#if traceLoading
							trace('loaded:$key',value);
							#end
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
			var msg:Dynamic = Thread.readMessage(true);

			/*
			if (msg == null)
				continue;
			*/

			if (msg == false){ // time to die
				mainThread.sendMessage({thread: thisThread, terminate: true, loadedGraphics: loadedGraphics, loadedSounds: loadedSounds});
				break;
			}

			switch (msg.type){
				case 'SOUND':
					var result = returnUncachedSound('sounds/${msg.path}', msg.library);
					if (result != null) loadedSounds.set(result.path, result.sound);
				case 'MUSIC':
					var result = returnUncachedSound('music/${msg.path}', msg.library);
					if (result != null) loadedSounds.set(result.path, result.sound);
				case 'SONG':
					var result = returnUncachedSound('songs/${msg.path}', msg.library);
					if (result != null) loadedSounds.set(result.path, result.sound);
				default:
					var result = returnUncachedGraphic(msg.path, msg.library);
					if (result != null) loadedGraphics.set(result.path, result.graphic);
			}
			
			mainThread.sendMessage({thread: thisThread, terminate: false});
		}
	}
	#end

	/** Returns an uncached image graphic, returns null if the image is already cached **/
	private static function returnUncachedGraphic(key:String, ?library:String)
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

			return {path: path, graphic: newGraphic};
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
					
			return {path: path, graphic: newGraphic};
		}

		return null;
	}

	inline static var SOUND_EXT = Paths.SOUND_EXT;

	/** Returns an uncached sound, returns null if the sound is already cached **/
	public static function returnUncachedSound(path:String, ?library:String)
	{
		var daPath = '$path.$SOUND_EXT';
		
		#if MODS_ALLOWED
		var file:String = Paths.modFolders(daPath);

		if (Paths.currentTrackedSounds.exists(file))
			return null;

		var leSound = Sound.fromFile(file); 
		if (leSound != null)
			return {path: file, sound: leSound}
		#end
		
		////
		var gottenPath:String = Paths.getPath(daPath, SOUND, library);
		
		if (Paths.currentTrackedSounds.exists(gottenPath))
			return null;
		
		#if (html5 || flash)
		if (Assets.exists(gottenPath, SOUND))
			return {path: gottenPath, sound: Assets.getSound(gottenPath)};
		#else
		var leSound = Sound.fromFile(gottenPath);
		if (leSound != null)
			return {path: gottenPath, sound: leSound};
		#end
		
		return null;
	}

	private static function load(toLoad:AssetPreload){
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
		
		#if traceLoading
		trace("loaded " + toLoad.path);
		#end
	}

	public static final threadLimit:Int = {	
		var result:Null<String> = null;

		#if !MULTICORE_LOADING

		#elseif windows
		result = Sys.getEnv("NUMBER_OF_PROCESSORS");
			
		#elseif linux
		result = runProcess("nproc", []);
		
		if (result == null) {
			var cpuinfo = runProcess("cat", [ "/proc/cpuinfo" ]);
			
			if (cpuinfo != null) {
				var split = cpuinfo.split("processor");
				result = Std.string(split.length - 1);
			}
		}
			
		#elseif mac
		var cores = ~/Total Number of Cores: (\d+)/;
		var output = runProcess("/usr/sbin/system_profiler", ["-detailLevel", "full", "SPHardwareDataType"]);
		
		if (cores.match(output))
			result = cores.matched(1);
		#end

		var n:Null<Int> = (result == null) ? null : Std.parseInt(result);
		(n == null) ? 1 : n;
	}

	#if sys
	// https://github.com/openfl/hxp/blob/master/src/hxp/System.hx
	@:unreflective
	private inline static function runProcess(command:String, args:Array<String>):Null<String> {
		var argString = "";
		for (arg in args) {
			if (arg.indexOf(" ") != -1)
				argString += " \"" + arg + "\"";
			else
				argString += " " + arg;
		}

		var process = new Process(command, args);
		var buffer = new BytesOutput();
		var waiting = true;

		while (waiting) {
			try {
				var current = process.stdout.readAll(1024);
				buffer.write(current);

				if (current.length == 0)
					waiting = false;
			} catch (e) {
				waiting = false;
			}
		}

		var result = process.exitCode();
		var output = buffer.getBytes().toString();
		var retVal:Null<String> = output;

		if (output == "") {
			var error = process.stderr.readAll().toString();
			process.close();

			if (result != 0 || error != "")
				retVal = null;
		} else {
			process.close();
		}
		
		return retVal;
	}
	#end
}