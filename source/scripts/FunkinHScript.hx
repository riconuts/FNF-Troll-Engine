package scripts;

import flixel.text.FlxText;
import editors.ChartingState;
import flixel.math.FlxPoint;
import JudgmentManager.Judgment;
import playfields.*;
import flixel.util.FlxColor;
import flixel.FlxG;
import flixel.math.FlxMath;

import lime.app.Application;

import hscript.*;
import scripts.Globals.*;

class FunkinHScript extends FunkinScript
{
	public static final parser:Parser = new Parser();
	public static final defaultVars:Map<String, Dynamic> = new Map<String, Dynamic>();

	public static function init() // BRITISH
	{
		parser.allowMetadata = true;
		parser.allowJSON = true;
		parser.allowTypes = true;

		// parser.preprocesorValues = sowy.Sowy.getDefines();
	}

	public static function parseString(script:String, ?name:String = "Script")
		return parser.parseString(script, name);

	public static function parseFile(file:String, ?name:String)
		return parseString(Paths.getContent(file), (name==null ? file : name));
	
	public static function blankScript(){
		parser.line = 1;
		return new FunkinHScript(parser.parseString(""), false);
	}

	public static function fromString(script:String, ?name:String = "Script", ?additionalVars:Map<String, Any>, ?doCreateCall:Bool=true)
	{
		parser.line = 1;
		var expr:Expr;

		try{
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

		return new FunkinHScript(expr, name, additionalVars, doCreateCall);
	}

	public static function fromFile(file:String, ?name:String, ?additionalVars:Map<String, Any>, ?doCreateCall:Bool = true)
		return fromString(Paths.getContent(file), (name==null ? file : name), additionalVars, doCreateCall);

	////

	var interpreter:Interp = new Interp();
	public function new(parsed:Expr, ?name:String = "Script", ?additionalVars:Map<String, Any>, ?doCreateCall:Bool=true)
	{
		scriptType = 'hscript';
		scriptName = name;

		set("script", this);

		setDefaultVars();

		set("Std", Std);
		set("Type", Type);
		set("Reflect", Reflect);
		set("Math", Math);
		set("StringTools", StringTools);

		set("StringMap", haxe.ds.StringMap);
		set("ObjectMap", haxe.ds.ObjectMap);
		set("IntMap", haxe.ds.IntMap);
		set("EnumValueMap", haxe.ds.EnumValueMap);

		set("FlxG", FlxG);
		set("FlxSprite", FlxSprite);
		set("FlxCamera", FlxCamera);
		set("FlxSound", FlxSound);
		set("FlxMath", flixel.math.FlxMath);
		set("FlxTimer", flixel.util.FlxTimer);
		set("FlxTween", flixel.tweens.FlxTween);
		set("FlxEase", flixel.tweens.FlxEase);
		set("FlxGroup", flixel.group.FlxGroup);
		set("FlxSave", flixel.util.FlxSave); // should probably give it 1 save instead of giving it FlxSave
		set("FlxBar", flixel.ui.FlxBar);
		
		set("FlxText", FlxText); // idk how this wasnt added sooner tbh
		set("FlxTextBorderStyle", FlxTextBorderStyle);
		
		set("FlxRuntimeShader", flixel.addons.display.FlxRuntimeShader);
		set("newShader", Paths.getShader);

		set("getClass", Type.resolveClass);
		set("getEnum", Type.resolveEnum);
		
		set("importClass", importClass);
		set("importEnum", importEnum);
		
		// Abstracts
		set("FlxColor", CustomFlxColor);
		set("FlxPoint", {
			get: FlxPoint.get, 
			weak: FlxPoint.weak
		});
		set("get_controls", ()->{
            return PlayerSettings.player1.controls;
        });
		set("FlxTextAlign", {
			CENTER: FlxTextAlign.CENTER,
			LEFT: FlxTextAlign.LEFT,
			RIGHT: FlxTextAlign.RIGHT,
			JUSTIFY: FlxTextAlign.JUSTIFY,

			fromOpenFL: FlxTextAlign.fromOpenFL,
			toOpenFL: FlxTextAlign.toOpenFL
		});
		set("Judgement", {
			UNJUDGED: Judgment.UNJUDGED,
			TIER1: Judgment.TIER1,
			TIER2: Judgment.TIER2,
			TIER3: Judgment.TIER3,
			TIER4: Judgment.TIER4,
			TIER5: Judgment.TIER5,
			MISS: Judgment.MISS,
			DAMAGELESS_MISS: Judgment.DAMAGELESS_MISS,
			HIT_MINE: Judgment.HIT_MINE,
			MISS_MINE: Judgment.MISS_MINE,
			CUSTOM_MINE: Judgment.CUSTOM_MINE
		});

		for(variable => arg in defaultVars)
			set(variable, arg);
		
		var state:Any = flixel.FlxG.state;
		@:privateAccess
		{
			set("state", state);

			if((state is PlayState) && state == PlayState.instance){
				var state:PlayState = PlayState.instance;

				set("game", state);
				set("global", state.variables);
				set("getInstance", getInstance);

			}
			else if ((state is ChartingState) && state == ChartingState.instance){
				var state:ChartingState = ChartingState.instance;

				set("game", state);
				set("global", state.variables);
				set("getInstance", flixel.FlxG.get_state);

			}
			else{
				set("game", null);
				set("global", null);
				set("getInstance", flixel.FlxG.get_state);

			}
		}

		set("controls", PlayerSettings.player1.controls);

		// FNF-specific things
		set("PlayState", PlayState);
		set("GameOverSubstate", GameOverSubstate);
		set("Song", Song);
        set("BGSprite", BGSprite);
        
		set("Note", Note);
		set("NoteObject", NoteObject);
		set("NoteSplash", NoteSplash);
		set("StrumNote", StrumNote);
		set("PlayField", PlayField);
		set("NoteField", NoteField);

		set("ProxyField", proxies.ProxyField);
		set("ProxySprite", proxies.ProxySprite);
		
		set("AttachedSprite", AttachedSprite);
		set("AttachedText", AttachedText);
		
		set("Paths", Paths);
		set("Conductor", Conductor);
		set("ClientPrefs", ClientPrefs);
		set("CoolUtil", CoolUtil);
		
		set("Character", Character);
		set("HealthIcon", HealthIcon);

		set("Wife3", PlayState.Wife3);
		
		
		set("JudgmentManager", JudgmentManager);

		set("ModManager", modchart.ModManager);
		set("Modifier", modchart.Modifier);
		set("SubModifier", modchart.SubModifier);
		set("NoteModifier", modchart.NoteModifier);
		set("EventTimeline", modchart.EventTimeline);
		set("StepCallbackEvent", modchart.events.StepCallbackEvent);
		set("CallbackEvent", modchart.events.CallbackEvent);
		set("ModEvent", modchart.events.ModEvent);
		set("EaseEvent", modchart.events.EaseEvent);
		set("SetEvent", modchart.events.SetEvent);

		#if !VIDEOS_ALLOWED set("MP4Handler", null);
		#elseif (hxCodec >= "3.0.0") set("MP4Handler", hxcodec.flixel.FlxVideo);
		#elseif (hxCodec >= "2.6.1") set("MP4Handler", hxcodec.VideoHandler);
		#elseif (hxCodec == "2.6.0") set("MP4Handler", VideoHandler);
		#elseif (hxCodec) set("MP4Handler", vlc.MP4Handler); #end
		
		
		set("FunkinHScript", FunkinHScript);

		set("HScriptedHUD", hud.HScriptedHUD);
		set("HScriptModifier", modchart.HScriptModifier);

        set("HScriptState", HScriptState);
		set("HScriptSubstate", HScriptSubstate);

		if (additionalVars != null){
			for (key in additionalVars.keys())
				set(key, additionalVars.get(key));
		}
		
		try
		{
			trace('Loading haxe script: $scriptName');
			interpreter.execute(parsed);
			if (doCreateCall) call('onCreate');
		}
		catch (e:haxe.Exception)
		{
			haxe.Log.trace(e.message, interpreter.posInfos());
		}
	}

	function importClass(className:String)
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
				if(daClass!=null) break;
			}
			if(daClass!=null){
				for(field in Reflect.fields(daClass))
					set(field, Reflect.field(daClass, field));
			}else{
				FlxG.log.error('Could not import class $className');
			}
		}else{
			set(daClassName, Type.resolveClass(className));
		}
	}

	function importEnum(enumName:String)
	{
		// same as importClass, but for enums
		// and it cant have enum.*;
		var splitted:Array<String> = enumName.split(".");
		var daEnum = Type.resolveClass(enumName);
		if (daEnum!=null)
			set(splitted.pop(), daEnum);
	}

	public function executeCode(script:String):Dynamic {
		try
		{
			return interpreter.execute(parser.parseString(script, scriptName));
		}
		catch (e:haxe.Exception)
		{
			haxe.Log.trace(e.message, interpreter.posInfos());
			stop();
		}
		return null;
	}

	override public function stop(){
		// idk if there's really a stop function or anythin for hscript so
		if (interpreter != null && interpreter.variables != null)
			interpreter.variables.clear();

		interpreter = null;
	}

	override public function get(varName:String):Dynamic
	{
		if (interpreter == null)
			return null;

		return interpreter.variables.get(varName);
	}

	override public function set(varName:String, value:Dynamic):Void
	{
		if (interpreter == null)
			return;

		interpreter.variables.set(varName, value);
	}

	public function exists(varName:String):Bool
	{
		if (interpreter == null)
			return false;
		
		return interpreter.variables.exists(varName);
	}

	override public function call(func:String, ?parameters:Array<Dynamic>, ?extraVars:Map<String,Dynamic>):Dynamic
	{
		var returnValue:Dynamic = executeFunc(func, parameters, null, extraVars);

		return returnValue==null ? Function_Continue : returnValue;
	}

	/**
	* Calls a function within the script
	**/
	public function executeFunc(func:String, ?parameters:Array<Dynamic>, ?parentObject:Any, ?extraVars:Map<String, Dynamic>):Dynamic
	{
		var daFunc = get(func);
		if (!Reflect.isFunction(daFunc))
			return null;

		if (parameters == null)
			parameters = [];

		if (extraVars == null) 
			extraVars = [];
		
		if (parentObject != null)
			extraVars.set("this", parentObject);

		var defaultShit:Map<String, Dynamic> = [];
		for (key in extraVars.keys()){
			defaultShit.set(key, get(key)); // Store original values of variables that are being overwritten

			set(key, extraVars.get(key));
		}

		var returnVal:Any = null;
		try{
			returnVal = Reflect.callMethod(parentObject, daFunc, parameters);
		}
		catch (e:haxe.Exception)
		{
			/* 
				When you call something outside the script and it throws an exception this traces the exception message but not the line where it came from
				just the script line that called it in the first place, which is confusing.
			*/
			var errorOrigin:String = "";

			for (stackItem in e.stack){
				switch (stackItem){
					default:
					case FilePos(s, file, line, column):{
						if (!StringTools.contains(StringTools.ltrim(file), "hscript/Interp.hx:")) // stupid.
							errorOrigin = '$file:$line - ';
						
						break;
					}
				}
			}

			haxe.Log.trace(errorOrigin + e.message, interpreter.posInfos());
		}

		for (key in defaultShit.keys())
			set(key, defaultShit.get(key));
		
		return returnVal;
	}
}

