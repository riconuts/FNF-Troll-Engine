package funkin.scripts;

import funkin.scripts.FunkinScript.ScriptType;
import funkin.states.*;
import funkin.states.PlayState;
import funkin.scripts.Globals.*;
import funkin.scripts.Util;
import funkin.scripts.Util.*;
import funkin.objects.*;
import funkin.modchart.SubModifier;

import flixel.*;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.addons.transition.FlxTransitionableState;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxSave;
import flixel.util.FlxTimer;
import haxe.Constraints.Function;
import Type.ValueType;

using StringTools;

#if DISCORD_ALLOWED
import funkin.api.Discord;
#end

#if (cpp && windows)
import funkin.api.Windows;
#end

#if LUA_ALLOWED
import llua.Convert;
import llua.Lua;
import llua.LuaL;
import llua.State;
#else
private typedef State = Dynamic;
#end

class FunkinLua extends FunkinScript
{
	public static final defaultVars:Map<String, Dynamic> = new Map<String, Dynamic>();
	
	public static var haxeScript:FunkinHScript;
	
	#if LUA_ALLOWED
	public var lua:State = null;

	public static function fromFile(path:String, ?name:String, ?ignoreCreateCall:Bool, ?vars:Map<String, Dynamic>):FunkinLua {
		trace('loading lua file: $path');

		var lua:State = LuaL.newstate();
		LuaL.openlibs(lua);

		try {
			var result:Dynamic = LuaL.dofile(lua, path);
			var resultStr:String = Lua.tostring(lua, result);
			if (resultStr != null && result != 0)
				throw resultStr;
		}
		catch (e:haxe.Exception)
		{
			var msg = e.message;
			var title = 'Error on lua script!';
			trace('$title $msg');

			#if windows
			var msgBoxResult = Windows.msgBox(msg, title, MessageBoxOptions.RETRYCANCEL | MessageBoxIcon.ERROR);
			if (msgBoxResult == MessageBoxReturnValue.RETRY)
				return fromFile(path);

			#else
			var window = lime.app.Application.current.window;
			window.fullscreen = false;
			window.alert(msg, title);

			#end

			lua = null;
		}

		if (name == null) name = path;
		return new FunkinLua(lua, name, ignoreCreateCall, vars);
	}

	inline private function addCallback(name:String, func:Function):Void
		Lua_helper.add_callback(lua, name, func);

	inline private function removeCallback(name:String):Void
		Lua_helper.remove_callback(lua, name);

	inline private function luaError(message:String):Void {
		#if (linc_luajit >= "0.0.6")
		LuaL.error(lua, message);
		#end
	}

	function resultIsAllowed(leLua:State, leResult:Null<Int>) { //Makes it ignore warnings
		return switch(Lua.type(leLua, leResult)) {
			case Lua.LUA_TNIL | Lua.LUA_TBOOLEAN | Lua.LUA_TNUMBER | Lua.LUA_TSTRING | Lua.LUA_TTABLE :
				true;
			default:
				false;
		}
	}

	public function getBool(variable:String):Bool {
		var result:String = null;
		Lua.getglobal(lua, variable);
		result = Convert.fromLua(lua, -1);
		Lua.pop(lua, 1);

		if (result == null)
			return false;

		// YES! FINALLY IT WORKS
		//trace('variable: ' + variable + ', ' + result);
		return (result == 'true');
	}

	function getErrorMessage() {
		var v:String = Lua.tostring(lua, -1);
		Lua.pop(lua, 1);
		return v;
	}
	#end

