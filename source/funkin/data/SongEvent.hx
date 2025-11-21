package funkin.data;

import funkin.scripts.FunkinHScript;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import funkin.objects.Character;
import flixel.util.FlxColor;
import funkin.scripts.Globals;
import funkin.data.ChartData.PsychEvent as EventData;
import funkin.states.PlayState.instance as game;
import funkin.states.PlayState;

using StringTools;

/*
	Song event classes to be used by PlayState only!!!
	TODO: get rid of that psych value1 value2 bs!!!
	Might make a json for the description, event data structure definition, maybe support to change chart editor icon? lmao 
	Will be handled by a diff class tho (SongEventData), don't want to pozz this class, it should be for PlayState shit only!
*/
class SongEvent {
	public final id:String;

	private function new(id:String)
		this.id = id;

	public function onLoad():Void {}

	/**
		@returns Whether this event data should be pushed into the events list or not.
	**/
	public function shouldPush(data:EventData):Bool return true;

	/**
		@returns Offset time in milliseconds, how much earlier should this event be triggered.
	**/
	public function getOffset(data:EventData):Float return 0.0;

	/** 
		Called for every event data with this `SongEvent`'s `id`.  
		@param data Event data
	**/
	public function onPush(data:EventData):Void {}

	public function onTrigger(data:EventData, ?time:Float):Void {}

	public function update(elapsed:Float):Void {}

	public function destroy():Void {}
}

class ScriptedSongEvent extends SongEvent {
	final script:FunkinHScript;
	
	#if ALLOW_DEPRECATION
	// why couldn't you give onTrigger the full data structure like every other function!!!!!!!!!!!!! ughh
	var useNewAPI:Bool;
	#end

	private function new(id:String, script:FunkinHScript) {
		super(id);
		this.script = script;
		script.set('this', this);
		#if ALLOW_DEPRECATION
		this.useNewAPI = script.get("useNewAPI") == true;
		#end
	}

	override function onLoad() {
		callScript("onLoad");
	}

	override function shouldPush(data:EventData):Bool {
		return switch(callScript("shouldPush", [data])) {
			#if ALLOW_DEPRECATION
			case Globals.Function_Stop: false;
			#end
			case false: false;
			default: true;
		}
	}

	override function getOffset(data:EventData):Float {
		var r = callScript("getOffset", [data]);
		return (r != null) && (r is Int || r is Float) ? r : 0.0;
	}

	override function onPush(data:EventData):Void {
		callScript("onPush", [data]);
	}
	
	override function onTrigger(data:EventData, ?time:Float):Void {
		#if ALLOW_DEPRECATION
		(!useNewAPI) ? callScript("onTrigger", [data.value1, data.value2, time]) :
		#end
		callScript("onTrigger", [data, time]);
	}
	
	override function update(elapsed:Float):Void {
		callScript("elapsed", [elapsed]);
	}
	
	override function destroy():Void {
		callScript("destroy");
		script.stop();
	}

	public function callScript(func:String, ?args:Array<Dynamic>):Null<Dynamic> {
		return script.executeFunc(func, args);
	}

	public static function fromName(name:String) {
		var path = Paths.getHScriptPath('events/$name');
		if (path == null) return null;
		var script = FunkinHScript.fromFile(path, name, null, false);
		return new ScriptedSongEvent(name, script);
	}
}

