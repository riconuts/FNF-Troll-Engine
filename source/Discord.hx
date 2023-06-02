package;

import Sys.sleep;
import discord_rpc.DiscordRpc;

using StringTools;

#if LUA_ALLOWED
import llua.Lua;
import llua.State;
#end

class DiscordClient
{
	public static var isInitialized:Bool = false;

	public static function initialize()
	{
		var DiscordDaemon = sys.thread.Thread.create(() ->
		{
			new DiscordClient();
		});
		trace("Discord Client initialized");
		isInitialized = true;
	}

	public function new()
	{
		trace("Discord Client starting...");
		DiscordRpc.start({
			clientID: "1009523643392475206",
			onReady: onReady,
			onError: onError,
			onDisconnected: onDisconnected
		});
		trace("Discord Client started.");

		while (true)
		{
			DiscordRpc.process();
			sleep(2);
			//trace("Discord Client Update");
		}

		DiscordRpc.shutdown();
	}
	
	static function onReady()
	{
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

	////
	static var allowedImageKeys:Array<String> = [
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
	];
	inline static function getImageKey(key):String
		return allowedImageKeys.contains(key) ? key : "app-logo";
	
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

		DiscordRpc.presence({
			details: details,
			state: state,

			largeImageKey: getImageKey(largeImageKey),
			largeImageText: "Tails Gets Trolled v" + lime.app.Application.current.meta.get('version'), //"Troll Engine"
			// largeImageText: "Engine Version: " + MainMenuState.engineVersion,

			// Obtained times are in milliseconds so they are divided so Discord can use it
			startTimestamp : Std.int(startTimestamp / 1000),
			endTimestamp : Std.int(endTimestamp / 1000)
		});
		
		//trace('Discord RPC Updated. Arguments: $details, $state, $smallImageKey, $hasStartTimestamp, $endTimestamp');
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

	public static function shutdown()
	{
		DiscordRpc.shutdown();
	}
}