	override function setDefaultVars(){
		#if LUA_ALLOWED
		super.setDefaultVars();

		// Lua shit
		set('luaDebugMode', false);
		set('luaDeprecatedWarnings', true);

		// Camera poo
		set('cameraX', 0);
		set('cameraY', 0);

		// Screen stuff
		set('screenWidth', FlxG.width);
		set('screenHeight', FlxG.height);

		// PlayState cringe ass nae nae bullcrap
		set('score', 0);
		set('misses', 0);
		set('hits', 0);

		set('rating', 0);
		set('ratingName', '');
		set('ratingFC', '');

		set("curSection", 0);

		set("playbackRate", 1.0); // for compatibility, don't give it the actual value.

		for (i in 0...5) {
			// annoying since some scripts use defaultPlayerStrumX/Y 4
			// (LOOKING AT YOU CHARA.)
			set('defaultPlayerStrumX' + i, 0);
			set('defaultPlayerStrumY' + i, 0);
			set('defaultOpponentStrumX' + i, 0);
			set('defaultOpponentStrumY' + i, 0);
		}

		// Default character positions woooo
		set('defaultBoyfriendX', PlayState.instance.BF_X);
		set('defaultBoyfriendY', PlayState.instance.BF_Y);
		set('defaultOpponentX', PlayState.instance.DAD_X);
		set('defaultOpponentY', PlayState.instance.DAD_Y);
		set('defaultGirlfriendX', PlayState.instance.GF_X);
		set('defaultGirlfriendY', PlayState.instance.GF_Y);

		// Character shit
		set('boyfriendName', PlayState.SONG.player1);
		set('dadName', PlayState.SONG.player2);
		set('gfName', PlayState.SONG.gfVersion);

		////
		addCallback("getProperty", getProperty);
		addCallback("setProperty", setProperty);
		addCallback("getPropertyFromGroup", getPropertyFromGroup);
		addCallback("setPropertyFromGroup", setPropertyFromGroup);
		addCallback("removeFromGroup", removeFromGroup);
		addCallback("getPropertyFromClass", getPropertyFromClass);
		addCallback("setPropertyFromClass", setPropertyFromClass);

		var gonnaClose:Bool = false;
		addCallback("close", (?printMessage:Bool) -> {
			if (!gonnaClose){
				if (printMessage == true)
					luaTrace('Stopping lua script: ' + scriptName);
				else
					trace('Stopping lua script $scriptName');

				PlayState.instance.scriptsToClose.push(this);
				gonnaClose = true;
			}
		});

		addCallback("debugPrint", Reflect.makeVarArgs((toPrint) -> luaTrace(toPrint.join(", "), true, false)));

		//// mod manager
		addCallback("setPercent", function(modName:String, val:Float, player:Int = -1)
			PlayState.instance.modManager.setPercent(modName, val, player)
		);

		addCallback("addBlankMod", function(modName:String, defaultVal:Float = 0, player:Int = -1) {
			PlayState.instance.modManager.registerBlankMod(modName, defaultVal, player);
		});

		addCallback("setValue", function(modName:String, val:Float, player:Int = -1)
			PlayState.instance.modManager.setValue(modName, val, player)
		);

		addCallback("getPercent", function(modName:String, player:Int)
			return PlayState.instance.modManager.getPercent(modName, player)
		);

		addCallback("getValue", function(modName:String, player:Int)
			return PlayState.instance.modManager.getValue(modName, player)
		);

		addCallback("setCurrentValue", function(modName:String, val:Float, ?player:Int = -1){
			return PlayState.instance.modManager.setCurrentValue(modName, val, player);
		});
		
		addCallback("getTargetValue", function(modName:String, player:Int){
			return PlayState.instance.modManager.getTargetValue(modName, player);
		});

		addCallback("queueSet", function(step:Float, modName:String, target:Float, player:Int = -1)
			PlayState.instance.modManager.queueSet(step, modName, target, player)
		);

		addCallback("queueSetP", function(step:Float, modName:String, perc:Float, player:Int = -1)
			PlayState.instance.modManager.queueSetP(step, modName, perc, player)
		);
		
		addCallback("queueEase",
			function(step:Float, endStep:Float, modName:String, percent:Float, style:String = 'linear', player:Int = -1, ?startVal:Float)
				PlayState.instance.modManager.queueEase(step, endStep, modName, percent, style, player, startVal)
		);

		addCallback("queueEaseP",
			function(step:Float, endStep:Float, modName:String, percent:Float, style:String = 'linear', player:Int = -1, ?startVal:Float)
				PlayState.instance.modManager.queueEaseP(step, endStep, modName, percent, style, player, startVal)
		);

		////
		addCallback("getRunningScripts", function(){
			var runningScripts:Array<String> = [];
			for (idx in 0...PlayState.instance.luaArray.length)
				runningScripts.push(PlayState.instance.luaArray[idx].scriptName);


			return runningScripts;
		});

		addCallback("callOnLuas", function(?funcName:String, ?args:Array<Dynamic>, ignoreStops=false, ignoreSelf=true, ?exclusions:Array<String>){
			if(funcName==null){
				#if (linc_luajit >= "0.0.6")
				LuaL.error(lua, "bad argument #1 to 'callOnLuas' (string expected, got nil)");
				#end
				return;
			}
			if(args==null) args = [];
			if(exclusions==null) exclusions = [];

			Lua.getglobal(lua, 'scriptName');
			var daScriptName = Lua.tostring(lua, -1);
			Lua.pop(lua, 1);
			if(ignoreSelf && !exclusions.contains(daScriptName))exclusions.push(daScriptName);
			PlayState.instance.callOnLuas(funcName, args, ignoreStops, exclusions);
		});

		addCallback("callScript", function(?luaFile:String, ?funcName:String, ?args:Array<Dynamic>){
			if(luaFile==null){
				#if (linc_luajit >= "0.0.6")
				LuaL.error(lua, "bad argument #1 to 'callScript' (string expected, got nil)");
				#end
				return;
			}
			if(funcName==null){
				#if (linc_luajit >= "0.0.6")
				LuaL.error(lua, "bad argument #2 to 'callScript' (string expected, got nil)");
				#end
				return;
			}
			if(args==null){
				args = [];
			}

			var luaInstance = getLuaFileInstance(luaFile);

			if (luaInstance == null)
			{
				Lua.pushnil(lua);
				return;
			}

			luaInstance.call(funcName, args);
		});

		addCallback("getGlobalFromScript", function(?luaFile:String, ?global:String){ // returns the global from a script
			if(luaFile==null){
				#if (linc_luajit >= "0.0.6")
				LuaL.error(lua, "bad argument #1 to 'getGlobalFromScript' (string expected, got nil)");
				#end
				return;
			}
			if(global==null){
				#if (linc_luajit >= "0.0.6")
				LuaL.error(lua, "bad argument #2 to 'getGlobalFromScript' (string expected, got nil)");
				#end
				return;
			}

			var luaInstance = getLuaFileInstance(luaFile);
			
			if (luaInstance == null)
			{
				Lua.pushnil(lua);
				return;
			}

						Lua.getglobal(luaInstance.lua, global);
						if(Lua.isnumber(luaInstance.lua,-1)){
							Lua.pushnumber(lua, Lua.tonumber(luaInstance.lua, -1));
						}else if(Lua.isstring(luaInstance.lua,-1)){
							Lua.pushstring(lua, Lua.tostring(luaInstance.lua, -1));
						}else if(Lua.isboolean(luaInstance.lua,-1)){
							Lua.pushboolean(lua, Lua.toboolean(luaInstance.lua, -1));
						}else{
							Lua.pushnil(lua);
						}
						// TODO: table

						Lua.pop(luaInstance.lua,1); // remove the global			
		});
		addCallback("setGlobalFromScript", function(luaFile:String, global:String, val:Dynamic){ // returns the global from a script
			var luaInstance = getLuaFileInstance(luaFile);

			if (luaInstance == null)
			{
				Lua.pushnil(lua);
				return;
			}

			luaInstance.set(global, val);
		});
		addCallback("getGlobals", function(luaFile:String){ // returns a copy of the specified file's globals
			var luaInstance = getLuaFileInstance(luaFile);

			if (luaInstance == null) {
				Lua.pushnil(lua);
				return;
			}

						Lua.newtable(lua);
						var tableIdx = Lua.gettop(lua);

						Lua.pushvalue(luaInstance.lua, Lua.LUA_GLOBALSINDEX);
						Lua.pushnil(luaInstance.lua);
						while(Lua.next(luaInstance.lua, -2) != 0) {
							// key = -2
							// value = -1

							var pop:Int = 0;

							// Manual conversion
							// first we convert the key
							if(Lua.isnumber(luaInstance.lua,-2)){
								Lua.pushnumber(lua, Lua.tonumber(luaInstance.lua, -2));
								pop++;
							}else if(Lua.isstring(luaInstance.lua,-2)){
								Lua.pushstring(lua, Lua.tostring(luaInstance.lua, -2));
								pop++;
							}else if(Lua.isboolean(luaInstance.lua,-2)#if (linc_luajit < "0.0.6")==1#end){
								Lua.pushboolean(lua, Lua.toboolean(luaInstance.lua, -2));
								pop++;
							}
							// TODO: table


							// then the value
							if(Lua.isnumber(luaInstance.lua,-1)){
								Lua.pushnumber(lua, Lua.tonumber(luaInstance.lua, -1));
								pop++;
							}else if(Lua.isstring(luaInstance.lua,-1)){
								Lua.pushstring(lua, Lua.tostring(luaInstance.lua, -1));
								pop++;
							}else if(Lua.isboolean(luaInstance.lua,-1)#if (linc_luajit < "0.0.6")==1#end){
								Lua.pushboolean(lua, Lua.toboolean(luaInstance.lua, -1));
								pop++;
							}
							// TODO: table

							if (pop==2) Lua.rawset(lua, tableIdx); // then set it
							Lua.pop(luaInstance.lua, 1); // for the loop
				  		}
				  		Lua.pop(luaInstance.lua,1); // end the loop entirely
						Lua.pushvalue(lua, tableIdx); // push the table onto the stack so it gets returned			
		});

		addCallback("runHaxeCode", function(code:String){
			#if HSCRIPT_ALLOWED
			if (haxeScript == null)
				return null;

			haxeScript.set('luaScript', this);
			var retVal = haxeScript.executeCode(code);

			if (retVal != null && !isOfTypes(retVal, [Bool, Int, Float, String, Array]))
				retVal = null;
	
			return retVal;
			#else
			luaTrace('runHaxeCode not supported');
			return null;
			#end
		});

		addCallback("isRunning", function(luaFile:String){
			return getLuaFileInstance(luaFile) != null;
		});

		addCallback("addLuaScript", function(luaFile:String, ?ignoreAlreadyRunning:Bool = false) { //would be dope asf.	
			var cervix = pussyPath(luaFile);
			var luaInstance = getLuaInstance(cervix);
			if (luaInstance == null) {
				luaTrace("Script " + luaFile + "doesn't exist!");
				return;
			}

			if (ignoreAlreadyRunning != true)
			{
				luaTrace('The script "' + luaFile + '" is already running!');
				return;
			}
			
			PlayState.instance.createLua(cervix);
		});
		addCallback("removeLuaScript", function(luaFile:String, ?ignoreAlreadyRunning:Bool = false) { //would be dope asf.
			var luaInstance = getLuaFileInstance(luaFile);
			if (luaInstance == null) {
				luaTrace("Script " + luaFile + "doesn't exist!");
				return;
			}
			
			PlayState.instance.removeLua(luaInstance);
		});

		addCallback("loadSong", function(?name:String = null, ?difficultyNum:Int = 1) {
			if(name == null || name.length < 1)
				name = PlayState.SONG.song;

			var poop = Paths.formatToSongPath(name);
			PlayState.SONG = funkin.data.Song.loadFromJson(poop, name);
			PlayState.instance.persistentUpdate = false;
			PlayState.difficulty = difficultyNum;
			PlayState.difficultyName = '';
			LoadingState.loadAndSwitchState(new PlayState());

			FlxG.sound.music.pause();
			FlxG.sound.music.volume = 0;
			if(PlayState.instance.vocals != null)
			{
				PlayState.instance.vocals.pause();
				PlayState.instance.vocals.volume = 0;
			}
		});

		addCallback("clearUnusedMemory", function() {
			Paths.clearUnusedMemory();
			return true;
		});

		addCallback("loadGraphic", function(tag:String, image:String, ?gridX:Int, ?gridY:Int) {
			var spr = cast(getObject(tag), FlxSprite);

			if(spr != null && image != null && image.length > 0)
			{
				var gX = gridX ?? 0;
				var gY = gridY ?? 0;
				var animated = gX!=0 || gY!=0;

				spr.loadGraphic(Paths.image(image), animated, gX, gY);
			}
		});
		addCallback("loadFrames", function(tag:String, image:String, spriteType:String = "sparrow") {
			var spr = cast(getObject(tag), FlxSprite);

			if (spr != null && image != null && image.length > 0)
				loadFrames(spr, image, spriteType);
		});

		addCallback("getObjectOrder", function(tag:String) {
			var leObj = getObject(tag);

			if (leObj == null) {
				luaTrace("Object " + tag + " doesn't exist!");
				return -1;
			}

			return getInstance().members.indexOf(leObj);
		});
		addCallback("setObjectOrder", function(tag:String, position:Int) {
			var leObj = getObject(tag);

			if (leObj == null) {
				luaTrace("Object " + tag + " doesn't exist!");
				return;
			}

			getInstance().remove(leObj, true);
			getInstance().insert(position, leObj);
		});

		// gay ass tweens
		inline function penisExam(tweenTag:String, objTag:String):Null<FlxBasic> {
			var obj:Dynamic = getObject(objTag);
			if (obj == null) {
				luaTrace('Couldnt find object: ' + objTag);
				return null;
			}
			cancelTween(tweenTag);
			return obj;
		}
		inline function getTweenCompleteCallback(tag:String) {
			return function(twn:FlxTween) {
				PlayState.instance.callOnLuas('onTweenCompleted', [tag]);
				PlayState.instance.modchartTweens.remove(tag);
			}
		}
		inline function getTweenOptions(tweenTag:String, ease:String):flixel.tweens.TweenOptions {
			return {
				ease: getFlxEaseByString(ease),
				onComplete: getTweenCompleteCallback(tweenTag),
			}
		}
		addCallback("doTweenX", function(tweenTag:String, objTag:String, value:Dynamic, duration:Float, ease:String) {
			var penisExam:Dynamic = penisExam(tweenTag, objTag);
			if (penisExam == null) return;
			PlayState.instance.modchartTweens.set(tweenTag, FlxTween.tween(penisExam, {x: value}, duration, getTweenOptions(tweenTag, ease)));
		});
		addCallback("doTweenY", function(tweenTag:String, objTag:String, value:Dynamic, duration:Float, ease:String) {
			var penisExam:Dynamic = penisExam(tweenTag, objTag);
			if (penisExam == null) return;
			PlayState.instance.modchartTweens.set(tweenTag, FlxTween.tween(penisExam, {y: value}, duration, getTweenOptions(tweenTag, ease)));
		});
		addCallback("doTweenAngle", function(tweenTag:String, objTag:String, value:Dynamic, duration:Float, ease:String) {
			var penisExam:Dynamic = penisExam(tweenTag, objTag);
			if (penisExam == null) return;
			PlayState.instance.modchartTweens.set(tweenTag, FlxTween.tween(penisExam, {angle: value}, duration, getTweenOptions(tweenTag, ease)));
		});
		addCallback("doTweenAlpha", function(tweenTag:String, objTag:String, value:Dynamic, duration:Float, ease:String) {
			var penisExam:Dynamic = penisExam(tweenTag, objTag);
			if (penisExam == null) return;
			PlayState.instance.modchartTweens.set(tweenTag, FlxTween.tween(penisExam, {alpha: value}, duration, getTweenOptions(tweenTag, ease)));
		});
		addCallback("doTweenZoom", function(tweenTag:String, objTag:String, value:Dynamic, duration:Float, ease:String) {
			var penisExam:Dynamic = penisExam(tweenTag, objTag);
			if (penisExam == null) return;
			PlayState.instance.modchartTweens.set(tweenTag, FlxTween.tween(penisExam, {zoom: value}, duration, getTweenOptions(tweenTag, ease)));
		});
		addCallback("doTweenColor", function(tweenTag:String, objTag:String, targetColor:String, duration:Float, ease:String) {
			var penisExam:Dynamic = penisExam(tweenTag, objTag);
			if (penisExam == null) return;
			var color:Int = FlxColor.fromString(targetColor);
			var curColor:FlxColor = penisExam.color;
			curColor.alphaFloat = penisExam.alpha;
			PlayState.instance.modchartTweens.set(tweenTag, FlxTween.color(penisExam, duration, curColor, color, getTweenOptions(tweenTag, ease)));
		});

		//Tween shit, but for strums
		addCallback("noteTweenX", function(tag:String, note:Int, value:Dynamic, duration:Float, ease:String) {
			trace("broken");
		});
		addCallback("noteTweenY", function(tag:String, note:Int, value:Dynamic, duration:Float, ease:String) {
			trace("broken");
		});
		addCallback("noteTweenDirection", function(tag:String, note:Int, value:Dynamic, duration:Float, ease:String) {
			trace("broken");
		});
		addCallback("noteTweenAngle", function(tag:String, note:Int, value:Dynamic, duration:Float, ease:String) {
			trace("broken");
		});
		addCallback("noteTweenAlpha", function(tag:String, note:Int, value:Dynamic, duration:Float, ease:String) {
			trace("broken");
		});

		addCallback("mouseClicked", getMouseClicked);
		addCallback("mousePressed", getMousePressed);
		addCallback("mouseReleased", getMouseReleased);

		addCallback("cancelTween", cancelTween);

		addCallback("runTimer", function(tag:String, time:Float = 1, loops:Int = 1) {
			cancelTimer(tag);
			PlayState.instance.modchartTimers.set(tag, new FlxTimer().start(time, function(tmr:FlxTimer) {
				if(tmr.finished) {
					PlayState.instance.modchartTimers.remove(tag);
				}
				PlayState.instance.callOnLuas('onTimerCompleted', [tag, tmr.loops, tmr.loopsLeft]);
				//trace('Timer Completed: ' + tag);
			}, loops));
		});
		addCallback("cancelTimer", function(tag:String) {
			cancelTimer(tag);
		});

		//stupid bietch ass functions
		addCallback("addScore", function(value:Int = 0) {
			PlayState.instance.stats.score += value;
			PlayState.instance.RecalculateRating();
		});
		addCallback("addMisses", function(value:Int = 0) {
			PlayState.instance.songMisses += value;
			PlayState.instance.RecalculateRating();
		});
		addCallback("addHits", function(value:Int = 0) {
			PlayState.instance.songHits += value;
			PlayState.instance.RecalculateRating();
		});
		addCallback("setScore", function(value:Int = 0) {
			PlayState.instance.songScore = value;
			PlayState.instance.RecalculateRating();
		});
		addCallback("setMisses", function(value:Int = 0) {
			PlayState.instance.songMisses = value;
			PlayState.instance.RecalculateRating();
		});
		addCallback("setHits", function(value:Int = 0) {
			PlayState.instance.songHits = value;
			PlayState.instance.RecalculateRating();
		});
		addCallback("getScore", function() {
			return PlayState.instance.songScore;
		});
		addCallback("getMisses", function() {
			return PlayState.instance.songMisses;
		});
		addCallback("getHits", function() {
			return PlayState.instance.songHits;
		});

		addCallback("setHealth", function(value:Float = 0) {
			PlayState.instance.health = value;
		});
		addCallback("addHealth", function(value:Float = 0) {
			PlayState.instance.health += value;
		});
		addCallback("getHealth", function() {
			return PlayState.instance.health;
		});

		addCallback("getColorFromHex", function(color:String) {
			if(!color.startsWith('0x')) color = '0xff' + color;
			return Std.parseInt(color);
		});
		addCallback("keyJustPressed", function(name:String) {
			var key:Bool = false;
			switch(name) {
				case 'left': key = PlayState.instance.getControl('NOTE_LEFT_P');
				case 'down': key = PlayState.instance.getControl('NOTE_DOWN_P');
				case 'up': key = PlayState.instance.getControl('NOTE_UP_P');
				case 'right': key = PlayState.instance.getControl('NOTE_RIGHT_P');
				case 'accept': key = PlayState.instance.getControl('ACCEPT');
				case 'back': key = PlayState.instance.getControl('BACK');
				case 'pause': key = PlayState.instance.getControl('PAUSE');
				case 'reset': key = PlayState.instance.getControl('RESET');
				case 'space': key = FlxG.keys.justPressed.SPACE;//an extra key for convinience
			}
			return key;
		});
		addCallback("keyPressed", function(name:String) {
			var key:Bool = false;
			switch(name) {
				case 'left': key = PlayState.instance.getControl('NOTE_LEFT');
				case 'down': key = PlayState.instance.getControl('NOTE_DOWN');
				case 'up': key = PlayState.instance.getControl('NOTE_UP');
				case 'right': key = PlayState.instance.getControl('NOTE_RIGHT');
				case 'space': key = FlxG.keys.pressed.SPACE;//an extra key for convinience
			}
			return key;
		});
		addCallback("keyReleased", function(name:String) {
			var key:Bool = false;
			switch(name) {
				case 'left': key = PlayState.instance.getControl('NOTE_LEFT_R');
				case 'down': key = PlayState.instance.getControl('NOTE_DOWN_R');
				case 'up': key = PlayState.instance.getControl('NOTE_UP_R');
				case 'right': key = PlayState.instance.getControl('NOTE_RIGHT_R');
				case 'space': key = FlxG.keys.justReleased.SPACE;//an extra key for convinience
			}
			return key;
		});
		addCallback("addCharacterToList", function(name:String, type:String) {
			try {
				var charType:CharacterType = CharacterType.fromString(type);
				PlayState.instance.addCharacterToList(name, charType);
			}catch(e:Dynamic){
				trace(e);
			}

		});
		addCallback("precacheImage", function(name:String) {
			Paths.image(name);
		});
		addCallback("precacheSound", function(name:String) {
			CoolUtil.precacheSound(name);
		});
		addCallback("precacheMusic", function(name:String) {
			CoolUtil.precacheMusic(name);
		});
		addCallback("triggerEvent", function(name:String, arg1:Dynamic, arg2:Dynamic) {
			PlayState.instance.triggerEventNote(name, Std.string(arg1), Std.string(arg2));
			//trace('Triggered event: ' + name + ', ' + value1 + ', ' + value2);
		});

		addCallback("startCountdown", function(){
			PlayState.instance.startCountdown();
			return true;
		});
		addCallback("endSong", function() {
			PlayState.instance.KillNotes();
			PlayState.instance.endSong();
			return true;
		});
		addCallback("restartSong", function(?skipTransition:Bool = false) {
			PlayState.instance.restartSong(skipTransition);
			return true;
		});
		addCallback("exitSong", function(?skipTransition:Bool = false) {
			if (skipTransition) {
				FlxTransitionableState.skipNextTransIn = true;
				FlxTransitionableState.skipNextTransOut = true;
			}

			if (PlayState.isStoryMode)
				MusicBeatState.switchState(new StoryMenuState());
			else
				MusicBeatState.switchState(new FreeplayState());

			MusicBeatState.playMenuMusic(true);
			
			PlayState.chartingMode = false;
			PlayState.instance.transitioning = true;
			return true;
		});
		addCallback("getSongPosition", function() {
			return Conductor.songPosition;
		});

		addCallback("getCharacterX", function(type:String) {
			switch(type.toLowerCase()) {
				case 'dad' | 'opponent':
					return PlayState.instance.dadGroup.x;
				case 'gf' | 'girlfriend':
					return PlayState.instance.gfGroup.x;
				default:
					return PlayState.instance.boyfriendGroup.x;
			}
		});
		addCallback("setCharacterX", function(type:String, value:Float) {
			switch(type.toLowerCase()) {
				case 'dad' | 'opponent':
					PlayState.instance.dadGroup.x = value;
				case 'gf' | 'girlfriend':
					PlayState.instance.gfGroup.x = value;
				default:
					PlayState.instance.boyfriendGroup.x = value;
			}
		});
		addCallback("getCharacterY", function(type:String) {
			switch(type.toLowerCase()) {
				case 'dad' | 'opponent':
					return PlayState.instance.dadGroup.y;
				case 'gf' | 'girlfriend':
					return PlayState.instance.gfGroup.y;
				default:
					return PlayState.instance.boyfriendGroup.y;
			}
		});
		addCallback("setCharacterY", function(type:String, value:Float) {
			switch(type.toLowerCase()) {
				case 'dad' | 'opponent':
					PlayState.instance.dadGroup.y = value;
				case 'gf' | 'girlfriend':
					PlayState.instance.gfGroup.y = value;
				default:
					PlayState.instance.boyfriendGroup.y = value;
			}
		});

		addCallback("cameraSetTarget", function(target:String) {
			var isDad:Bool = target == 'dad';
			PlayState.instance.moveCamera(isDad ? PlayState.instance.dad : PlayState.instance.boyfriend);
			return isDad;
		});

		addCallback("cameraShake", function(camera:String, intensity:Float, duration:Float) {
			cameraFromString(camera).shake(intensity, duration);
		});
		addCallback("cameraFlash", function(camera:String, color:String, duration:Float,forced:Bool) {
			cameraFromString(camera).flash(FlxColor.fromString(color), duration, null, forced);
		});
		addCallback("cameraFade", function(camera:String, color:String, duration:Float,forced:Bool) {	
			cameraFromString(camera).fade(FlxColor.fromString(color), duration, false, null, forced);
		});

		addCallback("setRatingPercent", function(value:Float) {
			PlayState.instance.ratingPercent = value;
		});
		addCallback("setRatingName", function(value:String) {
			PlayState.instance.stats.grade = value; // TODO: Maybe some sort of stats.overrideGrade thing??
		});
		addCallback("setRatingFC", function(value:String) {
			PlayState.instance.ratingFC = value;
		});
		addCallback("getMouseX", function(camera:String) {
			var cam:FlxCamera = cameraFromString(camera);
			return FlxG.mouse.getScreenPosition(cam).x;
		});
		addCallback("getMouseY", function(camera:String) {
			var cam:FlxCamera = cameraFromString(camera);
			return FlxG.mouse.getScreenPosition(cam).y;
		});

		addCallback("getMidpointX", function(variable:String) {
			var obj:FlxSprite = getObject(variable);
			if (obj == null) return 0.0;
			return obj.getMidpoint().x;
		});
		addCallback("getMidpointY", function(variable:String) {
			var obj:FlxSprite = getObject(variable);
			if (obj == null) return 0.0;
			return obj.getMidpoint().y;
		});
		addCallback("getGraphicMidpointX", function(variable:String) {
			var obj:FlxSprite = getObject(variable);
			if (obj == null) return 0.0;
			return obj.getGraphicMidpoint().x;
		});
		addCallback("getGraphicMidpointY", function(variable:String) {
			var obj:FlxSprite = getObject(variable);
			if (obj == null) return 0.0;
			return obj.getGraphicMidpoint().y;
		});
		addCallback("getScreenPositionX", function(variable:String) {
			var obj:FlxSprite = getObject(variable);
			if (obj == null) return 0.0;
			return obj.getScreenPosition().x;
		});
		addCallback("getScreenPositionY", function(variable:String) {
			var obj:FlxSprite = getObject(variable);
			if (obj == null) return 0.0;
			return obj.getScreenPosition().y;
		});
		addCallback("characterPlayAnim", function(character:String, anim:String, ?forced:Bool = false) {
			var character = PlayState.instance.getCharacterFromString(character);
			if (character != null && character.animOffsets.exists(anim)) {
				character.playAnim(anim, forced);
			}
		});
		addCallback("characterDance", function(character:String) {
			var character = PlayState.instance.getCharacterFromString(character);
			if (character != null)
				character.dance();
		});

		addCallback("makeLuaSprite", function(tag:String, image:String, ?x:Float, ?y:Float) {
			tag = tag.replace('.', '');
			resetSpriteTag(tag);
			var leSprite:ModchartSprite = new ModchartSprite(x, y);
			if(image != null && image.length > 0)
			{
				leSprite.loadGraphic(Paths.image(image));
			}
			PlayState.instance.modchartSprites.set(tag, leSprite);
			leSprite.active = true;
		});
		addCallback("makeAnimatedLuaSprite", function(tag:String, image:String, x:Float, y:Float, ?spriteType:String = "sparrow") {
			tag = tag.replace('.', '');
			resetSpriteTag(tag);
			var leSprite:ModchartSprite = new ModchartSprite(x, y);

			loadFrames(leSprite, image, spriteType);
			PlayState.instance.modchartSprites.set(tag, leSprite);
		});

		addCallback("makeGraphic", function(obj:String, width:Int, height:Int, color:String) {
			var colorNum:Int = Std.parseInt(color);
			if(!color.startsWith('0x')) colorNum = Std.parseInt('0xff' + color);

			var object:FlxSprite = getObjectSimple(obj);
			if(object != null) {
				object.makeGraphic(width, height, colorNum);
			}
		});
		addCallback("addAnimationByPrefix", function(obj:String, name:String, prefix:String, framerate:Int = 24, loop:Bool = true) {
			var cock:FlxSprite = getObjectSimple(obj);
			if(cock != null) {
				cock.animation.addByPrefix(name, prefix, framerate, loop);
				if(cock.animation.curAnim == null) {
					cock.animation.play(name, true);
				}
			}
		});

		addCallback("addAnimation", function(obj:String, name:String, frames:Array<Int>, framerate:Int = 24, loop:Bool = true) {
			var cock:FlxSprite = getObjectSimple(obj);
			if(cock != null) {
				cock.animation.add(name, frames, framerate, loop);
				if(cock.animation.curAnim == null) {
					cock.animation.play(name, true);
				}
			}
		});

		addCallback("addAnimationByIndices", function(obj:String, name:String, prefix:String, indices:String, framerate:Int = 24) {
			var pussy:FlxSprite = getObjectSimple(obj);
			if(pussy != null) {
				var die:Array<Int> = parseIntArray(indices);
				pussy.animation.addByIndices(name, prefix, die, '', framerate, false);
				if(pussy.animation.curAnim == null) {
					pussy.animation.play(name, true);
				}
			}
		});
		
		addCallback("playAnim", function(obj:String, name:String, forced:Bool = false, ?reverse:Bool = false, ?startFrame:Int = 0)
		{
			var spr:FlxSprite = getObjectDirectly(obj);
			if (spr != null)
			{
				if(spr.animation.exists(name))
				{
					if(Std.isOfType(spr, ModchartSprite))
					{
						var luaObj:ModchartSprite = cast spr;
						luaObj.animation.play(name, forced, reverse, startFrame);
						
						if (luaObj.animOffsets.exists(name))
						{
							var daOffset = luaObj.animOffsets.get(name);
							luaObj.offset.set(daOffset[0], daOffset[1]);
						}
					}
					else if(Std.isOfType(spr, Character))
					{
						var spr:Character = cast spr;
						spr.playAnim(name, forced, reverse, startFrame);
					}
					else
						spr.animation.play(name, forced, reverse, startFrame);
				}
				return true;
			}
			return false;
		});
		addCallback("addOffset", function(obj:String, anim:String, x:Float, y:Float) {
			if(PlayState.instance.modchartSprites.exists(obj)) {
				PlayState.instance.modchartSprites.get(obj).animOffsets.set(anim, [x, y]);
				return true;
			}

			var char:Character = Reflect.getProperty(getInstance(), obj);
			if(char != null) {
				char.addOffset(anim, x, y);
				return true;
			}
			return false;
		});

		addCallback("objectPlayAnimation", function(obj:String, name:String, forced:Bool = false, ?startFrame:Int = 0) {
			luaTrace("objectPlayAnimation is deprecated! Use playAnim instead", false, true);

			var spr:FlxSprite = getObjectSimple(obj);
			if(spr != null) {
				spr.animation.play(name, forced, startFrame);
			}
		});

		addCallback("objectPlayAnim",  function(obj:String, name:String, forced:Bool = false, ?startFrame:Int = 0) { // some psych mods use this but i cant find it any official psych code
			// weird
			luaTrace("objectPlayAnim is deprecated! Use playAnim instead", false, true);

			var spr:FlxSprite = getObjectSimple(obj);
			if(spr != null) {
				spr.animation.play(name, forced, startFrame);
			}
		});

		addCallback("setScrollFactor", function(obj:String, scrollX:Float, scrollY:Float) {
			var object:FlxObject = getObjectSimple(obj);
			if(object != null) {
				object.scrollFactor.set(scrollX, scrollY);
			}
		});
		addCallback("addLuaSprite", function(tag:String, front:Bool = false) {
			if (!PlayState.instance.modchartSprites.exists(tag))
				return;

			var spr:ModchartSprite = PlayState.instance.modchartSprites.get(tag);
			if(spr.wasAdded)
				return;

			var instance:FlxState = getInstance();

			if (front){
				instance.add(spr);			
			}else if (instance is GameOverSubstate){
				var instance:GameOverSubstate = cast instance; // fucking haxe
				instance.insert(instance.members.indexOf(instance.boyfriend), spr);
			}else if (instance is PlayState){
				var instance:PlayState = cast instance; // fucking haxe
				
				var position:Int = instance.members.indexOf(instance.gfGroup);
				position = FlxMath.minInt(position, instance.members.indexOf(instance.boyfriendGroup));
				position = FlxMath.minInt(position, instance.members.indexOf(instance.dadGroup));

				if (position == -1)
					instance.add(spr);
				else
					instance.insert(position, spr);
			}else{
				instance.add(spr);
			}
			
			spr.wasAdded = true;	
		});
		addCallback("setGraphicSize", function(obj:String, x:Int, y:Int = 0, updateHitbox:Bool = true) {
			var poop:FlxSprite = getObjectSimple(obj);

			if (poop != null) {
				luaTrace('Couldnt find object: ' + obj);
				return;
			}
			
			poop.setGraphicSize(x, y);
			if(updateHitbox) poop.updateHitbox();
		});
		addCallback("scaleObject", function(obj:String, x:Float, y:Float, updateHitbox:Bool = true) {
			var poop:FlxSprite = getObjectSimple(obj);

			if (poop == null) {
				luaTrace('Couldnt find object: ' + obj);
				return;
			}

			poop.scale.set(x, y);
			if(updateHitbox) poop.updateHitbox();
		});
		addCallback("updateHitbox", function(tag:String) {
			var obj:FlxSprite = getObjectSimple(tag);

			if (obj == null) {
				luaTrace('Couldnt find object: ' + obj);
				return;
			}

			obj.updateHitbox();
		});
		addCallback("updateHitboxFromGroup", function(group:String, index:Int) {
			var group:Dynamic = Reflect.getProperty(getInstance(), group);
			if (Std.isOfType(group, FlxTypedGroup))
				group.members[index].updateHitbox();
			else
				group[index].updateHitbox();
		});

		addCallback("isNoteChild", function(parentID:Int, childID:Int){
			var parent: Note = cast getLuaObject('note${parentID}',false);
			var child: Note = cast getLuaObject('note${childID}',false);
			if (parent==null || child==null) {
				luaTrace('${parentID} or ${childID} is not a valid note ID');
				return false;
			}

			return parent.tail.contains(child);
		});

		addCallback("removeLuaSprite", function(tag:String, destroy:Bool = true) {
			if(!PlayState.instance.modchartSprites.exists(tag)) {
				return;
			}

			var pee:ModchartSprite = PlayState.instance.modchartSprites.get(tag);
			if(destroy) {
				pee.kill();
			}

			if(pee.wasAdded) {
				getInstance().remove(pee, true);
				pee.wasAdded = false;
			}

			if(destroy) {
				pee.destroy();
				PlayState.instance.modchartSprites.remove(tag);
			}
		});

		addCallback("setObjectCamera", function(obj:String, camera:String = '') {
			var object:FlxSprite = getObject(obj);

			if(object == null) {
				luaTrace("Object " + obj + " doesn't exist!");
				return false;
			}

			object.cameras = [cameraFromString(camera)];
			return true;
		});
		addCallback("setBlendMode", function(obj:String, blend:String = '') {
			var spr:FlxSprite = getObject(obj);

			if (spr == null) {
				luaTrace("Object " + obj + " doesn't exist!");
				return false;
			}

			spr.blend = blendModeFromString(blend);
			return true;
		});
		addCallback("screenCenter", function(obj:String, pos:String = 'xy') {
			var spr:FlxSprite = getObject(obj);

			if (spr == null) {
				luaTrace("Object " + obj + " doesn't exist!");
				return;
			}

			switch(pos.trim().toLowerCase()) {
				case 'x': spr.screenCenter(X);
				case 'y': spr.screenCenter(Y);
				default: spr.screenCenter(XY);						
			}
		});
		addCallback("objectsOverlap", function(tag1:String, tag2:String) {
			var obj1 = getObjectSimple(tag1);
			var obj2 = getObjectSimple(tag2);
			return (obj1 != null) && (obj2 != null) && FlxG.overlap(obj1, obj2);
		});
		addCallback("getPixelColor", function(obj:String, x:Int, y:Int) {
			var spr:FlxSprite = getObject(obj);
			return (spr == null) ? 0 : (spr.framePixels ?? spr.pixels).getPixel32(x, y);
		});
		addCallback("getRandomInt", function(min:Int, max:Int = FlxMath.MAX_VALUE_INT, exclude:String = '') {
			return FlxG.random.int(min, max, parseIntArray(exclude));
		});
		addCallback("getRandomFloat", function(min:Float, max:Float = 1, exclude:String = '') {
			return FlxG.random.float(min, max, parseFloatArray(exclude));
		});
		addCallback("getRandomBool", function(chance:Float = 50) {
			return FlxG.random.bool(chance);
		});
		
		addCallback("startDialogue", function(dialogueFile:String, music:String = null) {
			new FlxTimer().start(0.2, (tmr:FlxTimer) -> {
				if(PlayState.instance.endingSong) {
					PlayState.instance.endSong();
				} else {
					PlayState.instance.startCountdown();
				}
			});
		});
		
		addCallback("startVideo", function(videoFile:String) {
			#if VIDEOS_ALLOWED
			if (Paths.exists(Paths.video(videoFile))) {
				PlayState.instance.startVideo(videoFile);
			} else {
				luaTrace('Video file not found: ' + videoFile);
			}
			#else
			if(PlayState.instance.endingSong) {
				PlayState.instance.endSong();
			} else {
				PlayState.instance.startCountdown();
			}
			#end
		});

		addCallback("playMusic", function(sound:String, volume:Float = 1, loop:Bool = false) {
			FlxG.sound.playMusic(Paths.music(sound), volume , loop);
		});
		addCallback("playSound", function(sound:String, volume:Float = 1, ?tag:String = null) {
			if(tag != null && tag.length > 0) {
				tag = tag.replace('.', '');
				if(PlayState.instance.modchartSounds.exists(tag)) {
					PlayState.instance.modchartSounds.get(tag).stop();
				}
				PlayState.instance.modchartSounds.set(tag, FlxG.sound.play(Paths.sound(sound), volume , false, function() {
					PlayState.instance.modchartSounds.remove(tag);
					PlayState.instance.callOnLuas('onSoundFinished', [tag]);
				}));
				return;
			}
			FlxG.sound.play(Paths.sound(sound), volume );
		});
		addCallback("stopSound", function(tag:String) {
			if(tag != null && tag.length > 1 && PlayState.instance.modchartSounds.exists(tag)) {
				PlayState.instance.modchartSounds.get(tag).stop();
				PlayState.instance.modchartSounds.remove(tag);
			}
		});
		addCallback("pauseSound", function(tag:String) {
			if(tag != null && tag.length > 1 && PlayState.instance.modchartSounds.exists(tag)) {
				PlayState.instance.modchartSounds.get(tag).pause();
			}
		});
		addCallback("resumeSound", function(tag:String) {
			if(tag != null && tag.length > 1 && PlayState.instance.modchartSounds.exists(tag)) {
				PlayState.instance.modchartSounds.get(tag).play();
			}
		});
		addCallback("soundFadeIn", function(tag:String, duration:Float, fromValue:Float = 0, toValue:Float = 1) {
			if(tag == null || tag.length < 1) {
				FlxG.sound.music.fadeIn(duration, fromValue, toValue);
			} else if(PlayState.instance.modchartSounds.exists(tag)) {
				PlayState.instance.modchartSounds.get(tag).fadeIn(duration, fromValue, toValue);
			}

		});
		addCallback("soundFadeOut", function(tag:String, duration:Float, toValue:Float = 0) {
			if(tag == null || tag.length < 1) {
				FlxG.sound.music.fadeOut(duration, toValue);
			} else if(PlayState.instance.modchartSounds.exists(tag)) {
				PlayState.instance.modchartSounds.get(tag).fadeOut(duration, toValue);
			}
		});
		addCallback("soundFadeCancel", function(tag:String) {
			if(tag == null || tag.length < 1) {
				if(FlxG.sound.music.fadeTween != null) {
					FlxG.sound.music.fadeTween.cancel();
				}
			} else if(PlayState.instance.modchartSounds.exists(tag)) {
				var theSound:FlxSound = PlayState.instance.modchartSounds.get(tag);
				if(theSound.fadeTween != null) {
					theSound.fadeTween.cancel();
					PlayState.instance.modchartSounds.remove(tag);
				}
			}
		});
		addCallback("getSoundVolume", function(tag:String) {
			if(tag == null || tag.length < 1) {
				if(FlxG.sound.music != null) {
					return FlxG.sound.music.volume;
				}
			} else if(PlayState.instance.modchartSounds.exists(tag)) {
				return PlayState.instance.modchartSounds.get(tag).volume;
			}
			return 0;
		});
		addCallback("setSoundVolume", function(tag:String, value:Float) {
			if(tag == null || tag.length < 1) {
				if(FlxG.sound.music != null) {
					FlxG.sound.music.volume = value;
				}
			} else if(PlayState.instance.modchartSounds.exists(tag)) {
				PlayState.instance.modchartSounds.get(tag).volume = value;
			}
		});
		addCallback("getSoundTime", function(tag:String) {
			if(tag != null && tag.length > 0 && PlayState.instance.modchartSounds.exists(tag)) {
				return PlayState.instance.modchartSounds.get(tag).time;
			}
			return 0;
		});
		addCallback("setSoundTime", function(tag:String, value:Float) {
			if(tag != null && tag.length > 0 && PlayState.instance.modchartSounds.exists(tag)) {
				var theSound:FlxSound = PlayState.instance.modchartSounds.get(tag);
				if(theSound != null) {
					var wasResumed:Bool = theSound.playing;
					theSound.pause();
					theSound.time = value;
					if(wasResumed) theSound.play();
				}
			}
		});
		
		#if DISCORD_ALLOWED
		addCallback("changePresence", DiscordClient.changePresence);
		#end

		// LUA TEXTS
		addCallback("makeLuaText", function(tag:String, text:String, width:Int, x:Float, y:Float) {
			tag = tag.replace('.', '');
			resetTextTag(tag);
			var leText:ModchartText = new ModchartText(x, y, text, width);
			PlayState.instance.modchartTexts.set(tag, leText);
		});

		addCallback("setTextString", function(tag:String, text:String) {
			var obj:FlxText = getTextObject(tag);
			if(obj != null)
			{
				obj.text = text;
			}
		});
		addCallback("setTextSize", function(tag:String, size:Int) {
			var obj:FlxText = getTextObject(tag);
			if(obj != null)
			{
				obj.size = size;
			}
		});
		addCallback("setTextWidth", function(tag:String, width:Float) {
			var obj:FlxText = getTextObject(tag);
			if(obj != null)
			{
				obj.fieldWidth = width;
			}
		});
		addCallback("setTextBorder", function(tag:String, size:Int, color:String) {
			var obj:FlxText = getTextObject(tag);
			if(obj != null)
			{
				obj.borderSize = size;
				obj.borderColor = FlxColor.fromString(color);
			}
		});
		addCallback("setTextColor", function(tag:String, color:String) {
			var obj:FlxText = getTextObject(tag);

			if(obj != null)
			{
				obj.color = FlxColor.fromString(color);
			}
		});
		addCallback("setTextFont", function(tag:String, newFont:String) {
			var obj:FlxText = getTextObject(tag);
			if(obj != null)
			{
				obj.font = Paths.font(newFont);
			}
		});
		addCallback("setTextItalic", function(tag:String, italic:Bool) {
			var obj:FlxText = getTextObject(tag);
			if(obj != null)
			{
				obj.italic = italic;
			}
		});
		addCallback("setTextAlignment", function(tag:String, alignment:String = 'left') {
			var obj:FlxText = getTextObject(tag);
			if(obj != null)
			{
				obj.alignment = LEFT;
				switch(alignment.trim().toLowerCase())
				{
					case 'right':
						obj.alignment = RIGHT;
					case 'center':
						obj.alignment = CENTER;
				}
			}
		});

		addCallback("getTextString", function(tag:String) {
			var obj:FlxText = getTextObject(tag);
			if(obj != null)
			{
				return obj.text;
			}
			return null;
		});
		addCallback("getTextSize", function(tag:String) {
			var obj:FlxText = getTextObject(tag);
			if(obj != null)
			{
				return obj.size;
			}
			return -1;
		});
		addCallback("getTextFont", function(tag:String) {
			var obj:FlxText = getTextObject(tag);
			if(obj != null)
			{
				return obj.font;
			}
			return null;
		});
		addCallback("getTextWidth", function(tag:String) {
			var obj:FlxText = getTextObject(tag);
			if(obj != null)
			{
				return obj.fieldWidth;
			}
			return 0;
		});

		addCallback("addLuaText", function(tag:String) {
			if(PlayState.instance.modchartTexts.exists(tag)) {
				var shit:ModchartText = PlayState.instance.modchartTexts.get(tag);
				if(!shit.wasAdded) {
					getInstance().add(shit);
					shit.wasAdded = true;
					//trace('added a thing: ' + tag);
				}
			}
		});
		addCallback("removeLuaText", function(tag:String, destroy:Bool = true) {
			if(!PlayState.instance.modchartTexts.exists(tag)) {
				return;
			}

			var pee:ModchartText = PlayState.instance.modchartTexts.get(tag);
			if(destroy) {
				pee.kill();
			}

			if(pee.wasAdded) {
				getInstance().remove(pee, true);
				pee.wasAdded = false;
			}

			if(destroy) {
				pee.destroy();
				PlayState.instance.modchartTexts.remove(tag);
			}
		});

		addCallback("initSaveData", function(name:String, ?folder:String = 'psychenginemods') {
			if(!PlayState.instance.modchartSaves.exists(name))
			{
				var save:FlxSave = new FlxSave();
				save.bind(name, folder);
				PlayState.instance.modchartSaves.set(name, save);
				return;
			}
			luaTrace('Save file already initialized: ' + name);
		});
		addCallback("flushSaveData", function(name:String) {
			if(PlayState.instance.modchartSaves.exists(name))
			{
				PlayState.instance.modchartSaves.get(name).flush();
				return;
			}
			luaTrace('Save file not initialized: ' + name);
		});
		addCallback("getDataFromSave", function(name:String, field:String) {
			if(PlayState.instance.modchartSaves.exists(name))
			{
				var retVal:Dynamic = Reflect.field(PlayState.instance.modchartSaves.get(name).data, field);
				return retVal;
			}
			luaTrace('Save file not initialized: ' + name);
			return null;
		});
		addCallback("setDataFromSave", function(name:String, field:String, value:Dynamic) {
			if(PlayState.instance.modchartSaves.exists(name))
			{
				Reflect.setField(PlayState.instance.modchartSaves.get(name).data, field, value);
				return;
			}
			luaTrace('Save file not initialized: ' + name);
		});

		addCallback("getTextFromFile", function(path:String, ?ignoreModFolders:Bool = false) {
			return Paths.text(path, ignoreModFolders);
		});

		// DEPRECATED, DONT MESS WITH THESE SHITS, ITS JUST THERE FOR BACKWARD COMPATIBILITY
		addCallback("luaSpriteMakeGraphic", function(tag:String, width:Int, height:Int, color:String) {
			luaTrace("luaSpriteMakeGraphic is deprecated! Use makeGraphic instead", false, true);
			if(PlayState.instance.modchartSprites.exists(tag)) {
				var colorNum:Int = Std.parseInt(color);
				if(!color.startsWith('0x')) colorNum = Std.parseInt('0xff' + color);

				PlayState.instance.modchartSprites.get(tag).makeGraphic(width, height, colorNum);
			}
		});
		addCallback("luaSpriteAddAnimationByPrefix", function(tag:String, name:String, prefix:String, framerate:Int = 24, loop:Bool = true) {
			luaTrace("luaSpriteAddAnimationByPrefix is deprecated! Use addAnimationByPrefix instead", false, true);
			if(PlayState.instance.modchartSprites.exists(tag)) {
				var cock:ModchartSprite = PlayState.instance.modchartSprites.get(tag);
				cock.animation.addByPrefix(name, prefix, framerate, loop);
				if(cock.animation.curAnim == null) {
					cock.animation.play(name, true);
				}
			}
		});
		addCallback("luaSpriteAddAnimationByIndices", function(tag:String, name:String, prefix:String, indices:String, framerate:Int = 24) {
			luaTrace("luaSpriteAddAnimationByIndices is deprecated! Use addAnimationByIndices instead", false, true);
			if(PlayState.instance.modchartSprites.exists(tag)) {
				var die:Array<Int> = parseIntArray(indices);
				var pussy:ModchartSprite = PlayState.instance.modchartSprites.get(tag);
				pussy.animation.addByIndices(name, prefix, die, '', framerate, false);
				if(pussy.animation.curAnim == null) {
					pussy.animation.play(name, true);
				}
			}
		});
		addCallback("luaSpritePlayAnimation", function(tag:String, name:String, forced:Bool = false) {
			luaTrace("luaSpritePlayAnimation is deprecated! Use objectPlayAnimation instead", false, true);
			if(PlayState.instance.modchartSprites.exists(tag)) {
				PlayState.instance.modchartSprites.get(tag).animation.play(name, forced);
			}
		});
		addCallback("setLuaSpriteCamera", function(tag:String, camera:String = '') {
			luaTrace("setLuaSpriteCamera is deprecated! Use setObjectCamera instead", false, true);
			if(PlayState.instance.modchartSprites.exists(tag)) {
				PlayState.instance.modchartSprites.get(tag).cameras = [cameraFromString(camera)];
				return true;
			}
			luaTrace("Lua sprite with tag: " + tag + " doesn't exist!");
			return false;
		});
		addCallback("setLuaSpriteScrollFactor", function(tag:String, scrollX:Float, scrollY:Float) {
			luaTrace("setLuaSpriteScrollFactor is deprecated! Use setScrollFactor instead", false, true);
			if(PlayState.instance.modchartSprites.exists(tag)) {
				PlayState.instance.modchartSprites.get(tag).scrollFactor.set(scrollX, scrollY);
			}
		});
		addCallback("scaleLuaSprite", function(tag:String, x:Float, y:Float) {
			luaTrace("scaleLuaSprite is deprecated! Use scaleObject instead", false, true);
			if(PlayState.instance.modchartSprites.exists(tag)) {
				var shit:ModchartSprite = PlayState.instance.modchartSprites.get(tag);
				shit.scale.set(x, y);
				shit.updateHitbox();
			}
		});
		addCallback("getPropertyLuaSprite", function(tag:String, variable:String) {
			luaTrace("getPropertyLuaSprite is deprecated! Use getProperty instead", false, true);
			if(PlayState.instance.modchartSprites.exists(tag)) {
				var killMe:Array<String> = variable.split('.');
				if(killMe.length > 1) {
					var coverMeInPiss:Dynamic = Reflect.getProperty(PlayState.instance.modchartSprites.get(tag), killMe[0]);
					for (i in 1...killMe.length-1) {
						coverMeInPiss = Reflect.getProperty(coverMeInPiss, killMe[i]);
					}
					return Reflect.getProperty(coverMeInPiss, killMe[killMe.length-1]);
				}
				return Reflect.getProperty(PlayState.instance.modchartSprites.get(tag), variable);
			}
			return null;
		});
		addCallback("setPropertyLuaSprite", function(tag:String, variable:String, value:Dynamic) {
			luaTrace("setPropertyLuaSprite is deprecated! Use setProperty instead", false, true);
			if(PlayState.instance.modchartSprites.exists(tag)) {
				var killMe:Array<String> = variable.split('.');
				if(killMe.length > 1) {
					var coverMeInPiss:Dynamic = Reflect.getProperty(PlayState.instance.modchartSprites.get(tag), killMe[0]);
					for (i in 1...killMe.length-1) {
						coverMeInPiss = Reflect.getProperty(coverMeInPiss, killMe[i]);
					}
					return Reflect.setProperty(coverMeInPiss, killMe[killMe.length-1], value);
				}
				return Reflect.setProperty(PlayState.instance.modchartSprites.get(tag), variable, value);
			}
			luaTrace("Lua sprite with tag: " + tag + " doesn't exist!");
		});
		addCallback("musicFadeIn", function(duration:Float, fromValue:Float = 0, toValue:Float = 1) {
			FlxG.sound.music.fadeIn(duration, fromValue, toValue);
			luaTrace('musicFadeIn is deprecated! Use soundFadeIn instead.', false, true);

		});
		addCallback("musicFadeOut", function(duration:Float, toValue:Float = 0) {
			FlxG.sound.music.fadeOut(duration, toValue);
			luaTrace('musicFadeOut is deprecated! Use soundFadeOut instead.', false, true);
		});

		// Other stuff
		addCallback("stringStartsWith", function(str:String, start:String) {
			return str.startsWith(start);
		});
		addCallback("stringEndsWith", function(str:String, end:String) {
			return str.endsWith(end);
		});
		#end
	}

