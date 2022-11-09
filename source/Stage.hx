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


class Stage extends FlxTypedGroup<FlxBasic>
{
	public var stageScripts:Array<FunkinScript> = [];
	public var hscriptArray:Array<FunkinHScript> = [];
	public var luaArray:Array<FunkinLua> = [];
	
	public var curStage = "stage1";
	public var stageData:StageFile = {
		directory: "",
		defaultZoom: 1,
		boyfriend: [770, 100],
		girlfriend: [400, 130],
		opponent: [100, 100],
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
		#if MODS_ALLOWED
		var doPush:Bool = false;
		var baseScriptFile:String = 'stages/' + curStage;

		for (ext in ["hscript" #if LUA_ALLOWED , "lua" #end])
		{
			if (doPush)
				break;
			var baseFile = '$baseScriptFile.$ext';
			var files = [#if MODS_ALLOWED Paths.modFolders(baseFile), #end Paths.getPreloadPath(baseFile)];
			for (file in files)
			{
				if (FileSystem.exists(file))
				{
					#if LUA_ALLOWED
					if (ext == 'lua'){
						var script = new FunkinLua(file);
						luaArray.push(script);
						stageScripts.push(script);
						doPush = true;
						script.call("onCreate", []);
					}
					else
					#end
					{
						var script = FunkinHScript.fromFile(file);
						hscriptArray.push(script);
						stageScripts.push(script);
						script.call("onLoad", [this, foreground]);
						doPush = true;
					}
					if (doPush)
						break;
				}
			}
		}
		#end

		return this;
	}

	override function destroy(){
		for (script in stageScripts)
			script.stop();
		super.destroy();
	}

	////
	public static function getStageList():Array<String>{
		var stages:Array<String> = [];

		#if MODS_ALLOWED
		var directories:Array<String> = [
			Paths.mods('stages/'),
			Paths.mods(Paths.currentModDirectory + '/stages/'),
			Paths.getPreloadPath('stages/')
		];
		#else
		var directories:Array<String> = [Paths.getPreloadPath('stages/')];
		#end
		
		var tempMap:Map<String, Bool> = new Map<String, Bool>();
		var stageFile:Array<String> = CoolUtil.coolTextFile(Paths.txt('stageList'));
		for (i in 0...stageFile.length)
		{ // Prevent duplicates
			var stageToCheck:String = stageFile[i];
			if (!tempMap.exists(stageToCheck))
			{
				stages.push(stageToCheck);
			}
			tempMap.set(stageToCheck, true);
		}
		#if MODS_ALLOWED
		for (i in 0...directories.length)
		{
			var directory:String = directories[i];
			if (FileSystem.exists(directory))
			{
				for (file in FileSystem.readDirectory(directory))
				{
					var path = haxe.io.Path.join([directory, file]);
					if (!FileSystem.isDirectory(path) && file.endsWith('.json'))
					{
						var stageToCheck:String = file.substr(0, file.length - 5);
						if (!tempMap.exists(stageToCheck))
						{
							tempMap.set(stageToCheck, true);
							stages.push(stageToCheck);
						}
					}
				}
			}
		}
		#end

		if (stages.length < 1)
			stages.push('stage');

		return stages;
	}
}

typedef StageFile = {
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

	@:optional var pixel_size:Null<Float>;
	@:optional var preloadStrings:Array<String>;
	#if sys
	@:optional var preload:Array<Cache.AssetPreload>; // incase you would like to add more information, though you shouldnt really need to
	#end
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
		if(stageFile == null) { //preventing crashes
			forceNextDirectory = '';
		} else {
			forceNextDirectory = stageFile.directory;
		}
	}

	public static function getStageFile(stage:String):StageFile {
		var rawJson:String = null;
		var path:String = Paths.getPreloadPath('stages/' + stage + '.json');

		#if MODS_ALLOWED
		var modPath:String = Paths.modFolders('stages/' + stage + '.json');
		if(FileSystem.exists(modPath)) {
			rawJson = File.getContent(modPath);
		} else if(FileSystem.exists(path)) {
			rawJson = File.getContent(path);
		}
		#else
		if(Assets.exists(path)) {
			rawJson = Assets.getText(path);
		}
		#end
		else
		{
			return null;
		}
		return cast Json.parse(rawJson);
	}
}
