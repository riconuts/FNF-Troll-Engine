package;

import openfl.events.IOErrorEvent;
import openfl.events.Event;
import openfl.net.FileReference;
import haxe.Json;
import flixel.util.FlxSort;
import flixel.input.keyboard.FlxKey;
import Character;
import flixel.text.FlxText;
import shaders.BlendModeEffect;
import flixel.math.FlxMath;
import flixel.group.FlxGroup;

import StringTools;

// working name, replace with regular character editor name once im done with it 
class SowyCharacterEditor extends MusicBeatState
{
	static var lastCharacterName:String = 'pico';

	var originMarker:FlxSprite;

	var stage:Null<Stage>;
	var curZoom:Float = 1.0;
	var defaultCamZoom(get, null):Float;
	function get_defaultCamZoom() return stage==null ? 1.0 : stage.stageData.defaultZoom;

	var charGroup = new FlxTypedGroup<Character>();
	var charIdx:Int;
	var animTxtGroup = new FlxTypedGroup<FlxText>();
	var animIdx(default, set):Int;
	var frameTxt:FlxText;

	var curChar(get, null):Character;
	function get_curChar() return charGroup.members[charIdx];
	var curAnims(get, null):Array<AnimArray>;
	function get_curAnims() return curChar.animationsArray;

	var camGame:FlxCamera;
	var camHUD:FlxCamera;
	var camFollow:FlxObject;

	var hudCams:Array<FlxCamera>;

	public function new(?charName:String, ?stageName:String)
	{
		super();

		if (charName != null)
			lastCharacterName = charName;
	}

	override function destroy(){
		FlxG.sound.muteKeys = StartupState.muteKeys;
		FlxG.sound.volumeDownKeys = StartupState.volumeDownKeys;
		FlxG.sound.volumeUpKeys = StartupState.volumeUpKeys;

		return super.destroy();
	}

	override function create()
	{
		FlxG.sound.volumeDownKeys = FlxG.sound.volumeUpKeys = FlxG.sound.muteKeys = [];

		camGame = new FlxCamera();
		camHUD = new FlxCamera();
		camFollow = new FlxObject();

		hudCams = [camHUD];
		camGame.pixelPerfectRender = true;
		camHUD.pixelPerfectRender = true;
		camGame.follow(camFollow);
		camGame.bgColor = 0xFFAAAAAA;
		camHUD.bgColor = 0x00000000;

		FlxG.cameras.add(camGame, true);
		FlxG.cameras.add(camHUD, false);
		add(camFollow);

		////
		add(charGroup);

		add(animTxtGroup);

		frameTxt = _makeAnimTxt();
		frameTxt.y = FlxG.height - 18 * 2 - 4;
		add(frameTxt);

		var ui = new FlxSprite().makeGraphic(1,1);
		ui.scale.set(400, 300);
		ui.updateHitbox();
		ui.x = FlxG.width - 400 - 10;
		ui.y = (FlxG.height - ui.height) / 2;
		ui.color = 0xFF444444;
		ui.cameras = hudCams;
		ui.blend = INVERT;
		add(ui);

		////
		originMarker = new FlxSprite(0, 0, Paths.image("stageeditor/originMarker"));
		originMarker.offset.set(originMarker.width / 2, originMarker.height / 2);
		add(originMarker);

		super.create();

		FlxG.mouse.visible = true;

		reloadStage("school");
		makeChar("bf-pixel");
	}

	function reloadStage(name:String){
		if (stage != null){
			remove(stage);
			remove(stage.foreground);
			stage.destroy();
		}

		stage = new Stage(name);
		stage.buildStage();
		insert(members.indexOf(charGroup), stage);
		insert(members.indexOf(charGroup)+1, stage.foreground);
	}

	function makeChar(name:String){
		var char = new Character(0, 0, name, true, true);
		
		var sp = char.isPlayer ? stage.stageData.boyfriend : stage.stageData.opponent;
		char.setPosition(
			sp[0]+char.positionArray[0], 
			sp[1]+char.positionArray[1]
		);
		charIdx = 0;
		// curChar.blend = flash.display.BlendMode.DARKEN; // is broken so the frame background turns black which is helpful ig
		charGroup.add(char);

		curChar.animationsArray.sort(animSortFunc);
		generateAnimTxts();
		animIdx = 0;
		snapToCharacterCamera();
	}

	function _makeAnimTxt(){
		var txt = new FlxText(4, 4, 0, 'Sowy', 14);
		txt.setBorderStyle(OUTLINE, 0xFF000000, 2, 1);
		txt.cameras = hudCams;
		return txt;
	}
	function generateAnimTxts(){
		animTxtGroup.kill();
		for (idx => anim in curAnims){
			var txt = animTxtGroup.recycle(FlxText, _makeAnimTxt);
			txt.y = 4+idx*18;
			txt.ID = idx;

			/* nvm this font doesn't work like that!!! FUCK!
			var string = anim.anim;
			for (_ in 0...FlxMath.maxInt(4, Math.floor(string.length / 4) * 4)) // like pressing tab
				string += ' ';  
			string += anim.offsets;
			*/

			txt.text = '${anim.anim} ${anim.offsets}';
		}
		animTxtGroup.exists = animTxtGroup.alive = true;
	}

	function snapToCharacterCamera(){
		var cam = curChar.getCamera();
		camFollow.setPosition(cam[0], cam[1]);

		curZoom = curZoom == 1.0 ? defaultCamZoom : 1.0;
	}

