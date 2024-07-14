package funkin.objects;

import openfl.geom.ColorTransform;
import flixel.util.FlxColor;
import flixel.animation.FlxAnimation;
import animateatlas.AtlasFrameMaker;
import flixel.FlxSprite;
import flixel.tweens.FlxTween;
import haxe.Json;
import funkin.scripts.*;
using flixel.util.FlxColorTransformUtil;
using StringTools;

typedef CharacterFile = {
	var animations:Array<AnimArray>;
	var image:String;
	var scale:Float;
	var sing_duration:Float;
	var healthicon:String;

	var position:Array<Float>;
	var camera_position:Array<Float>;

	var flip_x:Bool;
	var no_antialiasing:Bool;
	var healthbar_colors:Array<Int>;

	@:optional var x_facing:Float;
	@:optional var death_name:String;
	@:optional var script_name:String;
}

typedef AnimArray = {
	var anim:String;
	var name:String;
	var fps:Int;
	var loop:Bool;
	var indices:Array<Int>;
	var offsets:Array<Int>;
	@:optional var cameraOffset:Array<Float>;
}

class Character extends FlxSprite
{
	/**Whether the character should idle when the player is holding a gameplay key**/
	public var idleWhenHold:Bool = true;

	/**In case a character is missing, it will use BF on its place**/
	public static var DEFAULT_CHARACTER:String = 'bf'; 

	/**Whether the player controls this character**/
	public var controlled:Bool = false;

	/**Whether the character is facing left or right. -1 means it's facing to the left, 1 means its facing to the right.**/
	public var xFacing:Float = 1;

	/**Name of the death character to be used. Can be used to share 1 game over character across multiple characters**/
	public var deathName:String = DEFAULT_CHARACTER;

	/**Name of the script to be ran. Can be used to share 1 script across multiple characters**/
	public var scriptName:String = DEFAULT_CHARACTER;
	/**LEGACY. DO NOT USE.**/
	public var characterScript(get, set):FunkinScript;
	inline function get_characterScript()
		return characterScripts[0];
	function set_characterScript(script:FunkinScript){ // you REALLY shouldnt be setting characterScript, you should be using the removeScript and addScript functions though;
        var oldScript = characterScripts.shift(); // removes the first script
        stopScript(oldScript, true);
        characterScripts.unshift(script); // and replaces it w/ the new one
		startScript(script);
        return script;
    }
		
    /**Scripts running on the character. You should not modify this directly! Use pushScript/removeScript!
     * If you must modify it directly, atleast call character.startScript(script)/character.stopScript(script) after adding/removing it**/
    public var characterScripts:Array<FunkinScript> = [];

	/**for fleetway, mainly.
		but whenever you need to play an anim that has to be manually interrupted, here you go.
        
    Stops note anims and idle from playing. Make sure to set this to false once the animation is done.**/
	public var voicelining:Bool = false; 

	/**Unused. Might eventually be used to create an "idleSequence" which lets you create your own custom sequence of animations to be played during idling, instead of only idle or danceLeft and danceRight.**/
	public var idleSequence:Array<String> = ['idle'];
	/**How each animation offsets the character**/
    public var animOffsets = new Map<String, Array<Dynamic>>();
	/**How each animation offsets the camera**/
    public var camOffsets:Map<String, Array<Float>> = [];
	/**Used by the character editor. Disables most functions of the character besides animations**/
	public var debugMode:Bool = false;
	/**Camera horizontal offset from the animation**/
    public var camOffX:Float = 0;
	/**Camera vertical offset from the animation**/
	public var camOffY:Float = 0;
	/**Whether this character is playable. Not really used much anymore**/
	public var isPlayer:Bool = false;
	/**Name of the character**/
	public var curCharacter:String = DEFAULT_CHARACTER;

	/**BLAMMED LIGHTS!! idk not used anymore**/
	public var colorTween:FlxTween;
	/**How long in seconds the current sing animation has been held for**/
	public var holdTimer:Float = 0;
	/**How long in seconds to hold the hey/cheer anim**/
	public var heyTimer:Float = 0;
	/**Automatically resets the character to idle once this hits 0 after being set to any value above 0**/
	public var animTimer:Float = 0;
	/**Disables dancing while the hey/cheer animations are playing**/
	public var specialAnim:Bool = false;
	/**Disables the ability for characters to manually reset to idle**/
    public var stunned:Bool = false;
	
