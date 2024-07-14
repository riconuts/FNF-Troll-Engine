package funkin.states.editors;

import funkin.objects.Stage;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.addons.ui.*;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.group.FlxSpriteGroup;
import flixel.math.*;
import flixel.text.FlxText;
import flixel.ui.*;
import flixel.util.FlxColor;
import haxe.Json;
import openfl.events.Event;
import openfl.events.IOErrorEvent;
import openfl.net.FileReference;

using StringTools;
#if sys
import sys.FileSystem;
#end
#if discord_rpc
import funkin.api.Discord.DiscordClient;
#end

class StageEditorState extends MusicBeatState{
	public static var curStage = "stage";

	public var camGame:FlxCamera = new FlxCamera();
	public var camHUD:FlxCamera = new FlxCamera();
	public var camOverlay:FlxCamera = new FlxCamera();
	public var camOther:FlxCamera = new FlxCamera();
	private var camMenu:FlxCamera = new FlxCamera();

	public var camFollow = new FlxPoint();
	public var camFollowPos = new FlxObject(0, 0, 1, 1);
	
	public var defaultCamZoom:Float = 1;
	public var cameraSpeed:Float = 1;

	public var boyfriend:Character;
	public var dad:Character;
	public var gf:Character;

	public var boyfriendGroup:FlxSpriteGroup = new FlxSpriteGroup();
	public var dadGroup:FlxSpriteGroup = new FlxSpriteGroup();
	public var gfGroup:FlxSpriteGroup = new FlxSpriteGroup();

	public var BF_X:Float = 770;
	public var BF_Y:Float = 100;
	public var DAD_X:Float = 100;
	public var DAD_Y:Float = 100;
	public var GF_X:Float = 400;
	public var GF_Y:Float = 130;

	public var boyfriendCameraOffset:Array<Float> = null;
	public var opponentCameraOffset:Array<Float> = null;
	public var girlfriendCameraOffset:Array<Float> = null;

	var stage:Stage;
	var stageData:StageFile;

	var focusedChar(default, set):String = "boyfriend";
	function set_focusedChar(who:String):String{
		switch (who)
		{
			case "dad":
				camFollow.set(dad.getMidpoint().x + 150, dad.getMidpoint().y - 100);
				camFollow.x += dad.cameraPosition[0] + opponentCameraOffset[0];
				camFollow.y += dad.cameraPosition[1] + opponentCameraOffset[1];

				charTxt.text = "Opponent";
				xPosTxt.text = "X: " + DAD_X;
				yPosTxt.text = "Y: " + DAD_Y;
			case "boyfriend":
				camFollow.set(boyfriend.getMidpoint().x - 100, boyfriend.getMidpoint().y - 100);
				camFollow.x -= boyfriend.cameraPosition[0] - boyfriendCameraOffset[0];
				camFollow.y += boyfriend.cameraPosition[1] + boyfriendCameraOffset[1];

				charTxt.text = "Boyfriend";
				xPosTxt.text = "X: " + BF_X;
				yPosTxt.text = "Y: " + BF_Y;
			case "gf":
				camFollow.set(gf.getMidpoint().x - 100, gf.getMidpoint().y - 100);
				camFollow.x -= gf.cameraPosition[0] + girlfriendCameraOffset[0];
				camFollow.y += gf.cameraPosition[1] + girlfriendCameraOffset[1];

				xPosTxt.text = "X: " + GF_X;
				yPosTxt.text = "Y: " + GF_Y;
		}

		return focusedChar = who;
	}

	// editor shit
	/*
	var UI_characterbox:FlxUITabMenu;
	var UI_stagebox:FlxUITabMenu;
	*/
	var characterList:Array<String> = [];
	var dadDropDown:FlxUIDropDownMenuCustom;
	var gfDropDown:FlxUIDropDownMenuCustom;
	var bfDropDown:FlxUIDropDownMenuCustom;

	var charTxt:FlxText;
	var xPosTxt:FlxText;
	var yPosTxt:FlxText;

	function updateBF(name){
		if (boyfriend != null){
			boyfriendGroup.remove(boyfriend, true);
			boyfriend.destroy();
		}
		boyfriend = new Character(0, 0, name);
		startCharacterPos(boyfriend);
		boyfriendGroup.add(boyfriend);
	}
	function updateDad(name){
		if (dad != null){
			dadGroup.remove(dad, true);
			dad.destroy();
		}
		dad = new Character(0, 0, name);
		startCharacterPos(dad);
		dadGroup.add(dad);
	}
	function updateGF(name){
		if (gf != null){
			gfGroup.remove(gf, true);
			gf.destroy();
		}
		gf = new Character(0, 0, name);
		gf.scrollFactor.set(0.95, 0.95);
		startCharacterPos(gf);
		gfGroup.add(gf);
	}

