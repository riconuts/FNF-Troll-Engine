package;

import Paths.ContentMetadata;
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
	public var foreground = new FlxTypedGroup<FlxBasic>();

	public var stageScript:FunkinHScript;
	public var spriteMap = new Map<String, FlxBasic>();

	public function new(?StageName = "stage", ?StartScript:Bool = true)
	{
		super();

		if (StageName != null)
			curStage = StageName;
		
		var newStageData = StageData.getStageFile(curStage);
		if (newStageData != null)
			stageData = newStageData;

		if (StartScript)
			startScript(false);
	}

	var stageBuilt:Bool = false;
	public function startScript(?BuildStage = false)
	{
		if (stageScript != null)
		{
			trace("Stage script already started!");
			return;
		}

		var baseFile:String = 'stages/$curStage.hscript';
	
		for (file in [#if MODS_ALLOWED Paths.modFolders(baseFile), #end Paths.getPreloadPath(baseFile)])
		{
			if (!Paths.exists(file))
				continue;
		
			stageScript = FunkinHScript.fromFile(file);

			// define variables lolol
			stageScript.set("add", add);
			stageScript.set("stage", this);
			stageScript.set("this", this);
			stageScript.set("foreground", foreground);
			
			if (BuildStage){
				stageScript.call("onLoad", [this, foreground]);
				stageBuilt = true;
			}

			break;
		}
	}

	public function buildStage()
	{
		if (!stageBuilt){
			
			if (stageScript != null){
				if (stageScript is FunkinLua)
					stageScript.call("onCreate", []);
				else
					stageScript.call("onLoad", [this, foreground]);
			}

			stageBuilt = true;
		}

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
	public static function getTitleStages(modsOnly = false):Array<String>{
	
		var daList:Array<String> = [];
		#if MODS_ALLOWED
		var modsList = Paths.getText('data/stageList.txt', false);
		if (modsList != null)
			for (shit in modsList.split("\n"))daList.push(shit);
		
		var path = Paths.modFolders("metadata.json");
		var rawJson:Null<String> = Paths.getContent(path);

		if (rawJson != null && rawJson.length > 0)
		{
			var daJson:Dynamic = Json.parse(rawJson);
			if (Reflect.field(daJson, "titleStages") != null)
			{
				var data:ContentMetadata = cast daJson;
				for (stage in data.titleStages)
				{
					daList.push(stage);
				}
			}
		}

		#end
		return daList;
	}

	/**
		Returns an array with every stage in the stages folder(s).
	**/
	public static function getAllStages(modsOnly = false):Array<String>{
		var stages:Array<String> = [];

		for (folderPath in Paths.getFolders("stages", true)){
			if (FileSystem.exists(folderPath) && FileSystem.isDirectory(folderPath)){

				for (fileName in FileSystem.readDirectory(folderPath)){
					if (!fileName.endsWith(".json")) continue;

					var name = fileName.substr(0, fileName.length - 5);
					if(!stages.contains(name))stages.push(name);
				}
			}
		}

		if (!modsOnly){
			var folderPath = Paths.getPath('stages/');
			if (FileSystem.exists(folderPath) && FileSystem.isDirectory(folderPath)){

				for (fileName in FileSystem.readDirectory(folderPath)){
					if (!fileName.endsWith(".json")) continue;
					
					var name = fileName.substr(0, fileName.length - 5);
					if (!stages.contains(name))stages.push(name);
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
