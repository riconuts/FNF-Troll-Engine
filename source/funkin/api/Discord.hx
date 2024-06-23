package funkin.api;

#if discord_rpc
import discord_rpc.DiscordRpc;

import sys.thread.Mutex;
import sys.thread.Thread;
import Sys.sleep;

#if LUA_ALLOWED
import llua.Lua;
import llua.State;
#end

class DiscordClient
{
	private static final defaultID = #if tgt "1009523643392475206" #else '814588678700924999' #end;
	
	private static var discordDaemon:Thread;
	private static var mutex:Mutex = new Mutex(); // whatever the fuck this is

	private static var lastPresence:DiscordPresenceOptions;
	public static var currentID:String = defaultID;

	public static function start()
	{
		if (discordDaemon != null){
			discordDaemon.sendMessage(currentID);
			return;
		}

		trace("Discord Client initializing...");

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

					DiscordRpc.shutdown(); // Nothing should happen if it wasn't started before right???
					DiscordRpc.start({
						clientID: id,
						onReady: onReady,
						onError: onError,
						onDisconnected: onDisconnected
					});

					mutex.release();

					trace("Discord Client started.");
				}

				if (id!=null) DiscordRpc.process();

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
		DiscordRpc.shutdown();
		mutex.release();

		discordDaemon.sendMessage(false);
	}

	////
	static var allowedImageKeys:Array<String> = [
		#if !tgt
		"icon",
		#else
		"app-logo",
		"gorgeous",
		"trollface",

		"talentless-fox",
		"no-villains",
		"die-batsards",
		"taste-for-blood",
		
		"high-shovel",
		"on-your-trail",
		"proving-nothing",

		"no-heroes",
		"scars-n-stars",
		
		"lonely-looser",
		"hammerhead",
		"all-hail-the-king",

		"presentless-fox",
		"no-grinches",
		"die-carolers",

		"tricks-for-treats",
		"lonely-ghouler",
		"hammerdread",
		"fear-the-pumpkin-king",
		"you-cant-consent",
		#end
	];
	inline static function getImageKey(key):String
		return allowedImageKeys.contains(key) ? key : allowedImageKeys[0];

	public static function changePresence(details:String, state:Null<String>, largeImageKey:String = "app-logo", ?hasStartTimestamp:Bool, ?endTimestamp:Float)
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

		lastPresence = {
			details: details,
			state: state,

			largeImageKey: getImageKey(largeImageKey),
			#if tgt
			largeImageText: "Tails Gets Trolled v" + lime.app.Application.current.meta.get('version'),
			#else
			largeImageText: "Troll Engine " + Main.displayedVersion,
			#end

			// Obtained times are in milliseconds so they are divided so Discord can use it
			startTimestamp: Std.int(startTimestamp / 1000),
			endTimestamp: Std.int(endTimestamp / 1000)
		};

		DiscordRpc.presence(lastPresence);

		mutex.release();
		
		//trace('Discord RPC Updated. Arguments: $details, $state, $smallImageKey, $hasStartTimestamp, $endTimestamp');
	}

	static function onReady()
	{
		if (lastPresence != null)
			DiscordRpc.presence(lastPresence);
		else
			changePresence("In the Menus", null);
	}

	static function onError(_code:Int, _message:String)
	{
		trace('Error! $_code : $_message');
	}

	static function onDisconnected(_code:Int, _message:String)
	{
		trace('Disconnected! $_code : $_message');
	}

	#if LUA_ALLOWED
	public static function addLuaCallbacks(lua:State)
	{
		Lua_helper.add_callback(lua, "changePresence",
			function(details:String, state:Null<String>, ?smallImageKey:String, ?hasStartTimestamp:Bool, ?endTimestamp:Float){
				changePresence(details, state, smallImageKey, hasStartTimestamp, endTimestamp);
			});
	}
	#end
}
#end