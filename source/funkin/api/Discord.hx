package funkin.api;

#if DISCORD_ALLOWED
import hxdiscord_rpc.Discord as DiscordRpc;
import hxdiscord_rpc.Types;

import sys.thread.Mutex;
import sys.thread.Thread;
import Sys.sleep;

typedef DiscordRPCInfo = {
	var applicationId:String;
	var allowedImageKeys:Array<String>;

	@:optional var defaultLargeImageText:String;

	@:optional var defaultLargeImageKey:String;
	@:optional var defaultSmallImageKey:String;
}

private final defaultRPCInfo:DiscordRPCInfo = {
	applicationId: '814588678700924999',
	allowedImageKeys: ["icon"],

	defaultLargeImageText: 'Troll Engine ' + Main.Version.displayedVersion,

	defaultLargeImageKey: 'icon',
	defaultSmallImageKey: 'none'
};

// this is kinda fucked up i think
class DiscordClient
{
	private static var lastPresence:DiscordRichPresence;

	private static final mutex = new Mutex();
	private static final waitMutex = new Mutex();
	private static final thread:Thread = Thread.create(threadLoop);
	private static function threadLoop() {
		var curId:String = "";
		var isActive:Bool = false;

		while (true) {
			var msg:Dynamic = Thread.readMessage(isActive==false);

			mutex.acquire();

			if (msg==false) {
				trace("Discord Client shitting down...");
				DiscordRpc.Shutdown();
				isActive = false;

			}else if (msg==true || (msg is String)) {
				if (msg is String)
					curId = cast(msg, String);
			
				if (isActive != true) {
					isActive = true;
					trace('Discord Client starting with id: $curId');

					DiscordRpc.Shutdown();
					var eventHandler:DiscordEventHandlers = #if (hxdiscord_rpc >=  "1.3.0") new DiscordEventHandlers() #else DiscordEventHandlers.create() #end;
					eventHandler.ready = cpp.Function.fromStaticFunction(onReady);
					eventHandler.disconnected = cpp.Function.fromStaticFunction(onDisconnected);
					eventHandler.errored = cpp.Function.fromStaticFunction(onError);
					DiscordRpc.Initialize(curId, cpp.RawPointer.addressOf(eventHandler), #if (hxdiscord_rpc >=  "1.3.0") true #else 1 #end, null);
					
					trace("Discord Client started.");
					waitMutex.acquire();
				}
			}

			if (isActive) {
				#if DISCORD_DISABLE_IO_THREAD
				DiscordRpc.UpdateConnection();
				#end
				DiscordRpc.RunCallbacks();				
			}else {
				trace("Discord Client shat down.");
				waitMutex.release();
			}
			
			mutex.release();
			sleep(0.6);
		}
	}

	private static function onReady(request:cpp.RawConstPointer<DiscordUser>)
	{
		var presence = #if (hxdiscord_rpc >=  "1.3.0") new DiscordRichPresence() #else DiscordRichPresence.create() #end;
		presence.details = "Presence Unknown";
		DiscordRpc.UpdatePresence(cpp.RawConstPointer.addressOf(lastPresence));
	}

	private static function onError(_code:Int, _message:cpp.ConstCharStar)
	{
		trace('Error! $_code : $_message');
	}

	private static function onDisconnected(_code:Int, _message:cpp.ConstCharStar)
	{
		trace('Disconnected! $_code : $_message');
	}

	private static inline function wait_until_it_started() {
		while (waitMutex.tryAcquire())
			waitMutex.release();
	}
	private static inline function wait_until_it_shatdown() {
		waitMutex.acquire();
		waitMutex.release();
	}

	public static function isActive():Bool {
		if (waitMutex.tryAcquire()) {
			waitMutex.release();
			return false;
		}
		return true;
	}

	////
	@:isVar private static var currentInfo(null, null):DiscordRPCInfo;
	
	public static function start(wait:Bool = false)
	{
		if (!isActive()) {
			currentInfo ??= defaultRPCInfo;
			thread.sendMessage(currentInfo.applicationId);
			if (wait) wait_until_it_started();
		}
	}

	public static function setRPCInfo(info:DiscordRPCInfo, wait:Bool = false) {
		currentInfo = info ?? defaultRPCInfo;

		if (isActive()) {
			thread.sendMessage(currentInfo.applicationId);
			if (wait) wait_until_it_started();
		}
		
		return currentInfo; 
	}

	public static function shutdown(wait:Bool = false)
	{
		if (isActive()) {
			thread.sendMessage(false);
			if (wait) wait_until_it_shatdown();
		}
	}

	////
	public static function changePresence(details:String, ?state:String, ?largeImageKey:String, ?hasStartTimestamp:Bool, ?endTimestamp:Float)
	{
		if (!isActive())
			return;

		////
		var startTimestamp:Float = hasStartTimestamp ? Date.now().getTime() : 0;

		if (endTimestamp > 0)
			endTimestamp = startTimestamp + endTimestamp;
		
		if (largeImageKey==null || !currentInfo.allowedImageKeys.contains(largeImageKey))
			largeImageKey = currentInfo.defaultLargeImageKey;

		var largeImageKey:String = largeImageKey;
		var largeImageText:String = currentInfo.defaultLargeImageText;

		mutex.acquire();

		lastPresence = #if (hxdiscord_rpc >=  "1.3.0") new DiscordRichPresence() #else DiscordRichPresence.create() #end;
		lastPresence.details = details;
		lastPresence.state = state;
		lastPresence.largeImageKey = largeImageKey;
		lastPresence.largeImageText = largeImageText;

		// Obtained times are in milliseconds so they are divided so Discord can use it
		lastPresence.startTimestamp = Std.int(startTimestamp / 1000);
		lastPresence.endTimestamp = Std.int(endTimestamp / 1000);

		DiscordRpc.UpdatePresence(cpp.RawConstPointer.addressOf(lastPresence));

		mutex.release();
		
		// trace('Discord RPC Updated. Arguments: $details, $state, $largeImageKey, $hasStartTimestamp, $endTimestamp');
	}
}

#else
class DiscordClient {
	public inline static function start(wait:Bool) {}
	public inline static function shutdown(wait:Bool) {}
	public inline static function changePresence(details:String, ?state:String, largeImageKey:String = "app-logo", ?hasStartTimestamp:Bool, ?endTimestamp:Float) {}
}
#end