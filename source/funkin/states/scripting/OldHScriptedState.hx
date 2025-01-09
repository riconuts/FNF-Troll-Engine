package funkin.states.scripting;

import funkin.input.PlayerSettings;
import funkin.scripts.Globals;
import funkin.scripts.FunkinHScript;

using StringTools;

// tbh i'd *LIKE* to use a macro for this but im lazy lol

@:noScripting // honestly we could prob use the scripting thing to override shit instead
class OldHScriptedState extends MusicBeatState
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
		return new OldHScriptedState(FunkinHScript.fromString(str, "OldHScriptedState", null, doCreateCall));
	}

	public static function fromPath(scriptPath:String, ?doCreateCall:Bool = true)
	{
		var script:Null<FunkinHScript> = null;

		if (scriptPath != null) {
			script = FunkinHScript.fromFile(scriptPath, scriptPath, null, false);
		} else {
			trace('State script file "$scriptPath" not found!');
		}

		var state = new OldHScriptedState(script, doCreateCall);
		state.scriptPath = scriptPath;
		return state;
	}

	public static function fromFile(fileName:String, ?doCreateCall:Bool = true)
	{
		var scriptPath:Null<String> = null;

		var hasExtension = false;
		for(ext in Paths.HSCRIPT_EXTENSIONS){
			if(fileName.endsWith('.$ext')){
				hasExtension = true;
				break;
			}
		}
		
		if (!hasExtension)
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
		if (stateScript.call("onStateCreate", []) == Globals.Function_Stop) // idk why you'd return stop on create on a OldHScriptedState but.. sure
			return;

		super.create();
		stateScript.call("onStateCreatePost");
	}

	override function update(e)
	{
		#if debug
		if (FlxG.keys.justPressed.F7)
			if (scriptPath != null && !FlxG.keys.pressed.CONTROL)
				FlxG.switchState(OldHScriptedState.fromPath(scriptPath));
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

	#if ALLOW_DEPRECATION
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
	#end
	override function transitionIn(?onEnter:() -> Void)
	{
		if (stateScript.call("onTransitionIn", [onEnter]) == Globals.Function_Stop)
			return;

		super.transitionIn(onEnter);

		stateScript.call("onTransitionInPost", [onEnter]);
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