	function set_animIdx(val:Int){
	
		animTxtGroup.members[animIdx].color = 0xFFFFFFFF;

		var val = FlxMath.wrap(val, 0, curAnims.length - 1);
		var animArray = curChar.animationsArray[val];

		animTxtGroup.members[val].color = 0xFF00FF00;
		animTxtGroup.members[val].text = '${animArray.anim} ${animArray.offsets}';
		
		var prevPaused = curChar.animation.paused;
		curChar.playAnim(curAnims[val].anim, true);
		if (prevPaused) curChar.animation.pause();
		
		return animIdx = val;
	}

	function onAnimArrayUpdate(animArray:AnimArray){
		var idx = curChar.animationsArray.indexOf(animArray);
		animTxtGroup.members[idx].text = '${animArray.anim} ${animArray.offsets}';
	}

	function getAnimOrder(name){
		var points = 0;

		for (i => aaa in ['idle', 'singLEFT', 'singDOWN', 'singUP', 'singRIGHT']){
			if (StringTools.startsWith(name, aaa))
				points += (-272727) + i*10;
		}
		for (i => aaa in ['miss', 'alt', 'loop']){
			if (StringTools.endsWith(name, aaa))
				points += (2727) + i;
		}

		return points;
	}
	function animSortFunc(a:AnimArray, b:AnimArray)
		return getAnimOrder(a.anim) - getAnimOrder(b.anim);

	function roundTo(val:Float, roundFactor:Float)
		return Math.round(val / roundFactor) * roundFactor;
	function roundToInt(val:Float, roundFactor:Int)
		return Math.round(val / roundFactor) * roundFactor;


	

	override function update(elapsed:Float)
	{
		var keys = FlxG.keys;
		/*
			if (FlxG.keys.justPressed.ANY)
				trace([for (input in FlxG.keys.getIsDown()){FlxKey.toStringMap.get(input.ID);}]);
		 */

		if (keys.justPressed.QUOTE)
			animIdx--;
		if (keys.justPressed.SLASH)
			animIdx++;

		var curAnimObj = curChar != null ? curChar.animation.curAnim : null;
		var curAnimArray = curChar.animationsArray[animIdx];

		if (keys.justPressed.LEFT || keys.justPressed.DOWN || keys.justPressed.UP || keys.justPressed.RIGHT)
		{
			var xAdd = 0;
			var yAdd = 0;
			var shiftMod = keys.pressed.SHIFT ? 10 : 1;

			if (keys.justPressed.UP) yAdd++;
			if (keys.justPressed.DOWN) yAdd--;
			if (keys.justPressed.LEFT) xAdd++;
			if (keys.justPressed.RIGHT) xAdd--;

			var arrayOffsets = curAnimArray.offsets;
			curChar.offset.x = arrayOffsets[0] = Std.int(roundTo(arrayOffsets[0] + xAdd * shiftMod * curChar.scale.x, curChar.scale.x));
			curChar.offset.y = arrayOffsets[1] = Std.int(roundTo(arrayOffsets[1] + yAdd * shiftMod * curChar.scale.y, curChar.scale.y));
			curChar.animOffsets[curAnimArray.anim] = arrayOffsets;

			onAnimArrayUpdate(curAnimArray);
		}

		if (keys.justPressed.SPACE)
		{
			// animIdx += 0;
			// curChar.playAnim(curAnimObj.name, true);
			curAnimObj.restart();
		}

		if (keys.pressed.E || keys.pressed.Q)
		{
			if (keys.pressed.E)
				curZoom += elapsed * curZoom;
			if (keys.pressed.Q)
				curZoom -= elapsed * curZoom;
		}
		
		if (keys.pressed.A || keys.pressed.S || keys.pressed.W || keys.pressed.D)
		{
			var addToCam:Float = 500 * elapsed;
			if (keys.pressed.SHIFT) addToCam *= 4;
			if (keys.pressed.W) camFollow.y -= addToCam;
			if (keys.pressed.S) camFollow.y += addToCam;
			if (keys.pressed.A) camFollow.x -= addToCam;
			if (keys.pressed.D) camFollow.x += addToCam;
		}
		if (keys.justPressed.R)
		{
			snapToCharacterCamera();
		}

		if (keys.justPressed.COMMA)
		{
			curAnimObj.paused = true;
			curAnimObj.curFrame = FlxMath.wrap(curAnimObj.curFrame - 1, 0, curAnimObj.numFrames - 1);
		}
		if (keys.justPressed.PERIOD)
		{
			curAnimObj.paused = true;
			curAnimObj.curFrame = FlxMath.wrap(curAnimObj.curFrame + 1, 0, curAnimObj.numFrames - 1);
		}

		camGame.zoom = FlxMath.bound(roundTo(curZoom, 0.05), 0.1, 3);

		frameTxt.text = 'Zoom: ${camGame.zoom}';
		frameTxt.text += '\ncurFrame: ${curAnimObj.curFrame}';

		var unscaleFactor = 1 / camGame.zoom;
		originMarker.scale.set(unscaleFactor, unscaleFactor);
		originMarker.centerOrigin();

		if (keys.pressed.CONTROL && keys.justPressed.S)
			saveCharacter();

		super.update(elapsed);
	}

	function saveCharacter()
	{
		var char=curChar;
		var json = {
			"animations": char.animationsArray,
			"image": char.imageFile,
			"scale": char.jsonScale,
			"sing_duration": char.singDuration,
			"healthicon": char.healthIcon,

			"position": char.positionArray,
			"camera_position": char.cameraPosition,

			"flip_x": char.originalFlipX,
			"no_antialiasing": char.noAntialiasing,
			"healthbar_colors": char.healthColorArray
		};

		var data:String = Json.stringify(json, "\t");
		if (data.length > 0)
		{
			new FileReference().save(data, char.curCharacter + ".json");
		}
	}
}