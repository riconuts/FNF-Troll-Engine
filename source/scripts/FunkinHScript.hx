package scripts;

#if !macro
import flixel.util.FlxColor;
import flixel.FlxG;
import flixel.system.FlxSound;
import flixel.tweens.*;

import lime.utils.Assets;
import lime.app.Application;
#end

import hscript.*;
import scripts.Globals.*;

class FunkinHScript extends FunkinScript
{
	static var parser:Parser = new Parser();
	public static var defaultVars:Map<String,Dynamic> = new Map<String, Dynamic>();


	public static function init() // BRITISH
	{
		parser.allowMetadata = true;
		parser.allowJSON = true;
		parser.allowTypes = true;
	}

	public static function fromString(script:String, ?name:String = "Script", ?additionalVars:Map<String, Any>)
	{
		parser.line = 1;
		var expr:Expr;
		try
		{
			expr = parser.parseString(script, name);
		}
		catch (e:haxe.Exception)
		{
			var errMsg = 'Error parsing hscript! '#if hscriptPos + '$name:' + parser.line + ', ' #end + e.message;
			#if desktop
			Application.current.window.alert(errMsg, "Error on haxe script!");
			#end
			trace(errMsg);

			expr = parser.parseString("", name);
		}
		return new FunkinHScript(expr, name, additionalVars);
	}
	public static function parseString(script:String, ?name:String = "Script")
	{
		return parser.parseString(script, name);
	}

