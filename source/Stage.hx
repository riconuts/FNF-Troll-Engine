package;

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
	var hide_girlfriend:Bool;
	var camera_boyfriend:Array<Float>;
	var camera_opponent:Array<Float>;
	var camera_girlfriend:Array<Float>;
	var camera_speed:Null<Float>;

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
	public var stageScripts:Array<FunkinScript> = [];
	public var hscriptArray:Array<FunkinHScript> = [];
	#if LUA_ALLOWED
	public var luaArray:Array<FunkinLua> = [];
	#end
	
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
			var files = [#if MODS_ALLOWED Paths.modFolders(baseFile), #end Paths.getPreloadPath(baseFile)];
			for (file in files)
			{
				if (Paths.exists(file))
				{
					#if LUA_ALLOWED
					if (ext == 'hscript'){
					#end
						var script = FunkinHScript.fromFile(file);
						hscriptArray.push(script);
						stageScripts.push(script);

						// define variables lolol
						script.set("add", add);
						script.set("stage", this);
						script.set("foreground", foreground);
						
						script.call("onLoad", [this, foreground]);
						doPush = true;
					#if LUA_ALLOWED
					} else if (ext == 'lua'){
						var script = new FunkinLua(file);
						luaArray.push(script);
						stageScripts.push(script);
						
						script.call("onCreate", []);
						doPush = true;
					}
					else
					#end

					if (doPush)
						break;
				}
			}
		#if LUA_ALLOWED
		}
		#end
		return this;
	}

	override function destroy(){
		for (script in stageScripts)
			script.stop();
		super.destroy();
	}

	//// Stages of the currently loaded mod.
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
