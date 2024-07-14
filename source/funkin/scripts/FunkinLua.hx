package funkin.scripts;

#if LUA_ALLOWED
import llua.Convert;
import llua.Lua;
import llua.LuaL;
import llua.State;
#end

import funkin.states.*;
import funkin.states.PlayState;
import funkin.objects.*;
import funkin.scripts.Globals.*;

import Type.ValueType;
import animateatlas.AtlasFrameMaker;
import flixel.*;
import flixel.addons.transition.FlxTransitionableState;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxSave;
import flixel.util.FlxTimer;
import openfl.display.BlendMode;

import funkin.modchart.SubModifier;

#if discord_rpc
import funkin.api.Discord;
#end

using StringTools;

class FunkinLua extends FunkinScript
{
	public static var haxeScript:FunkinHScript;
	public var errorHandler:String->Void;
	#if LUA_ALLOWED
	public var lua:State = null;

	public final addCallback:(String, Dynamic)->Bool;
	public final removeCallback:String->Bool;	
	#end

	public var camTarget:FlxCamera;
	var gonnaClose:Bool = false;

	public function new(script:String, ?name:String, ?ignoreCreateCall:Bool=false, ?vars:Map<String, Dynamic>) {
		#if LUA_ALLOWED
		lua = LuaL.newstate();
		LuaL.openlibs(lua);
		Lua.init_callbacks(lua);
		
		//trace('Lua version: ' + Lua.version());
		//trace("LuaJIT version: " + Lua.versionJIT());
		
		scriptType = 'lua';
		scriptName = name!=null ? name : script;

		// Lua shit
		set('Function_StopLua', Function_Halt); // DEPRECATED
		set('luaDebugMode', false);
		set('luaDeprecatedWarnings', true);
		set('inChartEditor', false);

		// Song/Week shit
		setDefaultVars();
		if (vars != null){
			for(key => val in vars)
				set(key, val);
		}

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

		set("playbackRate", 1.0); // for compatibility, do not give it the actual value.

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

		#if windows
		set('buildTarget', 'windows');
		#elseif linux
		set('buildTarget', 'linux');
		#elseif mac
		set('buildTarget', 'mac');
		#elseif html5
		set('buildTarget', 'browser');
		#elseif android
		set('buildTarget', 'android');
		#else
		set('buildTarget', 'unknown');
		#end

		try
		{
			var result:Dynamic = LuaL.dofile(lua, script);
			var resultStr:String = Lua.tostring(lua, result);
			if (resultStr != null && result != 0)
			{
				trace('Error on lua script! ' + resultStr);
				#if windows
				FlxG.fullscreen = false;
				lime.app.Application.current.window.alert(resultStr, 'Error on lua script!');
				#else
				luaTrace('Error loading lua script: "$script"\n' + resultStr, true, false);
				#end
				lua = null;
				return;
			}
		}
		catch (e:Dynamic)
		{
			trace(e);
			return;
		}

		addCallback = Lua_helper.add_callback.bind(lua);
		removeCallback = Lua_helper.remove_callback.bind(lua);

		////
		addCallback("getProperty", getProperty);
		addCallback("setProperty", setProperty);
		addCallback("getPropertyFromGroup", getPropertyFromGroup);
		addCallback("setPropertyFromGroup", setPropertyFromGroup);
		addCallback("removeFromGroup", removeFromGroup);
		addCallback("getPropertyFromClass", getPropertyFromClass);
		addCallback("setPropertyFromClass", setPropertyFromClass);

		//// mod manager
		addCallback("setPercent", function(modName:String, val:Float, player:Int = -1)
		{
			PlayState.instance.modManager.setPercent(modName, val, player);
		});

		addCallback("addBlankMod", function(modName:String, defaultVal:Float = 0, player:Int = -1)
		{
			PlayState.instance.modManager.quickRegister(new SubModifier(modName, PlayState.instance.modManager));
			PlayState.instance.modManager.setValue(modName, defaultVal);
		});

		addCallback("setValue", function(modName:String, val:Float, player:Int = -1)
		{
			PlayState.instance.modManager.setValue(modName, val, player);
		});

		addCallback("getPercent", function(modName:String, player:Int)
		{
			return PlayState.instance.modManager.getPercent(modName, player);
		});

		addCallback("getValue", function(modName:String, player:Int)
		{
			return PlayState.instance.modManager.getValue(modName, player);
		});
		
		addCallback("queueSet", function(step:Float, modName:String, target:Float, player:Int = -1)
		{
			PlayState.instance.modManager.queueSet(step, modName, target, player);
		});

		addCallback("queueSetP", function(step:Float, modName:String, perc:Float, player:Int = -1)
		{
			PlayState.instance.modManager.queueSetP(step, modName, perc, player);
		});
		
		addCallback("queueEase",
			function(step:Float, endStep:Float, modName:String, percent:Float, style:String = 'linear', player:Int = -1, ?startVal:Float) // lua is autistic and can only accept 5 args
			{
				PlayState.instance.modManager.queueEase(step, endStep, modName, percent, style, player, startVal);
			}
		);

		addCallback("queueEaseP",
			function(step:Float, endStep:Float, modName:String, percent:Float, style:String = 'linear', player:Int = -1, ?startVal:Float) // lua is autistic and can only accept 5 args
			{
				PlayState.instance.modManager.queueEaseP(step, endStep, modName, percent, style, player, startVal);
			}
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

			var cervix = pussyPath(luaFile);
			var doPush = cervix==null;

			if(doPush)
			{
				for (luaInstance in PlayState.instance.luaArray)
				{
					if(luaInstance.scriptName == cervix)
					{
						luaInstance.call(funcName, args);

						return;
					}

				}
			}
			Lua.pushnil(lua);

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

			var cervix = pussyPath(luaFile);
			var doPush = cervix != null;
			
			if (doPush)
			{
				for (luaInstance in PlayState.instance.luaArray)
				{
					if(luaInstance.scriptName == cervix)
					{
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

						return;
					}

				}
			}
			Lua.pushnil(lua);
		});
		addCallback("setGlobalFromScript", function(luaFile:String, global:String, val:Dynamic){ // returns the global from a script
			var cervix = pussyPath(luaFile);
			var doPush = cervix != null;

			if(doPush)
			{
				for (luaInstance in PlayState.instance.luaArray)
				{
					if (luaInstance.scriptName == cervix)
						luaInstance.set(global, val);
				}
			}
			Lua.pushnil(lua);
		});
		addCallback("getGlobals", function(luaFile:String){ // returns a copy of the specified file's globals
			var cervix = pussyPath(luaFile);
			var doPush = cervix != null;
			
			if(doPush)
			{
				for (luaInstance in PlayState.instance.luaArray)
				{
					if(luaInstance.scriptName == cervix)
					{
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

							if(pop==2)Lua.rawset(lua, tableIdx); // then set it
					Lua.pop(luaInstance.lua, 1); // for the loop
				  }
				  Lua.pop(luaInstance.lua,1); // end the loop entirely
						Lua.pushvalue(lua, tableIdx); // push the table onto the stack so it gets returned

						return;
					}

				}
			}
			Lua.pushnil(lua);
		});

		addCallback("runHaxeCode", function(code:String){
			if (haxeScript == null){
				trace('null');
				return;
			}

			// getinfo randomly broke here idk why
			// so just trace from line 1
			FunkinHScript.parser.line = 1;
			var retVal = haxeScript.executeCode(code);
			if (retVal != null && !isOfTypes(retVal, [Bool, Int, Float, String, Array]))
				retVal = null;
	
			return retVal;
		});

		addCallback("isRunning", function(luaFile:String){
			var cervix = pussyPath(luaFile);
			var doPush = cervix != null;

			if(doPush){
				for (luaInstance in PlayState.instance.luaArray){
					if(luaInstance.scriptName == cervix)
						return true;
				}
			}

			return false;
		});

		addCallback("addLuaScript", function(luaFile:String, ?ignoreAlreadyRunning:Bool = false) { //would be dope asf.	
			var cervix = pussyPath(luaFile);
			var doPush = cervix != null;

			if(!doPush){
				luaTrace("Script doesn't exist!");
				return;
			}

			if (ignoreAlreadyRunning != true)
			{
				for (luaInstance in PlayState.instance.luaArray)
				{
					if(luaInstance.scriptName == cervix)
					{
						luaTrace('The script "' + cervix + '" is already running!');
						return;
					}
				}
			}
			
			PlayState.instance.createLua(cervix);
		});
		addCallback("removeLuaScript", function(luaFile:String, ?ignoreAlreadyRunning:Bool = false) { //would be dope asf.
			var cervix = pussyPath(luaFile);
			var doPush = cervix != null;

			if(!doPush){
				luaTrace("Script doesn't exist!");
				return;
			}
			
			//if (ignoreAlreadyRunning != true){
				for (luaInstance in PlayState.instance.luaArray){
					if(luaInstance.scriptName == cervix){
						//luaTrace('The script "' + cervix + '" is already running!');
						PlayState.instance.removeLua(luaInstance);
						return;
					}
				}		
			//}
			
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

		addCallback("loadGraphic", function(variable:String, image:String, ?gridX:Int, ?gridY:Int) {
			var killMe:Array<String> = variable.split('.');
			var spr:FlxSprite = getObjectDirectly(killMe[0]);
			var gX = gridX==null?0:gridX;
			var gY = gridY==null?0:gridY;
			var animated = gX!=0 || gY!=0;

			if(killMe.length > 1) {
				spr = getVarInArray(getPropertyLoopThingWhatever(killMe), killMe[killMe.length-1]);
			}

			if(spr != null && image != null && image.length > 0)
			{
				spr.loadGraphic(Paths.image(image), animated, gX, gY);
			}
		});


		addCallback("loadFrames", function(variable:String, image:String, spriteType:String = "sparrow") {
			var killMe:Array<String> = variable.split('.');
			var spr:FlxSprite = getObjectDirectly(killMe[0]);
			if(killMe.length > 1) {
				spr = getVarInArray(getPropertyLoopThingWhatever(killMe), killMe[killMe.length-1]);
			}

			if(spr != null && image != null && image.length > 0)
				loadFrames(spr, image, spriteType);
		});

		//shitass stuff for epic coders like me B)  *image of obama giving himself a medal*
		addCallback("getObjectOrder", function(obj:String) {
			var killMe:Array<String> = obj.split('.');
			var leObj:FlxBasic = getObjectDirectly(killMe[0]);
			if(killMe.length > 1) {
				leObj = getVarInArray(getPropertyLoopThingWhatever(killMe), killMe[killMe.length-1]);
			}

			if(leObj != null)
			{
				return getInstance().members.indexOf(leObj);
			}
			luaTrace("Object " + obj + " doesn't exist!");
			return -1;
		});
		addCallback("setObjectOrder", function(obj:String, position:Int) {
			var killMe:Array<String> = obj.split('.');
			var leObj:FlxBasic = getObjectDirectly(killMe[0]);
			if(killMe.length > 1) {
				leObj = getVarInArray(getPropertyLoopThingWhatever(killMe), killMe[killMe.length-1]);
			}

			if(leObj != null) {
				getInstance().remove(leObj, true);
				getInstance().insert(position, leObj);
				return;
			}
			luaTrace("Object " + obj + " doesn't exist!");
		});

		// gay ass tweens
		addCallback("doTweenX", function(tag:String, vars:String, value:Dynamic, duration:Float, ease:String) {
			var penisExam:Dynamic = tweenShit(tag, vars);
			if(penisExam != null) {
				PlayState.instance.modchartTweens.set(tag, FlxTween.tween(penisExam, {x: value}, duration, {ease: getFlxEaseByString(ease),
					onComplete: function(twn:FlxTween) {
						PlayState.instance.callOnLuas('onTweenCompleted', [tag]);
						PlayState.instance.modchartTweens.remove(tag);
					}
				}));
			} else {
				luaTrace('Couldnt find object: ' + vars);
			}
		});
		addCallback("doTweenY", function(tag:String, vars:String, value:Dynamic, duration:Float, ease:String) {
			var penisExam:Dynamic = tweenShit(tag, vars);
			if(penisExam != null) {
				PlayState.instance.modchartTweens.set(tag, FlxTween.tween(penisExam, {y: value}, duration, {ease: getFlxEaseByString(ease),
					onComplete: function(twn:FlxTween) {
						PlayState.instance.callOnLuas('onTweenCompleted', [tag]);
						PlayState.instance.modchartTweens.remove(tag);
					}
				}));
			} else {
				luaTrace('Couldnt find object: ' + vars);
			}
		});
		addCallback("doTweenAngle", function(tag:String, vars:String, value:Dynamic, duration:Float, ease:String) {
			var penisExam:Dynamic = tweenShit(tag, vars);
			if(penisExam != null) {
				PlayState.instance.modchartTweens.set(tag, FlxTween.tween(penisExam, {angle: value}, duration, {ease: getFlxEaseByString(ease),
					onComplete: function(twn:FlxTween) {
						PlayState.instance.callOnLuas('onTweenCompleted', [tag]);
						PlayState.instance.modchartTweens.remove(tag);
					}
				}));
			} else {
				luaTrace('Couldnt find object: ' + vars);
			}
		});
		addCallback("doTweenAlpha", function(tag:String, vars:String, value:Dynamic, duration:Float, ease:String) {
			var penisExam:Dynamic = tweenShit(tag, vars);
			if(penisExam != null) {
				PlayState.instance.modchartTweens.set(tag, FlxTween.tween(penisExam, {alpha: value}, duration, {ease: getFlxEaseByString(ease),
					onComplete: function(twn:FlxTween) {
						PlayState.instance.callOnLuas('onTweenCompleted', [tag]);
						PlayState.instance.modchartTweens.remove(tag);
					}
				}));
			} else {
				luaTrace('Couldnt find object: ' + vars);
			}
		});
		addCallback("doTweenZoom", function(tag:String, vars:String, value:Dynamic, duration:Float, ease:String) {
			var penisExam:Dynamic = tweenShit(tag, vars);
			if(penisExam != null) {
				PlayState.instance.modchartTweens.set(tag, FlxTween.tween(penisExam, {zoom: value}, duration, {ease: getFlxEaseByString(ease),
					onComplete: function(twn:FlxTween) {
						PlayState.instance.callOnLuas('onTweenCompleted', [tag]);
						PlayState.instance.modchartTweens.remove(tag);
					}
				}));
			} else {
				luaTrace('Couldnt find object: ' + vars);
			}
		});
		addCallback("doTweenColor", function(tag:String, vars:String, targetColor:String, duration:Float, ease:String) {
			var penisExam:Dynamic = tweenShit(tag, vars);
			if(penisExam != null) {
				var color:Int = FlxColor.fromString(targetColor);

				var curColor:FlxColor = penisExam.color;
				curColor.alphaFloat = penisExam.alpha;
				PlayState.instance.modchartTweens.set(tag, FlxTween.color(penisExam, duration, curColor, color, {ease: getFlxEaseByString(ease),
					onComplete: function(twn:FlxTween) {
						PlayState.instance.modchartTweens.remove(tag);
						PlayState.instance.callOnLuas('onTweenCompleted', [tag]);
					}
				}));
			} else {
				luaTrace('Couldnt find object: ' + vars);
			}
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
			PlayState.instance.songScore += value;
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
			try
			{
				var charType:Int = 0;
				switch (type.toLowerCase())
				{
					case 'gf' | 'girlfriend' | '2':
						charType = 2;
					case 'dad' | 'opponent' | '1':
						charType = 1;
					default:
						charType = Std.parseInt(type);
						if (Math.isNaN(charType))
							charType = 0;
				}
				
				trace(charType, type, PlayState.instance);

				PlayState.instance.addCharacterToList(name, charType);
			}catch(e:Dynamic){
				trace(e);
			}

		});
		addCallback("precacheImage", function(name:String) {
			Paths.returnGraphic(name);
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
			if(skipTransition)
			{
				FlxTransitionableState.skipNextTransIn = true;
				FlxTransitionableState.skipNextTransOut = true;
			}

			PlayState.instance.cancelMusicFadeTween();
			CustomFadeTransition.nextCamera = PlayState.instance.camOther;
			if(FlxTransitionableState.skipNextTransIn)
				CustomFadeTransition.nextCamera = null;

			if(PlayState.isStoryMode)
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
			var isDad:Bool = false;
			if(target == 'dad') {
				isDad = true;
			}
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
			PlayState.instance.ratingName = value;
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
			var killMe:Array<String> = variable.split('.');
			var obj:FlxSprite = getObjectDirectly(killMe[0]);
			if(killMe.length > 1) {
				obj = getVarInArray(getPropertyLoopThingWhatever(killMe), killMe[killMe.length-1]);
			}
			if(obj != null) return obj.getMidpoint().x;

			return 0;
		});
		addCallback("getMidpointY", function(variable:String) {
			var killMe:Array<String> = variable.split('.');
			var obj:FlxSprite = getObjectDirectly(killMe[0]);
			if(killMe.length > 1) {
				obj = getVarInArray(getPropertyLoopThingWhatever(killMe), killMe[killMe.length-1]);
			}
			if(obj != null) return obj.getMidpoint().y;

			return 0;
		});
		addCallback("getGraphicMidpointX", function(variable:String) {
			var killMe:Array<String> = variable.split('.');
			var obj:FlxSprite = getObjectDirectly(killMe[0]);
			if(killMe.length > 1) {
				obj = getVarInArray(getPropertyLoopThingWhatever(killMe), killMe[killMe.length-1]);
			}
			if(obj != null) return obj.getGraphicMidpoint().x;

			return 0;
		});
		addCallback("getGraphicMidpointY", function(variable:String) {
			var killMe:Array<String> = variable.split('.');
			var obj:FlxSprite = getObjectDirectly(killMe[0]);
			if(killMe.length > 1) {
				obj = getVarInArray(getPropertyLoopThingWhatever(killMe), killMe[killMe.length-1]);
			}
			if(obj != null) return obj.getGraphicMidpoint().y;

			return 0;
		});
		addCallback("getScreenPositionX", function(variable:String) {
			var killMe:Array<String> = variable.split('.');
			var obj:FlxSprite = getObjectDirectly(killMe[0]);
			if(killMe.length > 1) {
				obj = getVarInArray(getPropertyLoopThingWhatever(killMe), killMe[killMe.length-1]);
			}
			if(obj != null) return obj.getScreenPosition().x;

			return 0;
		});
		addCallback("getScreenPositionY", function(variable:String) {
			var killMe:Array<String> = variable.split('.');
			var obj:FlxSprite = getObjectDirectly(killMe[0]);
			if(killMe.length > 1) {
				obj = getVarInArray(getPropertyLoopThingWhatever(killMe), killMe[killMe.length-1]);
			}
			if(obj != null) return obj.getScreenPosition().y;

			return 0;
		});
		addCallback("characterPlayAnim", function(character:String, anim:String, ?forced:Bool = false) {
			switch(character.toLowerCase()) {
				case 'dad':
					if(PlayState.instance.dad.animOffsets.exists(anim))
						PlayState.instance.dad.playAnim(anim, forced);
				case 'gf' | 'girlfriend':
					if(PlayState.instance.gf != null && PlayState.instance.gf.animOffsets.exists(anim))
						PlayState.instance.gf.playAnim(anim, forced);
				default:
					if(PlayState.instance.boyfriend.animOffsets.exists(anim))
						PlayState.instance.boyfriend.playAnim(anim, forced);
			}
		});
		addCallback("characterDance", function(character:String) {
			switch(character.toLowerCase()) {
				case 'dad': PlayState.instance.dad.dance();
				case 'gf' | 'girlfriend': if(PlayState.instance.gf != null) PlayState.instance.gf.dance();
				default: PlayState.instance.boyfriend.dance();
			}
		});

		addCallback("makeLuaSprite", function(tag:String, image:String, x:Float, y:Float) {
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

			var spr:FlxSprite = PlayState.instance.getLuaObject(obj,false);
			if(spr!=null) {
				PlayState.instance.getLuaObject(obj,false).makeGraphic(width, height, colorNum);
				return;
			}

			var object:FlxSprite = Reflect.getProperty(getInstance(), obj);
			if(object != null) {
				object.makeGraphic(width, height, colorNum);
			}
		});
		addCallback("addAnimationByPrefix", function(obj:String, name:String, prefix:String, framerate:Int = 24, loop:Bool = true) {
			if(PlayState.instance.getLuaObject(obj,false)!=null) {
				var cock:FlxSprite = PlayState.instance.getLuaObject(obj,false);
				cock.animation.addByPrefix(name, prefix, framerate, loop);
				if(cock.animation.curAnim == null) {
					cock.animation.play(name, true);
				}
				return;
			}

			var cock:FlxSprite = Reflect.getProperty(getInstance(), obj);
			if(cock != null) {
				cock.animation.addByPrefix(name, prefix, framerate, loop);
				if(cock.animation.curAnim == null) {
					cock.animation.play(name, true);
				}
			}
		});

		addCallback("addAnimation", function(obj:String, name:String, frames:Array<Int>, framerate:Int = 24, loop:Bool = true) {
			if(PlayState.instance.getLuaObject(obj,false)!=null) {
				var cock:FlxSprite = PlayState.instance.getLuaObject(obj,false);
				cock.animation.add(name, frames, framerate, loop);
				if(cock.animation.curAnim == null) {
					cock.animation.play(name, true);
				}
				return;
			}

			var cock:FlxSprite = Reflect.getProperty(getInstance(), obj);
			if(cock != null) {
				cock.animation.add(name, frames, framerate, loop);
				if(cock.animation.curAnim == null) {
					cock.animation.play(name, true);
				}
			}
		});

		addCallback("addAnimationByIndices", function(obj:String, name:String, prefix:String, indices:String, framerate:Int = 24) {
			var strIndices:Array<String> = indices.trim().split(',');
			var die:Array<Int> = [];
			for (i in 0...strIndices.length) {
				die.push(Std.parseInt(strIndices[i]));
			}

			if(PlayState.instance.getLuaObject(obj, false)!=null) {
				var pussy:FlxSprite = PlayState.instance.getLuaObject(obj,false);
				pussy.animation.addByIndices(name, prefix, die, '', framerate, false);
				if(pussy.animation.curAnim == null) {
					pussy.animation.play(name, true);
				}
				return;
			}

			var pussy:FlxSprite = Reflect.getProperty(getInstance(), obj);
			if(pussy != null) {
				pussy.animation.addByIndices(name, prefix, die, '', framerate, false);
				if(pussy.animation.curAnim == null) {
					pussy.animation.play(name, true);
				}
			}
		});
		
		addCallback("playAnim", function(obj:String, name:String, forced:Bool = false, ?reverse:Bool = false, ?startFrame:Int = 0)
		{
			if(PlayState.instance.getLuaObject(obj, false) != null) {
				var luaObj:FlxSprite = PlayState.instance.getLuaObject(obj,false);
				if(luaObj.animation.getByName(name) != null)
				{
					luaObj.animation.play(name, forced, reverse, startFrame);
					if(Std.isOfType(luaObj, ModchartSprite))
					{
						var luaObj:ModchartSprite = cast luaObj;
						
						if (luaObj.animOffsets.exists(name))
						{
							var daOffset = luaObj.animOffsets.get(name);
							luaObj.offset.set(daOffset[0], daOffset[1]);
						}
					}
				}
				return true;
			}

			var spr:FlxSprite = Reflect.getProperty(getInstance(), obj);
			if(spr != null) {
				if(spr.animation.getByName(name) != null)
				{
					if(Std.isOfType(spr, Character))
					{
						//convert spr to Character
						var obj:Dynamic = spr;
						var spr:Character = obj;
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
			if(PlayState.instance.getLuaObject(obj,false)!=null) {
				PlayState.instance.getLuaObject(obj,false).animation.play(name, forced, startFrame);
				return;
			}

			var spr:FlxSprite = Reflect.getProperty(getInstance(), obj);
			if(spr != null) {
				spr.animation.play(name, forced);
			}
		});

		addCallback("objectPlayAnim",  function(obj:String, name:String, forced:Bool = false, ?startFrame:Int = 0) { // some psych mods use this but i cant find it any official psych code
			// weird
			luaTrace("objectPlayAnim is deprecated! Use playAnim instead", false, true);
			if(PlayState.instance.getLuaObject(obj,false)!=null) {
				PlayState.instance.getLuaObject(obj,false).animation.play(name, forced, startFrame);
				return;
			}

			var spr:FlxSprite = Reflect.getProperty(getInstance(), obj);
			if(spr != null) {
				spr.animation.play(name, forced);
			}
		});

		addCallback("setScrollFactor", function(obj:String, scrollX:Float, scrollY:Float) {
			if(PlayState.instance.getLuaObject(obj,false)!=null) {
				PlayState.instance.getLuaObject(obj,false).scrollFactor.set(scrollX, scrollY);
				return;
			}

			var object:FlxObject = Reflect.getProperty(getInstance(), obj);
			if(object != null) {
				object.scrollFactor.set(scrollX, scrollY);
			}
		});
		addCallback("addLuaSprite", function(tag:String, front:Bool = false) {
			if (PlayState.instance == null || !PlayState.instance.modchartSprites.exists(tag))
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
			if(PlayState.instance.getLuaObject(obj)!=null) {
				var shit:FlxSprite = PlayState.instance.getLuaObject(obj);
				shit.setGraphicSize(x, y);
				if(updateHitbox) shit.updateHitbox();
				return;
			}

			var killMe:Array<String> = obj.split('.');
			var poop:FlxSprite = getObjectDirectly(killMe[0]);
			if(killMe.length > 1) {
				poop = getVarInArray(getPropertyLoopThingWhatever(killMe), killMe[killMe.length-1]);
			}

			if(poop != null) {
				poop.setGraphicSize(x, y);
				if(updateHitbox) poop.updateHitbox();
				return;
			}
			luaTrace('Couldnt find object: ' + obj);
		});
		addCallback("scaleObject", function(obj:String, x:Float, y:Float, updateHitbox:Bool = true) {
			if(PlayState.instance.getLuaObject(obj)!=null) {
				var shit:FlxSprite = PlayState.instance.getLuaObject(obj);
				shit.scale.set(x, y);
				if(updateHitbox) shit.updateHitbox();
				return;
			}

			var killMe:Array<String> = obj.split('.');
			var poop:FlxSprite = getObjectDirectly(killMe[0]);
			if(killMe.length > 1) {
				poop = getVarInArray(getPropertyLoopThingWhatever(killMe), killMe[killMe.length-1]);
			}

			if(poop != null) {
				poop.scale.set(x, y);
				if(updateHitbox) poop.updateHitbox();
				return;
			}
			luaTrace('Couldnt find object: ' + obj);
		});
		addCallback("updateHitbox", function(obj:String) {
			if(PlayState.instance.getLuaObject(obj)!=null) {
				var shit:FlxSprite = PlayState.instance.getLuaObject(obj);
				shit.updateHitbox();
				return;
			}

			var poop:FlxSprite = Reflect.getProperty(getInstance(), obj);
			if(poop != null) {
				poop.updateHitbox();
				return;
			}
			luaTrace('Couldnt find object: ' + obj);
		});
		addCallback("updateHitboxFromGroup", function(group:String, index:Int) {
			if(Std.isOfType(Reflect.getProperty(getInstance(), group), FlxTypedGroup)) {
				Reflect.getProperty(getInstance(), group).members[index].updateHitbox();
				return;
			}
			Reflect.getProperty(getInstance(), group)[index].updateHitbox();
		});

		addCallback("isNoteChild", function(parentID:Int, childID:Int){
			var parent: Note = cast PlayState.instance.getLuaObject('note${parentID}',false);
			var child: Note = cast PlayState.instance.getLuaObject('note${childID}',false);
			if(parent!=null && child!=null)
				return parent.tail.contains(child);

			luaTrace('${parentID} or ${childID} is not a valid note ID');
			return false;
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
			/*if(PlayState.instance.modchartSprites.exists(obj)) {
				PlayState.instance.modchartSprites.get(obj).cameras = [cameraFromString(camera)];
				return true;
			}
			else if(PlayState.instance.modchartTexts.exists(obj)) {
				PlayState.instance.modchartTexts.get(obj).cameras = [cameraFromString(camera)];
				return true;
			}*/
			var real = PlayState.instance.getLuaObject(obj);
			if(real!=null){
				real.cameras = [cameraFromString(camera)];
				return true;
			}

			var killMe:Array<String> = obj.split('.');
			var object:FlxSprite = getObjectDirectly(killMe[0]);
			if(killMe.length > 1) {
				object = getVarInArray(getPropertyLoopThingWhatever(killMe), killMe[killMe.length-1]);
			}

			if(object != null) {
				object.cameras = [cameraFromString(camera)];
				return true;
			}
			luaTrace("Object " + obj + " doesn't exist!");
			return false;
		});
		addCallback("setBlendMode", function(obj:String, blend:String = '') {
			var real = PlayState.instance.getLuaObject(obj);
			if(real!=null) {
				real.blend = blendModeFromString(blend);
				return true;
			}

			var killMe:Array<String> = obj.split('.');
			var spr:FlxSprite = getObjectDirectly(killMe[0]);
			if(killMe.length > 1) {
				spr = getVarInArray(getPropertyLoopThingWhatever(killMe), killMe[killMe.length-1]);
			}

			if(spr != null) {
				spr.blend = blendModeFromString(blend);
				return true;
			}
			luaTrace("Object " + obj + " doesn't exist!");
			return false;
		});
		addCallback("screenCenter", function(obj:String, pos:String = 'xy') {
			var spr:FlxSprite = PlayState.instance.getLuaObject(obj);

			if(spr==null){
				var killMe:Array<String> = obj.split('.');
				spr = getObjectDirectly(killMe[0]);
				if(killMe.length > 1) {
					spr = getVarInArray(getPropertyLoopThingWhatever(killMe), killMe[killMe.length-1]);
				}
			}

			if(spr != null)
			{
				switch(pos.trim().toLowerCase())
				{
					case 'x':
						spr.screenCenter(X);
						return;
					case 'y':
						spr.screenCenter(Y);
						return;
					default:
						spr.screenCenter(XY);
						return;
				}
			}
			luaTrace("Object " + obj + " doesn't exist!");
		});
		addCallback("objectsOverlap", function(obj1:String, obj2:String) {
			var namesArray:Array<String> = [obj1, obj2];
			var objectsArray:Array<FlxSprite> = [];
			for (i in 0...namesArray.length)
			{
				var real = PlayState.instance.getLuaObject(namesArray[i]);
				if(real!=null) {
					objectsArray.push(real);
				} else {
					objectsArray.push(Reflect.getProperty(getInstance(), namesArray[i]));
				}
			}

			if(!objectsArray.contains(null) && FlxG.overlap(objectsArray[0], objectsArray[1]))
			{
				return true;
			}
			return false;
		});
		addCallback("getPixelColor", function(obj:String, x:Int, y:Int) {
			var killMe:Array<String> = obj.split('.');
			var spr:FlxSprite = getObjectDirectly(killMe[0]);
			if(killMe.length > 1) {
				spr = getVarInArray(getPropertyLoopThingWhatever(killMe), killMe[killMe.length-1]);
			}

			if(spr != null)
			{
				if(spr.framePixels != null) spr.framePixels.getPixel32(x, y);
				return spr.pixels.getPixel32(x, y);
			}
			return 0;
		});
		addCallback("getRandomInt", function(min:Int, max:Int = FlxMath.MAX_VALUE_INT, exclude:String = '') {
			var excludeArray:Array<String> = exclude.split(',');
			var toExclude:Array<Int> = [];
			for (i in 0...excludeArray.length)
			{
				toExclude.push(Std.parseInt(excludeArray[i].trim()));
			}
			return FlxG.random.int(min, max, toExclude);
		});
		addCallback("getRandomFloat", function(min:Float, max:Float = 1, exclude:String = '') {
			var excludeArray:Array<String> = exclude.split(',');
			var toExclude:Array<Float> = [];
			for (i in 0...excludeArray.length)
			{
				toExclude.push(Std.parseFloat(excludeArray[i].trim()));
			}
			return FlxG.random.float(min, max, toExclude);
		});
		addCallback("getRandomBool", function(chance:Float = 50) {
			return FlxG.random.bool(chance);
		});
		
		addCallback("startDialogue", function(dialogueFile:String, music:String = null) {
			if(PlayState.instance.endingSong) {
				PlayState.instance.endSong();
			} else {
				PlayState.instance.startCountdown();
			}
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

		addCallback("debugPrint", Reflect.makeVarArgs(function(toPrint:Array<Dynamic>) {
			luaTrace(toPrint.join(", "), true, false);
		}));
		addCallback("close", function(printMessage:Bool) {
			if(!gonnaClose && printMessage)
				luaTrace('Stopping lua script: ' + scriptName);
			
			gonnaClose = true;
		});

		addCallback("changePresence", function(details:String, state:Null<String>, ?smallImageKey:String, ?hasStartTimestamp:Bool, ?endTimestamp:Float) {
			#if discord_rpc
			DiscordClient.changePresence(details, state, smallImageKey, hasStartTimestamp, endTimestamp);
			#end
		});


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
			return Paths.getTextFromFile(path, ignoreModFolders);
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
				var strIndices:Array<String> = indices.trim().split(',');
				var die:Array<Int> = [];
				for (i in 0...strIndices.length) {
					die.push(Std.parseInt(strIndices[i]));
				}
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
		
		trace('lua file loaded: $script');

		if(!ignoreCreateCall) call('onCreate', []);
		#end
	}

	inline public static function pussyPath(luaFile:String):Null<String>
	{
		var cervix = luaFile.endsWith(".lua") ? luaFile : luaFile + ".lua";
		var doPush = false;

		#if MODS_ALLOWED
		if (Paths.exists(Paths.modFolders(cervix)))
		{
			cervix = Paths.modFolders(cervix);
			doPush = true;
		}
		else if (Paths.exists(cervix))
		{
			doPush = true;
		}
		else
		#end
		{
			cervix = Paths.getPreloadPath(cervix);
			if (Paths.exists(cervix))
				doPush = true;
		}

		return (doPush) ? cervix : null;
	}

	public static function getProperty(variable:String) {
		var killMe:Array<String> = variable.split('.');
		if(killMe.length > 1) {
			return getVarInArray(getPropertyLoopThingWhatever(killMe), killMe[killMe.length-1]);
		}
		return getVarInArray(getInstance(), variable);
	}
	public static function setProperty(variable:String, value:Dynamic) {
		var killMe:Array<String> = variable.split('.');
		if(killMe.length > 1) {
			setVarInArray(getPropertyLoopThingWhatever(killMe), killMe[killMe.length-1], value);
			return true;
		}
		setVarInArray(getInstance(), variable, value);
		return true;
	}

	public static function getPropertyFromGroup(obj:String, index:Int, variable:Dynamic) {
		var shitMyPants:Array<String> = obj.split('.');
		var realObject:Dynamic = Reflect.getProperty(getInstance(), obj);
		if(shitMyPants.length>1)
			realObject = getPropertyLoopThingWhatever(shitMyPants, true, false);


		if(Std.isOfType(realObject, FlxTypedGroup))
			return getGroupStuff(realObject.members[index], variable);


		var leArray:Dynamic = realObject[index];
		if(leArray != null) {
			if(Type.typeof(variable) == ValueType.TInt) {
				return leArray[variable];
			}
			return getGroupStuff(leArray, variable);
		}
		trace("Object #" + index + " from group: " + obj + " doesn't exist!");
		return null;
	}
	public static function setPropertyFromGroup(obj:String, index:Int, variable:Dynamic, value:Dynamic) {
		var shitMyPants:Array<String> = obj.split('.');
		var realObject:Dynamic = Reflect.getProperty(getInstance(), obj);
		if(shitMyPants.length>1)
			realObject = getPropertyLoopThingWhatever(shitMyPants, true, false);

		if(Std.isOfType(realObject, FlxTypedGroup)) {
			setGroupStuff(realObject.members[index], variable, value);
			return;
		}

		var leArray:Dynamic = realObject[index];
		if(leArray != null) {
			if(Type.typeof(variable) == ValueType.TInt) {
				leArray[variable] = value;
				return;
			}
			setGroupStuff(leArray, variable, value);
		}
	}
	public static function removeFromGroup(obj:String, index:Int, dontDestroy:Bool = false) {
		var instance = getInstance();

		if(Std.isOfType(Reflect.getProperty(instance, obj), FlxTypedGroup)) {
			var sex = Reflect.getProperty(instance, obj).members[index];
			if(!dontDestroy)
				sex.kill();
			Reflect.getProperty(instance, obj).remove(sex, true);
			if(!dontDestroy)
				sex.destroy();
			return;
		}
		Reflect.getProperty(instance, obj).remove(Reflect.getProperty(instance, obj)[index]);
	}

	public static function getPropertyFromClass(classVar:String, variable:String) {
		var killMe:Array<String> = variable.split('.');
		if(killMe.length > 1) {
			var coverMeInPiss:Dynamic = getVarInArray(Type.resolveClass(classVar), killMe[0]);
			for (i in 1...killMe.length-1) {
				coverMeInPiss = getVarInArray(coverMeInPiss, killMe[i]);
			}
			return getVarInArray(coverMeInPiss, killMe[killMe.length-1]);
		}
		return getVarInArray(Type.resolveClass(classVar), variable);
	}
	public static function setPropertyFromClass(classVar:String, variable:String, value:Dynamic) {
		var killMe:Array<String> = variable.split('.');
		if(killMe.length > 1) {
			var coverMeInPiss:Dynamic = getVarInArray(Type.resolveClass(classVar), killMe[0]);
			for (i in 1...killMe.length-1) {
				coverMeInPiss = getVarInArray(coverMeInPiss, killMe[i]);
			}
			setVarInArray(coverMeInPiss, killMe[killMe.length-1], value);
			return true;
		}
		setVarInArray(Type.resolveClass(classVar), variable, value);
		return true;
	}

	public static function setVarInArray(instance:Dynamic, variable:String, value:Dynamic):Any
	{
		var shit:Array<String> = variable.split('[');
		if(shit.length > 1)
		{
			var blah:Dynamic = Reflect.getProperty(instance, shit[0]);
			for (i in 1...shit.length)
			{
				var leNum:Dynamic = shit[i].substr(0, shit[i].length - 1);
				if(i >= shit.length-1) //Last array
					blah[leNum] = value;
				else //Anything else
					blah = blah[leNum];
			}
			return blah;
		}
		/*if(Std.isOfType(instance, Map))
			instance.set(variable,value);
		else*/
		switch(Type.typeof(instance)){
			case ValueType.TClass(haxe.ds.StringMap) | ValueType.TClass(haxe.ds.ObjectMap) | ValueType.TClass(haxe.ds.IntMap) | ValueType.TClass(haxe.ds.EnumValueMap):
				instance.set(variable, value);
			default:
				Reflect.setProperty(instance, variable, value);
		};


		return true;
	}
	public static function getVarInArray(instance:Dynamic, variable:String):Any
	{
		var shit:Array<String> = variable.split('[');
		if(shit.length > 1)
		{
			var blah:Dynamic = Reflect.getProperty(instance, shit[0]);
			for (i in 1...shit.length)
			{
				var leNum:Dynamic = shit[i].substr(0, shit[i].length - 1);
				blah = blah[leNum];
			}
			return blah;
		}
		switch(Type.typeof(instance)){
			case ValueType.TClass(haxe.ds.StringMap) | ValueType.TClass(haxe.ds.ObjectMap) | ValueType.TClass(haxe.ds.IntMap) | ValueType.TClass(haxe.ds.EnumValueMap):
				return instance.get(variable);
			default:
				return Reflect.getProperty(instance, variable);
		};
	}

	inline static function getTextObject(name:String):FlxText
	{
		return PlayState.instance.modchartTexts.exists(name) ? PlayState.instance.modchartTexts.get(name) : Reflect.getProperty(PlayState.instance, name);
	}

	static function getGroupStuff(leArray:Dynamic, variable:String) {
		var killMe:Array<String> = variable.split('.');
		if(killMe.length > 1) {
			var coverMeInPiss:Dynamic = Reflect.getProperty(leArray, killMe[0]);
			for (i in 1...killMe.length-1) {
				coverMeInPiss = Reflect.getProperty(coverMeInPiss, killMe[i]);
			}
			switch(Type.typeof(coverMeInPiss)){
				case ValueType.TClass(haxe.ds.StringMap) | ValueType.TClass(haxe.ds.ObjectMap) | ValueType.TClass(haxe.ds.IntMap) | ValueType.TClass(haxe.ds.EnumValueMap):
					return coverMeInPiss.get(killMe[killMe.length-1]);
				default:
					return Reflect.getProperty(coverMeInPiss, killMe[killMe.length-1]);
			};
		}
		switch(Type.typeof(leArray)){
			case ValueType.TClass(haxe.ds.StringMap) | ValueType.TClass(haxe.ds.ObjectMap) | ValueType.TClass(haxe.ds.IntMap) | ValueType.TClass(haxe.ds.EnumValueMap):
				return leArray.get(variable);
			default:
				return Reflect.getProperty(leArray, variable);
		};
	}
	static function setGroupStuff(leArray:Dynamic, variable:String, value:Dynamic) {
		var killMe:Array<String> = variable.split('.');
		if(killMe.length > 1) {
			var coverMeInPiss:Dynamic = Reflect.getProperty(leArray, killMe[0]);
			for (i in 1...killMe.length-1) {
				coverMeInPiss = Reflect.getProperty(coverMeInPiss, killMe[i]);
			}
			Reflect.setProperty(coverMeInPiss, killMe[killMe.length-1], value);
			return;
		}
		Reflect.setProperty(leArray, variable, value);
	}

	static function loadFrames(spr:FlxSprite, image:String, spriteType:String)
	{
		switch(spriteType.toLowerCase().trim())
		{
			case "texture" | "textureatlas" | "tex":
				spr.frames = AtlasFrameMaker.construct(image);

			case "texture_noaa" | "textureatlas_noaa" | "tex_noaa":
				spr.frames = AtlasFrameMaker.construct(image, null, true);

			case "packer" | "packeratlas" | "pac":
				spr.frames = Paths.getPackerAtlas(image);

			default:
				spr.frames = Paths.getSparrowAtlas(image);
		}
	}

	static function resetTextTag(tag:String) {
		if(!PlayState.instance.modchartTexts.exists(tag))
			return;

		var pee:ModchartText = PlayState.instance.modchartTexts.get(tag);
		pee.kill();
		if(pee.wasAdded)
			PlayState.instance.remove(pee, true);
		
		pee.destroy();
		PlayState.instance.modchartTexts.remove(tag);
	}

	static function resetSpriteTag(tag:String) {
		if(!PlayState.instance.modchartSprites.exists(tag))
			return;

		var pee:ModchartSprite = PlayState.instance.modchartSprites.get(tag);
		pee.kill();
		if(pee.wasAdded)
			PlayState.instance.remove(pee, true);
		
		pee.destroy();
		PlayState.instance.modchartSprites.remove(tag);
	}

	static function cancelTween(tag:String) {
		if(PlayState.instance.modchartTweens.exists(tag)) {
			PlayState.instance.modchartTweens.get(tag).cancel();
			PlayState.instance.modchartTweens.get(tag).destroy();
			PlayState.instance.modchartTweens.remove(tag);
		}
	}

	static function tweenShit(tag:String, vars:String)
	{
		cancelTween(tag);
		var variables:Array<String> = vars.split('.');

		if(variables.length > 1)
			return getVarInArray(getPropertyLoopThingWhatever(variables), variables[variables.length-1]);
		
		return getObjectDirectly(variables[0]);
	}

	static function cancelTimer(tag:String) {
		if (PlayState.instance.modchartTimers.exists(tag)) 
		{
			var theTimer:FlxTimer = PlayState.instance.modchartTimers.get(tag);
			theTimer.cancel();
			theTimer.destroy();
			PlayState.instance.modchartTimers.remove(tag);
		}
	}

	static function getMouseClicked(button:String) {
		return switch(button){
			case 'middle': FlxG.mouse.justPressedMiddle;
			case 'right': FlxG.mouse.justPressedRight;
			default: FlxG.mouse.justPressed;
		};
	}
	static function getMousePressed(button:String) {
		return switch(button){
			case 'middle': FlxG.mouse.pressedMiddle;
			case 'right': FlxG.mouse.pressedRight;
			default: FlxG.mouse.pressed;
		};
	}
	static function getMouseReleased(button:String) {
		return switch(button){
			case 'middle': FlxG.mouse.justReleasedMiddle;
			case 'right': FlxG.mouse.justReleasedRight;
			default: FlxG.mouse.justReleased;
		}
	}
	
	static function getFlxEaseByString(?ease:String):Float->Float
	{
		return (ease==null) ? FlxEase.linear : switch(ease.toLowerCase().trim()) 
		{
			case 'backin': FlxEase.backIn;
			case 'backinout': FlxEase.backInOut;
			case 'backout': FlxEase.backOut;
			case 'bouncein': FlxEase.bounceIn;
			case 'bounceinout': FlxEase.bounceInOut;
			case 'bounceout': FlxEase.bounceOut;
			case 'circin': FlxEase.circIn;
			case 'circinout': FlxEase.circInOut;
			case 'circout': FlxEase.circOut;
			case 'cubein': FlxEase.cubeIn;
			case 'cubeinout': FlxEase.cubeInOut;
			case 'cubeout': FlxEase.cubeOut;
			case 'elasticin': FlxEase.elasticIn;
			case 'elasticinout': FlxEase.elasticInOut;
			case 'elasticout': FlxEase.elasticOut;
			case 'expoin': FlxEase.expoIn;
			case 'expoinout': FlxEase.expoInOut;
			case 'expoout': FlxEase.expoOut;
			case 'quadin': FlxEase.quadIn;
			case 'quadinout': FlxEase.quadInOut;
			case 'quadout': FlxEase.quadOut;
			case 'quartin': FlxEase.quartIn;
			case 'quartinout': FlxEase.quartInOut;
			case 'quartout': FlxEase.quartOut;
			case 'quintin': FlxEase.quintIn;
			case 'quintinout': FlxEase.quintInOut;
			case 'quintout': FlxEase.quintOut;
			case 'sinein': FlxEase.sineIn;
			case 'sineinout': FlxEase.sineInOut;
			case 'sineout': FlxEase.sineOut;
			case 'smoothstepin': FlxEase.smoothStepIn;
			case 'smoothstepinout': FlxEase.smoothStepInOut;
			case 'smoothstepout': FlxEase.smoothStepInOut;
			case 'smootherstepin': FlxEase.smootherStepIn;
			case 'smootherstepinout': FlxEase.smootherStepInOut;
			case 'smootherstepout': FlxEase.smootherStepOut;
			default: FlxEase.linear;
		};
	}

	static function blendModeFromString(blend:String):BlendMode
	{
		return switch(blend.toLowerCase().trim()) 
		{
			case 'add': ADD;
			case 'alpha': ALPHA;
			case 'darken': DARKEN;
			case 'difference': DIFFERENCE;
			case 'erase': ERASE;
			case 'hardlight': HARDLIGHT;
			case 'invert': INVERT;
			case 'layer': LAYER;
			case 'lighten': LIGHTEN;
			case 'multiply': MULTIPLY;
			case 'overlay': OVERLAY;
			case 'screen': SCREEN;
			case 'shader': SHADER;
			case 'subtract': SUBTRACT;
			default: NORMAL;
		};
	}

	static function cameraFromString(cam:String):FlxCamera {
		switch(cam.toLowerCase()) {
			case 'camhud' | 'hud': return PlayState.instance.camHUD;
			case 'camother' | 'other': return PlayState.instance.camOther;
		}
		return PlayState.instance.camGame;
	}

	public function luaTrace(text:String, ignoreCheck:Bool = false, deprecated:Bool = false) {
		#if LUA_ALLOWED
		if(ignoreCheck || getBool('luaDebugMode')) {
			if(deprecated && !getBool('luaDeprecatedWarnings')) {
				return;
			}
			PlayState.instance.addTextToDebug(text);
			trace(text);
		}
		#end
	}

	/*public function call(event:String, args:Array<Dynamic>):Dynamic {
		#if LUA_ALLOWED
		if(lua == null) {
			return Function_Continue;
		}

		Lua.getglobal(lua, event);

		for (arg in args) {
			Convert.toLua(lua, arg);
		}

		var result:Null<Int> = Lua.pcall(lua, args.length, 1, 0);
		if(result != null && resultIsAllowed(lua, result)) {
			if(Lua.type(lua, -1) == Lua.LUA_TSTRING) {
				var error:String = Lua.tostring(lua, -1);
				Lua.pop(lua, 1);
				if(error == 'attempt to call a nil value') { //Makes it ignore warnings and not break stuff if you didn't put the functions on your lua file
					return Function_Continue;
				}
			}

			var conv:Dynamic = Convert.fromLua(lua, result);
			Lua.pop(lua, 1);
			return conv;
		}
		#end
		return Function_Continue;
	}*/

	function getErrorMessage() {
		#if LUA_ALLOWED
		var v:String = Lua.tostring(lua, -1);
		Lua.pop(lua, 1);
		return v;
		#else
		return "";
		#end
	}

	var duplicateErrors:Array<String> = [];

	override public function call(func:String, ?args:Array<Dynamic>, ?extraVars:Map<String,Dynamic>): Dynamic{
		#if LUA_ALLOWED
		try {
			if(args==null) args=[];
			if(lua==null) return Function_Continue;

			Lua.getglobal(lua, func);
			#if (linc_luajit >= "0.0.6")
			if(Lua.isfunction(lua, -1)==true){
			#else
			if(Lua.isfunction(lua, -1)==1){
			#end
				for(arg in args) 
					Convert.toLua(lua, arg);
				
				var result:Dynamic = Lua.pcall(lua, args.length, 1, 0);

				if(result!=0){
					var err = getErrorMessage();
					
					if(errorHandler != null)
						errorHandler(err);
					else{
						if (!duplicateErrors.contains(err)){
							// just so your output isnt SPAMMED

							var args = [for (arg in args){
								(arg is String ? '"$arg"' : Std.string(arg));
							}];
							Sys.println('$scriptName: Error on function $func(${args.join(', ')}): $err');
							duplicateErrors.push(err);
							while(duplicateErrors.length > 20)
								duplicateErrors.shift();
						}
					}
	
					return Function_Continue;
				}else{
					if(result != null){
						var conv:Dynamic = cast Convert.fromLua(lua, -1);
						Lua.pop(lua, 1);
						if (conv == null)
							return Function_Continue;
						return conv;
					}
				}
			}else{
				Lua.pop(lua, 1);
				return Function_Continue;
			}
		}catch(e:Dynamic){
			trace(e);
		}
		#end

		return Function_Continue;
	}

	public static function getPropertyLoopThingWhatever(killMe:Array<String>, ?checkForTextsToo:Bool = true, ?getProperty:Bool=true):Dynamic
	{
		var coverMeInPiss:Dynamic = getObjectDirectly(killMe[0], checkForTextsToo);
		var end = killMe.length;
		if(getProperty)end=killMe.length-1;

		for (i in 1...end) {
			coverMeInPiss = getVarInArray(coverMeInPiss, killMe[i]);
		}
		return coverMeInPiss;
	}

	public static function getObjectDirectly(objectName:String, ?checkForTextsToo:Bool = true):Dynamic
	{
		var coverMeInPiss:Dynamic = PlayState.instance.getLuaObject(objectName, checkForTextsToo);
		if(coverMeInPiss==null)
			coverMeInPiss = getVarInArray(getInstance(), objectName);

		return coverMeInPiss;
	}


	#if LUA_ALLOWED
	function resultIsAllowed(leLua:State, leResult:Null<Int>) { //Makes it ignore warnings
		return switch(Lua.type(leLua, leResult)) {
			case Lua.LUA_TNIL | Lua.LUA_TBOOLEAN | Lua.LUA_TNUMBER | Lua.LUA_TSTRING | Lua.LUA_TTABLE :
				true;
			default:
				false;
		}
	}
	#end

	override public function get(variable:String):Dynamic {
		#if LUA_ALLOWED
		if (lua == null)
			return null; // because void doesnt fit under dynamic
		
		var result:Dynamic = null;
		Lua.getglobal(lua, variable);
		result = Convert.fromLua(lua, -1);
		Lua.pop(lua, 1);
		return result;
		#else
		return null;
		#end
	}

	override public function set(variable:String, data:Dynamic):Void
	{
		#if LUA_ALLOWED
		if(lua == null)
			return;

		Convert.toLua(lua, data);
		Lua.setglobal(lua, variable);
		#end
	}

	#if LUA_ALLOWED
	public function getBool(variable:String) {
		var result:String = null;
		Lua.getglobal(lua, variable);
		result = Convert.fromLua(lua, -1);
		Lua.pop(lua, 1);

		if(result == null) {
			return false;
		}

		// YES! FINALLY IT WORKS
		//trace('variable: ' + variable + ', ' + result);
		return (result == 'true');
	}
	#end

	override public function stop() {
		#if LUA_ALLOWED
		if(lua == null) {
			return;
		}

		Lua.close(lua);
		lua = null;
		#end
	}

	public static function isOfTypes(value:Any, types:Array<Dynamic>)
	{
		for (type in types)
		{
			if (Std.isOfType(value, type))
				return true;
		}
		return false;
	}

}

class ModchartSprite extends FlxSprite
{
	public var wasAdded:Bool = false;
	//public var isInFront:Bool = false;
	public var animOffsets:Map<String, Array<Float>> = new Map<String, Array<Float>>();

	public function new(?x:Float = 0, ?y:Float = 0)
	{
		super(x, y);
		//antialiasing = ClientPrefs.globalAntialiasing;
	}
}

class ModchartText extends FlxText
{
	public var wasAdded:Bool = false;
	public function new(x:Float, y:Float, text:String, width:Float)
	{
		super(x, y, width, text, 16);
		setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		cameras = [PlayState.instance.camHUD];
		scrollFactor.set();
		borderSize = 2;
	}
}

class DebugLuaText extends FlxText
{
	private var disableTime:Float = 6;
	public var parentGroup:FlxTypedGroup<DebugLuaText>;
	public function new(text:String, parentGroup:FlxTypedGroup<DebugLuaText>) {
		this.parentGroup = parentGroup;
		super(10, 10, 0, text, 16);
		setFormat(Paths.font("vcr.ttf"), 20, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		scrollFactor.set();
		borderSize = 1;
	}

	override function update(elapsed:Float) {
		super.update(elapsed);
		disableTime -= elapsed;
		if(disableTime <= 0) {
			kill();
			parentGroup.remove(this);
			destroy();
		}
		else if(disableTime < 1) alpha = disableTime;
	}

}
