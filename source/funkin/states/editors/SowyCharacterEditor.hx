package funkin.states.editors;

import funkin.states.options.OptionsSubstate.Widget;
import haxe.ds.EnumValueMap;
import flixel.util.FlxColor;
import openfl.display.BitmapData;
import flixel.graphics.FlxGraphic;
import openfl.events.IOErrorEvent;
import openfl.events.Event;
import openfl.net.FileReference;
import haxe.Json;
import flixel.util.FlxSort;
import flixel.input.keyboard.FlxKey;
import funkin.objects.Character;
import flixel.text.FlxText;
import funkin.objects.shaders.BlendModeEffect;
import flixel.math.FlxMath;
import flixel.group.FlxGroup;

import StringTools;

// gonna use enums because why not :shrug:
private enum UI_Tab_ID{
	ANIMATION;
	CHARACTER;
	ICON;
	GUIDE;
}

private typedef UI_Tab = {
	var group:FlxGroup;
	var button:FlxSprite;
}

private class DropdownButton extends FlxSprite{
	public var elements:Array<String>;
	public var curSelected(default, set):Int;

	public var label:FlxText;
	public var text(get, set):String;

	public var callback:Null<(Int, String)->Void>;

	function set_curSelected(idx){
		var curElement = elements[idx];
		text = curElement==null ? '' : curElement;

		if (callback != null)
			callback(idx, curElement);

		return idx;
	}

	function get_text()
		return label.text;
	function set_text(text)
		return label.text = text;

	public function new(x:Float, y:Float, elements:Array<String>, ?width:Int = 118, ?height:Int = 20, ?label:FlxText)
	{
		super(x, y, CoolUtil.makeOutlinedGraphic(width, height, 0xFFFFFFFF, 1, 0xFF000000));

		var label = this.label = (label!=null) ? label : new FlxText();
		label.frameWidth = width - 16;
		label.setPosition(x + 2, y + 3);

		this.elements = elements;
		curSelected = 0;
	}
}

private class DropdownList extends FlxGroup
{
	public final elementHeight:Int = 19;

	public function new(){
		super();

		selector = new FlxSprite().makeGraphic(1, 1);
		selector.scale.set(118, elementHeight);
		selector.updateHitbox();
		selector.color = 0xFF3399FF;
		selector.exists = false;
		add(selector);
	}

	var labels:Array<FlxText> = [];
	function createLabel(?text:String, ?idx:Int = 0){
		var label = new FlxText(2, get_label_y(idx), 0, text);
		label.cameras = cameras;
		label.color = 0xFF000000;
		label.scrollFactor.set();
		label.moves = false;

		labels.push(label);
		return add(label);
	}

	var selector:FlxSprite;
	public var curSelected(default, set):Null<Int> = null;
	function set_curSelected(idx){
		var prevLabel = labels[curSelected];
		if (prevLabel != null)
			prevLabel.color = 0xFF000000;			
		
		var nextLabel = labels[idx];
		if (nextLabel != null){
			nextLabel.color = 0xFFFFFFFF;

			selector.exists = true;
			selector.y = idx * elementHeight;
		}else{
			selector.exists = false;
		}

		return curSelected = idx;
	}

	inline function get_label_y(idx:Int)
		return 3 + idx * elementHeight;

	public function setElements(array:Array<String>)
	{
		for (i in 0...array.length){
			var text:String = array[i];
			var label:FlxText = labels[i];
			
			if (label == null){
				createLabel(text, i);
			}else{
				label.y = get_label_y(i);
				label.text = text;
				label.exists = true;
			}
		}

		for (i in array.length...labels.length){
			var label:FlxText = labels[i];
			if (label != null) label.exists = false;
		}
	}
}

// working name, this will replace the regular character editor name once im done with it 
class SowyCharacterEditor extends MusicBeatState
{
	static var lastCharacterName:String = 'pico';

	var originMarker:FlxSprite;

	var stage:Null<Stage>;
	var curZoom:Float = 1.0;
	var defaultCamZoom(get, null):Float;
	function get_defaultCamZoom() return stage==null ? 1.0 : stage.stageData.defaultZoom;

	var charGroup = new flixel.group.FlxSpriteGroup.FlxTypedSpriteGroup<Character>();
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
	var camAnimList:FlxCamera; // what if all anims don't fit on screen
	var camFollow:FlxObject;

	var hudCams:Array<FlxCamera>;

	public function new(?charName:String, ?stageName:String)
	{
		super();

		if (charName != null)
			lastCharacterName = charName;
	}

