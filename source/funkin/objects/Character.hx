package funkin.objects;

import funkin.states.PlayState;
import funkin.scripts.FunkinScript.ScriptType;
import funkin.objects.playfields.PlayField;
import funkin.objects.notes.Note;
import funkin.data.CharacterData;
import funkin.data.CharacterData.*;
import funkin.scripts.*;
import animateatlas.AtlasFrameMaker;
import flixel.animation.FlxAnimation;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.math.FlxPoint;
import flixel.FlxSprite;
import openfl.geom.ColorTransform;

using flixel.util.FlxColorTransformUtil;
using StringTools;

class Character extends FlxSprite
{
	/**Character to use if the requested one fails to load**/
	public static final DEFAULT_CHARACTER:String = 'bf';

	////

	/**Id of the character**/
	public var characterId:String = DEFAULT_CHARACTER;

	/**Id of the death character to be used. Can be used to share 1 game over character across multiple characters**/
	public var deathId:String = DEFAULT_CHARACTER;

	/**Name of the image to be used for the health icon**/
	public var healthIcon:String = 'face';

	/**Whether this character is playable. Not really used much anymore**/
	public var isPlayer:Bool = false;

	/**Whether the player controls this character**/
	public var controlled:Bool = false;

	/**Used by the character editor. Disables most functions of the character besides animations**/
	public var debugMode:Bool = false;

	/**How each animation offsets the character**/
	public var animOffsets = new Map<String, Array<Dynamic>>();

	/**How each animation offsets the camera**/
	public var camOffsets:Map<String, Array<Float>> = [];

	/**Offsets the character on the stage**/
	public var positionArray:Array<Float> = [0, 0];

	/**Offsets the camera when its focused on the character**/
	public var cameraPosition:Array<Float> = [0, 0];

	/**Whether the character is facing left or right. -1 means it's facing to the left, 1 means its facing to the right.**/
	public var xFacing:Float = 1;

	/**The set of animations, in order, to be played for the character idling.**/
	public var idleSequence:Array<String> = ['idle'];

	/**String to be appended to idle animation names. For example, if this is -alt, then the animation used for idling will be idle-alt or danceLeft-alt/danceRight-alt**/
	public var idleSuffix:String = '';

	/**Character uses "danceLeft" and "danceRight" instead of "idle"**/
	public var danceIdle:Bool = false;

	/**How many steps a character should hold their sing animation for**/
	public var singDuration:Float = 4;

	/**If true, the character will go back to it's idle even if the player is holding a gameplay key**/
	public var idleWhenHold:Bool = false;

	/**Set to true if the character has miss animations. Optimization mainly**/
	public var hasMissAnimations:Bool = false;

	/**Allows the current dance animation to restart (if it hasn't finished)**/
	public var shouldForceDance:Bool = false;

	/**
	 * Beats to be added to `nextDanceBeat`
	 * How many beats should be waited before the character should dance again
	**/
	public var danceEveryNumBeats:Float = 2;

	////

	/**Whether this character is currently in use, Used by PlayState Character Change Events**/
	public var used:Bool = false;

	/**The next beat the character will dance on. Used by PlayState**/
	public var nextDanceBeat:Float = -5;

	/**Index of the next animation to play on the dance sequence**/
	public var danceIndex:Int = 0;
	
	/**How long in seconds the current sing animation has been held for**/
	public var holdTimer:Float = 0;

	/**How long in seconds to hold the hey/cheer anim**/
	public var heyTimer:Float = 0;

	/**Automatically resets the character to idle once this hits 0 after being set to any value above 0**/
	public var animTimer:Float = 0;

	/**
	 * Disables dancing if true.
	 * Automatically gets set to false once the current animation finishes.
	**/
	public var specialAnim:Bool = false;

	/**Disables the ability for characters to manually reset to idle**/
	public var stunned:Bool = false;

	/**Stops the idle from playing**/
	public var skipDance:Bool = false;

	/**
	 * Stops note anims and idle from playing.
	 * Make sure to set this to false once the animation is done.
	**/
	public var voicelining:Bool = false; // for fleetway, mainly
	// but whenever you need to play an anim that has to be manually interrupted, here you go

	/**Camera horizontal offset from the animation**/
	public var camOffX:Float = 0;

	/**Camera vertical offset from the animation**/
	public var camOffY:Float = 0;

	/**Overlay color used for characters that don't have miss animations.**/
	public var missOverlayColor:FlxColor = 0xFFC6A6FF;

	/**BLAMMED LIGHTS!! idk not used anymore**/
	public var colorTween:FlxTween;
	
	//Used on Character Editor
	public var animationsArray:Array<AnimArray> = [];
	public var imageFile:String = '';
	public var baseScale:Float = 1;
	public var noAntialiasing:Bool = false;
	public var originalFlipX:Bool = false;
	public var healthColorArray:Array<Int> = [255, 0, 0];