class DefaultSongEvent extends SongEvent {
	override function onPush(data:EventData) 
	{
		if (data.value1 == null) data.value1 = '';
		if (data.value2 == null) data.value2 = '';

		switch(data.event)
		{
			case 'Change Scroll Speed': // Negative duration means using the event time as the tween finish time
				var duration = Std.parseFloat(data.value2);
				if (!Math.isNaN(duration) && duration < 0.0){
					data.strumTime -= duration * 1000;
					data.value2 = Std.string(-duration);
				}

			case 'Mult SV' | 'Constant SV':
				var speed:Float = 1;
				if(data.event == 'Constant SV'){
					var b = Std.parseFloat(data.value1);
					speed = Math.isNaN(b) ? 1 : (b / game.songSpeed);
				}else{
					speed = Std.parseFloat(data.value1);
					if (Math.isNaN(speed)) speed = 1;
				}

				@:privateAccess
				var speedChanges = game.speedChanges;

				#if EASED_SVs
				var endTime:Null<Float> = null;
				var easeFunc:EaseFunction = FlxEase.linear;

				var tweenOptions = data.value2.split("/");
				if(tweenOptions.length >= 1){
					easeFunc = FlxEase.linear;
					var parsed:Float = Std.parseFloat(tweenOptions[0]);
					if(!Math.isNaN(parsed))
						endTime = data.strumTime + (parsed * 1000);

					if(tweenOptions.length > 1){
						var f:EaseFunction = ScriptingUtil.getFlxEaseByString(tweenOptions[1]);
						if(f != null)
							easeFunc = f;
					}
				}

				var lastChange:SpeedEvent = speedChanges[speedChanges.length - 1];
				speedChanges.push({
					position: getTimeFromSV(data.strumTime, lastChange),
					startTime: data.strumTime,
					endTime: endTime,
					easeFunc: easeFunc,
					startSpeed: lastChange.startSpeed,
					speed: speed
				});
				#else
				var lastChange:SpeedEvent = speedChanges[speedChanges.length - 1];
				speedChanges.push({
					position: game.getTimeFromSV(data.strumTime, lastChange),
					startTime: data.strumTime,
					speed: speed
				});
				#end
				
			case 'Change Character':
				var charType = PlayState.getCharacterTypeFromString(data.value1);
				if (charType != -1) game.addCharacterToList(data.value2, charType);

				for (shit in funkin.data.CharacterData.returnCharacterPreload(data.value2)) {
					@:privateAccess
					game.shitToLoad.push(shit);
				}
		}
	}

