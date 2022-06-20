package scripts;

import flixel.system.FlxSound;
import flixel.FlxG;
import hscript.Expr;
import hscript.Interp;
import hscript.Parser;
import lime.utils.AssetType;
import lime.utils.Assets;
import sys.io.File;
import scripts.Globals.*;
class FunkinHScript extends FunkinScript
{
	static var parser:Parser = new Parser();

	public static function init() // BRITISH
	{
		parser.allowMetadata = true;
		parser.allowJSON = true;
		parser.allowTypes = true;
	}

	public static function fromFile(file:String, ?name:String, ?additionalVars:Map<String, Any>)
	{
		if (name == null)
			name = file;
		return fromString(File.getContent(file), name, additionalVars);
	}

	public static function fromString(script:String, ?name:String = "Script", ?additionalVars:Map<String, Any>)
	{
		var expr:Expr;
		try{
			expr = parser.parseString(script, name);
		}catch(e:haxe.Exception){
			trace(e.details());
			FlxG.log.error("Error parsing hscript: " + e.message);
			expr = parser.parseString("", name);
		}
		return new FunkinHScript(expr, name, additionalVars);
	}

	public static function parseFile(file:String, ?name:String)
	{
		if (name == null)
			name = file;
		return parseString(File.getContent(file), name);
	}

	public static function parseString(script:String, ?name:String = "Script")
	{
		return parser.parseString(script, name);
	}

	var interpreter:Interp = new Interp();

	override public function scriptTrace(text:String) {
		var posInfo = interpreter.posInfos();
		haxe.Log.trace(text, posInfo);
	}
	public function new(parsed:Expr, ?name:String = "Script", ?additionalVars:Map<String, Any>)
	{
		scriptType = 'hscript';
		scriptName = name;

		setDefaultVars();
		set("FlxG", flixel.FlxG);
		set("FlxSprite", flixel.FlxSprite);
		set("Std", Std);
		set("state", flixel.FlxG.state);
		set("Math", Math);
		set("Assets", Assets);
		set("FlxSound", FlxSound);
		set("OpenFlAssets", openfl.utils.Assets);
		set("FlxCamera", flixel.FlxCamera);
		set("FlxTimer", flixel.util.FlxTimer);
		set("FlxTween", flixel.tweens.FlxTween);
		set("FlxEase", flixel.tweens.FlxEase);
		set("FlxSave", flixel.util.FlxSave); // should probably give it 1 save instead of giving it FlxSave
		set("FlxBar", flixel.ui.FlxBar);
		set("StringTools", StringTools);
		set("trace", function(text:String)
		{
			scriptTrace(text);
		});
		set("getClass", function(className:String)
		{
			return Type.resolveClass(className);
		});
		set("getEnum", function(enumName:String)
		{
			return Type.resolveEnum(enumName);
		});
		set("importClass", function(className:String)
		{
			// importClass("flixel.util.FlxSort") should give you FlxSort.byValues, etc
			// whereas importClass("scripts.Globals.*") should give you Function_Stop, Function_Continue, etc
			// i would LIKE to do like.. flixel.util.* but idk if I can get everything in a namespace
			var classSplit:Array<String> = className.split(".");
			var daClassName = classSplit[classSplit.length-1]; // last one
			if (daClassName=='*'){
				var daClass = Type.resolveClass(className);
				while(classSplit.length > 0 && daClass==null){
					daClassName = classSplit.pop();
					daClass = Type.resolveClass(classSplit.join("."));
					if(daClass!=null)break;
				}
				if(daClass!=null){
					for(field in Reflect.fields(daClass)){
						set(field, Reflect.field(daClass, field));
					}
				}else{
					FlxG.log.error('Could not import class ${daClass}');
					scriptTrace('Could not import class ${daClass}');
				}
			}else{
				var daClass = Type.resolveClass(className);
				set(daClassName, daClass);	
			}
		});

		set("importEnum", function(enumName:String)
		{
			// same as importClass, but for enums
			// and it cant have enum.*;
			var splitted:Array<String> = enumName.split(".");
			var daEnum = Type.resolveClass(enumName);
			if (daEnum!=null)
				set(splitted.pop(), daEnum);
			
		});
		
		// FNF-specific things
		set("Paths", Paths);
		set("AttachedSprite", AttachedSprite);
		set("AttachedText", AttachedText);
		set("Conductor", Conductor);
		set("Note", Note);
		set("Song", Song);
		set("StrumNote", StrumNote);
		set("NoteSplash", NoteSplash);
		set("ClientPrefs", ClientPrefs);
		set("Alphabet", Alphabet);
		set("BGSprite", BGSprite);
		set("CoolUtil", CoolUtil);
		set("Character", Character);
		set("Boyfriend", Boyfriend);
		set("StageData", StageData);
		set("DialogueBox", DialogueBoxPsych);
		set("FlxVideo", FlxVideo);
		set("PlayState", PlayState);
		set("PlayField", PlayField);
		set("FunkinLua", FunkinLua);
		set("FunkinHScript", FunkinHScript);
		set("GameOverSubstate", GameOverSubstate);
		set("HealthIcon", HealthIcon);
		var currentState = flixel.FlxG.state;
		if ((currentState is PlayState)){
			var state:PlayState = cast currentState;
			set("global", state.hscriptGlobals);
			set("getInstance", function()
			{
				return getInstance();
			});
		}else{
			set("getInstance", function()
			{
				return flixel.FlxG.state;
			});
		}


		if (additionalVars != null)
		{
			for (key in additionalVars.keys())
				set(key, additionalVars.get(key));
		}

		trace('loaded hscript ${scriptName}');
		try{
			interpreter.execute(parsed);
		}catch(e:haxe.Exception){
			trace(e.details());
			FlxG.log.error("Error running hscript: " + e.message);
		}
	}

	override public function stop(){
		// idk if there's really a stop function or anythin for hscript so
		interpreter = null;
	}

	override public function get(varName:String): Dynamic
	{
		return interpreter.variables.get(varName);
	}

	override public function set(varName:String, value:Dynamic):Void
	{
		interpreter.variables.set(varName, value);
	}

	public function exists(varName:String)
	{
		return interpreter.variables.exists(varName);
	}
	
	override public function call(func:String, ?parameters:Array<Dynamic>):Dynamic
	{
		var returnValue:Dynamic = executeFunc(func, parameters, this);
		if (returnValue == null)
			return Function_Continue;
		return returnValue;
	}

	public function executeFunc(func:String, ?parameters:Array<Dynamic>, ?theObject:Any, ?extraVars:Map<String,Dynamic>):Dynamic
	{
		if (extraVars == null)
			extraVars=[];
		if (exists(func))
		{
			var daFunc = get(func);
			if (Reflect.isFunction(daFunc))
			{
				var returnVal:Any = null;
				var defaultShit:Map<String,Dynamic>=[];
				for (key in extraVars.keys()){
					defaultShit.set(key, get(key));
					set(key, extraVars.get(key));
				}
				try
				{
					returnVal = Reflect.callMethod(theObject, daFunc, parameters);
				}
				catch (e:haxe.Exception)
				{
					Sys.println(e.message);
				}
				for (key in defaultShit.keys())
				{
					set(key, defaultShit.get(key));
				}
				return returnVal;
			}
		}
		return null;
	}
}