	#if ALLOW_DEPRECATION
	@:deprecated
	public var danced:Bool = false;

	@:deprecated("curCharacter is deprecated. Use characterId instead.")
	public var curCharacter(get, set):String;
	inline function get_curCharacter() return characterId;
	inline function set_curCharacter(v:String) return characterId = v;
	
	@:deprecated("deathName is deprecated. Use deathId instead.")
	public var deathName(get, set):String;
	inline function get_deathName() return deathId;
	inline function set_deathName(v:String) return deathId = v;

	/**LEGACY. DO NOT USE.**/
	@:deprecated("characterScript is deprecated. Use pushScript and removeScript instead.")
	public var characterScript(get, set):FunkinScript;
	@:noCompletion
	inline function get_characterScript()
		return characterScripts[0];
	@:noCompletion
	function set_characterScript(script:FunkinScript){ // you REALLY shouldnt be setting characterScript, you should be using the removeScript and addScript functions though;
		var oldScript = characterScripts.shift(); // removes the first script
		stopScript(oldScript, true);
		characterScripts.unshift(script); // and replaces it w/ the new one
		startScript(script);
		return script;
	}
	#end

	override function destroy()
	{
		for(script in characterScripts)
			removeScript(script, true);
		
		return super.destroy();
	}

	function loadFromPsychData(json:CharacterFile)
	{
		//// some troll engine stuff

		deathId = json.death_name != null ? json.death_name : characterId;
		
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
					camOffsets[anim.anim] = (camOffset != null) ? [camOffset[0], camOffset[1]] : CharacterData.getDefaultAnimCamOffset(animAnim);
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

	public function new(x:Float, y:Float, ?characterId:String, ?isPlayer:Bool = false, ?debugMode:Bool = false)
	{
		super(x, y);

		this.characterId = characterId ?? DEFAULT_CHARACTER;
		this.isPlayer = isPlayer;
		this.debugMode = debugMode;

		this.xFacing = this.isPlayer ? -1 : 1;
		this.controlled = this.isPlayer;
	}

	function _setupCharacter() {
		var json = getCharacterFile(characterId);
		if (json == null) {
			trace('Character file: $characterId not found.');
			json = getCharacterFile(DEFAULT_CHARACTER);
			characterId = DEFAULT_CHARACTER;
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
		var characterScript = characterScripts[0];
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
			cloneAnimation(animName, 		animName+'miss');
			cloneAnimation(animName, 		animName+'-alt');
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
		
		if (!debugMode && animation.curAnim != null)
		{
			if (animTimer > 0) {
				animTimer -= elapsed;
				if (animTimer<=0) {
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

			if (animation.name.startsWith('sing'))
				holdTimer += elapsed;
			else
				holdTimer = 0;

			if (animation.finished) {
				var name:String = animation.curAnim.name;

				if (specialAnim) {
					specialAnim = false;
					dance();
	
					callOnScripts("onSpecialAnimFinished", [name]);
				}
				else if (name.endsWith('miss')) {
					dance();
				}
				else if (animation.exists(name + '-loop')) {
					playAnim(name + '-loop');
				}
				else if (name.startsWith("hold") && name.endsWith("Start")) {
					var newName = name.substring(0, name.length-5);
					if (animation.exists(newName)) {
						playAnim(newName,true);
					}else {
						var singName = "sing" + name.substring(3, name.length-5);
						playAnim(singName,true);
					}
				}
			}
		}
		
		super.update(elapsed);
		callOnScripts("onCharacterUpdatePost", [elapsed]);
	}

	override function draw(){
		if (callOnScripts("onCharacterDraw") == Globals.Function_Stop)
			return;
		super.draw();
		callOnScripts("onCharacterDrawPost");
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
		callOnScripts("onAnimPlayed", [AnimName, Force, Reversed, Frame]);
	}
	
	public function dance()
	{
		if (debugMode || skipDance || specialAnim || animTimer > 0 || voicelining)
			return;
		
		if (callOnScripts("onDance") == Globals.Function_Stop)
			return;

		playAnim(idleSequence[danceIndex] + idleSuffix, shouldForceDance);
		
		if (idleSequence.length > 1) {
			danceIndex++;
			if (danceIndex >= idleSequence.length)
				danceIndex = 0;
		}
		
		callOnScripts("onDancePost");
	}

	public inline function canResetDance(holdingKeys:Bool = false) {
		var curAnim = animation.name;
		return curAnim==null || (
			(!holdingKeys || idleWhenHold)
			&& holdTimer * 1000 > Conductor.stepCrochet * singDuration
			&& curAnim.startsWith('sing') 
			&& !curAnim.endsWith('miss') // will go back to the idle once it finishes
		);
	}
	public function resetDance(){
		// called when resetting back to idle from a pose
		// useful for stuff like sing return animations
		if(callOnScripts("onResetDance") != Globals.Function_Stop) dance();
	}

	inline public static function getFieldColumnSingAnimation(column:Int, field:PlayField):String
	{
		return field.singAnimations[column % field.singAnimations.length];
	}

	inline public static function getNoteHitAnimation(note:Note, field:PlayField):String
	{
		return note.characterHitAnimName ?? getFieldColumnSingAnimation(note.column, field) + note.characterHitAnimSuffix;
	}

	inline public static function getNoteMissAnimation(note:Note, field:PlayField):String
	{
		return note.characterMissAnimName ?? getFieldColumnSingAnimation(note.column, field) + note.characterMissAnimSuffix;
	}

	public function playNote(note:Note, field:PlayField) {
		if (callOnScripts("playNote", [note, field]) == Globals.Function_Stop)
			return;

		if (note.noAnimation || animTimer > 0.0 || voicelining)
			return;

		var animToPlay:String = getNoteHitAnimation(note, field);

		if (note.noteType == 'Hey!' && animOffsets.exists(animToPlay)) {
			playAnim(animToPlay, true);
			specialAnim = true;
			heyTimer = 0.6;
			return;
		}

		playAnim(animToPlay, true);

		holdTimer = 0.0;
		callOnScripts("playNoteAnim", [animToPlay, note]);
	}

	public function missNote(note:Note, field:PlayField) {
		if (callOnScripts("missNote", [note, field]) == Globals.Function_Stop)
			return;

		if (animTimer > 0 || voicelining)
			return;

		var animToPlay:String = getNoteMissAnimation(note, field);
		playAnim(animToPlay, true);

		if (!hasMissAnimations)
			colorOverlay = missOverlayColor;	
	}

	public function missPress(direction:Int, field:PlayField) {
		if (animTimer > 0 || voicelining)
			return;

		var animToPlay:String = getFieldColumnSingAnimation(direction, field) + 'miss';
		playAnim(animToPlay, true);
		
		if(!hasMissAnimations)
			colorOverlay = missOverlayColor;	
	}

	private var settingCharacterUp:Bool = true;
	public function recalculateDanceIdle() {
		var lastDanceIdle:Bool = danceIdle;
		danceIdle = animation.exists('danceLeft' + idleSuffix) && animation.exists('danceRight' + idleSuffix);

		if (danceIdle)
			idleSequence = ["danceLeft" + idleSuffix, "danceRight" + idleSuffix];
		
		if (settingCharacterUp) {
			settingCharacterUp = false;
			danceEveryNumBeats = (danceIdle ? 1 : 2);
		}
		else if(lastDanceIdle != danceIdle) {
			var calc:Float = danceEveryNumBeats * (danceIdle ? 0.5 : 2.0);
			danceEveryNumBeats = Math.round(Math.max(calc, 1));
		}
	}

	/** To be called when this character is used, Used by PlayState Character Change Events **/
	public function changedIn(prevCharacter:Null<Character>) {
		inline function canResumeAnim(c:Character):Bool {
			return c != null && animation.exists(c.animation.name) && (characterId.startsWith(c.characterId) || c.characterId.startsWith(characterId));
		}
		if (canResumeAnim(prevCharacter)) {
			var anim = prevCharacter.animation.curAnim;
			playAnim(anim.name, true, anim.reversed, anim.curFrame);
		}else {
			dance();
		}
		
		used = true;
		setOnScripts("used", true);
		callOnScripts("changedIn", [prevCharacter]); // if you can come up w/ a better name for this callback then change it lol
		// (this also gets called for the characters set by the chart's player1/player2)
	}

	/** To be called when this character is changed out for another, Used by PlayState Character Change Events **/
	public function changedOut(newCharacter:Null<Character>) {
		used = false;
		setOnScripts("used", false);
		callOnScripts("changedOut", [newCharacter]);
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
	/**
	 * Scripts running on the character. 
	 *
	 * You should not modify this directly! Use `pushScript`/`removeScript`!
	 *
	 * If you must modify it directly, remember to call `startScript`/`stopScript` after adding/removing it
	**/
	public var characterScripts:Array<FunkinScript> = [];

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

		var key:String = 'characters/$characterId';

		#if HSCRIPT_ALLOWED
		var hscriptFile = Paths.getHScriptPath(key);
		if (hscriptFile != null) {
			var script = FunkinHScript.fromFile(hscriptFile, hscriptFile, defaultVars);
			pushScript(script);
			return this;
		}
		#end

		return this;
	}

	public function callOnScripts(event:String, ?args:Array<Dynamic>, ignoreStops:Bool = false, ?exclusions:Array<String>, ?scriptArray:Array<Dynamic>, ?vars:Map<String, Dynamic>, ?ignoreSpecialShit:Bool = true):Dynamic
	{
		#if (HSCRIPT_ALLOWED)
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
		return Globals.Function_Continue;
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
		#if (HSCRIPT_ALLOWED) // no point in calling this code if you.. for whatever reason, disabled scripting.
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