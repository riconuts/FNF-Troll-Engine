package;

import StageData;
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
import scripts.*;

using StringTools;
#if sys
import sys.FileSystem;
#end


class Stage extends FlxTypedGroup<FlxBasic>
{
	public var stageScripts:Array<FunkinHScript> = []; // should only be one script but im gonna leave this array just in case
	var exts = ["hx", "hscript", "hxs"];

	public var foreground = new FlxTypedGroup<FlxBasic>();
	public var curStage = "stage1";
	public var stageData:StageFile = {
		directory: "",
		defaultZoom: 1,
		isPixelStage: false,
		boyfriend: [770, 100],
		girlfriend: [400, 130],
		opponent: [100, 100],
		hide_girlfriend: false,
		camera_boyfriend: [0, 0],
		camera_opponent: [0, 0],
		camera_girlfriend: [0, 0],
		camera_speed: 1
	};

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
		// STAGE SCRIPTS
		var doPush:Bool = false;
		var baseScriptFile:String = 'stages/' + curStage;

		for (ext in exts)
		{
			if (doPush)
				break;
			var baseFile = '$baseScriptFile.$ext';
			var files = [#if MODS_ALLOWED Paths.modFolders(baseFile), #end Paths.getPreloadPath(baseFile)];
			for (file in files)
			{
				if (FileSystem.exists(file))
				{
					var script = FunkinHScript.fromFile(file);
					stageScripts.push(script);
					doPush = true;

					if (doPush)
						break;
				}
			}
		}

		callOnScripts("onLoad", [this, foreground], true, null, null, false);

		return this;
	}

	////
	public function callOnScripts(event:String, args:Array<Dynamic>, ignoreStops:Bool = false, ?exclusions:Array<String>, ?scriptArray:Array<Dynamic>,
			?ignoreSpecialShit:Bool = true)
	{
		if (scriptArray == null)
			scriptArray = stageScripts;
		if (exclusions == null)
			exclusions = [];
		var returnVal:Dynamic = Globals.Function_Continue;
		for (script in scriptArray)
		{
			if (exclusions.contains(script.scriptName)
				|| ignoreSpecialShit /*&& (notetypeScripts.exists(script.scriptName) || eventScripts.exists(script.scriptName))*/)
			{
				continue;
			}
			var ret:Dynamic = script.call(event, args);
			if (ret == Globals.Function_Halt)
			{
				ret = returnVal;
				if (!ignoreStops)
					return returnVal;
			};
			if (ret != Globals.Function_Continue && ret != null)
				returnVal = ret;
		}
		if (returnVal == null)
			returnVal = Globals.Function_Continue;
		return returnVal;
	}

	public function setOnScripts(variable:String, arg:Dynamic, ?scriptArray:Array<Dynamic>)
	{
		if (scriptArray == null)
			scriptArray = stageScripts;
		for (script in scriptArray)
		{
			script.set(variable, arg);
		}
	}

	public function callScript(script:Dynamic, event:String, args:Array<Dynamic>):Dynamic
	{
		if ((script is FunkinScript))
		{
			return callOnScripts(event, args, true, [], [script], false);
		}
		else if ((script is Array))
		{
			return callOnScripts(event, args, true, [], script, false);
		}
		else if ((script is String))
		{
			var scripts:Array<FunkinScript> = [];
			for (scr in stageScripts)
			{
				if (scr.scriptName == script)
					scripts.push(scr);
			}
			return callOnScripts(event, args, true, [], scripts, false);
		}
		return Globals.Function_Continue;
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
		for (mod in Paths.getGlobalMods())
			directories.push(Paths.mods(mod + '/stages/'));
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