	public function new(state:State, ?name:String = "Lua", ?ignoreCreateCall:Bool, ?vars:Map<String, Dynamic>) {
		super(name, ScriptType.PSYCH_LUA);

		if (state == null)
			return;

		#if LUA_ALLOWED
		lua = state;
		Lua.init_callbacks(lua);

		setDefaultVars();

		for (variable => arg in defaultVars)
			set(variable, arg);

		if (vars != null){
			for(key => val in vars)
				set(key, val);
		}
		
		if (ignoreCreateCall != true) 
			call('onCreate');
		#end
	}

	#if LUA_ALLOWED
	// private var duplicateErrors:Array<String> = [];

	private function executeFunc(name:String, ?args:Array<Dynamic>):Null<Dynamic>
	{
		Lua.getglobal(lua, name);
		#if (linc_luajit >= "0.0.6")
		if(Lua.isfunction(lua, -1)==true)
		#else
		if(Lua.isfunction(lua, -1)==1)
		#end
		{
			var result:Dynamic;
			if (args != null){
				for (arg in args) Convert.toLua(lua, arg);
				result = Lua.pcall(lua, args.length, 1, 0);
			}else{
				result = Lua.pcall(lua, 0, 1, 0);
			}

			if(result!=0){
				var err = getErrorMessage();

				var args = [for (arg in args){
					(arg is String ? '"$arg"' : Std.string(arg));
				}];
				print('$scriptName: Error on function $name(${args.join(', ')}): $err');
				
				/* just so your output isnt SPAMMED
				if (!duplicateErrors.contains(err)) {
					var args = [for (arg in args){
						(arg is String ? '"$arg"' : Std.string(arg));
					}];
					print('$scriptName: Error on function $func(${args.join(', ')}): $err');
					duplicateErrors.push(err);
					while(duplicateErrors.length > 20)
						duplicateErrors.shift();
				}*/

				return null;
			}else if(result != null){
				var conv:Dynamic = cast Convert.fromLua(lua, -1);
				Lua.pop(lua, 1);
				return conv;
			}
		}

		Lua.pop(lua, 1);
		return null;
	}

