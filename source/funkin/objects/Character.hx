package funkin.objects;

import funkin.states.PlayState;
import funkin.scripts.FunkinScript.ScriptType;
import funkin.objects.playfields.PlayField;
import flixel.math.FlxPoint;
import funkin.data.CharacterData.*;
import funkin.data.CharacterData.AnimArray;
import funkin.data.CharacterData.CharacterFile;
import funkin.scripts.*;
import animateatlas.AtlasFrameMaker;
import flixel.animation.FlxAnimation;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.FlxSprite;
import openfl.geom.ColorTransform;

using flixel.util.FlxColorTransformUtil;
using StringTools;

class Character extends FlxSprite
{
	/**The next beat the character will dance on**/
	public var nextDanceBeat:Float = -5;

	/**Whether to force the dance animation to play**/
	public var shouldForceDance:Bool = false;

	/**Whether the character can go back to the idle while the player is holding a gameplay key**/
	public var idleWhenHold:Bool = true;

	/**In case a character is missing, it will use BF on its place**/
	public static var DEFAULT_CHARACTER:String = 'bf'; 

	/**Whether the player controls this character**/
	public var controlled:Bool = false;

	/**Whether the character is facing left or right. -1 means it's facing to the left, 1 means its facing to the right.**/
	public var xFacing:Float = 1;

	/**Name of the death character to be used. Can be used to share 1 game over character across multiple characters**/
	public var deathName:String = DEFAULT_CHARACTER;

	/**Name of the script to be ran. Can be used to share 1 script file across multiple characters**/
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

	/**The set of animations, in order, to be played for the character idling.**/
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
	/**Overlay color used for characters that don't have miss animations.**/
	public var missOverlayColor:FlxColor = 0xFFC6A6FF;
	
	//Used on Character Editor
	public var animationsArray:Array<AnimArray> = [];
	public var imageFile:String = '';
	public var baseScale:Float = 1;
	public var noAntialiasing:Bool = false;
	public var originalFlipX:Bool = false;
	public var healthColorArray:Array<Int> = [255, 0, 0];