	override function destroy(){
		StartupState.specialKeysEnabled = true;

		return super.destroy();
	}

	override function create()
	{
		StartupState.specialKeysEnabled = false;

		camGame = new FlxCamera();
		camHUD = new FlxCamera();
		camFollow = new FlxObject();

		hudCams = [camHUD];
		camGame.pixelPerfectRender = true;
		camHUD.pixelPerfectRender = true;
		camGame.follow(camFollow, LOCKON, 0.06);
		camGame.bgColor = 0xFFAAAAAA;
		camHUD.bgColor = 0x00000000;
		
		FlxG.cameras.reset(camGame);
		FlxG.cameras.add(camHUD, false);
		FlxG.cameras.setDefaultDrawTarget(camGame, true);
		add(camFollow);

		////
		add(charGroup);

		add(animTxtGroup);

		frameTxt = _makeAnimTxt();
		frameTxt.y = FlxG.height - 18 * 2 - 4;
		add(frameTxt);

		makeUI();
		add(ui_group);

		////
		originMarker = new FlxSprite(0, 0, Paths.image("stageeditor/originMarker"));
		originMarker.offset.set(originMarker.width / 2, originMarker.height / 2);
		add(originMarker);

		super.create();

		FlxG.mouse.visible = true;

		reloadStage();
		changeMainChar("bf");
	}

	var ui_cam:FlxCamera;
	var ui_group:FlxGroup;

	var ui_dd_cam:FlxCamera;
	var ui_dropdown:DropdownList;
	var ui_curDropdown:Null<DropdownButton> = null;

	var ui_curTab:Null<UI_Tab_ID> = null;
	var ui_tabs = new EnumValueMap<UI_Tab_ID, UI_Tab>();

	var characterDidi:DropdownButton;

	function openDropdown(?button:DropdownButton)
	{
		if (button == null){
			ui_dd_cam.visible = ui_dropdown.visible = false;
			ui_dd_cam.exists = ui_dropdown.exists = false;
			ui_curDropdown = null;
		}else{
			ui_dropdown.setElements(button.elements);

			ui_dd_cam.height = button.elements.length * ui_dropdown.elementHeight;
			ui_dd_cam.setPosition(ui_cam.x + button.x, ui_cam.y + button.y + button.height);

			ui_dd_cam.visible = ui_dropdown.visible = true;
			ui_dd_cam.exists = ui_dropdown.exists = true;
			ui_curDropdown = button;
		}
	}
	inline function closeDropdown()
		openDropdown(null);
		

	var characterList:Array<String> = Character.getAllCharacters();

	function makeUI()
	{
		ui_group = new FlxGroup();

		ui_cam = new FlxCamera();
		ui_cam.setSize(400, 300);
		ui_cam.setPosition(
			FlxG.width - ui_cam.width - 10,
			10 + 20
		);
		ui_cam.bgColor = 0xFF444444;
		ui_cam.bgColor.alphaFloat = 0.85;
		FlxG.cameras.add(ui_cam, false);

		var ui_cams = [ui_cam];

		ui_dd_cam = new FlxCamera();
		ui_dd_cam.bgColor = 0xFFFFFFFF;
		ui_dd_cam.width = 118;
		ui_dd_cam.exists = false;
		FlxG.cameras.add(ui_dd_cam, false);

		ui_dropdown = new DropdownList();
		ui_dropdown.cameras = [ui_dd_cam];
		ui_dropdown.setElements(Character.getAllCharacters());
		ui_dropdown.exists = false;
		add(ui_dropdown);

		//// Create tab buttons
		final tabsToAdd:Array<UI_Tab_ID> = UI_Tab_ID.createAll();
		
		final tabPadding = 4;
		final tabColor = FlxColor.fromRGB(70, 70, 70);

		final tabWidth:Float = (ui_cam.width - tabPadding * Math.max(0, tabsToAdd.length - 1)) / tabsToAdd.length;
		final tabHeight:Float = 20;
		
		var tabX = ui_cam.x;
		var tabY = ui_cam.y - tabHeight;
		var pixel = FlxGraphic.fromBitmapData(new BitmapData(1, 1), false, "charactereditor_tabpixel", false);
		
		for (tabId in tabsToAdd)
		{
			var tabIdName:String = tabId.getName().toLowerCase();
			var tabName:String = tabIdName.charAt(0).toUpperCase() + tabIdName.substr(1).toLowerCase();

			var button = new FlxSprite(tabX, tabY, pixel);
			button.scale.set(tabWidth, tabHeight);
			button.updateHitbox();
			button.cameras = hudCams;
			button.color = tabColor;

			var buttonLabel = new FlxText(0, 0, 0, tabName); // Paths.getString() blah blah
			buttonLabel.setPosition(
				tabX + 6, //+ (tabWidth - buttonLabel.width) * 0.5,
				tabY + (tabHeight - buttonLabel.height) * 0.5
			);
			buttonLabel.cameras = hudCams;

			/////
			var group = new FlxGroup();
			group.cameras = ui_cams; // for what purpose
			group.exists = false;

			group.add(new FlxText(10, 10, 0, tabName)); // test

			ui_group.add(button);
			ui_group.add(buttonLabel);
			ui_group.add(group);
			ui_tabs.set(
				tabId,
				{
					button: button,
					group: group
				}
			);

			tabX += tabWidth + tabPadding;
		}

		////
		var tabG = ui_tabs.get(CHARACTER).group;

		characterDidi = new DropdownButton(6, 6, characterList);
		characterDidi.callback = (idx, name)->{changeMainChar(name);};
		tabG.add(characterDidi);
		tabG.add(characterDidi.label);
		
		// temp
		var stageDidi = new DropdownButton(400 - 118 - 6, 6, Stage.getAllStages());
		stageDidi.callback = (idx, name)->{reloadStage(name); snapToCharacterCamera();};
		tabG.add(stageDidi);
		tabG.add(stageDidi.label);

		////
		var tabG = ui_tabs.get(ICON).group;

		////
		selectTab(CHARACTER);
	}