	override function create()
	{
		#if discord_rpc
		// Updating Discord Rich Presence
		DiscordClient.changePresence("In the Stage Editor", null);

		FlxG.mouse.visible = true;
		#end
		
		//// editor shit
		var tabs = [{name: 'Character Preview', label: 'Character Preview'},];
		var UI_characterbox = new FlxUITabMenu(null, tabs, true);
		UI_characterbox.cameras = [camMenu];

		UI_characterbox.resize(250, 190);
		UI_characterbox.x = FlxG.width - 275;
		UI_characterbox.y = 25;
		UI_characterbox.scrollFactor.set();

		var tab_group = new FlxUI(null, UI_characterbox);
		tab_group.name = "Character Preview";

		var weirdArray = FlxUIDropDownMenuCustom.makeStrIdLabelArray([''], true);
		dadDropDown = new FlxUIDropDownMenuCustom(15, 110, weirdArray, function(character:String)
		{
			var daAnim = characterList[Std.parseInt(character)];
			updateDad(daAnim);
			
			reloadCharacterArray();
			dadDropDown.selectedLabel = daAnim;
		});
		gfDropDown = new FlxUIDropDownMenuCustom(15, 70, weirdArray, function(character:String)
		{
			var daAnim = characterList[Std.parseInt(character)];
			updateGF(daAnim);

			reloadCharacterArray();
			gfDropDown.selectedLabel = daAnim;
		});
		bfDropDown = new FlxUIDropDownMenuCustom(15, 30, weirdArray, function(character:String)
		{
			var daAnim = characterList[Std.parseInt(character)];
			updateBF(daAnim);

			reloadCharacterArray();
			bfDropDown.selectedLabel = daAnim;
		});

		tab_group.add(new FlxText(bfDropDown.x, bfDropDown.y - 15, 200, "Boyfriend:"));
		tab_group.add(new FlxText(dadDropDown.x, dadDropDown.y - 15, 200, "Opponent:"));
		tab_group.add(new FlxText(gfDropDown.x, gfDropDown.y - 15, 200, "Girlfriend:"));

		tab_group.add(gfDropDown);
		tab_group.add(dadDropDown);
		tab_group.add(bfDropDown);
		
		UI_characterbox.addGroup(tab_group);

		var tabs = [{name: 'Stage Data', label: 'Stage Data'},];
		var UI_stagebox = new FlxUITabMenu(null, tabs, true);
		UI_stagebox.cameras = [camMenu];

		UI_stagebox.resize(250, 360);
		UI_stagebox.x = FlxG.width - 275;
		UI_stagebox.y = UI_characterbox.y + UI_characterbox.height;
		UI_stagebox.scrollFactor.set();

		var tab_group = new FlxUI(null, UI_characterbox);

		var stages = Stage.getAllStages();
		var stageDropDown = new FlxUIDropDownMenuCustom(15, 30, FlxUIDropDownMenuCustom.makeStrIdLabelArray(stages, true), function(character:String){
			curStage = stages[Std.parseInt(character)];
			makeStage();
		});
		tab_group.name = "Stage Data";
		var saveButton:FlxButton = new FlxButton(stageDropDown.x + stageDropDown.width + 15, 30, "Save Stage", function(){
			saveStage();
		});
		tab_group.add(saveButton);
		tab_group.add(stageDropDown);
		UI_stagebox.addGroup(tab_group);

		add(UI_stagebox);
		add(UI_characterbox);
		

		
		yPosTxt = new FlxText(3, camMenu.height - 24, camMenu.width, "", 20);
		xPosTxt = new FlxText(3, yPosTxt.y - 24, camMenu.width, "", 20);
		charTxt = new FlxText(3, xPosTxt.y - 24, camMenu.width, "", 20);

		xPosTxt.setFormat(Paths.font("calibri.ttf"), 20, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		xPosTxt.scrollFactor.set();
		xPosTxt.borderSize = 1.25;
		xPosTxt.cameras = [camMenu];

		yPosTxt.setFormat(Paths.font("calibri.ttf"), 20, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		yPosTxt.scrollFactor.set();
		yPosTxt.borderSize = 1.25;
		yPosTxt.cameras = [camMenu];

		charTxt.setFormat(Paths.font("calibri.ttf"), 20, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		charTxt.scrollFactor.set();
		charTxt.borderSize = 1.25;
		charTxt.cameras = [camMenu];

		add(charTxt);
		add(yPosTxt);
		add(xPosTxt);

		//// le cameras xd
		camGame.follow(camFollowPos, LOCKON, 1);
		camGame.focusOn(camFollow);
		
		camOverlay.bgColor.alpha = 0;
		camHUD.bgColor.alpha = 0;
		camOther.bgColor.alpha = 0;
		camMenu.bgColor.alpha = 0;

		FlxG.cameras.reset(camGame);
		FlxG.cameras.add(camHUD, false);
		FlxG.cameras.add(camOverlay, false);
		FlxG.cameras.add(camOther, false);
		FlxG.cameras.add(camMenu, false);

		FlxG.cameras.setDefaultDrawTarget(camGame, true);

		reloadCharacterArray();
		makeStage();

		focusedChar = "boyfriend";
		changeCharacterX();
		changeCharacterY();
		
		super.create();
	}

	function changeCharacterX(add:Float = 0){
		var sowy = "X: ";
		switch (focusedChar)
		{
			case "boyfriend":
				sowy += boyfriendGroup.x = BF_X += add;
			case "dad":
				sowy += dadGroup.x = DAD_X += add;
			case "gf":
				sowy += gfGroup.x = GF_X += add;
		}
		xPosTxt.text = sowy;
	}
	function changeCharacterY(add:Float = 0){
		var sowy = "Y: ";
		switch (focusedChar){
			case "boyfriend":
				sowy += boyfriendGroup.y = BF_Y += add;
			case "dad":
				sowy += dadGroup.y = DAD_Y += add;
			case "gf":
				sowy += gfGroup.y = GF_Y += add;
		}
		yPosTxt.text = sowy;
	}

	override function update(elapsed:Float)
	{
		if (FlxG.keys.justPressed.ONE){
			focusedChar = "dad";
		}else if (FlxG.keys.justPressed.TWO){
			focusedChar = "gf";
		}else if (FlxG.keys.justPressed.THREE){
			focusedChar = "boyfriend";
		}

		var move = FlxG.keys.pressed.SHIFT ? 100 : 10;
		if (FlxG.keys.justPressed.RIGHT)
			changeCharacterX(move);
		if (FlxG.keys.justPressed.LEFT)
			changeCharacterX(-move);
		if (FlxG.keys.justPressed.DOWN)
			changeCharacterY(move);
		if (FlxG.keys.justPressed.UP)
			changeCharacterY(-move);

		if (controls.BACK)
			MusicBeatState.switchState(new funkin.states.editors.MasterEditorMenu());

		var lerpVal:Float = CoolUtil.boundTo(elapsed * 2.4 * cameraSpeed, 0, 1);
		camFollowPos.setPosition(FlxMath.lerp(camFollowPos.x, camFollow.x, lerpVal), FlxMath.lerp(camFollowPos.y, camFollow.y, lerpVal));

		super.update(elapsed);
	}

	function makeStage()
	{
		if (stage != null){
			if (stage.foreground != null){
				remove(stage.foreground);
				stage.foreground.destroy();
			}

			remove(stage);
			stage.destroy();
		}

		stage = new Stage(curStage).buildStage();
		stageData = stage.stageData;

		var color = FlxColor.fromString(stageData.bg_color);
		camGame.bgColor = color != null ? color : FlxColor.BLACK;

		////
		defaultCamZoom = 1 * stageData.defaultZoom;

		BF_X = stageData.boyfriend[0];
		BF_Y = stageData.boyfriend[1];
		GF_X = stageData.girlfriend[0];
		GF_Y = stageData.girlfriend[1];
		DAD_X = stageData.opponent[0];
		DAD_Y = stageData.opponent[1];

		if (stageData.camera_speed != null)
			cameraSpeed = stageData.camera_speed;

		boyfriendCameraOffset = stageData.camera_boyfriend;
		if (boyfriendCameraOffset == null)
			boyfriendCameraOffset = [0, 0];

		opponentCameraOffset = stageData.camera_opponent;
		if (opponentCameraOffset == null)
			opponentCameraOffset = [0, 0];

		girlfriendCameraOffset = stageData.camera_girlfriend;
		if (girlfriendCameraOffset == null)
			girlfriendCameraOffset = [0, 0];
		
		////
		boyfriendGroup.x = BF_X;
		boyfriendGroup.y = BF_Y;

		dadGroup.x = DAD_X;
		dadGroup.y = DAD_Y;

		gfGroup.x = GF_X;
		gfGroup.y = GF_Y;
		////
		updateBF(bfDropDown.selectedLabel);
		updateGF(gfDropDown.selectedLabel);
		updateDad(dadDropDown.selectedLabel);

		////
		camGame.zoom = defaultCamZoom;

		var camPos:FlxPoint = new FlxPoint(girlfriendCameraOffset[0], girlfriendCameraOffset[1]);
		if (gf != null){
			camPos.x += gf.getGraphicMidpoint().x + gf.cameraPosition[0];
			camPos.y += gf.getGraphicMidpoint().y + gf.cameraPosition[1];
		}else{
			camPos.set(opponentCameraOffset[0], opponentCameraOffset[1]);
			camPos.x += dad.getGraphicMidpoint().x + dad.cameraPosition[0];
			camPos.y += dad.getGraphicMidpoint().y + dad.cameraPosition[1];
		}
		camFollow.set(camPos.x, camPos.y);

		////
		if (dad.curCharacter.startsWith('gf')){
			dad.setPosition(GF_X, GF_Y);
			if (gf != null)
				gf.visible = false;
		}

		// trace(stageData);

		remove(gfGroup);
		remove(dadGroup);
		remove(boyfriendGroup);

		add(stage);
		add(gfGroup);
		add(dadGroup);
		add(boyfriendGroup);
		add(stage.foreground);
	}

	function startCharacterPos(char:Character, ?gfCheck:Bool = false)
	{
		if (gfCheck && char.curCharacter.startsWith('gf')){ // IF DAD IS GIRLFRIEND, HE GOES TO HER POSITION
			char.setPosition(GF_X, GF_Y);
			char.scrollFactor.set(0.95, 0.95);
			char.danceEveryNumBeats = 2;
		}
		char.x += char.positionArray[0];
		char.y += char.positionArray[1];
	}

	function reloadCharacterArray()
	{
		characterList = Character.getAllCharacters();

		var weirdArray = FlxUIDropDownMenuCustom.makeStrIdLabelArray(characterList, true);
		dadDropDown.setData(weirdArray);
		gfDropDown.setData(weirdArray);
		bfDropDown.setData(weirdArray);
	}

	var _file:FileReference;
	
	function onSaveComplete(_):Void
	{
		_file.removeEventListener(Event.COMPLETE, onSaveComplete);
		_file.removeEventListener(Event.CANCEL, onSaveCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		_file = null;
		FlxG.log.notice("Successfully saved file.");
	}

	/**
	 * Called when the save file dialog is cancelled.
	 */
	function onSaveCancel(_):Void
	{
		_file.removeEventListener(Event.COMPLETE, onSaveComplete);
		_file.removeEventListener(Event.CANCEL, onSaveCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		_file = null;
	}

	/**
	 * Called if there is an error while saving the gameplay recording.
	 */
	function onSaveError(_):Void
	{
		_file.removeEventListener(Event.COMPLETE, onSaveComplete);
		_file.removeEventListener(Event.CANCEL, onSaveCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		_file = null;
		FlxG.log.error("Problem saving file");
	}

	function saveStage()
	{
		var json = {
			"directory": "",
			"defaultZoom": stageData.defaultZoom,

			"boyfriend": [BF_X, BF_Y],
			"girlfriend": [GF_X, GF_Y],
			"opponent": [DAD_X, DAD_Y],
			"hide_girlfriend": stageData.hide_girlfriend,

			"camera_boyfriend": stageData.camera_boyfriend,
			"camera_opponent": stageData.camera_opponent,
			"camera_girlfriend": stageData.camera_girlfriend,
			"camera_speed": stageData.camera_speed,

			// "pixel_size": stageData.pixel_size,

			"preloadStrings": stageData.preloadStrings,
			#if MULTICORE_LOADING
			"preload": stageData.preload
			#end
		};

		var data:String = Json.stringify(json, "\t");

		if (data.length > 0)
		{
			_file = new FileReference();
			_file.addEventListener(Event.COMPLETE, onSaveComplete);
			_file.addEventListener(Event.CANCEL, onSaveCancel);
			_file.addEventListener(IOErrorEvent.IO_ERROR, onSaveError);
			_file.save(data, curStage + ".json");
		}
	}
}