// tbh i'd *LIKE* to use a macro for this but im lazy lol

@:noScripting // honestly we could prob use the scripting thing to override shit instead
class HScriptState extends MusicBeatState
{
	public function new(fileName:String, ?additionalVars:Map<String, Any>)
	{
		super(false); // false because the whole point of this state is its scripted lol

		for (filePath in Paths.getFolders("states"))
		{
			var name = filePath + fileName;
			if (!Paths.exists(name)) continue;

			// some shortcuts
			var variables = new Map<String, Dynamic>();
			variables.set("this", this);
			variables.set("add", add);
			variables.set("remove", remove);
            variables.set("insert", insert);
            variables.set("members", members);
            // TODO: use a macro to auto-generate code to variables.set all variables/methods of MusicBeatState


			variables.set("get_controls", function(){
                return PlayerSettings.player1.controls;
            });
            variables.set("controls", PlayerSettings.player1.controls);

			if (additionalVars != null){
				for (key in additionalVars.keys())
					variables.set(key, additionalVars.get(key));
			}

			trace(name);

			script = FunkinHScript.fromFile(name, variables);
			script.scriptName = fileName;

			break;
		}

		if (script == null){
            script = FunkinHScript.blankScript();
			trace('Script file "$fileName" not found!');
			return;
		}

		script.call("onLoad");
	}