	public function luaTrace(text:String, ignoreCheck:Bool = false, deprecated:Bool = false):Void {
		if (ignoreCheck || getBool('luaDebugMode')) {
			if (deprecated && !getBool('luaDeprecatedWarnings'))
				return;
			
			PlayState.instance.addTextToDebug(text);
			print('$scriptName: $text');
		}
	}
	#end

	public function set(name:String, val:Dynamic):Void
	{
		#if LUA_ALLOWED
		if (lua == null)
			return;

		/** Convert.toLua(lua, val); **/
		switch (Type.typeof(val)) {
			case Type.ValueType.TNull:
				Lua.pushnil(lua);
			case Type.ValueType.TBool:
				Lua.pushboolean(lua, val);
			case Type.ValueType.TInt:
				Lua.pushinteger(lua, cast(val, Int));
			case Type.ValueType.TFloat:
				Lua.pushnumber(lua, val);
			case Type.ValueType.TClass(String):
				Lua.pushstring(lua, cast(val, String));
			case Type.ValueType.TClass(Array):
				Convert.arrayToLua(lua, val);
			case Type.ValueType.TObject:
				@:privateAccess Convert.objectToLua(lua, val); // {}
			case Type.ValueType.TFunction:
				addCallback(name, val);
				return;
			default:
				trace('$scriptName: Unsupported value: $val ${Type.typeof(val)}');
				return;
		}
		
		Lua.setglobal(lua, name);
		#end
	}

	public function get(name:String):Dynamic {
		#if LUA_ALLOWED
		if (lua == null)
			return null;
		
		var result:Dynamic = null;
		Lua.getglobal(lua, name);
		result = Convert.fromLua(lua, -1);
		Lua.pop(lua, 1);
		return result;

		#else
		return null;
		#end
	}

	public function call(funcName:String, ?args:Array<Dynamic>, ?extraVars:Map<String,Dynamic>):Dynamic {
		#if LUA_ALLOWED
		if (lua==null) return Function_Continue;
		
		try {
			var ret = executeFunc(funcName, args);
			return ret==null ? Function_Continue : ret;
		}catch(e:Dynamic){
			trace(e);
		}
		#end

		return Function_Continue;
	}

	public function stop():Void {
		#if LUA_ALLOWED
		if (lua == null)
			return;

		Lua.close(lua);
		lua = null;
		#end
	}
}