	/**How many steps a character should hold their sing animation for**/
	public var singDuration:Float = 4;

	/**String to be appended to idle animation names. For example, if this is -alt, then the animation used for idling will be idle-alt or danceLeft-alt/danceRight-alt**/
	public var idleSuffix:String = '';
	/**Character uses "danceLeft" and "danceRight" instead of "idle"**/
	public var danceIdle:Bool = false;

	/**Stops the idle from playing**/
	public var skipDance:Bool = false;
    

	/**Name of the image to be used for the health icon**/
	public var healthIcon:String = 'face';

	/**Offsets the character on the stage**/
	public var positionArray:Array<Float> = [0, 0];
	/**Offsets the camera when its focused on the character**/
	public var cameraPosition:Array<Float> = [0, 0];
    
	/**Set to true if the character has miss animations. Optimization mainly**/
	public var hasMissAnimations:Bool = false;

	/**Overlay color used for character that don't have miss animations.**/
	public var missOverlayColor:FlxColor = 0xFFC6A6FF;
    
	//Used on Character Editor
	public var animationsArray:Array<AnimArray> = [];
	public var imageFile:String = '';
	public var jsonScale:Float = 1;
	public var noAntialiasing:Bool = false;
	public var originalFlipX:Bool = false;
	public var healthColorArray:Array<Int> = [255, 0, 0];

	public static function getCharacterFile(characterName:String):Null<CharacterFile>
	{
		var json:Null<CharacterFile> = Paths.json('characters/$characterName.json');
		if (json == null){
			trace('Could not find character "$characterName" JSON file');
			return null;
		} 

		try{
			for (anim in json.animations){
				try{
					if (anim.indices != null)
						anim.indices = parseIndices(anim.indices);
				}catch(e){
					trace('$characterName: Error parsing anim indices for ${anim.name}');
				}
			}

			if (json.healthbar_colors == null)
				json.healthbar_colors = [192, 192, 192];
			else if (json.healthbar_colors is String){
				var color:Null<FlxColor> = FlxColor.fromString(cast json.healthbar_colors);
				json.healthbar_colors = (color==null) ? null : [color.red, color.green, color.blue];
			}

			return json;
		}catch(e){
			trace('$characterName: Error loading character JSON file');
		}

		return null;
	}

	/**	
		Returns "texture", "packer" or "sparrow"
	**/
	public static function getImageFileType(path:String):String
	{
		if (Paths.fileExists('images/$path/Animation.json', TEXT))
			return "texture";
		else if (Paths.fileExists('images/$path.txt', TEXT))
			return "packer";
		else
			return "sparrow";
	}

	public static function returnCharacterPreload(characterName:String):Array<funkin.data.Cache.AssetPreload>{
		var char = Character.getCharacterFile(characterName);

		if (char == null)
			return [];

		return [
			{path: char.image}, // spritesheet
			{path: 'icons/${char.healthicon}'} // icon
		];
	}

	override function destroy()
	{
        for(script in characterScripts)
            removeScript(script, true);
        
		return super.destroy();
	}

	public static function parseIndices(indices:Array<Any>):Array<Int>
	{
		var parsed:Array<Int> = [];

		for (expr in indices)
		{
			if (expr is Int)
				parsed.push(expr);
			else if (expr is String)
			{
				var expr:String = Std.string(expr);
				var isRange:Bool = expr.contains("...");
				var exprArgs:Array<String> = expr.split(isRange ? "..." : "*");

				switch (exprArgs.length){
					case 0: 
						// Can't do anything lol
					case 1:
						parsed.push(Std.parseInt(exprArgs[0]));
					default:
						var exprA = Std.parseInt(exprArgs[0]);
						var exprB = Std.parseInt(exprArgs[1]);
						
						if (isRange){
							// starting from 'a' and ending on 'b'
							for (frameN in exprA...(exprB + 1))
								parsed.push(frameN);
						}else{
							// 'a' repeated 'b' times
							for (_ in 0...(exprB + 1))
								parsed.push(exprA);
						}
				}		
			}
		}

		return parsed;
	}