	override function onTrigger(data:EventData, ?time:Float) {
		var eventName:String = data.event;
		var value1:String = data.value1;
		var value2:String = data.value2;
		time ??= funkin.Conductor.songPosition;

		switch(eventName) {
			case 'Change Focus':
				switch(value1.toLowerCase().trim()){
					case 'dad' | 'opponent':
						if (game.callOnScripts('onMoveCamera', ["dad"]) != Globals.Function_Stop){
							game.moveCamera(game.dad);
						}
					case 'gf' | 'girlfriend':
						if (game.callOnScripts('onMoveCamera', ["gf"]) != Globals.Function_Stop){
							game.moveCamera(game.gf);
						}
					default:
						if (game.callOnScripts('onMoveCamera', ["bf"]) != Globals.Function_Stop){
							game.moveCamera(game.boyfriend);
						}
				}

			case 'Game Flash':
				var dur:Float = Std.parseFloat(value2);
				if(Math.isNaN(dur)) dur = 0.5;

				var col:Null<FlxColor> = FlxColor.fromString(value1);
				if (col == null) col = 0xFFFFFFFF;

				game.camGame.flash(col, dur, null, true);

			case 'Hey!':
				var value:Int = switch (value1.toLowerCase().trim()) {
					case 'bf' | 'boyfriend' | '0': 0;
					case 'gf' | 'girlfriend' | '1': 1;
					default: 2;
				}

				var time:Float = Std.parseFloat(value2);
				if(Math.isNaN(time) || time <= 0) time = 0.6;

				if (value != 0 && game.gf != null) {
					game.gf.playAnim('cheer', true);
					game.gf.specialAnim = true;
					game.gf.heyTimer = time;
				}
				if (value != 1 && game.boyfriend != null) {
					game.boyfriend.playAnim('hey', true);
					game.boyfriend.specialAnim = true;
					game.boyfriend.heyTimer = time;
				}

			case 'Set GF Speed':
				var value:Null<Int> = Std.parseInt(value1);
				if (value == null || value < 1) value = 1;
				game.gfSpeed = value;

			case 'Add Camera Zoom':
				if (ClientPrefs.camZoomP > 0) {
					var camZoom:Float = Std.parseFloat(value1);
					var hudZoom:Float = Std.parseFloat(value2);
					if(Math.isNaN(camZoom)) camZoom = 0.015;
					if(Math.isNaN(hudZoom)) hudZoom = 0.03;

					game.cameraBump(camZoom, hudZoom);
				}
				
			case 'Play Animation':
				var char:Character = game.getCharacterFromString(value2);
				if (char != null) {
					char.playAnim(value1, true);
					char.specialAnim = true;
				}

			case 'Camera Follow Pos':
				var val1:Float = Std.parseFloat(value1);
				var val2:Float = Std.parseFloat(value2);

				var isNan1 = Math.isNaN(val1);
				var isNan2 = Math.isNaN(val2);

				if (isNan1 && isNan2) 
					game.cameraPoints.remove(game.customCamera);
				else{
					if (!isNan1) game.customCamera.x = val1;
					if (!isNan2) game.customCamera.y = val2;
					game.addCameraPoint(game.customCamera);
				}

			case 'Alt Idle Animation':
				var char:Character = game.getCharacterFromString(value1);
				if (char != null) {
					char.idleSuffix = value2;
					char.recalculateDanceIdle();
				}

			case 'Screen Shake':
				var valuesArray:Array<String> = [value1, value2];
				var targetsArray:Array<FlxCamera> = [game.camGame, game.camHUD];
				for (i in 0...targetsArray.length) {
					var split:Array<String> = valuesArray[i].split(',');
					var duration:Float = 0;
					var intensity:Float = 0;
					if(split[0] != null) duration = Std.parseFloat(split[0].trim());
					if(split[1] != null) intensity = Std.parseFloat(split[1].trim());
					if(Math.isNaN(duration)) duration = 0;
					if(Math.isNaN(intensity)) intensity = 0;

					if(duration > 0 && intensity != 0) {
						targetsArray[i].shake(intensity, duration);
					}
				}

			case 'Change Character':
				var charType:CharacterType = PlayState.getCharacterTypeFromString(value1);
				if (charType != -1) game.changeCharacter(value2, charType);

			case 'Change Scroll Speed':
				if (game.songSpeedType == "constant")
					return;

				var val1:Float = Std.parseFloat(value1);
				var val2:Float = Std.parseFloat(value2);
				if(Math.isNaN(val1)) val1 = 1.0;
				if(Math.isNaN(val2)) val2 = 0.0;

				var newValue:Float = PlayState.SONG.speed * ClientPrefs.getGameplaySetting('scrollspeed', 1.0) * val1;
				if (game.songSpeedTween != null)
					game.songSpeedTween.cancel();

				// value should never be negative as that should be handled and changed prior to this
				if (val2 == 0.0)
					game.songSpeed = newValue;
				else{
					@:privateAccess
					game.songSpeedTween = FlxTween.num(
						game.songSpeed, newValue, val2, 
						{
							ease: FlxEase.linear, 
							onComplete: (twn) -> game.songSpeedTween = null	
						},
						game.set_songSpeed
					);
				}

			case 'Set Property':
				var value2:Dynamic = switch(value2){
					case "true": true;
					case "false": false;
					default: value2;
				}

				try{
					funkin.scripts.Util.setProperty(value1, value2);					
				}catch (e:haxe.Exception){
					trace('Set Property event error: $value1 | $value2');
				}
		}
	}
}

class SongEventHandler {
	private final eventMap:Map<String, SongEvent> = [];

	public function new() {}

	public function get(id:String):Null<SongEvent> {
		if (exists(id))
			return eventMap[id];

		var event:SongEvent;

		event = ScriptedSongEvent.fromName(id);

		// TODO: make hardcoded events good, separate them into their own classes instead of a big ass switch block
		event ??= new DefaultSongEvent(id);

		if (event != null)
			eventMap[id] = event;
			
		return event;
	}

	public function exists(id:String):Bool
		return eventMap.exists(id);

	public function update(elapsed:Float) {
		for (event in eventMap)
			event.update(elapsed);
	}

	public function destroy() {
		for (event in eventMap)
			event.destroy();
		eventMap.clear();
	}
}