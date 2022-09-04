package editors;

import StageData;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.group.FlxSpriteGroup;
import flixel.math.FlxPoint;
import scripts.*;
import scripts.FunkinLua;

using StringTools;
#if sys
import sys.FileSystem;
#end

class StageEditorState extends MusicBeatState{
	public static var curStage = "stage1";

	public var camGame:FlxCamera;
	public var camHUD:FlxCamera;
	public var camOverlay:FlxCamera;
	public var camOther:FlxCamera;
    
	public var defaultCamZoom:Float = FlxG.initialZoom;
	public var cameraSpeed:Float = 1;

    public var boyfriend:Character;
	public var dad:Character;
	public var gf:Character;

	public var boyfriendGroup:FlxSpriteGroup;
	public var dadGroup:FlxSpriteGroup;
	public var gfGroup:FlxSpriteGroup;

	public var BF_X:Float = 770;
	public var BF_Y:Float = 100;
	public var DAD_X:Float = 100;
	public var DAD_Y:Float = 100;
	public var GF_X:Float = 400;
	public var GF_Y:Float = 130;

	public var boyfriendCameraOffset:Array<Float> = null;
	public var opponentCameraOffset:Array<Float> = null;
	public var girlfriendCameraOffset:Array<Float> = null;

	var stageData:StageFile;

	var exts = [
		"hx", "hscript", "hxs" // hscript is cross platform i think?
        #if LUA_ALLOWED , "lua" #end
    ];
	var funkyScripts:Array<FunkinScript> = [];
	var luaArray:Array<FunkinLua> = [];
	var hscriptArray:Array<FunkinHScript> = [];

	override function create()
	{
		camGame = new FlxCamera();
		camHUD = new FlxCamera();
		camOverlay = new FlxCamera();
		camOther = new FlxCamera();
		camOverlay.bgColor.alpha = 0;
		camHUD.bgColor.alpha = 0;
		camOther.bgColor.alpha = 0;

		FlxG.cameras.reset(camGame);
		FlxG.cameras.add(camHUD, false);
		FlxG.cameras.add(camOverlay, false);
		FlxG.cameras.add(camOther, false);

		FlxG.cameras.setDefaultDrawTarget(camGame, true);

		loadStage(curStage);
        
		callOnScripts('onCreatePost', []);
		super.create();
    }
    override function update(elapsed:Float){
		if (controls.BACK)
			MusicBeatState.switchState(new MainMenuState());
		
        super.update(elapsed);
    }