    public function pushScript(script:FunkinScript, alreadyStarted:Bool=false){
        characterScripts.push(script);
        if(!alreadyStarted)
            startScript(script);
    }

	public function removeScript(script:FunkinScript, destroy:Bool = false, alreadyStopped:Bool = false)
	{
		characterScripts.remove(script);
		if (!alreadyStopped)
			stopScript(script, destroy);
	}


    public function startScript(script:FunkinScript){        
		#if HSCRIPT_ALLOWED
        if(script.scriptType == 'hscript'){
		    callScript(script, "onLoad", [this]);
        }
        #end
    }

    public function stopScript(script:FunkinScript, destroy:Bool=false){
        #if HSCRIPT_ALLOWED
        if (script.scriptType == 'hscript'){
            callScript(script, "onStop", [this]);
            if(destroy){
		        script.call("onDestroy");
		        script.stop();
            }
        }
        #end
    }

	function loadFromPsychData(json:CharacterFile)
	{
		//// some troll engine stuff

		deathName = json.death_name != null ? json.death_name : curCharacter;
		scriptName = json.script_name != null ? json.script_name : curCharacter;
		
		if (json.x_facing != null)
			xFacing *= json.x_facing;

		////
		imageFile = json.image;

		switch (getImageFileType(imageFile))
		{
			case "texture":	frames = AtlasFrameMaker.construct(imageFile);
			case "packer":	frames = Paths.getPackerAtlas(imageFile);
			case "sparrow":	frames = Paths.getSparrowAtlas(imageFile);
		}

		////
		jsonScale = Math.isNaN(json.scale) ? 1 : json.scale;
		scale.set(jsonScale, jsonScale);
		updateHitbox();

		////
		positionArray = json.position;
		cameraPosition = json.camera_position;

		healthIcon = json.healthicon;
		singDuration = json.sing_duration;
		flipX = json.flip_x == true;

		if (json.no_antialiasing == true)
		{
			antialiasing = false;
			noAntialiasing = true;
		}

		if (json.healthbar_colors != null && json.healthbar_colors.length > 2)
			healthColorArray = json.healthbar_colors;

		animationsArray = json.animations;

		if (animationsArray != null && animationsArray.length > 0)
		{
			for (anim in animationsArray)
			{
				var animAnim:String = '' + anim.anim;
				var animName:String = '' + anim.name;
				var animFps:Int = anim.fps;
				var animLoop:Bool = anim.loop==true;
				var animIndices:Array<Int> = anim.indices;
				var camOffset:Null<Array<Float>> = anim.cameraOffset;

				if (!debugMode)
				{
					camOffsets[anim.anim] = (camOffset != null) ? [camOffset[0], camOffset[1]] : {
						if (!animAnim.startsWith('sing'))
							[0.0, 0.0];
						else if (animAnim.startsWith('singLEFT'))
							[-30.0, 0.0];
						else if (animAnim.startsWith('singDOWN'))
							[0.0, 30.0];
						else if (animAnim.startsWith('singUP'))
							[0.0, -30.0];
						else if (animAnim.startsWith('singRIGHT'))
							[30.0, 0.0];
						else
							[0.0, 0.0];
					};
				}

				////
				if (animIndices != null && animIndices.length > 0)
					animation.addByIndices(animAnim, animName, animIndices, "", animFps, animLoop);
				else
					animation.addByPrefix(animAnim, animName, animFps, animLoop);

				////
				if (anim.offsets != null && anim.offsets.length > 1)
					addOffset(anim.anim, anim.offsets[0], anim.offsets[1]);
				/* else
					addOffset(anim.anim, 0, 0); */
			}
		}
		else
		{
			quickAnimAdd('idle', 'BF idle dance');
		}
	}

