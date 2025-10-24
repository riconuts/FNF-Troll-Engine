package funkin.scripts;

import funkin.states.PlayState;
import funkin.scripts.Globals;
import funkin.Conductor;
import funkin.ClientPrefs;

enum abstract ScriptType(String) from String to String {
	var HSCRIPT = "hscript";
}

/** 
	Base class meant to be overridden so you can implement custom script types 
**/
abstract class FunkinScript 
{
	public var scriptName:String;
	public var scriptType:String;

	public function new(scriptName:String = '', scriptType = ''){
		this.scriptName = scriptName;
		this.scriptType = scriptType;
	}

	/**
		Called to set a variable defined in the script
	**/
	abstract public function set(variable:String, data:Dynamic):Void;

	/**
		Called to get a variable defined in the script
	**/
	abstract public function get(key:String):Dynamic;

	/**
		Called to call a function within the script
	**/
	abstract public function call(func:String, ?args:Array<Dynamic>, ?extraVars:Map<String,Dynamic>):Dynamic;

	/**
		Called when the script should be stopped
	**/
	abstract public function stop():Void;

	/**
		Helper function
		Sets a bunch of basic variables for the script depending on the state
	**/
	function setDefaultVars(){
		set("scriptName", scriptName);

		set('Function_Halt', Globals.Function_Halt);
		set('Function_Stop', Globals.Function_Stop);
		set('Function_Continue', Globals.Function_Continue);
		set('Function_StopLua', Globals.Function_Halt); // DEPRECATED

		set('version', "0.5.2h"); // version of psych troll engine is based on
		set('teVersion', StringTools.trim(Main.Version.displayedVersion));
		set("trollEngine", true); // so if any psych mods wanna add troll engine specific stuff well there they go

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
		
		set('curBpm', Conductor.bpm);
		set('crochet', Conductor.crochet);
		set('stepCrochet', Conductor.stepCrochet);

		set('curBeat', 0);
		set('curStep', 0);
		set('curDecBeat', 0.0);
		set('curDecStep', 0.0);

		var currentState = flixel.FlxG.state;

		set("inTitlescreen", (currentState is funkin.states.TitleState));
		set('inGameOver', false);
		set('inChartEditor', false);

		if (currentState is PlayState && currentState == PlayState.instance) {
			set("inPlaystate", true);
			
			set("curSection", -1);
			set("sectionData", null);
		}else{
			set("inPlaystate", false);
			set("showDebugTraces", Main.showDebugTraces);
		}
	}
}