    override function create(){
        // UPDATE: realised I should be using the "on" prefix just so if a script needs to call an internal function it doesnt cause issues
        // (Also need to figure out how to give the super to the classes incase that's needed in the on[function] funcs though honestly thats what the post functions are for)
        // I'd love to modify HScript to add override specifically for troll engine hscript
        // THSCript...

        if(script==null){
            FlxG.switchState(new MainMenuState(false));
            return;
        }
        
        // onCreate is used when the script is created so lol
        if(script.call("onStateCreate", []) == Globals.Function_Stop) // idk why you'd return stop on create on a hscriptstate but.. sure
            return;

        super.create(); 
        script.call("onStateCreatePost");
    }

    override function update(e)
	{
		if (script.call("onUpdate", [e]) == Globals.Function_Stop)
			return;

		super.update(e);

		script.call("onUpdatePost", [e]);
	}

	override function beatHit()
	{
		script.call("onBeatHit");
		super.beatHit();
	}
	
	override function stepHit()
	{
		script.call("onStepHit");
		super.stepHit();
	}

    override function closeSubState()
	{
		if (script.call("onCloseSubState") == Globals.Function_Stop)
			return;

		super.closeSubState();

		script.call("onCloseSubStatePost");
	}

    override function onFocus()
	{
		if (script.call("onOnFocus") == Globals.Function_Stop)
			return;

		super.onFocus();

		script.call("onOnFocusPost");
	}
    