	public function new(x:Float, y:Float, ?characterName:String = 'bf', ?isPlayer:Bool = false, ?debugMode:Bool = false)
	{
		super(x, y);		

		curCharacter = (characterName == null) ? DEFAULT_CHARACTER : characterName;
		var isPlayer:Bool = this.isPlayer = isPlayer;
		var debugMode:Bool = this.debugMode = debugMode;

		xFacing = isPlayer ? -1 : 1;
		idleWhenHold = !isPlayer;
		controlled = isPlayer;

		switch (curCharacter)
		{
			//case 'your character name in case you want to hardcode them instead':

			default:
				var json = getCharacterFile(curCharacter);

				if (json == null){
					trace('Character file: $curCharacter not found.');
					json = getCharacterFile(DEFAULT_CHARACTER);
					curCharacter = DEFAULT_CHARACTER;
				}

				loadFromPsychData(json);
		}
		originalFlipX = flipX;

		if(animOffsets.exists('singLEFTmiss') && animOffsets.exists('singDOWNmiss') && animOffsets.exists('singUPmiss') && animOffsets.exists('singRIGHTmiss')) 
			hasMissAnimations = true;

		//// placeholder animations
		if (!this.debugMode){
			for (animName in ['singLEFT', 'singRIGHT', 'singUP', 'singDOWN'])
			{
				cloneAnimation(animName,		animName+'miss');
				cloneAnimation(animName,		animName+'-alt');
				cloneAnimation(animName+'-alt',	animName+'-altmiss');
			}
		}

		recalculateDanceIdle();
		dance();

		if (isPlayer)
			flipX = !flipX;
	}

	override function update(elapsed:Float)
	{
        if (callOnScripts("onCharacterUpdate", [elapsed]) == Globals.Function_Stop)
			return;
		
		if(!debugMode && animation.curAnim != null)
		{
			if(animTimer > 0){
				animTimer -= elapsed;
				if(animTimer<=0){
					animTimer=0;
					dance();
				}
			}
			if(heyTimer > 0)
			{
				heyTimer -= elapsed;
				if(heyTimer <= 0)
				{
					if(specialAnim && (animation.curAnim.name == 'hey' || animation.curAnim.name == 'cheer'))
					{
						specialAnim = false;
						dance();
					}
					heyTimer = 0;
				}
			} else if(specialAnim && animation.curAnim.finished)
			{
				// trace("special done");
				specialAnim = false;
				dance();

				callOnScripts("onSpecialAnimFinished", [animation.curAnim.name]);
			}

			if (!controlled)
			{
				if (animation.curAnim.name.startsWith('sing'))
				{
					holdTimer += elapsed;
				}

				if (holdTimer >= Conductor.stepCrochet * 0.0011 * singDuration
					&& (idleWhenHold || !funkin.states.PlayState.pressedGameplayKeys.contains(true)))
				{
					dance();
					holdTimer = 0;
				}
			}else{
				if (animation.curAnim.name.startsWith('sing'))
					holdTimer += elapsed;
				else
					holdTimer = 0;

				if (animation.curAnim.name.endsWith('miss') && animation.curAnim.finished && !debugMode)
				{
					dance(); // playAnim('idle', true, false, 10);
				}

			}

			if(animation.curAnim.finished && animation.getByName(animation.curAnim.name + '-loop') != null)
			{
				playAnim(animation.curAnim.name + '-loop');
			}
		}

		super.update(elapsed);

		if(!debugMode){
			if(animation.curAnim!=null){
				var name = animation.curAnim.name;
				if(name.startsWith("hold")){
					if(name.endsWith("Start") && animation.curAnim.finished){
						var newName = name.substring(0,name.length-5);
						var singName = "sing" + name.substring(3, name.length-5);
						if(animation.getByName(newName)!=null){
							playAnim(newName,true);
						}else{
							playAnim(singName,true);
						}
					}
				}
			}
		}

		callOnScripts("onCharacterUpdatePost", [elapsed]);
	}

	public var danced:Bool = false;

    public function resetDance(){
        // called when resetting back to idle from a pose
        // useful for stuff like sing return animations
		if(callOnScripts("onResetDance") != Globals.Function_Stop) dance();
    }
	/**
	 * FOR GF DANCING SHIT
	 */
	public function dance()
	{
		if (debugMode || skipDance || specialAnim || animTimer > 0 || voicelining)
			return;
		
		if (callOnScripts("onDance") == Globals.Function_Stop)
			return;

		if(danceIdle){
			danced = !danced;
			playAnim((danced ? 'danceRight' : 'danceLeft') + idleSuffix);
		}
		else if(animation.getByName('idle' + idleSuffix) != null) {
			playAnim('idle' + idleSuffix);
		}

		callOnScripts("onDancePost");
	}

