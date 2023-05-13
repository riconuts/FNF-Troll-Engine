package;

import scripts.FunkinLua.ModchartSprite;
import scripts.FunkinLua.ModchartText;
#if LUA_ALLOWED
import llua.Convert;
import llua.Lua;
import llua.LuaL;
import llua.State;
#end

import Song;
import flixel.FlxBasic;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.addons.effects.FlxTrail;
import flixel.addons.effects.chainable.FlxWaveEffect;
import flixel.group.*;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.group.FlxSpriteGroup;
import flixel.math.FlxPoint;
import flixel.system.FlxSound;
import flixel.text.FlxText;
import flixel.tweens.FlxTween;
import haxe.Json;
import haxe.format.JsonParser;
import scripts.*;

using StringTools;

#if MODS_ALLOWED
import sys.FileSystem;
import sys.io.File;
#else
import openfl.utils.Assets;
#end

typedef StageFile =
{
	var directory:String;
	var defaultZoom:Float;

	var boyfriend:Array<Dynamic>;
	var girlfriend:Array<Dynamic>;
	var opponent:Array<Dynamic>;
	@:optional var hide_girlfriend:Bool;

	@:optional var camera_boyfriend:Array<Float>;
	@:optional var camera_opponent:Array<Float>;
	@:optional var camera_girlfriend:Array<Float>;
	@:optional var camera_speed:Null<Float>;

	@:optional var bg_color:Null<String>;

	@:optional var camera_stage:Array<Float>; // for the title screen
	@:optional var pixel_size:Null<Float>;
	@:optional var preloadStrings:Array<String>;
	#if sys
	@:optional var preload:Array<Cache.AssetPreload>; // incase you would like to add more information, though you shouldnt really need to
	#end
}

class Stage extends FlxTypedGroup<FlxBasic>
{
	public var stageScript:FunkinScript;
	
	public var curStage = "stage1";
	public var stageData:StageFile = {
		directory: "",
		defaultZoom: 0.8,
		boyfriend: [500, 100],
		girlfriend: [0, 100],
		opponent: [-500, 100],
		hide_girlfriend: false,
		camera_boyfriend: [0, 0],
		camera_opponent: [0, 0],
		camera_girlfriend: [0, 0],
		camera_speed: 1
	};

	public var spriteMap = new Map<String, FlxBasic>();
	public var foreground = new FlxTypedGroup<FlxBasic>();

	public function new(?StageName = "stage")
	{
		super();

		if (StageName != null)
			curStage = StageName;
		
		var newStageData = StageData.getStageFile(curStage);
		if (newStageData != null)
			stageData = newStageData;
	}