	public static function fromFile(file:String, ?name:String, ?additionalVars:Map<String, Any>)
	{
		if (name == null)
			name = file;
		return fromString(Paths.getContent(file), name, additionalVars);
	}
	public static function parseFile(file:String, ?name:String)
	{
		return parseString(Paths.getContent(file), name != null ? name : file);
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

		set("Std", Std);
		set("Type", Type);
		set("Reflect", Reflect);
		set("Math", Math);
		set("script", this);
		set("StringTools", StringTools);
		set("scriptTrace", scriptTrace);

		set("newMap", function(){
			return new Map<Dynamic, Dynamic>();
		});
		// this is stupid, there has to be a better way
		set("newTypedGroup", function(maxSize:Int = 0){
			return new flixel.group.FlxGroup.FlxTypedGroup<FlxBasic>(maxSize);
		});

		set("Assets", Assets);
		set("OpenFlAssets", openfl.utils.Assets);

		set("FlxG", flixel.FlxG);
		set("state", flixel.FlxG.state);
		set("FlxSprite", flixel.FlxSprite);
		set("NoteObject", NoteObject);
		set("FlxCamera", flixel.FlxCamera);
		set("PlayField", PlayField);
		set("NoteField", PlayField.NoteField);

		set("FlxMath", flixel.math.FlxMath);
		set("FlxSound", FlxSound);
		set("FlxTimer", flixel.util.FlxTimer);
		set("FlxColor", { // same case as maps?
			toRGBArray: function(color:FlxColor){return [color.red, color.green, color.blue];},
			setHue: function(color:FlxColor, hue){
				color.hue = hue;
				return color;
			},

			fromCMYK: FlxColor.fromCMYK,
			fromHSL: FlxColor.fromHSL,
			fromHSB: FlxColor.fromHSB,
			fromInt: FlxColor.fromInt,
			fromRGBFloat: FlxColor.fromRGBFloat,
			fromString: FlxColor.fromString,
			fromRGB: FlxColor.fromRGB
		});
		set("FlxTween", FlxTween);
		set("FlxEase", FlxEase);
		set("FlxSave", flixel.util.FlxSave); // should probably give it 1 save instead of giving it FlxSave
		set("FlxBar", flixel.ui.FlxBar);

		set("getClass", Type.resolveClass);
		set("getEnum", Type.resolveEnum);
		@:privateAccess
		{
			if(FlxG.state == PlayState.instance){
				var state:PlayState = PlayState.instance;
				set("initPlayfield", state.initPlayfield);
				set("newPlayField", function(){
					var field = new PlayField(state.modManager);
					field.modNumber = state.playfields.members.length;
					field.cameras = state.playfields.cameras;
					state.initPlayfield(field);
					state.playfields.add(field);
					return field;
				});
			}
		}
		set("importClass", function(className:String)
		{
			// importClass("flixel.util.FlxSort") should give you FlxSort.byValues, etc
			// whereas importClass("scripts.Globals.*") should give you Function_Stop, Function_Continue, etc
			// i would LIKE to do like.. flixel.util.* but idk if I can get everything in a namespace
			var classSplit:Array<String> = className.split(".");
			var daClassName = classSplit[classSplit.length-1]; // last one
			if (daClassName == '*'){
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
		set("addHaxeLibrary", function(libName:String, ?libPackage:String = ''){
			try{
				var str:String = '';
				if (libPackage.length > 0)
					str = libPackage + '.';

				set(libName, Type.resolveClass(str + libName));
			}
			catch (e:Dynamic){

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

		set("importScript", function(){
			// unimplemented lol
			throw new haxe.exceptions.NotImplementedException();
		});

		for(variable => arg in defaultVars){
			set(variable, arg);
		}

		// Util
		set("makeSprite", function(?x:Float, ?y:Float, ?image:String)
		{
			var spr = new FlxSprite(x, y);
			spr.antialiasing = ClientPrefs.globalAntialiasing;

			return image == null ? spr : spr.loadGraphic(Paths.image(image));
		});
		set("makeAnimatedSprite", function(?x:Float, ?y:Float, ?image:String, ?spriteType:String){
			var spr = new FlxSprite(x, y);
			spr.antialiasing = ClientPrefs.globalAntialiasing;

			if(image != null && image.length > 0){
				/*
				switch(spriteType)
				{
					case "texture" | "textureatlas" | "tex":
						spr.frames = AtlasFrameMaker.construct(image);
					case "texture_noaa" | "textureatlas_noaa" | "tex_noaa":
						spr.frames = AtlasFrameMaker.construct(image, null, true);
					case "packer" | "packeratlas" | "pac":
						spr.frames = Paths.getPackerAtlas(image);
					default:*/
						spr.frames = Paths.getSparrowAtlas(image);
				//}
			}

			return spr;
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

		set("HScriptModifier", modchart.HScriptModifier);
		set("SubModifier", modchart.SubModifier);
		set("NoteModifier", modchart.NoteModifier);
		set("EventTimeline", modchart.EventTimeline);
		set("ModManager", modchart.ModManager);
		set("Modifier", modchart.Modifier);
		set("StepCallbackEvent", modchart.events.StepCallbackEvent);
		set("CallbackEvent", modchart.events.CallbackEvent);
		set("ModEvent", modchart.events.ModEvent);
		set("EaseEvent", modchart.events.EaseEvent);
		set("SetEvent", modchart.events.SetEvent);

		set("StageData", Stage.StageData);
		#if VIDEOS_ALLOWED
		set("MP4Handler", vlc.MP4Handler);
		#end
		set("PlayState", PlayState);
		set("FunkinLua", FunkinLua);
		set("FunkinHScript", FunkinHScript);
		set("HScriptSubstate", HScriptSubstate);
		set("GameOverSubstate", GameOverSubstate);
		set("HealthIcon", HealthIcon);
		var currentState = flixel.FlxG.state;

		if ((currentState is PlayState)){
			var state:PlayState = cast currentState;

			set("game", currentState);
			set("global", state.variables);
			set("getInstance", function(){
				return getInstance();
			});
		}else{
			set("getInstance", function(){
				return flixel.FlxG.state;
			});
		}

		if (additionalVars != null){
			for (key in additionalVars.keys())
				set(key, additionalVars.get(key));
		}

		try{
			interpreter.execute(parsed);
			call('onCreate');
			trace('Loaded script: $scriptName');
		}catch(e:haxe.Exception){
			Sys.println('${e.details()}');
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

	override public function call(func:String, ?parameters:Array<Dynamic>, ?extraVars:Map<String,Dynamic>):Dynamic
	{
		var returnValue:Dynamic = executeFunc(func, parameters, this, extraVars);
		if (returnValue == null) return Function_Continue;

		return returnValue;
	}

	/**
	* Calls a function within the script
	**/
	public function executeFunc(func:String, ?parameters:Array<Dynamic>, ?theObject:Any, ?extraVars:Map<String, Dynamic>):Dynamic
	{
		var daFunc = get(func);
		if (!Reflect.isFunction(daFunc))
			return null;

		if (extraVars == null) 
			extraVars = [];
		
		if (theObject != null)
			extraVars.set("this", theObject);

		var defaultShit:Map<String, Dynamic> = [];
		for (key in extraVars.keys()){
			defaultShit.set(key, get(key)); // Store original values of variables that are being overwritten

			set(key, extraVars.get(key));
		}

		var returnVal:Any = null;
		try{
			returnVal = Reflect.callMethod(theObject, daFunc, parameters);
		}catch (e:haxe.Exception){
			#if sys
			Sys.println(e.message);
			#end
		}

		for (key in defaultShit.keys())
			set(key, defaultShit.get(key));
		
		return returnVal;
	}
}

#if !macro
class HScriptSubstate extends MusicBeatSubstate
{
	public var script:FunkinHScript;

	public function new(ScriptName:String, ?additionalVars:Map<String, Any>)
	{
		super();

		var fileName = 'substates/$ScriptName.hscript';

		for (filePath in [#if MODS_ALLOWED Paths.modFolders(fileName), Paths.mods(fileName), #end Paths.getPreloadPath(fileName)])
		{
			if (!Paths.exists(filePath)) continue;

			// some shortcuts
			var variables = new Map<String, Dynamic>();
			variables.set("this", this);
			variables.set("add", add);
			variables.set("remove", remove);
			variables.set("getControls", function(){ return controls;}); // i get it now
			variables.set("close", close);

			if (additionalVars != null){
				for (key in additionalVars.keys())
					variables.set(key, additionalVars.get(key));
			}

			script = FunkinHScript.fromFile(filePath, variables);
			script.scriptName = ScriptName;

			break;
		}

		if (script == null){
			trace('Script file "$ScriptName" not found!');
			return close();
		}

		script.call("onLoad");
	}

	override function update(e)
	{
		if (script.call("onUpdate", [e]) == Globals.Function_Stop)
			return;

		super.update(e);
		script.call("onUpdatePost", [e]);
	}

	override function close(){
		if (script != null)
			script.call("onClose");

		return super.close();
	}

	override function destroy()
	{
		if (script != null){
			script.call("onDestroy");
			script.stop();
		}
		script = null;

		return super.destroy();
	}
}
#end