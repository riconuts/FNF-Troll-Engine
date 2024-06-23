package funkin.scripts;

import hscript.*;

import funkin.hscript.*;
import funkin.scripts.Globals.*;

import lime.app.Application;
import haxe.ds.StringMap;
import flixel.FlxG;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;

import funkin.states.PlayState;
import funkin.states.MusicBeatState;
import funkin.states.MusicBeatSubstate;
import funkin.data.JudgmentManager;

import funkin.objects.*;
import funkin.objects.playfields.*;
import funkin.states.PlayState.RatingSprite;

import funkin.input.PlayerSettings;

using StringTools;

class FunkinHScript extends FunkinScript
{
	public static final parser:Parser = new Parser();
	public static final defaultVars:Map<String, Dynamic> = new Map<String, Dynamic>();

	public static function init() // BRITISH
	{
		parser.allowMetadata = true;
		parser.allowJSON = true;
		parser.allowTypes = true;

		final definitions:Map<String, String> = funkin.macros.Sowy.getDefines();
		for (k => v in definitions)
			parser.preprocesorValues.set(k, v);

		parser.preprocesorValues.set("TROLL_ENGINE", Main.semanticVersion);
	}

	public static function parseString(script:String, ?name:String = "Script")
		return parser.parseString(script, name);

	public static function parseFile(file:String, ?name:String)
		return parseString(Paths.getContent(file), (name == null ? file : name));

	public static function blankScript()
	{
		parser.line = 1;
		return new FunkinHScript(parser.parseString(""), false);
	}

	public static function fromString(script:String, ?name:String = "Script", ?additionalVars:Map<String, Any>, ?doCreateCall:Bool = true)
	{
		parser.line = 1;
		var expr:Expr;

		try
		{
			expr = parser.parseString(script, name);
		}
		catch (e:haxe.Exception)
		{
			var errMsg = 'Error parsing hscript! ' #if hscriptPos + '$name:' + parser.line + ', ' #end + e.message;
			#if desktop
			Application.current.window.alert(errMsg, "Error on haxe script!");
			#end
			trace(errMsg);

			expr = parser.parseString("", name);
		}

		return new FunkinHScript(expr, name, additionalVars, doCreateCall);
	}

	public static function fromFile(file:String, ?name:String, ?additionalVars:Map<String, Any>, ?doCreateCall:Bool = true)
		return fromString(Paths.getContent(file), (name == null ? file : name), additionalVars, doCreateCall);

	////
	var interpreter:Interp = new Interp();

	public function new(?parsed:Expr, ?name:String = "Script", ?additionalVars:Map<String, Any>, ?doCreateCall:Bool = true)
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

		// for some reason these cant be imported so	// dce removes unused classes no matter what ;_;
		set("FlxParticle", flixel.effects.particles.FlxParticle);
		set("FlxTypedEmitter", flixel.effects.particles.FlxEmitter.FlxTypedEmitter);
		set("FlxSkewedSprite", flixel.addons.effects.FlxSkewedSprite);

		set("getClass", Type.resolveClass);
		set("getEnum", Type.resolveEnum);

		set("importClass", importClass);
		set("importEnum", importEnum);

		// Abstracts
		// TODO: maybe add SemanticVersion tho tbh prob not needed