	function selectTab(id:UI_Tab_ID)
	{
		var prevTab = ui_curTab==null ? null : ui_tabs.get(ui_curTab);
		if (prevTab != null){
			prevTab.button.color = FlxColor.fromRGB(70, 70, 70);
			prevTab.group.exists = false;
		}

		var newTab = id==null ? null : ui_tabs.get(id);
		if (newTab != null){
			newTab.button.color = FlxColor.fromRGB(128, 128, 128);
			newTab.group.exists = true;
			ui_curTab = id;
		}
	}

	function reloadStage(?name:String){
		if (stage != null){
			remove(stage);
			remove(stage.foreground);
			stage.destroy();
		}

		stage = new Stage(name);
		if (name != null) stage.buildStage();
		insert(members.indexOf(charGroup), stage);
		insert(members.indexOf(charGroup)+1, stage.foreground);

		camGame.bgColor = FlxColor.fromString(stage.stageData.bg_color);

		var pos = stage.stageData.boyfriend;
		charGroup.setPosition(
			pos[0],
			pos[1]
		);

		if (curChar != null)
		snapToCharacterCamera();
		camGame.snapToTarget();
	}

	function changeMainChar(name:String){
		if (curChar != null){
			curChar.destroy();
			charGroup.remove(curChar);
		}

		makeChar(name);
		snapToCharacterCamera();
	}