    override function onFocusLost()
	{
		if (script.call("onOnFocusLost") == Globals.Function_Stop)
			return;

		super.onFocusLost();

		script.call("onOnFocusLostPost");
	}

    override function onResize(w:Int, h:Int)
	{
		if (script.call("onOnResize", [w, h]) == Globals.Function_Stop)
			return;

		super.onResize(w, h);

		script.call("onOnResizePost", [w, h]);
	}

    override function openSubState(subState:FlxSubState)
	{
		if (script.call("onOpenSubState", [subState]) == Globals.Function_Stop)
			return;

		super.openSubState(subState);

		script.call("onOpenSubStatePost", [subState]);
	}

    override function resetSubState()
	{
		if (script.call("onResetSubState") == Globals.Function_Stop)
			return;

		super.resetSubState();

		script.call("onResetSubStatePost");
	}

    override function startOutro(onOutroFinished:()->Void){
        final currentState = FlxG.state;

		if (script.call("onStartOutro", [onOutroFinished]) == Globals.Function_Stop)
			return;

        if(FlxG.state == currentState) // if "onOutroFinished" wasnt called by the func above ^ then call onOutroFinished for it
            onOutroFinished(); // same as super.startOutro(onOutroFinished)

        script.call("onStartOutroPost", []);
    }

    static var switchToDeprecation = false;

