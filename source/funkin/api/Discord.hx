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
	var defaultPresence:DiscordClientPresenceParams;
}

private final defaultRPCInfo:DiscordRPCInfo = {
	applicationId: '814588678700924999',
	allowedImageKeys: ["icon"],

	defaultPresence: {
		largeImageText: 'Troll Engine ' + Main.Version.displayedVersion,	
		largeImageKey: 'icon',
		smallImageKey: 'none',
		details: 'Presence Unknown',
	}
};

// this is kinda fucked up i think
class DiscordClient
{
	public static var hideDetails:Bool = true;
	
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
		changePresence(null);
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
	public static function changePresence(data:DiscordClientPresenceParams, mergeDefault:Bool = true)
	{
		if (!isActive())
			return;

		if (hideDetails) {
			data = currentInfo.defaultPresence;
		}else if (mergeDefault) {
			data = merge(data, currentInfo.defaultPresence);
		}

		////
		var details = data.details;
		var state = data.state;
		var largeImageKey = data.largeImageKey;
		var largeImageText = data.largeImageText;
		var smallImageKey = data.smallImageKey;
		// does discord even use these anymore i havent seen them working in a huge while
		//var startTimestamp = data.startTimestamp;
		//var endTimestamp = data.endTimestamp;

		if (!currentInfo.allowedImageKeys.contains(largeImageKey))
			largeImageKey = currentInfo.defaultPresence.largeImageKey;

		////
		mutex.acquire();

		lastPresence = #if (hxdiscord_rpc >=  "1.3.0") new DiscordRichPresence() #else DiscordRichPresence.create() #end;
		lastPresence.details = details;
		lastPresence.state = state;
		lastPresence.largeImageKey = largeImageKey;
		lastPresence.largeImageText = largeImageText;
		lastPresence.smallImageKey = smallImageKey;
		/*
		lastPresence.startTimestamp = startTimestamp;
		lastPresence.endTimestamp = endTimestamp;
		*/

		DiscordRpc.UpdatePresence(cpp.RawConstPointer.addressOf(lastPresence));

		mutex.release();
	}

	private static function merge(data:Dynamic, defaultData:Dynamic) {
		if (data == null)
			return defaultData;

		data = Reflect.copy(data);

		if (defaultData != null) {
			var dataFields = Reflect.fields(data);
			for (fieldName in Reflect.fields(defaultData)) {
				if (!dataFields.contains(fieldName)) {
					Reflect.setField(data, fieldName, Reflect.field(defaultData, fieldName));
				}
			}		
		}

		return data;
	}
}

#else
class DiscordClient {
	public inline static function start(wait:Bool) {}
	public inline static function shutdown(wait:Bool) {}
	public inline static function changePresence(details:String, ?state:String, largeImageKey:String = "app-logo", ?hasStartTimestamp:Bool, ?endTimestamp:Float) {}
}
#end

// copied from Funkin zzzzzzzzzzzzz
typedef DiscordClientPresenceParams =
{
	/** 
		The first row of text below the game title.  
	**/
	var ?state:String;

	/** 
		The second row of text below the game title.  
	**/
	var ?details:Null<String>;

	/** 
		A large, 4-row high image to the left of the content.  
	**/
	var ?largeImageKey:String;

	/** 
		A small, inset image to the bottom right of `largeImageKey`.  
	**/
	var ?smallImageKey:String;

	/**
		Text that is displayed when hovering over `largeImageKey`.  
	**/
	var ?largeImageText:String;
}