	function makeChar(name:String){
		var char = new Character(0, 0, name, true, true);
		
		
		var sp = char.isPlayer ? stage.stageData.boyfriend : stage.stageData.opponent;
		char.setPosition(
			/*sp[0]+*/char.positionArray[0], 
			/*sp[1]+*/char.positionArray[1]
		);

		charGroup.add(char);
		charIdx = charGroup.members.length - 1;

		curChar.animationsArray.sort(animSortFunc);
		generateAnimTxts();
		animIdx = 0;
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
		return Math.fround(val / roundFactor) * roundFactor;
	function roundToInt(val:Float, roundFactor:Int)
		return Math.round(val / roundFactor) * roundFactor;

	/*
	inline private function overCam(camera:FlxCamera):Bool{
		return !(FlxG.mouse.x < camera.x	||	FlxG.mouse.y < camera.y		||	FlxG.mouse.x > camera.x+camera.width	||	FlxG.mouse.y > camera.y+camera.height);
	}
	*/

	function updateMouse():Void
	{
		final mouse = FlxG.mouse;
		
		if (mouse.justPressed)
		{
			if (ui_dd_cam.exists){
				var mousePos = mouse.getPositionInCameraView(ui_dd_cam);
				if (!( mousePos.x < 0
					|| mousePos.y < 0
					|| mousePos.x > ui_dd_cam.width
					|| mousePos.y > ui_dd_cam.height)
				){
					ui_curDropdown.curSelected = Math.floor(mousePos.y / ui_dropdown.elementHeight);
				}

				closeDropdown();
				return;
			}

			for (name => tab in ui_tabs)
			{
				if (mouse.overlaps(tab.button, camHUD)){
					selectTab(name);
					return;
				}
			}
			
			for (obj in ui_tabs.get(ui_curTab).group)
			{
				if (!mouse.overlaps(obj, ui_cam))
					continue;

				if (obj is DropdownButton){
					var obj:DropdownButton = cast obj;
					openDropdown(obj);
					return;
				}
			}
			
		}

		/*
		if (mouse.wheel != 0)
		{

		}
		*/
	}

	var curAnimObj:Null<flixel.animation.FlxAnimation> = null;
	var curAnimArray:Null<AnimArray> = null;

	inline function updateCurrentAnimVars(){
		curAnimObj = curChar != null ? curChar.animation.curAnim : null;
		curAnimArray = curChar.animationsArray[animIdx];
	}

	function updateKeys()
	{
		var keys = FlxG.keys;
		/*
			if (keys.justPressed.ANY)
				trace([for (input in keys.getIsDown()){FlxKey.toStringMap.get(input.ID);}]);
		*/

		if (keys.justPressed.QUOTE)
			animIdx--;
		if (keys.justPressed.SLASH)
			animIdx++;
		
		updateCurrentAnimVars(); // hmmm

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
				curZoom += FlxG.elapsed * curZoom;
			if (keys.pressed.Q)
				curZoom -= FlxG.elapsed * curZoom;
		}
		
		if (keys.pressed.A || keys.pressed.S || keys.pressed.W || keys.pressed.D)
		{
			var addToCam:Float = 500 * FlxG.elapsed;
			if (keys.pressed.SHIFT) addToCam *= 4;
			if (keys.pressed.W) camFollow.y -= addToCam;
			if (keys.pressed.S) camFollow.y += addToCam;
			if (keys.pressed.A) camFollow.x -= addToCam;
			if (keys.pressed.D) camFollow.x += addToCam;
		}
		if (keys.justPressed.R)
		{
			snapToCharacterCamera();
			curZoom = curZoom == 1.0 ? defaultCamZoom : 1.0;
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
	}

	override function update(elapsed:Float)
	{
		updateMouse();

		if (FlxG.keys.pressed.BACKSPACE){
			MusicBeatState.switchState(new MainMenuState());
		}else if (FlxG.keys.pressed.CONTROL && FlxG.keys.justPressed.S){
			saveJSON((FlxG.keys.pressed.SHIFT) ? charToFunkinData(curChar) : charToPsychData(curChar), curChar.curCharacter);
		}else
			updateKeys();

		camGame.zoom = FlxMath.bound(roundTo(curZoom, 0.05), 0.1, 3);

		frameTxt.text = 'Zoom: ${camGame.zoom}';
		frameTxt.text += '\ncurFrame: ${curAnimObj.curFrame}';

		var unscaleFactor = 1 / camGame.zoom;
		originMarker.scale.set(unscaleFactor, unscaleFactor);
		originMarker.centerOrigin();

		super.update(elapsed);
	}

	///////////
	// Try moving these somewhere else
	///////////

	public static function saveJSON(json:Dynamic, ?name:String)
	{
		var data:String = Json.stringify(json, "\t");
		if (data.length > 0)
		{
			new FileReference().save(data, name==null ? null : '$name.json');
		}
	}

	public static function charToPsychData(char:Character){
		return {
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
	}
	
	public static function psychToFunkinAnim(anim:AnimArray) return {
		"name": anim.anim,
		"prefix": anim.name,
		"offsets": anim.offsets,
		"looped": anim.loop,
		"frameRate": 24,
		"flipX": false,
		"flipY": false
	}

	public static function charToFunkinData(char:Character){
		return {
			"generatedBy": "TROLL ENGINE",
			"version": "1.0.0",

			"name": char.curCharacter,
			"assetPath": char.imageFile,
			"renderType": Character.getImageFileType(char.imageFile),
			"flipX": char.originalFlipX,
			"scale": char.jsonScale,
			"isPixel": char.noAntialiasing == true, // i think // isPixel also assumes its scaled up by 6 so

			"offsets": char.positionArray,
			"cameraOffsets": char.cameraPosition,

			"singTime": char.singDuration, 
			"danceEvery": char.danceEveryNumBeats,
			"startingAnimation": char.danceIdle ? "danceLeft" : "idle",

			"healthIcon": {
				"id": char.healthIcon,
				"offsets": [0, 0],
				"isPixel": StringTools.endsWith(char.healthIcon, "-pixel"),
				"flipX": false,
				"scale": 1
			},

			"animations": [for (anim in char.animationsArray) psychToFunkinAnim(anim)],
		};
	}
}