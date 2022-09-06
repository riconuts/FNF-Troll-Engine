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
#if sys
import sys.FileSystem;
#end

class Stage extends FlxTypedGroup<FlxBasic>
{
	public var stageScripts:Array<FunkinHScript> = [];
	var exts = ["hx", "hscript", "hxs"];

	public var foreground = new FlxTypedGroup<FlxBasic>();
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

	public function new(?curStage = "stage")
	{
		super();
		loadStage(curStage);
	}

	function loadStage(curStage:String)
	{
		var newStageData = StageData.getStageFile(curStage);
		if (newStageData != null)
			stageData = newStageData;

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
}