    override function draw(){
        if(callOnScripts("onDraw") == Globals.Function_Stop)
            return;
        super.draw();
        callOnScripts("onDrawPost");
    }

	public var colorOverlay(default, set):FlxColor = FlxColor.WHITE;

	function set_colorOverlay(val:FlxColor){
		if (colorOverlay!=val){
			colorOverlay = val;
			updateColorTransform();
		}
		return colorOverlay;
	}

	public function getCamera()
	{
		var cam:Array<Float> = [
			x + width * 0.5 + (cameraPosition[0] + 150) * xFacing,
			y + height * 0.5 + cameraPosition[1] - 100
		];

		var scriptCam:Null<Array<Float>> = null;
		
        var retValue = callOnScripts("getCamera", [cam]);
        if((retValue is Array))scriptCam = retValue;
        

		return scriptCam!=null ? scriptCam : cam;
	}

	override function updateColorTransform():Void
	{
		if (colorTransform == null)
			colorTransform = new ColorTransform();

		useColorTransform = alpha != 1 || (color * colorOverlay) != 0xffffff;
		if (useColorTransform)
			colorTransform.setMultipliers(color.redFloat * colorOverlay.redFloat, color.greenFloat * colorOverlay.greenFloat, color.blueFloat * colorOverlay.blueFloat, alpha);
		else
			colorTransform.setMultipliers(1, 1, 1, 1);

		dirty = true;
	}

	public function playAnim(AnimName:String, Force:Bool = false, Reversed:Bool = false, Frame:Int = 0):Void
	{
		if (callOnScripts("onAnimPlay", [AnimName, Force, Reversed, Frame]) == Globals.Function_Stop)
			return;

		if (!AnimName.endsWith("miss"))
			colorOverlay = FlxColor.WHITE;

		specialAnim = false;
		animation.play(AnimName, Force, Reversed, Frame);

		var daOffset = animOffsets.get(AnimName);
		if (daOffset != null)
			offset.set(daOffset[0], daOffset[1]);
		else
			offset.set();

		////

		var daOffset:Array<Float> = camOffsets.get(AnimName);
		if (daOffset == null || daOffset.length < 2)
			daOffset = camOffsets.get(AnimName.replace("-loop", ""));
		
		if (daOffset != null && daOffset.length >= 2){
			camOffX = daOffset[0];
			camOffY = daOffset[1];
		}else{
			camOffX = 0;
			camOffY = 0;
		}

		////
		if (curCharacter.startsWith('gf'))
		{
			if (AnimName == 'singLEFT')
				danced = true;
			
			else if (AnimName == 'singRIGHT')
				danced = false;
			
			else if (AnimName == 'singUP' || AnimName == 'singDOWN')
				danced = !danced;
		}

		////
		callOnScripts("onAnimPlayed", [AnimName, Force, Reversed, Frame]);
	}

	public var danceEveryNumBeats:Int = 2;
	private var settingCharacterUp:Bool = true;
	public function recalculateDanceIdle() {
		var lastDanceIdle:Bool = danceIdle;
		danceIdle = (animation.getByName('danceLeft' + idleSuffix) != null && animation.getByName('danceRight' + idleSuffix) != null);

		if(settingCharacterUp)
		{
			danceEveryNumBeats = (danceIdle ? 1 : 2);
		}
		else if(lastDanceIdle != danceIdle)
		{
			var calc:Float = danceEveryNumBeats;
			if(danceIdle) 
				calc /= 2;
			else
				calc *= 2;

			danceEveryNumBeats = Math.round(Math.max(calc, 1));
		}
		settingCharacterUp = false;
	}

	public function addOffset(name:String, x:Float = 0, y:Float = 0)
	{
		animOffsets[name] = [x, y];
	}

	public function quickAnimAdd(name:String, anim:String)
	{
		animation.addByPrefix(name, anim, 24, false);
	}