    override function switchTo(s:FlxState)
	{
        if(!script.exists("onSwitchTo"))
            return super.switchTo(s);
    
		if (!switchToDeprecation){
			trace("switchTo is deprecated. Consider using startOutro");
			switchToDeprecation = true;
        }
		if (script.call("onSwitchTo", [s]) == Globals.Function_Stop)
			return false;

		super.switchTo(s);

		script.call("onSwitchToPost", [s]);
        return true;
	}

    override function transitionIn()
	{
		if (script.call("onTransitionIn") == Globals.Function_Stop)
			return;

		super.transitionIn();

		script.call("onTransitionInPost");
	}

    override function transitionOut(?onExit: ()->Void)
	{
		if (script.call("onTransitionOut", [onExit]) == Globals.Function_Stop)
			return;

		super.transitionOut(onExit);

		script.call("onTransitionOutPost", [onExit]);
	}

    override function draw()
	{
		if (script.call("onDraw", []) == Globals.Function_Stop)
			return;

		super.draw();

		script.call("onDrawPost", []);
	}

    override function destroy()
	{
		if (script.call("onDestroy", []) == Globals.Function_Stop)
			return;

		super.destroy();

		script.call("onDestroyPost", []);
	}


    // idk sometimes you wanna override add/remove
	override function add(member:FlxBasic):FlxBasic
	{
		if (script.call("onAdd", [member], []) == Globals.Function_Stop)
			return member;

		super.add(member);

		script.call("onAddPost", [member]);
		return member;
	}

    override function remove(member:FlxBasic, splice:Bool = false):FlxBasic
	{
		if (script.call("onRemove", [member, splice]) == Globals.Function_Stop)
			return member;

		super.remove(member, splice);

		script.call("onRemovePost", [member, splice]);
		return member;
	}

	override function insert(position:Int, member:FlxBasic):FlxBasic
	{
		if (script.call("onInsert", [position, member]) == Globals.Function_Stop)
			return member;

		super.insert(position, member);

		script.call("onInsertPost", [position, member]);

		return member;
	}

}

@:noScripting // honestly we could prob use the scripting thing to override shit instead
class HScriptSubstate extends MusicBeatSubstate
{
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
			variables.set("get_controls", function(){
                return PlayerSettings.player1.controls;
            });
            variables.set("controls", PlayerSettings.player1.controls);
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

// stupidity
class CustomFlxColor{
	// These aren't part of FlxColor but i thought they could be useful
	// honestly we should replace source/flixel/FlxColor.hx or w/e with one with these funcs

	public static function toRGBArray(color:FlxColor) 
		return [color.red, color.green, color.blue];

	public static function lerp(from:FlxColor, to:FlxColor, ratio:Float) // FlxColor.interpolate() exists -_-
		return FlxColor.fromRGBFloat(
			FlxMath.lerp(from.redFloat, to.redFloat, ratio),
			FlxMath.lerp(from.greenFloat, to.greenFloat, ratio),
			FlxMath.lerp(from.blueFloat, to.blueFloat, ratio),
			FlxMath.lerp(from.alphaFloat, to.alphaFloat, ratio)
		);
				
	////
	public static function get_red(color:FlxColor) return color.red;
	public static function get_green(color:FlxColor) return color.green;
	public static function get_blue(color:FlxColor) return color.blue;	

	public static function set_red(color:FlxColor, val){
		color.red = val;		
		return color;
	}
	public static function set_green(color:FlxColor, val){
		color.green = val;
		return color;
	}
	public static function set_blue(color:FlxColor, val){
		color.blue = val;
		return color;
	}

	public static function get_rgb(color:FlxColor) return color.rgb;

	public static function get_redFloat(color:FlxColor) return color.redFloat;
	public static function get_greenFloat(color:FlxColor) return color.greenFloat;
	public static function get_blueFloat(color:FlxColor) return color.blueFloat;	