	function loadStage(curStage:String)
	{
		stageData = StageData.getStageFile(curStage);
		if (stageData == null)
		{ // Stage couldn't be found, create a dummy stage for preventing a crash
			stageData = {
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
		}
		setStageData(stageData);

		add(gfGroup);
		add(dadGroup);
		add(boyfriendGroup);

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
					if (ext == 'lua')
					{
						var script = new FunkinLua(file);
						luaArray.push(script);
						funkyScripts.push(script);
						doPush = true;
					}
					else
					{
						var script = FunkinHScript.fromFile(file);
						hscriptArray.push(script);
						funkyScripts.push(script);
						doPush = true;
					}
					if (doPush)
						break;
				}
			}
		}

		if (!stageData.hide_girlfriend)
		{
			gf = new Character(0, 0, "gf");
			startCharacterPos(gf);
			gf.scrollFactor.set(0.95, 0.95);
			gfGroup.add(gf);
			startCharacterLua(gf.curCharacter);
		}

		dad = new Character(0, 0, "bf");
		startCharacterPos(dad, true);
		dadGroup.add(dad);
		startCharacterLua(dad.curCharacter);
		//dadMap.set(dad.curCharacter, dad);

		boyfriend = new Boyfriend(0, 0, "bf");
		startCharacterPos(boyfriend);
		boyfriendGroup.add(boyfriend);
		startCharacterLua(boyfriend.curCharacter);
		//boyfriendMap.set(boyfriend.curCharacter, boyfriend);

		var camPos:FlxPoint = new FlxPoint(girlfriendCameraOffset[0], girlfriendCameraOffset[1]);
		if(gf != null)
		{
			camPos.x += gf.getGraphicMidpoint().x + gf.cameraPosition[0];
			camPos.y += gf.getGraphicMidpoint().y + gf.cameraPosition[1];
		}else{
			camPos.set(opponentCameraOffset[0], opponentCameraOffset[1]);
			camPos.x += dad.getGraphicMidpoint().x + dad.cameraPosition[0];
			camPos.y += dad.getGraphicMidpoint().y + dad.cameraPosition[1];
		}

		if(dad.curCharacter.startsWith('gf')) {
			dad.setPosition(GF_X, GF_Y);
			if(gf != null)
				gf.visible = false;
		}
	}

    function setStageData(stageData:StageFile){
		defaultCamZoom *= stageData.defaultZoom;
		FlxG.camera.zoom = defaultCamZoom;

		//isPixelStage = stageData.isPixelStage;

		BF_X = stageData.boyfriend[0];
		BF_Y = stageData.boyfriend[1];
		GF_X = stageData.girlfriend[0];
		GF_Y = stageData.girlfriend[1];
		DAD_X = stageData.opponent[0];
		DAD_Y = stageData.opponent[1];

		if(stageData.camera_speed != null)
			cameraSpeed = stageData.camera_speed;

		boyfriendCameraOffset = stageData.camera_boyfriend;
		if(boyfriendCameraOffset == null) //Fucks sake should have done it since the start :rolling_eyes:
			boyfriendCameraOffset = [0, 0];

		opponentCameraOffset = stageData.camera_opponent;
		if(opponentCameraOffset == null)
			opponentCameraOffset = [0, 0];

		girlfriendCameraOffset = stageData.camera_girlfriend;
		if(girlfriendCameraOffset == null)
			girlfriendCameraOffset = [0, 0];

		if(boyfriendGroup==null)
			boyfriendGroup = new FlxSpriteGroup(BF_X, BF_Y);
		else{
			boyfriendGroup.x = BF_X;
			boyfriendGroup.y = BF_Y;
		}
		if(dadGroup==null)
			dadGroup = new FlxSpriteGroup(DAD_X, DAD_Y);
		else{
			dadGroup.x = DAD_X;
			dadGroup.y = DAD_Y;
		}

		if(gfGroup==null)
			gfGroup = new FlxSpriteGroup(GF_X, GF_Y);
		else{
			gfGroup.x = GF_X;
			gfGroup.y = GF_Y;
		}
	}

	function startCharacterPos(char:Character, ?gfCheck:Bool = false)
	{
		if (gfCheck && char.curCharacter.startsWith('gf'))
		{ // IF DAD IS GIRLFRIEND, HE GOES TO HER POSITION
			char.setPosition(GF_X, GF_Y);
			char.scrollFactor.set(0.95, 0.95);
			char.danceEveryNumBeats = 2;
		}
		char.x += char.positionArray[0];
		char.y += char.positionArray[1];
	}

	function startCharacterLua(name:String)
	{
		#if LUA_ALLOWED
		var doPush:Bool = false;
		var luaFile:String = 'characters/' + name + '.lua';
		#if MODS_ALLOWED
		if (FileSystem.exists(Paths.modFolders(luaFile)))
		{
			luaFile = Paths.modFolders(luaFile);
			doPush = true;
		}
		else
		{
			luaFile = Paths.getPreloadPath(luaFile);
			if (FileSystem.exists(luaFile))
			{
				doPush = true;
			}
		}
		#else
		luaFile = Paths.getPreloadPath(luaFile);
		if (Assets.exists(luaFile))
		{
			doPush = true;
		}
		#end

		if (doPush)
		{
			for (lua in luaArray)
			{
				if (lua.scriptName == luaFile)
					return;
			}
			var lua:FunkinLua = new FunkinLua(luaFile);
			luaArray.push(lua);
			funkyScripts.push(lua);
		}
		#end
	}

	////
	public var closeLuas:Array<FunkinLua> = [];

	public function callOnScripts(event:String, args:Array<Dynamic>, ignoreStops:Bool = false, ?exclusions:Array<String>, ?scriptArray:Array<Dynamic>,
			?ignoreSpecialShit:Bool = true)
	{
		if (scriptArray == null)
			scriptArray = funkyScripts;
		if (exclusions == null)
			exclusions = [];
		var returnVal:Dynamic = Globals.Function_Continue;
		for (script in scriptArray)
		{
			if (exclusions.contains(script.scriptName)
				|| ignoreSpecialShit
				/*&& (notetypeScripts.exists(script.scriptName) || eventScripts.exists(script.scriptName))*/)
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
			scriptArray = funkyScripts;
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
			for (scr in funkyScripts)
			{
				if (scr.scriptName == script)
					scripts.push(scr);
			}
			return callOnScripts(event, args, true, [], scripts, false);
		}
		return Globals.Function_Continue;
	}

	public function callOnHScripts(event:String, args:Array<Dynamic>, ignoreStops = false, ?exclusions:Array<String>)
	{
		return callOnScripts(event, args, ignoreStops, exclusions, hscriptArray);
	}

	public function setOnHScripts(variable:String, arg:Dynamic)
	{
		return setOnScripts(variable, arg, hscriptArray);
	}

	public function callOnLuas(event:String, args:Array<Dynamic>, ignoreStops = false, ?exclusions:Array<String>)
	{
		#if LUA_ALLOWED
		return callOnScripts(event, args, ignoreStops, exclusions, luaArray);
		#else
		return Globals.Function_Continue;
		#end
	}

	public function setOnLuas(variable:String, arg:Dynamic)
	{
		#if LUA_ALLOWED
		setOnScripts(variable, arg, luaArray);
		#end
	}

	////
}