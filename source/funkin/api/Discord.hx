package funkin.api;

#if DISCORD_ALLOWED
import hxdiscord_rpc.Discord as DiscordRpc;
import hxdiscord_rpc.Types;
#end

import sys.thread.Mutex;
import sys.thread.Thread;
import Sys.sleep;

#if !DISCORD_ALLOWED
class DiscordClient {
	public inline static function start() {}
	public inline static function changeID(id:String) {}
	public inline static function shutdown(?noTrace:Bool) {}
	public inline static function changePresence(details:String, ?state:String, largeImageKey:String = "app-logo", ?hasStartTimestamp:Bool, ?endTimestamp:Float) {}
}
#else
class DiscordClient
{
	private static final defaultID = '814588678700924999';
	private static final defaultAllowedImageKeys:Array<String> = [
		"icon"
	];
	
	private static var discordDaemon:Thread;
	private static var mutex:Mutex = new Mutex(); // whatever the fuck this is
	private static var lastPresence:DiscordRichPresence;

	////
	public static var currentID(default, null):String = defaultID;
	public static var allowedImageKeys:Array<String> = defaultAllowedImageKeys.copy();

	public static function start()
	{
		if (discordDaemon != null){
			discordDaemon.sendMessage(currentID);
			return;
		}

		trace("Discord Client initializing...");

		function initDiscordRPC(appid:String) {
			DiscordRpc.Shutdown(); // Nothing should happen if it wasn't started before right???
			var eventHandler:DiscordEventHandlers = DiscordEventHandlers.create();
			eventHandler.ready = cpp.Function.fromStaticFunction(onReady);
			eventHandler.disconnected = cpp.Function.fromStaticFunction(onDisconnected);
			eventHandler.errored = cpp.Function.fromStaticFunction(onError);
			DiscordRpc.Initialize(appid, cpp.RawPointer.addressOf(eventHandler), 1, null);
		}

		discordDaemon = Thread.create(() ->{
			var id:Null<String> = null;

			while (true)
			{
				var msg:Dynamic = Thread.readMessage(id==null);  // wait for a wake up call 

				if (msg == null){
					// nothing you idot

				}
				else if (msg == false){
					// DiscordClient.shutdown() was called
					id = null;

				}
				else if (msg!=id || (msg==true && id!=null)){
					id = msg;
					trace('Discord Client starting with id: $id');
					mutex.acquire();
					initDiscordRPC(id);
					mutex.release();
					trace("Discord Client started.");
				}

				if (id!=null) {
					#if DISCORD_DISABLE_IO_THREAD
					DiscordRpc.UpdateConnection();
					#end
					DiscordRpc.RunCallbacks();
				}

				sleep(0.6);
			}
		});

		discordDaemon.sendMessage(defaultID);
		trace("Discord Client initialized.");
	}

	public static function changeID(id:String){
		currentID = id;

		if (ClientPrefs.discordRPC)
			discordDaemon.sendMessage(id);
	}

	public static function shutdown(?noTrace:Bool)
	{
		if (discordDaemon == null) return;

		if (noTrace != true)
			trace("Discord Client shitting down...");

		mutex.acquire();
		DiscordRpc.Shutdown();
		mutex.release();

		discordDaemon.sendMessage(false);
	}

	////
	inline static function getImageKey(key):String
		return allowedImageKeys.contains(key) ? key : allowedImageKeys[0];

	public static function changePresence(details:String, ?state:String, largeImageKey:String = "app-logo", ?hasStartTimestamp:Bool, ?endTimestamp:Float)
	{
		/*
		DiscordRpc.presence({
			details: "thats how you do it",
			largeImageKey: 'gorgeous',
			largeImageText: 'gorgeous'
		});
		*/

		////
		var startTimestamp:Float = hasStartTimestamp ? Date.now().getTime() : 0;

		if (endTimestamp > 0)
			endTimestamp = startTimestamp + endTimestamp;

		mutex.acquire();

		lastPresence = DiscordRichPresence.create();
		lastPresence.details = details;
		lastPresence.state = state;
		lastPresence.largeImageKey = getImageKey(largeImageKey);
		lastPresence.largeImageText = "Troll Engine " + Main.Version.displayedVersion;

		// Obtained times are in milliseconds so they are divided so Discord can use it
		lastPresence.startTimestamp = Std.int(startTimestamp / 1000);
		lastPresence.endTimestamp = Std.int(endTimestamp / 1000);

		DiscordRpc.UpdatePresence(cpp.RawConstPointer.addressOf(lastPresence));

		mutex.release();
		
		//trace('Discord RPC Updated. Arguments: $details, $state, $smallImageKey, $hasStartTimestamp, $endTimestamp');
	}

	static function onReady(request:cpp.RawConstPointer<DiscordUser>)
	{
		if (lastPresence.instance == 0)
			DiscordRpc.UpdatePresence(cpp.RawConstPointer.addressOf(lastPresence));
		else
			changePresence("In the Menus", null);
	}

	static function onError(_code:Int, _message:cpp.ConstCharStar)
	{
		trace('Error! $_code : $_message');
	}

	static function onDisconnected(_code:Int, _message:cpp.ConstCharStar)
	{
		trace('Disconnected! $_code : $_message');
	}
}
#end