	override function destroy()
	{
		for(script in characterScripts)
			removeScript(script, true);
		
		return super.destroy();
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
		baseScale = Math.isNaN(json.scale) ? 1.0 : json.scale;
		scale.set(baseScale, baseScale);
		updateHitbox();

		////
		positionArray = json.position;
		cameraPosition = json.camera_position;

		healthIcon = json.healthicon;
		singDuration = json.sing_duration;
		originalFlipX = json.flip_x == true;

		if (json.no_antialiasing == true) {
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
		this.isPlayer = isPlayer;
		this.debugMode = debugMode;

		xFacing = isPlayer ? -1 : 1;
		idleWhenHold = !isPlayer;
		controlled = isPlayer;
	}

	function _setupCharacter() {
		var json = getCharacterFile(curCharacter);
		if (json == null) {
			trace('Character file: $curCharacter not found.');
			json = getCharacterFile(DEFAULT_CHARACTER);
			curCharacter = DEFAULT_CHARACTER;
		}

		loadFromPsychData(json);
		
		hasMissAnimations = (animOffsets.exists('singLEFTmiss') && animOffsets.exists('singDOWNmiss') && animOffsets.exists('singUPmiss') && animOffsets.exists('singRIGHTmiss'));

		if (!debugMode) createPlaceholderAnims();

		recalculateDanceIdle();
		dance();
		animation.finish();

		flipX = isPlayer ? !originalFlipX : originalFlipX;
	}

	public function setupCharacter()
	{
		if (characterScript != null && characterScript.scriptType == HSCRIPT) {
			var characterScript:FunkinHScript = cast characterScript;
			if (characterScript.exists('setupCharacter')) {
				characterScript.executeFunc('setupCharacter', null, this, ["super" => _setupCharacter]);
				return;
			}
		}

		_setupCharacter();
	}

	public function createPlaceholderAnims() {
		for (animName in ["singLEFT", "singDOWN", "singUP", "singRIGHT"]) {
			cloneAnimation(animName,		animName+'miss');
			cloneAnimation(animName,		animName+'-alt');
			cloneAnimation(animName+'-alt',	animName+'-altmiss');
		}
	}

	public function getCamera() {
		var cam:Array<Float> = [
			x + width * 0.5 + (cameraPosition[0] + 150) * xFacing,
			y + height * 0.5 + cameraPosition[1] - 100
		];

		var scriptCam:Null<Array<Float>> = null;
		
		var retValue = callOnScripts("getCamera", [cam]);
		if((retValue is Array))scriptCam = retValue;

		return scriptCam!=null ? scriptCam : cam;
	}

	override function update(elapsed:Float)
	{
		if (callOnScripts("onCharacterUpdate", [elapsed]) == Globals.Function_Stop)
			return;
		
		if(!debugMode && animation.curAnim != null)
		{
			if (animTimer > 0) {
				animTimer -= elapsed;
				if(animTimer<=0) {
					animTimer=0;
					dance();
				}
			}

			if (heyTimer > 0) {
				heyTimer -= elapsed;

				if (heyTimer <= 0) {
					heyTimer = 0;
					if (specialAnim && (animation.curAnim.name == 'hey' || animation.curAnim.name == 'cheer'))
						animation.curAnim.finish();
				}
			} 

			if (specialAnim && animation.curAnim.finished) {
				specialAnim = false;
				dance();

				callOnScripts("onSpecialAnimFinished", [animation.curAnim.name]);
			}

			if (animation.name.startsWith('sing'))
				holdTimer += elapsed;
			else
				holdTimer = 0;

			if (animation.finished) {
				if (animation.name.endsWith('miss')) {
					dance();
				
				}else if (animation.exists(animation.name + '-loop')) {
					playAnim(animation.name + '-loop');
				}
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

	public var danced:Bool = false;
	var danceIndex:Int = 0;	
	
	public function dance()
	{
		if (debugMode || skipDance || specialAnim || animTimer > 0 || voicelining)
			return;
		
		if (callOnScripts("onDance") == Globals.Function_Stop)
			return;

		if(idleSequence.length > 1){
			danceIndex++;
			if(danceIndex >= idleSequence.length)
				danceIndex = 0;
		}
		playAnim(idleSequence[danceIndex] + idleSuffix, shouldForceDance);
		
/* 		if(danceIdle){
			danced = !danced;
			playAnim((danced ? 'danceRight' : 'danceLeft') + idleSuffix);
		}
		else if(animation.getByName('idle' + idleSuffix) != null) {
			playAnim('idle' + idleSuffix);
		}
 */
		callOnScripts("onDancePost");
	}

	public inline function canResetDance(holdingKeys:Bool = false) {
		return animation.name==null || (
			holdTimer > Conductor.stepCrochet * 0.001 * singDuration
			&& (!holdingKeys || idleWhenHold)
			&& animation.name.startsWith('sing') 
			&& !animation.name.endsWith('miss') // will go back to the idle once it finishes
		);
	}
	public function resetDance(){
		// called when resetting back to idle from a pose
		// useful for stuff like sing return animations
		if(callOnScripts("onResetDance") != Globals.Function_Stop) dance();
	}

	public function playNote(note:Note, field:PlayField) {
		if (callOnScripts("playNote", [note, field]) == Globals.Function_Stop)
			return;

		if (note.noAnimation || animTimer > 0.0 || voicelining)
			return;

		if (note.noteType == 'Hey!' && animOffsets.exists('hey')) {
			playAnim('hey', true);
			specialAnim = true;
			heyTimer = 0.6;
			return;
		}

		var animToPlay:String = note.characterHitAnimName;
		if (animToPlay == null) {
			animToPlay = field.singAnimations[note.column % field.singAnimations.length];
			animToPlay += note.characterHitAnimSuffix;
		}

		playAnim(animToPlay, true);
		holdTimer = 0.0;
		callOnScripts("playNoteAnim", [animToPlay, note]);
	}

	public function missNote(note:Note, field:PlayField) {
		if (animTimer > 0 || voicelining)
			return;

		var animToPlay:String = note.characterMissAnimName;
		if (animToPlay == null) {
			animToPlay = field.singAnimations[note.column % field.singAnimations.length];
			animToPlay += note.characterMissAnimSuffix;
		}

		playAnim(animToPlay + 'miss', true);

		if (!hasMissAnimations)
			colorOverlay = missOverlayColor;	
	}

	public function missPress(direction:Int, field:PlayField) {
		if (animTimer > 0 || voicelining)
			return;

		var animToPlay:String = field.singAnimations[direction % field.singAnimations.length];
		playAnim(animToPlay + 'miss', true);
		
		if(!hasMissAnimations)
			colorOverlay = missOverlayColor;	
	}

	public var danceEveryNumBeats:Float = 2;
	private var settingCharacterUp:Bool = true;
	public function recalculateDanceIdle() {
		var lastDanceIdle:Bool = danceIdle;
		danceIdle = (animation.getByName('danceLeft' + idleSuffix) != null && animation.getByName('danceRight' + idleSuffix) != null);

		if(danceIdle)
			idleSequence = ["danceLeft" + idleSuffix, "danceRight" + idleSuffix];
		
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

	/**
	 * @param ogName Name of the animation to be cloned. 
	 * @param cloneName Name of the resulting clone.
	 * @param force Whether to override the resulting animation, if it exists.
	 */
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
	
	public function pushScript(script:FunkinScript, alreadyStarted:Bool=false){
		characterScripts.push(script);
		if (!alreadyStarted)
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
		if(script.scriptType == ScriptType.HSCRIPT){
			callScript(script, "onLoad", [this]);
		}
		#end
	}

	public function stopScript(script:FunkinScript, destroy:Bool=false){
		#if HSCRIPT_ALLOWED
		if (script.scriptType == ScriptType.HSCRIPT){
			callScript(script, "onStop", [this]);
			if(destroy){
				script.call("onDestroy");
				script.stop();
			}
		}
		#end
	}

	public function startScripts()
	{
		setDefaultVar("this", this);

		var key:String = 'characters/$curCharacter';

		#if HSCRIPT_ALLOWED
		var hscriptFile = Paths.getHScriptPath(key);
		if (hscriptFile != null) {
			var script = FunkinHScript.fromFile(hscriptFile, hscriptFile, defaultVars);
			pushScript(script);
			return this;
		}
		#end

		#if LUA_ALLOWED
		var luaFile = Paths.getLuaPath(key);
		if (luaFile != null) {
			var script = FunkinLua.fromFile(luaFile, luaFile, defaultVars);
			pushScript(script);
			return this;
		}
		#end

		return this;
	}

	public function callOnScripts(event:String, ?args:Array<Dynamic>, ignoreStops:Bool = false, ?exclusions:Array<String>, ?scriptArray:Array<Dynamic>, ?vars:Map<String, Dynamic>, ?ignoreSpecialShit:Bool = true):Dynamic
	{
		#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
		if (args == null)
			args = [];
		if (exclusions == null)
			exclusions = [];
		if (scriptArray == null)
			scriptArray = characterScripts;

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

		for (script in scriptArray) {
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
}