	function cloneAnimation(ogName:String, cloneName:String, ?force:Bool)
	{
		var daAnim:FlxAnimation = animation.getByName(ogName);

		if (daAnim!=null && (force==true || !animation.exists(cloneName)))
		{
			animation.add(cloneName, daAnim.frames, daAnim.frameRate, daAnim.looped, daAnim.flipX, daAnim.flipY);

			camOffsets[cloneName] = camOffsets[ogName];
			animOffsets[cloneName] = animOffsets[ogName];
		}
	}

	////
    public var defaultVars:Map<String, Dynamic> = [];
    public function setDefaultVar(i:String, v:Dynamic)
		defaultVars.set(i, v);
    

	public function startScripts()
	{
		setDefaultVar("this", this);

		for (filePath in Paths.getFolders("characters"))
		{
			var file = filePath + '$scriptName.hscript';
			if (Paths.exists(file)){
				var script = FunkinHScript.fromFile(file, file, defaultVars);
				pushScript(script);
				break;
			}
			#if LUA_ALLOWED
			file = filePath + '$scriptName.lua';
			if (Paths.exists(file)){
				var script = new FunkinLua(file);
				pushScript(script);
				break;
			}
			#end
		}

		return this;
	}

    public function callOnScripts(event:String, ?args:Array<Dynamic>, ignoreStops:Bool = false, ?exclusions:Array<String>, ?scriptArray:Array<Dynamic>,
        ?vars:Map<String, Dynamic>, ?ignoreSpecialShit:Bool = true):Dynamic
    {
    #if (LUA_ALLOWED || HSCRIPT_ALLOWED)
    if (args == null)
        args = [];
    if (scriptArray == null)
        scriptArray = characterScripts;
    if (exclusions == null)
        exclusions = [];

    var returnVal:Dynamic = Globals.Function_Continue;
    for (script in scriptArray)
    {
        if (exclusions.contains(script.scriptName))
            continue;
        
        var ret:Dynamic = script.call(event, args, vars);
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
    #else
    return Globals.Function_Continue
    #end
    }

    public function setOnScripts(variable:String, value:Dynamic, ?scriptArray:Array<Dynamic>)
    {
    if (scriptArray == null)
        scriptArray = characterScripts;

    for (script in scriptArray)
    {
        script.set(variable, value);
        // trace('set $variable, $value, on ${script.scriptName}');
    }
    }

    public function callScript(script:Dynamic, event:String, ?args:Array<Dynamic>):Dynamic
    {
    #if (LUA_ALLOWED || HSCRIPT_ALLOWED) // no point in calling this code if you.. for whatever reason, disabled scripting.
    if ((script is FunkinScript))
    {
        return callOnScripts(event, args, true, [], [script], [], false);
    }
    else if ((script is Array))
    {
        return callOnScripts(event, args, true, [], script, [], false);
    }
    else if ((script is String))
    {
        var scripts:Array<FunkinScript> = [];

        for (scr in characterScripts)
        {
            if (scr.scriptName == script)
                scripts.push(scr);
        }

        return callOnScripts(event, args, true, [], scripts, [], false);
    }
    #end
    return Globals.Function_Continue;
    }

	/**
		Returns an array with every character file in the characters folder(s).
	**/
	#if !sys
	@:noCompletion private static var _listCache:Null<Array<String>> = null;
	#end
	public static function getAllCharacters(modsOnly = false):Array<String>
	{
		#if !sys
		if (_listCache != null)
			return _listCache;

		var characters:Array<String> = _listCache = [];
		#else
		var characters:Array<String> = [];
		#end

		var _characters = new Map<String, Bool>();

		function readFileNameAndPush(fileName:String){
			if (fileName==null || !fileName.endsWith(".json"))
				return;

			var name = fileName.substr(0, fileName.length - 5);
			_characters.set(name, true);
		}
		
		for (folderPath in Paths.getFolders("characters", true)){
			Paths.iterateDirectory(folderPath, readFileNameAndPush);
		}

		if (!modsOnly){
			Paths.iterateDirectory(Paths.getPath('characters/'), readFileNameAndPush);
		}

		for (name in _characters.keys())
			characters.push(name);

		return characters;
	}
}