	public function buildStage()
	{
		var doPush:Bool = false;
		var baseScriptFile:String = 'stages/' + curStage;

		#if LUA_ALLOWED
		for (ext in ["hscript" , "lua"])
		{
			if (doPush)
				break;
			var baseFile = '$baseScriptFile.$ext';
		#else
			var baseFile = '$baseScriptFile.hscript';
		#end
			for (file in [#if MODS_ALLOWED Paths.modFolders(baseFile), #end Paths.getPreloadPath(baseFile)])
			{
				if (!Paths.exists(file))
					continue;
				
				#if LUA_ALLOWED
				if (ext == 'hscript'){
				#end
					stageScript = FunkinHScript.fromFile(file);

					// define variables lolol
					stageScript.set("add", add);
					stageScript.set("stage", this);
					stageScript.set("this", this);
					stageScript.set("foreground", foreground);
					
					stageScript.call("onLoad", [this, foreground]);
					break;
				#if LUA_ALLOWED
				} else if (ext == 'lua'){
					stageScript = new FunkinLua(file, true);
					#if PE_MOD_COMPATIBILITY
					var lua:FunkinLua = cast stageScript;
					var state = lua.lua;
					Lua_helper.add_callback(state, "addLuaSprite", function(tag:String, front:Bool = false) {
						// TODO: put modchartSprites n shit outside of PlayState
						// maybe put it into FunkinLua so that stages made for psych mods will work on the title screen, etc

						if (PlayState.instance == null || !PlayState.instance.modchartSprites.exists(tag))
							return;

						var spr:FunkinLua.ModchartSprite = PlayState.instance.modchartSprites.get(tag);
						if(spr.wasAdded)
							return;

						if (front)
							foreground.add(spr);			
						else
							add(spr);
						
						
						spr.wasAdded = true;	
					});

					Lua_helper.add_callback(state, "removeLuaSprite", function(tag:String, destroy:Bool = true)
					{
						if (!PlayState.instance.modchartSprites.exists(tag))
						{
							return;
						}

						var pee:ModchartSprite = PlayState.instance.modchartSprites.get(tag);
						if (destroy)
						{
							pee.kill();
						}

						if (pee.wasAdded)
						{
							remove(pee, true);
							foreground.remove(pee, true);
							pee.wasAdded = false;
						}

						if (destroy)
						{
							pee.destroy();
							PlayState.instance.modchartSprites.remove(tag);
						}
					});

					Lua_helper.add_callback(state, "addLuaText", function(tag:String)
					{
						if (PlayState.instance.modchartTexts.exists(tag))
						{
							var shit:ModchartText = PlayState.instance.modchartTexts.get(tag);
							if (!shit.wasAdded)
							{
								foreground.add(shit);
								shit.wasAdded = true;
								// trace('added a thing: ' + tag);
							}
						}
					});

					Lua_helper.add_callback(state, "removeLuaText", function(tag:String, destroy:Bool = true)
					{
						if (!PlayState.instance.modchartTexts.exists(tag))
						{
							return;
						}

						var pee:ModchartText = PlayState.instance.modchartTexts.get(tag);
						if (destroy)
						{
							pee.kill();
						}

						if (pee.wasAdded)
						{
							foreground.remove(pee, true);
							pee.wasAdded = false;
						}

						if (destroy)
						{
							pee.destroy();
							PlayState.instance.modchartTexts.remove(tag);
						}
					});
					#end
					stageScript.call("onCreate", []);
					stageScript.call("onLoad", []);

					break;
				#end
				}				
			}
		#if LUA_ALLOWED
		}
		#end
		
		return this;
	}

	override function destroy()
	{
		if (stageScript != null){
			stageScript.call("onDestroy");
			stageScript.stop();
		}
		
		super.destroy();
	}

	/**
		Return an array with the names in the stageList file(s).
	**/ 
	public static function getStageList(modsOnly = false):Array<String>{
		var rawList:Null<String> = modsOnly ? null : Paths.getText('data/stageList.txt', true);

		#if MODS_ALLOWED
		var modsList = Paths.getText('data/stageList.txt', false);
		if (modsList != null){
			if (rawList != null)
				rawList += "\n" + modsList;
			else
				rawList = modsList;
		}
		#end
		
		if (rawList == null)
			return [];

		var stages:Array<String> = [];

		for (i in rawList.trim().split('\n'))
		{
			var modStage = i.trim();
			if (!stages.contains(modStage))
				stages.push(modStage);
		}

		return stages;
	}

	/**
		Returns an array with every stage in the stages folder(s).
	**/
	public static function getAllStages(modsOnly = false):Array<String>{
		var stages:Array<String> = [];

		var folderPath = Paths.mods('${Paths.currentModDirectory}/stages/');
		if (FileSystem.exists(folderPath) && FileSystem.isDirectory(folderPath)){

			for (fileName in FileSystem.readDirectory(folderPath)){
				if (!fileName.endsWith(".json")) continue;

				stages.push(fileName.substr(0, fileName.length - 5));
			}
		}

		if (!modsOnly){
			var folderPath = Paths.getPath('stages/');
			if (FileSystem.exists(folderPath) && FileSystem.isDirectory(folderPath)){

				for (fileName in FileSystem.readDirectory(folderPath)){
					if (!fileName.endsWith(".json")) continue;

					stages.push(fileName.substr(0, fileName.length - 5));
				}
			}
		}

		return stages;
	}

	/*
	//// stage -> modDirectory
	public static function getStageMap():Map<String, String>
	{
		var directories:Array<String> = [
			#if MODS_ALLOWED
			Paths.mods(Paths.currentModDirectory + '/stages/'),
			Paths.mods('stages/'),
			#end
			Paths.getPreloadPath('stages/')
		];

		var theMap:Map<String, String> = new Map();

		return theMap;
	}
	*/
}

class StageData {
	public static var forceNextDirectory:String = null;

	public static function loadDirectory(SONG:SwagSong) {
		var stage:String = '';

		if(SONG.stage != null)
			stage = SONG.stage;
		else 
			stage = 'stage';

		var stageFile:StageFile = getStageFile(stage);

		// preventing crashes
		forceNextDirectory = stageFile == null ? '' : stageFile.directory;
	}

	public static function getStageFile(stage:String):StageFile {
		var rawJson:String = null;
		var path:String = Paths.getPreloadPath('stages/' + stage + '.json');

		#if MODS_ALLOWED
		var modPath:String = Paths.modFolders('stages/' + stage + '.json');

		if(FileSystem.exists(modPath))
			rawJson = File.getContent(modPath);
		else if(FileSystem.exists(path))
			rawJson = File.getContent(path);

		#else
		if(Assets.exists(path))
			rawJson = Assets.getText(path);
		#end
		else
			return null;

		return cast Json.parse(rawJson);
	}
}
