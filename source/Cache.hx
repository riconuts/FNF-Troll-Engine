package;

// thanks neb

import flixel.FlxSprite;
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
	@:optional var library:String;
	@:optional var terminate:Bool;
}

class Cache{

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
		//trace("loaded " + toLoad.path);
	}

	static public function loadWithList(shitToLoad:Array<AssetPreload>, ?multicoreOnly = false)
	{
		#if loadBenchmark
		var currentTime = Sys.time();
		#end

		#if MULTICORE_LOADING
		if (ClientPrefs.multicoreLoading){
			// TODO: go through shitToLoad and clear it of repeats as to not waste time loadin shit that already exists
			for (shit in shitToLoad)
				trace(shit.path);

			var threadLimit:Int = ClientPrefs.loadingThreads; // Math.floor(Std.parseInt(Sys.getEnv("NUMBER_OF_PROCESSORS")));
			if (shitToLoad.length > 0 && threadLimit > 1)
			{
				// thanks shubs -neb
				for (shit in shitToLoad)
					if (shit.terminate)
						shit.terminate = false; // do not

				var count = shitToLoad.length;
				if (threadLimit > count)
					threadLimit = count; // only use as many as it needs

				var threads:Array<Thread> = [];
				var finished:Bool = false;

				trace("loading " + count + " items with " + threadLimit + " threads");

				var main = Thread.current();
				var loadIdx:Int = 0;

				for (i in 0...threadLimit)
				{
					var thread:Thread = Thread.create(() ->
					{
						while (true)
						{
							var toLoad:Null<AssetPreload> = Thread.readMessage(true); // get the next thing that should be loaded
							if (toLoad != null)
							{
								if (toLoad.terminate == true)
									break;
								Cache.load(toLoad);
								#if traceLoading
								trace("getting next asset");
								#end
								main.sendMessage({ // send message so that it can get the next thing to load
									thread: Thread.current(),
									asset: toLoad,
									terminated: false
								});
							}
						}
						main.sendMessage({ // send message so that it can get the next thing to load
							thread: Thread.current(),
							asset: '',
							terminated: true
						});
						return;
					});

					threads.push(thread);
				}
				for (thread in threads)
					thread.sendMessage(shitToLoad.pop()); // gives the thread the top thing to load
				while (loadIdx < count)
				{
					var res:Null<PreloadResult> = Thread.readMessage(true); // whenever a thread loads its asset, it sends a message to get a new asset for it to load
					if (res != null)
					{
						if (res.terminated)
						{
							if (threads.contains(res.thread))
							{
								threads.remove(res.thread); // so it wont have a message sent at the end
							}
						}
						else
						{
							loadIdx++;
							#if traceLoading
							trace("loaded " + loadIdx + " out of " + count);
							#end
							if (shitToLoad.length > 0)
								res.thread.sendMessage(shitToLoad.pop()); // gives the thread the next thing it should load
							else
								res.thread.sendMessage({path: '', library: '', terminate: true}); // terminate the thread
						}
					}
				};
				//trace(loadIdx, count);
				//var idx:Int = 0;
				for (t in threads)
				{
					t.sendMessage({path: '', library: '', terminate: true}); // terminate all threads
					//trace("terminating thread " + idx);
					//idx++;
				}
				finished = true;
			}
		}
		else		
		#end
			if (!multicoreOnly){
				for (shit in shitToLoad)
					Cache.load(shit);
			}

		#if loadBenchmark
		trace("loaded in " + (Sys.time() - currentTime));
		#end
	}
}