		set("FlxColor", CustomFlxColor);
		set("FlxPoint", {
			get: FlxPoint.get,
			weak: FlxPoint.weak
		});
		set("get_controls", () ->
		{
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
		/*
		// These are also defined on FlxTween. Get them from there.
		set("FlxTweenType", {
			PERSIST: flixel.tweens.FlxTween.FlxTweenType.PERSIST,
			LOOPING: flixel.tweens.FlxTween.FlxTweenType.LOOPING,
			PINGPONG: flixel.tweens.FlxTween.FlxTweenType.PINGPONG,
			ONESHOT: flixel.tweens.FlxTween.FlxTweenType.ONESHOT,
			BACKWARD: flixel.tweens.FlxTween.FlxTweenType.BACKWARD
		}); 
		 */
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

		set("controls", PlayerSettings.player1.controls);

		// FNF-specific things
		set("PlayState", PlayState);
		set("GameOverSubstate", funkin.states.GameOverSubstate);
		set("Song", funkin.data.Song);
		set("BGSprite", funkin.objects.BGSprite);
		set("RatingSprite", RatingSprite);

		set("Note", funkin.objects.Note);
		set("NoteObject", funkin.objects.NoteObject);
		set("NoteSplash", funkin.objects.NoteSplash);
		set("StrumNote", funkin.objects.StrumNote);
		set("PlayField", PlayField);
		set("NoteField", NoteField);

		set("ProxyField", funkin.objects.proxies.ProxyField);
		set("ProxySprite", funkin.objects.proxies.ProxySprite);

		set("FlxSprite3D", funkin.objects.FlxSprite3D);

		set("AttachedSprite", funkin.objects.AttachedSprite);
		set("AttachedText", funkin.objects.AttachedText);

		set("Paths", funkin.Paths);
		set("Conductor", funkin.Conductor);
		set("ClientPrefs", funkin.ClientPrefs);
		set("CoolUtil", funkin.CoolUtil);

		set("Character", funkin.objects.Character);
		set("HealthIcon", funkin.objects.hud.HealthIcon);

		set("JudgmentManager", JudgmentManager);
		set("Wife3", Wife3);

		set("ModManager", funkin.modchart.ModManager);
		set("Modifier", funkin.modchart.Modifier);
		set("SubModifier", funkin.modchart.SubModifier);
		set("NoteModifier", funkin.modchart.NoteModifier);
		set("EventTimeline", funkin.modchart.EventTimeline);
		set("StepCallbackEvent", funkin.modchart.events.StepCallbackEvent);
		set("CallbackEvent", funkin.modchart.events.CallbackEvent);
		set("ModEvent", funkin.modchart.events.ModEvent);
		set("EaseEvent", funkin.modchart.events.EaseEvent);
		set("SetEvent", funkin.modchart.events.SetEvent);

		// TODO: create a compatibility wrapper for the various versions
		// (so you can use any version of hxcodec and use the same versions)

		#if !VIDEOS_ALLOWED
		set("hxcodec", "0");
		set("MP4Handler", null);
		set("MP4Sprite", null);
		#else
		#if (hxvlc)
		set("hxcodec", "0");
		set("hxvlc", "1.0.0");
		set("MP4Handler", hxvlc.flixel.FlxVideo);
		set("MP4Sprite", hxvlc.flixel.FlxVideoSprite);
		#else
		set("hxvlc", "0");
		#end
		#if (hxCodec >= "3.0.0")
		set("hxcodec", "3.0.0");
		set("MP4Handler", hxcodec.flixel.FlxVideo);
		set("MP4Sprite", hxcodec.flixel.FlxVideoSprite); // idk how hxcodec 3.0.0 works :clueless:
		#elseif (hxCodec >= "2.6.1")
		set("hxcodec", "2.6.1");
		set("MP4Handler", hxcodec.VideoHandler);
		set("MP4Sprite", hxcodec.VideoSprite);
		#elseif (hxCodec == "2.6.0")
		set("hxcodec", "2.6.0");
		set("MP4Handler", VideoHandler);
		set("MP4Sprite", VideoSprite);
		#elseif (hxCodec)
		set("hxcodec", "1.0.0");
		set("MP4Handler", vlc.MP4Handler);
		set("MP4Sprite", vlc.MP4Sprite);
		#end
		#end
		set("FunkinHScript", FunkinHScript);

		set("HScriptedHUD", funkin.objects.hud.HScriptedHUD);
		set("HScriptModifier", funkin.modchart.HScriptModifier);

		set("HScriptedState", HScriptedState);
		set("HScriptedSubstate", HScriptedSubState);

		set("global", Globals.variables);

		for (variable => arg in defaultVars)
			set(variable, arg);

		if (additionalVars != null)
		{
			for (key => value in additionalVars)
				set(key, value);
		}

		if (parsed != null)
			run(parsed, doCreateCall);
	}

	public function run(parsed:Expr, doCreateCall:Bool=false){
		var returnValue:Dynamic = null;
        try
		{
			trace('Running haxe script: $scriptName');
			returnValue = interpreter.execute(parsed);
			if (doCreateCall)
				call('onCreate');
		}
		catch (e:haxe.Exception)
		{
			haxe.Log.trace(e.message, interpreter.posInfos());
            //stop();
		}
        return returnValue;
    }

	/**
		Helper function
		Sets a bunch of basic variables for the script depending on the state
	**/
	override function setDefaultVars() {
		super.setDefaultVars();

		var currentState = flixel.FlxG.state;
		
		set("state", currentState);
		set("game", currentState);
		
		// set("inTitlescreen", (currentState is TitleState)); // hmmm
		if (currentState is PlayState){
			set("getInstance", getInstance);
		}else{
			@:privateAccess
			set("getInstance", FlxG.get_state);
		}
	}

	function importClass(className:String)
	{
		// importClass("flixel.util.FlxSort") should give you FlxSort.byValues, etc
		// whereas importClass("scripts.Globals.*") should give you Function_Stop, Function_Continue, etc
		// i would LIKE to do like.. flixel.util.* but idk if I can get everything in a namespace
		var classSplit:Array<String> = className.split(".");
		var daClassName = classSplit[classSplit.length - 1]; // last one

		if (daClassName == '*')
		{
			var daClass = Type.resolveClass(className);

			while (classSplit.length > 0 && daClass == null)
			{
				daClassName = classSplit.pop();
				daClass = Type.resolveClass(classSplit.join("."));
				if (daClass != null)
					break;
			}
			if (daClass != null)
			{
				for (field in Reflect.fields(daClass))
					set(field, Reflect.field(daClass, field));
			}
			else
			{
				FlxG.log.error('Could not import funkin.class $className');
			}
		}
		else
		{
			set(daClassName, Type.resolveClass(className));
		}
	}

	function importEnum(enumName:String)
	{
		// same as importClass, but for enums
		// and it cant have enum.*;
		// EDIT this doesnt work
		var splitted:Array<String> = enumName.split(".");
		var daEnum = Type.resolveClass(enumName);
		if (daEnum != null)
			set(splitted.pop(), daEnum);
	}

	public inline function executeCode(script:String):Dynamic{
        parser.line = 1;
		return run(parser.parseString(script, scriptName));
    }
	

	override public function stop()
	{
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

	override public function call(func:String, ?parameters:Array<Dynamic>, ?extraVars:Map<String, Dynamic>):Dynamic
	{
        var returnValue:Dynamic = null;
        
        try{
		    returnValue = executeFunc(func, parameters, null, extraVars); // I AM SICK OF THIS CASUING CRASHES
        }catch(e:haxe.Exception){
			trace('HScript error (${scriptName}): ${e.message}');
        }
		return returnValue == null ? Function_Continue : returnValue;
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
		for (key in extraVars.keys())
		{
			defaultShit.set(key, get(key)); // Store original values of variables that are being overwritten

			set(key, extraVars.get(key));
		}

		var returnVal:Any = null;
		try
		{
			returnVal = Reflect.callMethod(parentObject, daFunc, parameters);
		}
		catch (e:haxe.Exception)
		{
			/* 
				When you call something outside the script and it throws an exception this traces the exception message but not the line where it came from
				just the script line that called it in the first place, which is confusing.
			 */
			var errorOrigin:String = "";

			for (stackItem in e.stack)
			{
				switch (stackItem)
				{
					default:
					case FilePos(s, file, line, column):
						{
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
class HScriptedState extends MusicBeatState
{
	public var stateScript:FunkinHScript;
	public var scriptPath:Null<String> = null;

	public function new(?script:FunkinHScript, ?doCreateCall:Bool = true)
	{
		super(false); // false because the whole point of this state is its scripted lol

		if (script == null)
			this.stateScript = FunkinHScript.blankScript();
		else
			this.stateScript = script;

		// some shortcuts
		stateScript.set("this", this);
		stateScript.set("add", this.add);
		stateScript.set("remove", this.remove);
		stateScript.set("insert", this.insert);
		stateScript.set("members", this.members);
		// TODO: use a macro to auto-generate code to variables.set all variables/methods of MusicBeatState

		stateScript.set("get_controls", () -> return PlayerSettings.player1.controls);
		stateScript.set("controls", PlayerSettings.player1.controls);

		if (doCreateCall != false)
			stateScript.call("onLoad");
	}

	public static function fromString(str:String, ?doCreateCall:Bool = true)
	{
		return new HScriptedState(FunkinHScript.fromString(str, "HScriptedState", null, doCreateCall));
	}

	public static function fromPath(scriptPath:String, ?doCreateCall:Bool = true)
	{
		var script:Null<FunkinHScript> = null;

		if (scriptPath != null) {
			script = FunkinHScript.fromFile(scriptPath, scriptPath, variables, false);
		} else {
			trace('State script file "$scriptPath" not found!');
		}

		var state = new HScriptedState(script, doCreateCall);
		state.scriptPath = scriptPath;
		return state;
	}

	public static function fromFile(fileName:String, ?doCreateCall:Bool = true)
	{
		var scriptPath:Null<String> = null;

		if (!fileName.endsWith(".hscript"))
			fileName += ".hscript";

		for (folderPath in Paths.getFolders("states"))
		{
			var filePath = folderPath + fileName;

			if (Paths.exists(filePath)){
				scriptPath = filePath;
				break;
			}
		}

		return fromPath(scriptPath);
	}

	override function create()
	{
		// UPDATE: realised I should be using the "on" prefix just so if a script needs to call an internal function it doesnt cause issues
		// (Also need to figure out how to give the super to the classes incase that's needed in the on[function] funcs though honestly thats what the post functions are for)
		// I'd love to modify HScript to add override specifically for troll engine hscript
		// THSCript...

		// onCreate is used when the script is created so lol
		if (stateScript.call("onStateCreate", []) == Globals.Function_Stop) // idk why you'd return stop on create on a HScriptedState but.. sure
			return;

		super.create();
		stateScript.call("onStateCreatePost");
	}

	override function update(e)
	{
		#if debug
		if (FlxG.keys.justPressed.F7)
			if (scriptPath != null && !FlxG.keys.pressed.CONTROL)
				FlxG.switchState(new HScriptedState(scriptPath));
			else
				FlxG.switchState(new FreeplayState());
		#end

		if (stateScript.call("onUpdate", [e]) == Globals.Function_Stop)
			return;

		super.update(e);

		stateScript.call("onUpdatePost", [e]);
	}

	override function beatHit()
	{
		stateScript.call("onBeatHit");
		super.beatHit();
	}

	override function stepHit()
	{
		stateScript.call("onStepHit");
		super.stepHit();
	}

	override function closeSubState()
	{
		if (stateScript.call("onCloseSubState") == Globals.Function_Stop)
			return;

		super.closeSubState();

		stateScript.call("onCloseSubStatePost");
	}

	override function onFocus()
	{
		if (stateScript.call("onOnFocus") == Globals.Function_Stop)
			return;

		super.onFocus();

		stateScript.call("onOnFocusPost");
	}

	override function onFocusLost()
	{
		if (stateScript.call("onOnFocusLost") == Globals.Function_Stop)
			return;

		super.onFocusLost();

		stateScript.call("onOnFocusLostPost");
	}

	override function onResize(w:Int, h:Int)
	{
		if (stateScript.call("onOnResize", [w, h]) == Globals.Function_Stop)
			return;

		super.onResize(w, h);

		stateScript.call("onOnResizePost", [w, h]);
	}

	override function openSubState(subState:FlxSubState)
	{
		if (stateScript.call("onOpenSubState", [subState]) == Globals.Function_Stop)
			return;

		super.openSubState(subState);

		stateScript.call("onOpenSubStatePost", [subState]);
	}

	override function resetSubState()
	{
		if (stateScript.call("onResetSubState") == Globals.Function_Stop)
			return;

		super.resetSubState();

		stateScript.call("onResetSubStatePost");
	}

	override function startOutro(onOutroFinished:() -> Void)
	{
		final currentState = FlxG.state;

		if (stateScript.call("onStartOutro", [onOutroFinished]) == Globals.Function_Stop)
			return;

		if (FlxG.state == currentState) // if "onOutroFinished" wasnt called by the func above ^ then call onOutroFinished for it
			onOutroFinished(); // same as super.startOutro(onOutroFinished)

		stateScript.call("onStartOutroPost", []);
	}

	static var switchToDeprecation = false;

	override function switchTo(s:FlxState)
	{
		if (!stateScript.exists("onSwitchTo"))
			return super.switchTo(s);

		if (!switchToDeprecation)
		{
			trace("switchTo is deprecated. Consider using startOutro");
			switchToDeprecation = true;
		}
		if (stateScript.call("onSwitchTo", [s]) == Globals.Function_Stop)
			return false;

		super.switchTo(s);

		stateScript.call("onSwitchToPost", [s]);
		return true;
	}

	override function transitionIn()
	{
		if (stateScript.call("onTransitionIn") == Globals.Function_Stop)
			return;

		super.transitionIn();

		stateScript.call("onTransitionInPost");
	}

	override function transitionOut(?onExit:() -> Void)
	{
		if (stateScript.call("onTransitionOut", [onExit]) == Globals.Function_Stop)
			return;

		super.transitionOut(onExit);

		stateScript.call("onTransitionOutPost", [onExit]);
	}

	override function draw()
	{
		if (stateScript.call("onDraw", []) == Globals.Function_Stop)
			return;

		super.draw();

		stateScript.call("onDrawPost", []);
	}

	override function destroy()
	{
		if (stateScript.call("onDestroy", []) == Globals.Function_Stop)
			return;

		super.destroy();

		stateScript.call("onDestroyPost", []);
	}

	// idk sometimes you wanna override add/remove
	override function add(member:FlxBasic):FlxBasic
	{
		if (stateScript.call("onAdd", [member], []) == Globals.Function_Stop)
			return member;

		super.add(member);

		stateScript.call("onAddPost", [member]);
		return member;
	}

	override function remove(member:FlxBasic, splice:Bool = false):FlxBasic
	{
		if (stateScript.call("onRemove", [member, splice]) == Globals.Function_Stop)
			return member;

		super.remove(member, splice);

		stateScript.call("onRemovePost", [member, splice]);
		return member;
	}

	override function insert(position:Int, member:FlxBasic):FlxBasic
	{
		if (stateScript.call("onInsert", [position, member]) == Globals.Function_Stop)
			return member;

		super.insert(position, member);

		stateScript.call("onInsertPost", [position, member]);

		return member;
	}
}

@:noScripting // honestly we could prob use the scripting thing to override shit instead
class HScriptedSubState extends MusicBeatSubstate
{
	public var stateScript:FunkinHScript;
	public var scriptPath:Null<String> = null;

	public function new(?script:FunkinHScript, ?doCreateCall:Bool = true)
	{
		super();

		if (script==null)
			this.stateScript = FunkinHScript.blankScript();
		else
			this.stateScript = script;

		// some shortcuts
		stateScript.set("this", this);
		stateScript.set("add", this.add);
		stateScript.set("remove", this.remove);
		stateScript.set("insert", this.insert);
		stateScript.set("members", this.members);
		stateScript.set("close", close);

		// TODO: use a macro to auto-generate code to variables.set all variables/methods of MusicBeatState

		stateScript.set("get_controls", () -> return PlayerSettings.player1.controls);
		stateScript.set("controls", PlayerSettings.player1.controls);

		if (doCreateCall != false)
			stateScript.call("onLoad");
	}

	public static function fromString(str:String, ?doCreateCall:Bool = true)
	{
		return new HScriptedSubState(FunkinHScript.fromString(str, "HScriptedState", null, doCreateCall));
	}

	public static function fromFile(fileName:String, ?doCreateCall:Bool = true)
	{
		var scriptPath:Null<String> = null;

		if (!fileName.endsWith(".hscript"))
			fileName += ".hscript";

		for (folderPath in Paths.getFolders("states"))
		{
			var filePath = folderPath + fileName;

			if (Paths.exists(filePath)){
				scriptPath = filePath;
				break;
			}
		}

		var script:Null<FunkinHScript> = null;

		if (scriptPath != null){
			script = FunkinHScript.fromFile(scriptPath, scriptPath, variables, false);			
		}else{
			trace('Script file "$fileName" not found!');
		}

		var state = new HScriptedSubState(script, doCreateCall);
		state.scriptPath = scriptPath;
		return state;
	}

	override function update(e)
	{
		if (stateScript.call("onUpdate", [e]) == Globals.Function_Stop)
			return;

		super.update(e);

		stateScript.call("onUpdatePost", [e]);
	}

	override function close()
	{
		if (stateScript != null)
			stateScript.call("onClose");

		return super.close();
	}

	override function destroy()
	{
		if (stateScript != null)
		{
			stateScript.call("onDestroy");
			stateScript.stop();
		}
		stateScript = null;

		return super.destroy();
	}
}

// stupidity
class CustomFlxColor
{
	// These aren't part of FlxColor but i thought they could be useful
	// honestly we should replace source/flixel/FlxColor.hx or w/e with one with these funcs
	public static function toRGBArray(color:FlxColor)
		return [color.red, color.green, color.blue];

	public static function lerp(from:FlxColor, to:FlxColor, ratio:Float) // FlxColor.interpolate() exists -_-
		return FlxColor.fromRGBFloat(FlxMath.lerp(from.redFloat, to.redFloat, ratio), FlxMath.lerp(from.greenFloat, to.greenFloat, ratio),
			FlxMath.lerp(from.blueFloat, to.blueFloat, ratio), FlxMath.lerp(from.alphaFloat, to.alphaFloat, ratio));

	////
	public static function get_red(color:FlxColor)
		return color.red;

	public static function get_green(color:FlxColor)
		return color.green;

	public static function get_blue(color:FlxColor)
		return color.blue;

	public static function set_red(color:FlxColor, val:Int)
	{
		color.red = val;
		return color;
	}

	public static function set_green(color:FlxColor, val:Int)
	{
		color.green = val;
		return color;
	}

	public static function set_blue(color:FlxColor, val:Int)
	{
		color.blue = val;
		return color;
	}

	public static function get_rgb(color:FlxColor)
		return color.rgb;

	public static function get_redFloat(color:FlxColor)
		return color.redFloat;

	public static function get_greenFloat(color:FlxColor)
		return color.greenFloat;

	public static function get_blueFloat(color:FlxColor)
		return color.blueFloat;

	public static function set_redFloat(color:FlxColor, val:Float)
	{
		color.redFloat = val;
		return color;
	}

	public static function set_greenFloat(color:FlxColor, val:Float)
	{
		color.greenFloat = val;
		return color;
	}

	public static function set_blueFloat(color:FlxColor, val:Float)
	{
		color.blueFloat = val;
		return color;
	}

	//
	public static function get_hue(color:FlxColor)
		return color.hue;

	public static function get_saturation(color:FlxColor)
		return color.saturation;

	public static function get_lightness(color:FlxColor)
		return color.lightness;

	public static function get_brightness(color:FlxColor)
		return color.brightness;

	public static function set_hue(color:FlxColor, val:Float)
	{
		color.hue = val;
		return color;
	}

	public static function set_saturation(color:FlxColor, val:Float)
	{
		color.saturation = val;
		return color;
	}

	public static function set_lightness(color:FlxColor, val:Float)
	{
		color.lightness = val;
		return color;
	}

	public static function set_brightness(color:FlxColor, val:Float)
	{
		color.brightness = val;
		return color;
	}

	//
	public static function get_cyan(color:FlxColor)
		return color.cyan;

	public static function get_magenta(color:FlxColor)
		return color.magenta;

	public static function get_yellow(color:FlxColor)
		return color.yellow;

	public static function get_black(color:FlxColor)
		return color.black;

	public static function set_cyan(color:FlxColor, val:Float)
	{
		color.cyan = val;
		return color;
	}

	public static function set_magenta(color:FlxColor, val:Float)
	{
		color.magenta = val;
		return color;
	}

	public static function set_yellow(color:FlxColor, val:Float)
	{
		color.yellow = val;
		return color;
	}

	public static function set_black(color:FlxColor, val:Float)
	{
		color.black = val;
		return color;
	}

	//
	public static function getAnalogousHarmony(color:FlxColor)
		return color.getAnalogousHarmony();

	public static function getComplementHarmony(color:FlxColor)
		return color.getComplementHarmony();

	public static function getSplitComplementHarmony(color:FlxColor)
		return color.getSplitComplementHarmony();

	public static function getTriadicHarmony(color:FlxColor)
		return color.getTriadicHarmony();

	public static function getDarkened(color:FlxColor)
		return color.getDarkened();

	public static function getInverted(color:FlxColor)
		return color.getInverted();

	public static function getLightened(color:FlxColor)
		return color.getLightened();

	public static function to24Bit(color:FlxColor)
		return color.to24Bit();

	public static function getColorInfo(color:FlxColor)
		return color.getColorInfo;

	public static function toHexString(color:FlxColor)
		return color.toHexString();

	public static function toWebString(color:FlxColor)
		return color.toWebString();

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