	public static function set_redFloat(color:FlxColor, val){
		color.redFloat = val;
		return color;
	}
	public static function set_greenFloat(color:FlxColor, val){
		color.greenFloat = val;
		return color;
	}
	public static function set_blueFloat(color:FlxColor, val){
		color.blue = val;
		return color;
	}

	//
	public static function get_hue(color:FlxColor) return color.hue;
	public static function get_saturation(color:FlxColor) return color.saturation;
	public static function get_lightness(color:FlxColor) return color.lightness;
	public static function get_brightness(color:FlxColor) return color.brightness;

	public static function set_hue(color:FlxColor, val){
		color.hue = val;
		return color;
	}
	public static function set_saturation(color:FlxColor, val){
		color.saturation = val;
		return color;
	}
	public static function set_lightness(color:FlxColor, val){
		color.lightness = val;
		return color;
	}
	public static function set_brightness(color:FlxColor, val){
		color.brightness = val;
		return color;
	}

	//
	public static function get_cyan(color:FlxColor) return color.cyan;
	public static function get_magenta(color:FlxColor) return color.magenta;
	public static function get_yellow(color:FlxColor) return color.yellow;
	public static function get_black(color:FlxColor) return color.black;

	public static function set_cyan(color:FlxColor, val){
		color.cyan = val;
		return color;
	}
	public static function set_magenta(color:FlxColor, val){
		color.magenta = val;
		return color;
	}
	public static function set_yellow(color:FlxColor, val){
		color.yellow = val;
		return color;
	}
	public static function set_black(color:FlxColor, val){
		color.black = val;
		return color;
	}

	//
	public static function getAnalogousHarmony(color:FlxColor) return color.getAnalogousHarmony();
	public static function getComplementHarmony(color:FlxColor) return color.getComplementHarmony();
	public static function getSplitComplementHarmony(color:FlxColor) return color.getSplitComplementHarmony();	
	public static function getTriadicHarmony(color:FlxColor) return color.getTriadicHarmony();	

	public static function getDarkened(color:FlxColor) return color.getDarkened();
	public static function getInverted(color:FlxColor) return color.getInverted();
	public static function getLightened(color:FlxColor) return color.getLightened();

	public static function to24Bit(color:FlxColor) return color.to24Bit();

	public static function getColorInfo(color:FlxColor) return color.getColorInfo;	

	public static function toHexString(color:FlxColor) return color.toHexString();
	public static function toWebString(color:FlxColor) return color.toWebString();

	//
	public static final fromCMYK = FlxColor.fromCMYK;
	public static final fromHSL = FlxColor.fromHSL;
	public static final fromHSB = FlxColor.fromHSB;
	public static final fromInt = FlxColor.fromInt;
	public static final fromRGBFloat = FlxColor.fromRGBFloat;
	public static final fromString = FlxColor.fromString;
	public static final fromRGB = FlxColor.fromRGB;

	public static final getHSBColorWheel = FlxColor.getHSBColorWheel;
	public static final interpolate = FlxColor.interpolate;
	public static final gradient = FlxColor.gradient;

	public static final TRANSPARENT:Int = FlxColor.TRANSPARENT;
	public static final BLACK:Int = FlxColor.BLACK;
	public static final WHITE:Int = FlxColor.WHITE;
	public static final GRAY:Int = FlxColor.GRAY;

	public static final GREEN:Int = FlxColor.GREEN;
	public static final LIME:Int = FlxColor.LIME;
	public static final YELLOW:Int = FlxColor.YELLOW;
	public static final ORANGE:Int = FlxColor.ORANGE;
	public static final RED:Int = FlxColor.RED;
	public static final PURPLE:Int = FlxColor.PURPLE;
	public static final BLUE:Int = FlxColor.BLUE;
	public static final BROWN:Int = FlxColor.BROWN;
	public static final PINK:Int = FlxColor.PINK;
	public static final MAGENTA:Int = FlxColor.MAGENTA;
	public static final CYAN:Int = FlxColor.CYAN;
}