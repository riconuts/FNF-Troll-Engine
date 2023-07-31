package;

import flash.geom.ColorTransform;
import flixel.util.FlxColor;
import flixel.animation.FlxAnimation;
import Section.SwagSection;
import animateatlas.AtlasFrameMaker;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.addons.effects.FlxTrail;
import flixel.animation.FlxBaseAnimation;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.tweens.FlxTween;
import flixel.util.FlxSort;
import haxe.Json;
import haxe.format.JsonParser;
import openfl.utils.AssetType;
import openfl.utils.Assets;
import scripts.*;
using flixel.util.FlxColorTransformUtil;
using StringTools;
#if MODS_ALLOWED
import sys.FileSystem;
import sys.io.File;
#end

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

	public var controlled:Bool = false;
	public var xFacing:Float = 1;

	public var deathName:String = DEFAULT_CHARACTER;
	public var scriptName:String = DEFAULT_CHARACTER;
	public var characterScript:FunkinScript;

	/**for fleetway, mainly.
		but whenever you need to play an anim that has to be manually interrupted, here you go**/
	public var voicelining:Bool = false; 

	public var idleAnims:Array<String> = ['idle'];
	public var animOffsets:Map<String, Array<Dynamic>>;
	public var camOffsets:Map<String, Array<Float>> = [];
	public var debugMode:Bool = false;
	public var camOffX:Float = 0;
	public var camOffY:Float = 0;

	public var isPlayer:Bool = false;
	public var curCharacter:String = DEFAULT_CHARACTER;

	public var colorTween:FlxTween;
	public var holdTimer:Float = 0;
	public var heyTimer:Float = 0;
	public var animTimer:Float = 0;
	public var specialAnim:Bool = false;
	public var animationNotes:Array<Dynamic> = [];
	public var stunned:Bool = false;
	
	/**Multiplier of how long a character holds the sing pose**/
	public var singDuration:Float = 4;
	public var idleSuffix:String = '';
	
	/**Character uses "danceLeft" and "danceRight" instead of "idle"**/
	public var danceIdle:Bool = false;
	public var skipDance:Bool = false;

	public var healthIcon:String = 'face';
	public var animationsArray:Array<AnimArray> = [];

	public var positionArray:Array<Float> = [0, 0];
	public var cameraPosition:Array<Float> = [0, 0];

	public var hasMissAnimations:Bool = false;

	//Used on Character Editor
	public var imageFile:String = '';
	public var jsonScale:Float = 1;
	public var noAntialiasing:Bool = false;
	public var originalFlipX:Bool = false;
	public var healthColorArray:Array<Int> = [255, 0, 0];

	public static function getCharacterFile(character:String):Null<CharacterFile>
	{
		var rawJson:Null<String> = Paths.getText('characters/' + character + '.json');

		return rawJson != null ? cast Json.parse(rawJson) : null;
	}

	public static function returnCharacterPreload(characterName:String):Array<Cache.AssetPreload>{
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
		if (characterScript != null){
			characterScript.call("onDestroy");
			characterScript.stop();
		}

		return super.destroy();
	}

	public function new(x:Float, y:Float, ?character:String = 'bf', ?isPlayer:Bool = false, ?debugMode = false)
	{
		super(x, y);

		this.debugMode = debugMode == true;

		xFacing = isPlayer ? -1 : 1;
		idleWhenHold = !isPlayer;
		controlled = isPlayer;

		#if (haxe >= "4.0.0")
		animOffsets = new Map();
		#else
		animOffsets = new Map<String, Array<Dynamic>>();
		#end
		curCharacter = character;
		this.isPlayer = isPlayer;
		
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

				// new death
				deathName = json.death_name != null ? json.death_name : curCharacter;
				scriptName = json.script_name != null ? json.script_name : curCharacter;

				var spriteType = "sparrow";
				//sparrow
				//packer
				//texture
				#if MODS_ALLOWED
				var modTxtToFind:String = Paths.modsTxt(json.image);
				var txtToFind:String = Paths.getPath('images/' + json.image + '.txt', TEXT);

				if (Paths.exists(modTxtToFind) || Paths.exists(txtToFind))
				#else
				if (Paths.exists(Paths.getPath('images/' + json.image + '.txt', TEXT)))
				#end
				{
					spriteType = "packer";
				}

				#if MODS_ALLOWED
				var modAnimToFind:String = Paths.modFolders('images/' + json.image + '/Animation.json');
				var animToFind:String = Paths.getPath('images/' + json.image + '/Animation.json', TEXT);

				if (Paths.exists(modAnimToFind) || Paths.exists(animToFind))
				#else
				if (Paths.exists(Paths.getPath('images/' + json.image + '/Animation.json', TEXT)))
				#end
				{
					spriteType = "texture";
				}

				switch (spriteType)
				{
					case "packer":
						frames = Paths.getPackerAtlas(json.image);

					case "sparrow":
						frames = Paths.getSparrowAtlas(json.image);

					case "texture":
						frames = AtlasFrameMaker.construct(json.image);
				}
				imageFile = json.image;

				jsonScale = json.scale;
				if(jsonScale != 1)
					setGraphicSize(Math.ceil(width * jsonScale));
				else
					scale.set(1, 1);
				
				updateHitbox();

				positionArray = json.position;
				cameraPosition = json.camera_position;

				healthIcon = json.healthicon;
				singDuration = json.sing_duration;
				flipX = !!json.flip_x;
				if(json.no_antialiasing) {
					antialiasing = false;
					noAntialiasing = true;
				}

				if(json.healthbar_colors != null && json.healthbar_colors.length > 2)
					healthColorArray = json.healthbar_colors;

				animationsArray = json.animations;
				if(animationsArray != null && animationsArray.length > 0) {
					for (anim in animationsArray) {
						var animAnim:String = '' + anim.anim;
						var animName:String = '' + anim.name;
						var animFps:Int = anim.fps;
						var animLoop:Bool = !!anim.loop; //Bruh
						var animIndices:Array<Int> = anim.indices;
						var camOffset:Null<Array<Float>> = anim.cameraOffset;
						
						if(camOffset==null){
							switch(animAnim){
								case 'singLEFT' | 'singLEFTmiss' | 'singLEFT-alt':
									camOffset = [-30, 0];
								case 'singRIGHT' | 'singRIGHTmiss' | 'singRIGHT-alt':
									camOffset = [30, 0];
								case 'singUP' | 'singUPmiss' | 'singUP-alt':
									camOffset = [0, -30];
								case 'singDOWN' | 'singDOWNmiss' | 'singDOWN-alt':
									camOffset = [0, 30];
								default:
									camOffset = [0, 0];
							}
						}
						if(animIndices != null && animIndices.length > 0) {
							animation.addByIndices(animAnim, animName, animIndices, "", animFps, animLoop);
						} else {
							animation.addByPrefix(animAnim, animName, animFps, animLoop);
						}

						if(anim.offsets != null && anim.offsets.length > 1) {
							addOffset(anim.anim, anim.offsets[0], anim.offsets[1]);
						}
						camOffsets[anim.anim] = [camOffset[0], camOffset[1]];
					}
				} else {
					quickAnimAdd('idle', 'BF idle dance');
				}
				//trace('Loaded file to character ' + curCharacter);
		}
		originalFlipX = flipX;

		if(animOffsets.exists('singLEFTmiss') && animOffsets.exists('singDOWNmiss') && animOffsets.exists('singUPmiss') && animOffsets.exists('singRIGHTmiss')) 
			hasMissAnimations = true;

		if (!this.debugMode){
			var anims = ['singLEFT','singRIGHT', 'singUP', 'singDOWN'];
			var sufs = ["miss", "-alt"];

			for (anim in anims)
			{
				for (s in sufs){
					var shid = anim + s;
					if (!animOffsets.exists(shid) && animOffsets.exists(anim)){
						var daAnim:FlxAnimation = animation.getByName(anim);
						if (daAnim == null) continue;
						animation.add(shid, daAnim.frames, daAnim.frameRate, daAnim.looped, daAnim.flipX, daAnim.flipY);

						camOffsets[shid] = camOffsets[anim];
						animOffsets[shid] = animOffsets[anim];
					}
				}
			}

			for (anim in anims)
			{
				anim += "-alt";
				var shid = anim + "miss";
				if (!animOffsets.exists(shid) && animOffsets.exists(anim))
				{
					var daAnim:FlxAnimation = animation.getByName(anim);
					if (daAnim == null) continue;
					animation.add(shid, daAnim.frames, daAnim.frameRate, daAnim.looped, daAnim.flipX, daAnim.flipY);

					camOffsets[shid] = camOffsets[anim];
					animOffsets[shid] = animOffsets[anim];
				}
			}
		}

		recalculateDanceIdle();
		dance();

		if (isPlayer)
			flipX = !flipX;
	}

	override function update(elapsed:Float)
	{
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
					&& (idleWhenHold || !PlayState.pressedGameplayKeys.contains(true)))
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
	}

	public var danced:Bool = false;

	/**
	 * FOR GF DANCING SHIT
	 */
	public function dance()
	{
		if (!debugMode && !skipDance && !specialAnim && animTimer <= 0 && !voicelining)
		{
			if(danceIdle)
			{
				danced = !danced;

				if (danced)
					playAnim('danceRight' + idleSuffix);
				else
					playAnim('danceLeft' + idleSuffix);

				callOnScripts("onDance");
			}
			else if(animation.getByName('idle' + idleSuffix) != null) {
				playAnim('idle' + idleSuffix);
				callOnScripts("onDance");
			}
		}
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
		
		if (characterScript!=null && characterScript is FunkinHScript)
			scriptCam = characterScript.call("getCamera", [cam]);

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
		if (!AnimName.endsWith("miss"))
			colorOverlay = FlxColor.WHITE;
		if(callOnScripts("onAnimPlay", [AnimName, Force, Reversed, Frame]) == Globals.Function_Stop)
			return;

		specialAnim = false;
		animation.play(AnimName, Force, Reversed, Frame);

		var daOffset = animOffsets.get(AnimName);
		if (animOffsets.exists(AnimName))
			offset.set(daOffset[0], daOffset[1]);
		else
			offset.set(0, 0);

		camOffX = 0;
		camOffY = 0;

		if(camOffsets.exists(AnimName) && camOffsets.get(AnimName).length==2){
			camOffX = camOffsets.get(AnimName)[0];
			camOffY = camOffsets.get(AnimName)[1];
		}
		else if (camOffsets.exists(AnimName.replace("-loop", "")) && camOffsets.get(AnimName.replace("-loop", "")).length == 2)
		{
			camOffX = camOffsets.get(AnimName.replace("-loop", ""))[0];
			camOffY = camOffsets.get(AnimName.replace("-loop", ""))[1];
		}

		if (curCharacter.startsWith('gf'))
		{
			if (AnimName == 'singLEFT')
			{
				danced = true;
			}
			else if (AnimName == 'singRIGHT')
			{
				danced = false;
			}

			if (AnimName == 'singUP' || AnimName == 'singDOWN')
			{
				danced = !danced;
			}
		}
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

	////
	public function startScripts()
	{
		for (filePath in Paths.getFolders("characters")){

			var file = filePath + '$scriptName.hscript';
			if (Paths.exists(file)){
				characterScript = FunkinHScript.fromFile(file, file, ["this" => this]);
				callOnScripts("onLoad", [this], true);
				break;
			}
			#if LUA_ALLOWED
			file = filePath + '$scriptName.lua';
			if (Paths.exists(file)){
				characterScript = new FunkinLua(file);
				break;
			}
			#end
		}

		return this;
	}

	public function callOnScripts(event:String, ?args:Array<Dynamic>, ?ignoreStops:Bool = false, ?extraVars:Map<String,Dynamic>)
	{
		var returnVal:Dynamic = Globals.Function_Continue;

		if (characterScript == null)
			return returnVal;

		var ret:Dynamic;

		if (characterScript is FunkinHScript){
			var characterScript:FunkinHScript = cast characterScript;
			ret = characterScript.executeFunc(event, args, this, extraVars); 
		}else{
			ret = characterScript.call(event, args, extraVars);
		}

		if (ret == Globals.Function_Halt){
			ret = returnVal;
			if (!ignoreStops)
				return returnVal;
		};

		if (ret != Globals.Function_Continue && ret != null)
			returnVal = ret;

		if (returnVal == null)
			returnVal = Globals.Function_Continue;


		return returnVal;
	}

	public function setOnScripts(variable:String, value:Dynamic)
	{
		if (characterScript != null)
			characterScript.set(variable, value);
	}

	/**
		Returns an array with all the characters contained in the characters folder(s)
	**/
	public static function getCharacterList():Array<String>
	{
		#if MODS_ALLOWED
		var charsLoaded:Map<String, Bool> = new Map();
		var characterList = [];
		var directories:Array<String> = Paths.getFolders('characters');
		for (i in 0...directories.length) {
			var directory:String = directories[i];
			if(FileSystem.exists(directory)) {
				for (file in FileSystem.readDirectory(directory)) {
					var path = haxe.io.Path.join([directory, file]);
					if (!FileSystem.isDirectory(path) && file.endsWith('.json')) {
						var charToCheck:String = file.substr(0, file.length - 5);
						if(!charsLoaded.exists(charToCheck)) {
							characterList.push(charToCheck);
							charsLoaded.set(charToCheck, true);
						}
					}
				}
			}
		}
		return characterList;
		#else
		return CoolUtil.coolTextFile(Paths.txt('characterList'));
		#end
	}
}
