package funkin.states.editors;

import funkin.objects.hud.HealthIcon;
import funkin.objects.Character;
import funkin.data.CharacterData;
import animateatlas.AtlasFrameMaker;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.addons.display.FlxGridOverlay;
import flixel.addons.ui.FlxUIDropDownMenu;
import flixel.addons.ui.FlxInputText;
import flixel.addons.ui.FlxUI9SliceSprite;
import flixel.addons.ui.FlxUI;
import flixel.addons.ui.FlxUICheckBox;
import flixel.addons.ui.FlxUIInputText;
import flixel.addons.ui.FlxUINumericStepper;
import flixel.addons.ui.FlxUITabMenu;
import flixel.addons.ui.FlxUITooltip.FlxUITooltipStyle;
import flixel.animation.FlxAnimation;
import flixel.graphics.FlxGraphic;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.input.keyboard.FlxKey;
import flixel.system.debug.interaction.tools.Pointer.GraphicCursorCross;
import flixel.text.FlxText;
import flixel.ui.FlxButton;
import flixel.util.FlxColor;
import haxe.Json;
import lime.system.Clipboard;
import openfl.events.Event;
import openfl.events.IOErrorEvent;
import openfl.net.FileReference;

using StringTools;

#if DISCORD_ALLOWED
import funkin.api.Discord.DiscordClient;
#end

final TemplateCharacter:String = '{
	"animations": [
		{
			"loop": false,
			"offsets": [
				0,
				0
			],
			"fps": 24,
			"anim": "idle",
			"indices": [],
			"name": "Dad idle dance"
		},
		{
			"offsets": [
				0,
				0
			],
			"indices": [],
			"fps": 24,
			"anim": "singLEFT",
			"loop": false,
			"name": "Dad Sing Note LEFT"
		},
		{
			"offsets": [
				0,
				0
			],
			"indices": [],
			"fps": 24,
			"anim": "singDOWN",
			"loop": false,
			"name": "Dad Sing Note DOWN"
		},
		{
			"offsets": [
				0,
				0
			],
			"indices": [],
			"fps": 24,
			"anim": "singUP",
			"loop": false,
			"name": "Dad Sing Note UP"
		},
		{
			"offsets": [
				0,
				0
			],
			"indices": [],
			"fps": 24,
			"anim": "singRIGHT",
			"loop": false,
			"name": "Dad Sing Note RIGHT"
		}
	],
	"no_antialiasing": false,
	"image": "characters/DADDY_DEAREST",
	"position": [
		0,
		0
	],
	"healthicon": "face",
	"flip_x": false,
	"healthbar_colors": [
		161,
		161,
		161
	],
	"camera_position": [
		0,
		0
	],
	"sing_duration": 6.1,
	"scale": 1
}';

class CharacterEditorState extends MusicBeatState
{
	static function getAnimOrder(name:String):Int {
		var points = 0;

		for (i => aaa in ['idle', 'singLEFT', 'singDOWN', 'singUP', 'singRIGHT']){
			if (name.startsWith(aaa))
				points += (-272727) + i*10;
		}
		for (i => aaa in ['miss', 'alt', 'loop']){
			if (name.endsWith(aaa))
				points += (2727) + i;
		}

		return points;
	}
	
	static function animSortFunc(a:AnimArray, b:AnimArray)
		return getAnimOrder(a.anim) - getAnimOrder(b.anim);

	////
	var goToPlayState:Bool = true;

	var originMarker:FlxSprite;
	var char:Character;
	var ghostChar:Null<Character>;
	var bgLayer:FlxTypedGroup<FlxSprite>;
	var charLayer:FlxTypedGroup<Character>;
	var dumbTexts:FlxTypedGroup<FlxText>;
	//var animList:Array<String> = [];
	var curAnim:Int = 0;
	var charName:String = 'pico';
	var camFollow:FlxObject;

	public function new(charName:String = 'pico', goToPlayState:Bool = true) {
		super();
		this.charName = charName;
		this.goToPlayState = goToPlayState;
	}

	var UI_box:FlxUITabMenu;
	var UI_characterbox:FlxUITabMenu;

	private var camEditor:FlxCamera;
	private var camHUD:FlxCamera;
	private var camMenu:FlxCamera;

	var changeBGbutton:FlxButton;
	var testModeButton:FlxButton;
	var leHealthIcon:HealthIcon;
	var characterList:Array<String> = [];

	var cameraFollowPointer:FlxSprite;
	var healthBarBG:FlxSprite;

	var ghostCamPointer:FlxSprite;

	override function create()
	{
		//FlxG.sound.playMusic(Paths.music('breakfast'), 0.5);

		camEditor = new FlxCamera();
		camHUD = new FlxCamera();
		camHUD.bgColor.alpha = 0;
		camMenu = new FlxCamera();
		camMenu.bgColor.alpha = 0;

		FlxG.cameras.reset(camEditor);
		FlxG.cameras.add(camHUD, false);
		FlxG.cameras.add(camMenu, false);
		FlxG.cameras.setDefaultDrawTarget(camEditor, true);

		bgLayer = new FlxTypedGroup<FlxSprite>();
		add(bgLayer);
		charLayer = new FlxTypedGroup<Character>();
		add(charLayer);

		var pointer:FlxGraphic = FlxGraphic.fromClass(GraphicCursorCross);
	
		ghostCamPointer = new FlxSprite().loadGraphic(pointer);
		ghostCamPointer.setGraphicSize(40, 40);
		ghostCamPointer.updateHitbox();
		ghostCamPointer.color = FlxColor.BLUE;
		ghostCamPointer.alpha = 0;
		ghostCamPointer.visible = false;
		add(ghostCamPointer);
		
		cameraFollowPointer = new FlxSprite().loadGraphic(pointer);
		cameraFollowPointer.setGraphicSize(40, 40);
		cameraFollowPointer.updateHitbox();
		cameraFollowPointer.color = FlxColor.RED;
		add(cameraFollowPointer);

		originMarker = new FlxSprite(0, 0, Paths.image("stageeditor/originMarker"));
		originMarker.offset.set(originMarker.width / 2, originMarker.height / 2);
		add(originMarker);

		testModeButton = new FlxButton(FlxG.width - 360, 25, "Test: OFF", function()
		{
			testModeButton.text = (testMode = !testMode) ? "Test: ON" : "Test: OFF";
		});
		testModeButton.cameras = [camMenu];

		changeBGbutton = new FlxButton(FlxG.width - 360, 55, "BG: BLACK", function()
		{
			changeBGbutton.text = (onPixelBG = !onPixelBG) ? "BG: BLACK" : "BG: WHITE";
			reloadBGs();
		});
		changeBGbutton.cameras = [camMenu];

		dumbTexts = new FlxTypedGroup<FlxText>();
		add(dumbTexts);
		dumbTexts.cameras = [camHUD];

		var healthbarGraphic = Paths.image('healthBar');
		if (healthbarGraphic == null)
			healthbarGraphic = CoolUtil.makeOutlinedGraphic(600, 18, 0xFFFFFFFF, 5, 0xFF000000);

		healthBarBG = new FlxSprite(30, FlxG.height - 75, healthbarGraphic);
		healthBarBG.scrollFactor.set();
		add(healthBarBG);
		healthBarBG.cameras = [camHUD];

		leHealthIcon = new HealthIcon();
		leHealthIcon.y = FlxG.height - 150;
		add(leHealthIcon);
		leHealthIcon.cameras = [camHUD];

		var height = FlxG.height;
		var greenHill = new FlxSprite(-height* 0.5 + 220, -height + 718);
		greenHill.makeGraphic(height, height);
		//bgLayer.add(greenHill);

		camFollow = new FlxObject(0, 0, 2, 2);
		var mid = greenHill.getMidpoint();
		camFollow.setPosition(mid.x, mid.y);
		add(camFollow);
		FlxG.camera.follow(camFollow);

		loadChar(charName.startsWith('bf'));
		resetCam();

		var tipTextArray:Array<String> = "E/Q - Camera Zoom In/Out
		\nR - Reset Camera Zoom
		\nIJKL - Move Camera
		\nW/S - Previous/Next Animation
		\nSpace - Play Animation
		\nArrow Keys - Move Character Offset
		\nT - Reset Current Offset
		\nHold Shift to Move 10x faster\n".split('\n');

		for (i in 0...tipTextArray.length-1)
		{
			var tipText:FlxText = new FlxText(FlxG.width - 320, FlxG.height - 15 - 16 * (tipTextArray.length - i), 300, tipTextArray[i], 12);
			tipText.cameras = [camHUD];
			tipText.setFormat(null, 12, FlxColor.WHITE, RIGHT, FlxTextBorderStyle.OUTLINE_FAST, FlxColor.BLACK);
			tipText.scrollFactor.set();
			tipText.borderSize = 1;
			add(tipText);
		}

		var tabs = [
			//{name: 'Offsets', label: 'Offsets'},
			{name: 'Settings', label: 'Settings'},
		];

		UI_box = new FlxUITabMenu(null, tabs, true);
		UI_box.cameras = [camMenu];

		UI_box.resize(250, 120);
		UI_box.x = FlxG.width - 275;
		UI_box.y = 25;
		UI_box.scrollFactor.set();

		var tabs = [
			{name: 'Character', label: 'Character'},
			{name: 'Ghost', label: 'Ghost'},
			{name: 'Animations', label: 'Animations'},
		];
		UI_characterbox = new FlxUITabMenu(null, tabs, true);
		UI_characterbox.cameras = [camMenu];

		UI_characterbox.resize(400, 250);
		UI_characterbox.x = UI_box.x - 150;
		UI_characterbox.y = UI_box.y + UI_box.height;
		UI_characterbox.scrollFactor.set();
		add(UI_characterbox);
		add(UI_box);
		add(testModeButton);
		add(changeBGbutton);

		//addOffsetsUI();
		addSettingsUI();

		addCharacterUI();
		addGhostUI();
		addAnimationsUI();
		UI_characterbox.selected_tab_id = 'Character';

		FlxG.mouse.visible = true;
		reloadCharacterOptions();

		super.create();
	}

	function resetCam() {
		var camPos = char.getCamera();
		camFollow.x = camPos[0];
		camFollow.y = camPos[1];

		FlxG.camera.zoom = 1;
	}

	override function onFocus(){
		FlxG.mouse.visible = true;
	}
	var testMode:Bool = false;
	var onPixelBG:Bool = false;
	function reloadBGs() {
		FlxG.camera.bgColor = onPixelBG ? FlxColor.BLACK : FlxColor.WHITE;
	}

	var charDropDown:FlxUIDropDownMenu;
	function addSettingsUI() {
		var tab_group = new FlxUI(null, UI_box);
		tab_group.name = "Settings";

		var check_player = new FlxUICheckBox(10, 60, null, null, "Playable Character", 100);
		check_player.checked = char.isPlayer;
		check_player.callback = function() {
			char.isPlayer = !char.isPlayer;
			char.flipX = !char.flipX;
			char.xFacing = char.isPlayer ? -1 : 1;

			updatePointerPos();
			reloadBGs();
		};

		charDropDown = new FlxUIDropDownMenu(10, 30, FlxUIDropDownMenu.makeStrIdLabelArray([''], true), function(character:String) {
			charName = characterList[Std.parseInt(character)];
			
			loadChar(check_player.checked);
			updateDiscordPresence();
			reloadCharacterDropDown();
		});

		var reloadCharacter:FlxButton = new FlxButton(140, 20, "Reload Char", function() {
			loadChar(check_player.checked);
			reloadCharacterDropDown();
		});

		var templateCharacter:FlxButton = new FlxButton(140, 50, "Load Template", function() {
			var parsedJson:CharacterFile = cast Json.parse(TemplateCharacter);

			char.animOffsets.clear();
			char.animationsArray = parsedJson.animations;
			for (anim in char.animationsArray) {
				char.addOffset(anim.anim, anim.offsets[0], anim.offsets[1]);
			}
			if (char.animationsArray[0] != null) {
				char.playAnim(char.animationsArray[0].anim, true);
			}

			char.singDuration = parsedJson.sing_duration;
			char.positionArray = parsedJson.position;
			char.cameraPosition = parsedJson.camera_position;

			char.imageFile = parsedJson.image;
			char.baseScale = parsedJson.scale;
			char.noAntialiasing = parsedJson.no_antialiasing;
			char.originalFlipX = parsedJson.flip_x;
			char.healthIcon = parsedJson.healthicon;
			char.healthColorArray = parsedJson.healthbar_colors;
			char.setPosition(char.positionArray[0], char.positionArray[1]);

			reloadCharacterImage();
			reloadCharacterDropDown();
			reloadCharacterOptions();
			resetHealthBarColor();
			updatePointerPos();
			genBoyOffsets();
		});
		templateCharacter.color = FlxColor.RED;
		templateCharacter.label.color = FlxColor.WHITE;

		tab_group.add(new FlxText(charDropDown.x, charDropDown.y - 18, 0, 'Character:'));
		tab_group.add(check_player);
		tab_group.add(reloadCharacter);
		tab_group.add(charDropDown);
		tab_group.add(reloadCharacter);
		tab_group.add(templateCharacter);
		UI_box.addGroup(tab_group);

		charDropDown.selectedLabel = charName;
		reloadCharacterDropDown();
	}

	var imageInputText:FlxUIInputText;
	var healthIconInputText:FlxUIInputText;

	var singDurationStepper:FlxUINumericStepper;
	var scaleStepper:FlxUINumericStepper;
	var positionXStepper:FlxUINumericStepper;
	var positionYStepper:FlxUINumericStepper;
	var positionCameraXStepper:FlxUINumericStepper;
	var positionCameraYStepper:FlxUINumericStepper;

	var flipXCheckBox:FlxUICheckBox;
	var noAntialiasingCheckBox:FlxUICheckBox;

	var healthColorStepperR:FlxUINumericStepper;
	var healthColorStepperG:FlxUINumericStepper;
	var healthColorStepperB:FlxUINumericStepper;

	function addCharacterUI() {
		var tab_group = new FlxUI(null, UI_box);
		tab_group.name = "Character";

		imageInputText = new FlxUIInputText(15, 30, 200, 'characters/BOYFRIEND', 8);
		var reloadImage:FlxButton = new FlxButton(imageInputText.x + 210, imageInputText.y - 3, "Reload Image", function()
		{
			char.imageFile = imageInputText.text;
			reloadCharacterImage();
			if(char.animation.curAnim != null) {
				char.playAnim(char.animation.curAnim.name, true);
			}
		});

		var decideIconColor:FlxButton = new FlxButton(reloadImage.x, reloadImage.y + 30, "Get Icon Color", function()
			{
				var coolColor = FlxColor.fromInt(CoolUtil.dominantColor(leHealthIcon));
				healthColorStepperR.value = coolColor.red;
				healthColorStepperG.value = coolColor.green;
				healthColorStepperB.value = coolColor.blue;
				getEvent(FlxUINumericStepper.CHANGE_EVENT, healthColorStepperR, null);
				getEvent(FlxUINumericStepper.CHANGE_EVENT, healthColorStepperG, null);
				getEvent(FlxUINumericStepper.CHANGE_EVENT, healthColorStepperB, null);
			});

		healthIconInputText = new FlxUIInputText(15, imageInputText.y + 35, 75, leHealthIcon.getCharacter(), 8);

		singDurationStepper = new FlxUINumericStepper(15, healthIconInputText.y + 45, 0.1, 4, 0, 999, 1);

		scaleStepper = new FlxUINumericStepper(15, singDurationStepper.y + 40, 0.1, 1, 0.05, 10, 1);

		flipXCheckBox = new FlxUICheckBox(singDurationStepper.x + 80, singDurationStepper.y, null, null, "Flip X", 50);
		flipXCheckBox.checked = char.flipX;
		if(char.isPlayer) flipXCheckBox.checked = !flipXCheckBox.checked;
		flipXCheckBox.callback = function() {
			char.originalFlipX = !char.originalFlipX;
			char.flipX = char.originalFlipX;
			if(char.isPlayer) char.flipX = !char.flipX;
		};

		noAntialiasingCheckBox = new FlxUICheckBox(flipXCheckBox.x, flipXCheckBox.y + 40, null, null, "No Antialiasing", 80);
		noAntialiasingCheckBox.checked = char.noAntialiasing;
		noAntialiasingCheckBox.callback = function() {
			char.antialiasing = !noAntialiasingCheckBox.checked;
			char.noAntialiasing = noAntialiasingCheckBox.checked;
		};

		positionXStepper = new FlxUINumericStepper(flipXCheckBox.x + 110, flipXCheckBox.y, 10, char.positionArray[0], -9000, 9000, 0);
		positionYStepper = new FlxUINumericStepper(positionXStepper.x + 60, positionXStepper.y, 10, char.positionArray[1], -9000, 9000, 0);

		positionCameraXStepper = new FlxUINumericStepper(positionXStepper.x, positionXStepper.y + 40, 10, char.cameraPosition[0], -9000, 9000, 0);
		positionCameraYStepper = new FlxUINumericStepper(positionYStepper.x, positionYStepper.y + 40, 10, char.cameraPosition[1], -9000, 9000, 0);

		var saveCharacterButton:FlxButton = new FlxButton(reloadImage.x, noAntialiasingCheckBox.y + 40, "Save Character", saveCharacter);

		healthColorStepperR = new FlxUINumericStepper(singDurationStepper.x, saveCharacterButton.y, 20, char.healthColorArray[0], 0, 255, 0);
		healthColorStepperG = new FlxUINumericStepper(singDurationStepper.x + 65, saveCharacterButton.y, 20, char.healthColorArray[1], 0, 255, 0);
		healthColorStepperB = new FlxUINumericStepper(singDurationStepper.x + 130, saveCharacterButton.y, 20, char.healthColorArray[2], 0, 255, 0);

		tab_group.add(new FlxText(15, imageInputText.y - 18, 0, 'Image file name:'));
		tab_group.add(new FlxText(15, healthIconInputText.y - 18, 0, 'Health icon name:'));
		tab_group.add(new FlxText(15, singDurationStepper.y - 18, 0, 'Sing Animation length:'));
		tab_group.add(new FlxText(15, scaleStepper.y - 18, 0, 'Scale:'));
		tab_group.add(new FlxText(positionXStepper.x, positionXStepper.y - 18, 0, 'Character X/Y:'));
		tab_group.add(new FlxText(positionCameraXStepper.x, positionCameraXStepper.y - 18, 0, 'Camera X/Y:'));
		tab_group.add(new FlxText(healthColorStepperR.x, healthColorStepperR.y - 18, 0, 'Health bar R/G/B:'));
		tab_group.add(imageInputText);
		tab_group.add(reloadImage);
		tab_group.add(decideIconColor);
		tab_group.add(healthIconInputText);
		tab_group.add(singDurationStepper);
		tab_group.add(scaleStepper);
		tab_group.add(flipXCheckBox);
		tab_group.add(noAntialiasingCheckBox);
		tab_group.add(positionXStepper);
		tab_group.add(positionYStepper);
		tab_group.add(positionCameraXStepper);
		tab_group.add(positionCameraYStepper);
		tab_group.add(healthColorStepperR);
		tab_group.add(healthColorStepperG);
		tab_group.add(healthColorStepperB);
		tab_group.add(saveCharacterButton);
		UI_characterbox.addGroup(tab_group);
	}

	var animationDropDown:FlxUIDropDownMenu;
	var animationInputText:FlxUIInputText;
	var animationXCam:FlxUINumericStepper;
	var animationYCam:FlxUINumericStepper;
	var animationNameInputText:FlxUIInputText;
	var animationIndicesInputText:FlxUIInputText;
	var animationNameFramerate:FlxUINumericStepper;
	var animationLoopCheckBox:FlxUICheckBox;
	function addAnimationsUI() {
		var tab_group = new FlxUI(null, UI_box);
		tab_group.name = "Animations";

		animationInputText = new FlxUIInputText(15, 85, 80, '', 8);
		animationNameInputText = new FlxUIInputText(animationInputText.x, animationInputText.y + 35, 150, '', 8);
		animationIndicesInputText = new FlxUIInputText(animationNameInputText.x, animationNameInputText.y + 40, 250, '', 8);
		animationNameFramerate = new FlxUINumericStepper(animationInputText.x + 170, animationInputText.y, 1, 24, 0, 240, 0);
		animationLoopCheckBox = new FlxUICheckBox(animationNameInputText.x + 170, animationNameInputText.y - 1, null, null, "Should it Loop?", 100);

		animationXCam = new FlxUINumericStepper(animationNameFramerate.x + 75, animationNameFramerate.y, 10, 0, -9000, 9000, 0);
		animationYCam = new FlxUINumericStepper(animationXCam.x + 75, animationXCam.y, 10, 0, -9000, 9000, 0);

		animationDropDown = new FlxUIDropDownMenu(15, animationInputText.y - 55, FlxUIDropDownMenu.makeStrIdLabelArray([''], true), function(pressed:String) {
			var selectedAnimation:Int = Std.parseInt(pressed);
			var anim:AnimArray = char.animationsArray[selectedAnimation];

			if (anim == null)
				return;

			animationInputText.text = anim.anim;
			animationNameInputText.text = anim.name;
			animationLoopCheckBox.checked = anim.loop;
			animationNameFramerate.value = anim.fps;
			
			animationIndicesInputText.text = (anim.indices==null) ? '' : anim.indices.join(',');

			var cameraOffset:Array<Float> = anim.cameraOffset ?? CharacterData.getDefaultAnimCamOffset(anim.anim);
			animationXCam.value = cameraOffset[0];
			animationYCam.value = cameraOffset[1];
			updatePointerPos();
		});

		var addUpdateButton:FlxButton = new FlxButton(70, animationIndicesInputText.y + 30, "Add/Update", function() {
			var indicesInput = animationIndicesInputText.text.trim();
			var indices:Array<Int> = indicesInput.length==0 ? null : CharacterData.parseIndices(indicesInput.split(','));
			
			var lastAnim:String = char.animationsArray[curAnim] != null ? char.animationsArray[curAnim].anim : '';

			var lastOffsets:Array<Int> = [0, 0];
			for (anim in char.animationsArray) {
				if (animationInputText.text == anim.anim) {
					lastOffsets = anim.offsets;
					if (char.animation.exists(animationInputText.text))
						char.animation.remove(animationInputText.text);
					
					char.animationsArray.remove(anim);
				}
			}

			var newAnim:AnimArray = {
				anim: animationInputText.text,
				name: animationNameInputText.text,
				fps: Math.round(animationNameFramerate.value),
				loop: animationLoopCheckBox.checked,
				indices: indices,
				offsets: lastOffsets,
				cameraOffset: [animationXCam.value, animationYCam.value]
			};

			if (indices != null && indices.length > 0) {
				char.animation.addByIndices(newAnim.anim, newAnim.name, newAnim.indices, "", newAnim.fps, newAnim.loop);
			} else {
				char.animation.addByPrefix(newAnim.anim, newAnim.name, newAnim.fps, newAnim.loop);
			}

			if (!char.animOffsets.exists(newAnim.anim))
				char.addOffset(newAnim.anim, 0, 0);
			
			char.animationsArray.push(newAnim);
			char.animationsArray.sort(animSortFunc);

			if(lastAnim == animationInputText.text) {
				var leAnim:FlxAnimation = char.animation.getByName(lastAnim);
				if(leAnim != null && leAnim.frames.length > 0) {
					char.playAnim(lastAnim, true);
				} else {
					for(i in 0...char.animationsArray.length) {
						if(char.animationsArray[i] != null) {
							leAnim = char.animation.getByName(char.animationsArray[i].anim);
							if(leAnim != null && leAnim.frames.length > 0) {
								char.playAnim(char.animationsArray[i].anim, true);
								curAnim = i;
								break;
							}
						}
					}
				}
			}

			reloadAnimationDropDown();
			genBoyOffsets();
			trace('Added/Updated animation: ' + animationInputText.text);
		});

		var removeButton:FlxButton = new FlxButton(180, animationIndicesInputText.y + 30, "Remove", function() {
			for (anim in char.animationsArray) {
				if (animationInputText.text == anim.anim) {
					var resetAnim:Bool = (anim.anim == char.animation.name);

					if (resetAnim)
						char.animation.curAnim = null;

					if (char.animation.exists(anim.anim)) 
						char.animation.remove(anim.anim);
					
					if (char.animOffsets.exists(anim.anim))
						char.animOffsets.remove(anim.anim);
					
					char.animationsArray.remove(anim);

					if (resetAnim && char.animationsArray.length > 0)
						char.playAnim(char.animationsArray[0].anim, true);
					
					reloadAnimationDropDown();
					genBoyOffsets();
					trace('Removed animation: ' + animationInputText.text);
					break;
				}
			}
		});

		tab_group.add(new FlxText(animationXCam.x, animationXCam.y - 18, 0, 'Camera X/Y Offset:'));
		//tab_group.add(new FlxText(animationDropDown.x, animationDropDown.y - 18, 0, 'Animations:'));
		tab_group.add(new FlxText(animationInputText.x, animationInputText.y - 18, 0, 'Animation name:'));
		tab_group.add(new FlxText(animationNameFramerate.x, animationNameFramerate.y - 18, 0, 'Framerate:'));
		tab_group.add(new FlxText(animationNameInputText.x, animationNameInputText.y - 18, 0, 'Animation on .XML/.TXT file:'));
		tab_group.add(new FlxText(animationIndicesInputText.x, animationIndicesInputText.y - 18, 0, 'ADVANCED - Animation Indices:'));

		tab_group.add(animationInputText);
		tab_group.add(animationNameInputText);
		tab_group.add(animationIndicesInputText);
		tab_group.add(animationNameFramerate);
		tab_group.add(animationLoopCheckBox);
		tab_group.add(animationXCam);
		tab_group.add(animationYCam);
		tab_group.add(addUpdateButton);
		tab_group.add(removeButton);
		
		tab_group.add(animationDropDown);

		updatePointerPos();
		UI_characterbox.addGroup(tab_group);
	}

	var ghostCharDropDown:FlxUIDropDownMenu;
	var ghostAnimDropDown:FlxUIDropDownMenu;
	var ghostAnimTxt:FlxText;
	var ghostPlayableCheckbox:FlxUICheckBox;

	var ghostList:Array<String>;
	function updateGhostCharList(){
		ghostList = CharacterData.getAllCharacters();
		ghostList.sort(CoolUtil.alphabeticalSort);
		ghostList.insert(0, "");
		ghostCharDropDown.setData(FlxUIDropDownMenu.makeStrIdLabelArray(ghostList, true));
	}

	function addGhostUI(){
		var tab_group = new FlxUI(null, UI_box);
		tab_group.name = "Ghost";

		ghostCharDropDown = new FlxUIDropDownMenu(15, 30, FlxUIDropDownMenu.makeStrIdLabelArray([''], true), function(pressed:String) {
			var idx:Int = Std.parseInt(pressed);
			var charName = ghostList[idx];

			updateGhostCharList();
			ghostCharDropDown.selectedLabel = charName;

			if (ghostChar != null){
				charLayer.remove(ghostChar);
				ghostChar.destroy();
				ghostChar = null;
			}

			if (charName != "") {
				reloadGhost(charName);
				char.alpha = 0.85;
				cameraFollowPointer.alpha = 0.85;
			}else{
				ghostAnimDropDown.setData(FlxUIDropDownMenu.makeStrIdLabelArray([''], true));
				ghostAnimTxt.text = "";

				char.alpha = 1;
				cameraFollowPointer.alpha = 1;
			}

			updateGhostPointerPos();
		});
		updateGhostCharList();

		ghostAnimDropDown = new FlxUIDropDownMenu(15, ghostCharDropDown.y + 50, FlxUIDropDownMenu.makeStrIdLabelArray([''], true), function(pressed:String) {
			if (ghostChar == null) return;
			
			var curAnimData = ghostChar.animationsArray[Std.parseInt(pressed)];
			var offsets = curAnimData.offsets;
			
			ghostChar.playAnim(curAnimData.anim, true);
			ghostAnimTxt.text = 'Offset [${offsets[0]}, ${offsets[1]}]';
		});

		ghostPlayableCheckbox = new FlxUICheckBox(15, ghostAnimDropDown.y + 50, null, null, "Playable Character", 100);
		ghostPlayableCheckbox.callback = ()->{
			if (ghostChar != null) {
				ghostChar.isPlayer = !ghostChar.isPlayer;
				ghostChar.flipX = !ghostChar.flipX;
				ghostChar.xFacing = ghostChar.isPlayer ? -1 : 1;
			}

			updateGhostPointerPos();
		}

		var copyGhostCamera = new FlxButton(400 - 80 - 15, ghostCharDropDown.y, "Copy Camera", function(){
			if (ghostChar == null) return;

			var diff = ghostCamPointer.x - cameraFollowPointer.x;
			trace(diff);
			char.cameraPosition[0] += diff * char.xFacing;
			char.cameraPosition[1] += ghostCamPointer.y - cameraFollowPointer.y;

			updatePointerPos();
		});

		var copyGhostOffsets = new FlxButton(400 - 80 - 15, ghostAnimDropDown.y, "Copy Offset", function(){
			if (ghostChar == null) return;

			var curAnimData = char.animationsArray[curAnim];
			var animName = curAnimData.anim;
			var offsets = curAnimData.offsets;
			
			char.addOffset(animName, offsets[0], offsets[1]);
			char.playAnim(animName, true);
		});

		ghostAnimTxt = new FlxText(ghostAnimDropDown.x + 120, ghostAnimDropDown.y, 0, '');
		ghostAnimTxt.fieldWidth = copyGhostOffsets.x - ghostAnimTxt.x;
		ghostAnimTxt.alignment = CENTER;

		var ghostShowCamPointer = new FlxUICheckBox(ghostCharDropDown.x + 160, ghostCharDropDown.y, null, null, "Show Camera Pointer");
		ghostShowCamPointer.checked = ghostCamPointer.visible;
		ghostShowCamPointer.callback = ()->{
			ghostCamPointer.visible = ghostShowCamPointer.checked;
		};

		////
		tab_group.add(new FlxText(ghostCharDropDown.x, ghostCharDropDown.y - 18, 0, 'Character:'));
		tab_group.add(new FlxText(ghostAnimDropDown.x, ghostAnimDropDown.y - 18, 0, 'Animation:'));
		tab_group.add(ghostPlayableCheckbox);
		tab_group.add(ghostAnimDropDown);
		tab_group.add(ghostCharDropDown);

		tab_group.add(ghostShowCamPointer);
		tab_group.add(ghostAnimTxt);

		tab_group.add(copyGhostOffsets);
		tab_group.add(copyGhostCamera);

		UI_characterbox.addGroup(tab_group);
	}

	function reloadGhost(charName:String) {
		ghostChar = new Character(0, 0, charName, ghostPlayableCheckbox.checked, true);
		ghostChar.setupCharacter();
		ghostChar.alpha = 0.6;
		ghostChar.color = 0xFF666688;

		ghostChar.setPosition(ghostChar.positionArray[0], ghostChar.positionArray[1]);
		
		charLayer.insert(0, ghostChar);

		////
		var animList:Array<String> = [
			for (anim in ghostChar.animationsArray)
				anim.anim
		];
		if (animList.length < 1) animList.push('NO ANIMATIONS'); // Prevents crash

		var firstAnim = animList.indexOf("idle");
		firstAnim = firstAnim != -1 ? firstAnim : 0;

		ghostAnimDropDown.setData(FlxUIDropDownMenu.makeStrIdLabelArray(animList, true));
		ghostAnimDropDown.selectedId = Std.string(firstAnim);

		var curAnimData = ghostChar.animationsArray[firstAnim];
		var offsets = curAnimData.offsets;
		
		ghostChar.playAnim(curAnimData.anim, true);
		ghostAnimTxt.text = 'Offset [${offsets[0]}, ${offsets[1]}]';
	}

	function updateGhostPointerPos() {
		if (ghostChar == null){
			ghostCamPointer.alpha = 0;
			return;
		}else{
			ghostCamPointer.alpha = 0.6;
		}

		var cam = ghostChar.getCamera();

		ghostCamPointer.setPosition(
			cam[0] - ghostCamPointer.width* 0.5,
			cam[1] - ghostCamPointer.height* 0.5
		);
	}

	override function getEvent(id:String, sender:Dynamic, data:Dynamic, ?params:Array<Dynamic>) {
		if(id == FlxUIInputText.CHANGE_EVENT && (sender is FlxUIInputText)) {
			if(sender == healthIconInputText) {
				leHealthIcon.changeIcon(healthIconInputText.text);
				char.healthIcon = healthIconInputText.text;
				updateDiscordPresence();
			}
			else if(sender == imageInputText) {
				char.imageFile = imageInputText.text;
			}
		} else if(id == FlxUINumericStepper.CHANGE_EVENT && (sender is FlxUINumericStepper)) {
			if (sender == scaleStepper)
			{
				char.baseScale = sender.value;
				char.scale.set(sender.value, sender.value);

				updatePointerPos();

				if(char.animation.curAnim != null) {
					char.playAnim(char.animation.curAnim.name, true);
				}else{
					char.updateHitbox();
				}
			}
			else if(sender == positionXStepper)
			{
				char.positionArray[0] = positionXStepper.value;
				char.x = char.positionArray[0];
				updatePointerPos();
			}
			else if(sender == animationXCam || sender == animationYCam)
			{
				updatePointerPos();
			}
			else if(sender == singDurationStepper)
			{
				char.singDuration = singDurationStepper.value;//ermm you forgot this??
			}
			else if(sender == positionYStepper)
			{
				char.positionArray[1] = positionYStepper.value;
				char.y = char.positionArray[1];
				updatePointerPos();
			}
			else if(sender == positionCameraXStepper)
			{
				char.cameraPosition[0] = positionCameraXStepper.value;
				updatePointerPos();
			}
			else if(sender == positionCameraYStepper)
			{
				char.cameraPosition[1] = positionCameraYStepper.value;
				updatePointerPos();
			}
			else if(sender == healthColorStepperR)
			{
				char.healthColorArray[0] = Math.round(healthColorStepperR.value);
				healthBarBG.color = FlxColor.fromRGB(char.healthColorArray[0], char.healthColorArray[1], char.healthColorArray[2]);
			}
			else if(sender == healthColorStepperG)
			{
				char.healthColorArray[1] = Math.round(healthColorStepperG.value);
				healthBarBG.color = FlxColor.fromRGB(char.healthColorArray[0], char.healthColorArray[1], char.healthColorArray[2]);
			}
			else if(sender == healthColorStepperB)
			{
				char.healthColorArray[2] = Math.round(healthColorStepperB.value);
				healthBarBG.color = FlxColor.fromRGB(char.healthColorArray[0], char.healthColorArray[1], char.healthColorArray[2]);
			}
		}
	}

	function reloadCharacterImage() {
		var lastAnim:String = '';

		if(char.animation.curAnim != null)
			lastAnim = char.animation.curAnim.name;
		
		//var anims:Array<AnimArray> = char.animationsArray.copy();

		Paths.removeBitmap(char.frames.parent.key); // is null SOMETIMES idk WHY
		
		if (Paths.fileExists('images/' + char.imageFile + '/Animation.json', TEXT)) {
			char.frames = AtlasFrameMaker.construct(char.imageFile);
		} else if(Paths.fileExists('images/' + char.imageFile + '.txt', TEXT)) {
			char.frames = Paths.getPackerAtlas(char.imageFile);
		} else {
			char.frames = Paths.getSparrowAtlas(char.imageFile);
		}

		if(char.animationsArray != null && char.animationsArray.length > 0) {
			for (anim in char.animationsArray) {
				var animAnim:String = '' + anim.anim;
				var animName:String = '' + anim.name;
				var animFps:Int = anim.fps;
				var animLoop:Bool = !!anim.loop; //Bruh
				var animIndices:Array<Int> = anim.indices;
				if(animIndices != null && animIndices.length > 0) {
					char.animation.addByIndices(animAnim, animName, animIndices, "", animFps, animLoop);
				} else {
					char.animation.addByPrefix(animAnim, animName, animFps, animLoop);
				}
			}
		} else {
			char.quickAnimAdd('idle', 'BF idle dance');
		}

		if(lastAnim != '') {
			char.playAnim(lastAnim, true);
		} else {
			char.dance();
		}
		ghostAnimDropDown.selectedLabel = '';
	}

	function genBoyOffsets():Void {
		dumbTexts.killMembers();

		if (char.animationsArray.length < 1) {
			var text:FlxText = dumbTexts.recycle(FlxText, () -> return new FlxText());
			text.text = 'NO ANIMATIONS AVAILABLE.';
			text.setPosition(10, 20);
			text.setFormat(null, 16, 0xFFFF0000, CENTER);
			text.setBorderStyle(FlxTextBorderStyle.OUTLINE, FlxColor.BLACK, 2);
			text.scrollFactor.set();
			text.cameras = [camHUD];
			dumbTexts.add(text);

			return;
		} 

		char.animationsArray.sort(animSortFunc);
		for (i => anim in char.animationsArray) {
			var name = anim.anim;
			var offsets = char.animOffsets.get(name);
			var isSelected = i==curAnim;

			var text:FlxText = dumbTexts.recycle(FlxText, () -> return new FlxText());
			text.text = (isSelected ? '> ' : '') + '$name: $offsets';
			text.setPosition(isSelected ? 16 : 10, 20 + (18 * i));
			text.setFormat(null, 16, isSelected ? 0xFF00FF00 : 0xFFFFFFFF, CENTER);
			text.setBorderStyle(FlxTextBorderStyle.OUTLINE, FlxColor.BLACK, 1);
			text.scrollFactor.set();
			text.cameras = [camHUD];
			dumbTexts.add(text);
		}
	}

	function loadChar(isPlayer:Bool) {
		if (char != null) {
			charLayer.remove(char);
			char.destroy();
		}

		char = new Character(0, 0, charName, isPlayer, true);
		char.setupCharacter();
		if (char.animationsArray[0] != null)
			char.playAnim(char.animationsArray[0].anim, true);
		
		char.setPosition(char.positionArray[0], char.positionArray[1]);
		charLayer.add(char);

		genBoyOffsets();
		reloadCharacterOptions();
		reloadBGs();
		updatePointerPos();
	}

	function updatePointerPos() {
		var cam = char.getCamera();
		var x:Float = cam[0];
		var y:Float = cam[1];

		if(animationXCam!=null)
			x += animationXCam.value;
		if(animationYCam!=null)
			y += animationYCam.value;

		x -= cameraFollowPointer.width* 0.5;
		y -= cameraFollowPointer.height* 0.5;
		cameraFollowPointer.setPosition(x, y);
	}

	function findAnimationByName(name:String):AnimArray {
		for (anim in char.animationsArray) {
			if(anim.anim == name) {
				return anim;
			}
		}
		return null;
	}

	function reloadCharacterOptions() {
		if(UI_characterbox != null) {
			imageInputText.text = char.imageFile;
			healthIconInputText.text = char.healthIcon;
			singDurationStepper.value = char.singDuration;
			scaleStepper.value = char.baseScale;
			flipXCheckBox.checked = char.originalFlipX;
			noAntialiasingCheckBox.checked = char.noAntialiasing;
			resetHealthBarColor();
			leHealthIcon.changeIcon(healthIconInputText.text);
			positionXStepper.value = char.positionArray[0];
			positionYStepper.value = char.positionArray[1];
			positionCameraXStepper.value = char.cameraPosition[0];
			positionCameraYStepper.value = char.cameraPosition[1];
			reloadAnimationDropDown();
			updateDiscordPresence();
		}
	}

	function reloadAnimationDropDown() {
		var anims:Array<String> = [];

		char.animationsArray.sort(animSortFunc);
		for (anim in char.animationsArray)
			anims.push(anim.anim);
		
		if (anims.length < 1) 
			anims.push('NO ANIMATIONS'); // Prevents crash		

		animationDropDown.setData(FlxUIDropDownMenu.makeStrIdLabelArray(anims, true));
	}

	function reloadCharacterDropDown() {
		characterList = CharacterData.getAllCharacters();
		characterList.sort(CoolUtil.alphabeticalSort);

		charDropDown.setData(FlxUIDropDownMenu.makeStrIdLabelArray(characterList, true));
		charDropDown.selectedLabel = charName;
	}

	function resetHealthBarColor() {
		healthColorStepperR.value = char.healthColorArray[0];
		healthColorStepperG.value = char.healthColorArray[1];
		healthColorStepperB.value = char.healthColorArray[2];
		healthBarBG.color = FlxColor.fromRGB(char.healthColorArray[0], char.healthColorArray[1], char.healthColorArray[2]);
	}

	function changeCurOffset(x:Int, y:Int, isAbs:Bool=false) {
		var curAnimData = char.animationsArray[curAnim];

		if (isAbs) {
			curAnimData.offsets[0] = x;
			curAnimData.offsets[1] = y;
		}else {
			curAnimData.offsets[0] += x;
			curAnimData.offsets[1] += y;	
		}

		char.addOffset(curAnimData.anim, curAnimData.offsets[0], curAnimData.offsets[1]);
		char.playAnim(curAnimData.anim, true);

		genBoyOffsets();
	}

	function updateDiscordPresence() {
		#if DISCORD_ALLOWED
		// Updating Discord Rich Presence
		DiscordClient.changePresence("Character Editor", "Character: " + charName, leHealthIcon.getCharacter());
		#end
	}

	override function draw() {
		var unscaleFactor = (1 / FlxG.camera.zoom);
		originMarker.scale.set(unscaleFactor, unscaleFactor);
		originMarker.centerOrigin();
		
		super.draw();
	}

	function close() {
		if (goToPlayState) {
			MusicBeatState.switchState(new PlayState());
		} else {
			MusicBeatState.switchState(new MasterEditorMenu());
			MusicBeatState.playMenuMusic(true);
		}
		FlxG.mouse.visible = false;
	}

	override function update(elapsed:Float)
	{
		var inputTexts:Array<FlxUIInputText> = [animationInputText, imageInputText, healthIconInputText, animationNameInputText, animationIndicesInputText];
		for (i in 0...inputTexts.length) {
			if(inputTexts[i].hasFocus) {
				if(FlxG.keys.pressed.CONTROL && FlxG.keys.justPressed.V && Clipboard.text != null) { //Copy paste
					inputTexts[i].text = ClipboardAdd(inputTexts[i].text);
					inputTexts[i].caretIndex = inputTexts[i].text.length;
					getEvent(FlxUIInputText.CHANGE_EVENT, inputTexts[i], null, []);
				}
				if(FlxG.keys.justPressed.ENTER) {
					inputTexts[i].hasFocus = false;
				}
				FNFGame.specialKeysEnabled = false;
				super.update(elapsed);
				return;
			}
		}
		FNFGame.specialKeysEnabled = true;

		if (testMode) {
			var alt = FlxG.keys.pressed.SHIFT ? "-alt" : '';
			// who cares anymore
			if (FlxG.keys.justPressed.SPACE){
				char.playAnim("idle", true);
			}
			if (FlxG.keys.justPressed.D){
				char.playAnim("singLEFT"+alt, true);
			}
			if (FlxG.keys.justPressed.F){
				char.playAnim("singDOWN"+alt, true);
			}
			if (FlxG.keys.justPressed.J){
				char.playAnim("singUP"+alt, true);
			}
			if (FlxG.keys.justPressed.K){
				char.playAnim("singRIGHT"+alt, true);
			}
			if (FlxG.keys.justPressed.E){
				char.playAnim("singLEFTmiss", true);
			}
			if (FlxG.keys.justPressed.R){
				char.playAnim("singDOWNmiss", true);
			}
			if (FlxG.keys.justPressed.U){
				char.playAnim("singUPmiss", true);
			}
			if (FlxG.keys.justPressed.I){
				char.playAnim("singRIGHTmiss", true);
			}
		}
		else if(!charDropDown.dropPanel.visible) {
			if (FlxG.keys.justPressed.ESCAPE) {
				close();
				return;
			}

			if (FlxG.keys.justPressed.R) {
				resetCam();
			}

			if (FlxG.keys.pressed.E && FlxG.camera.zoom < 3) {
				FlxG.camera.zoom += elapsed * FlxG.camera.zoom;
				if(FlxG.camera.zoom > 3) FlxG.camera.zoom = 3;
			}
			if (FlxG.keys.pressed.Q && FlxG.camera.zoom > 0.1) {
				FlxG.camera.zoom -= elapsed * FlxG.camera.zoom;
				if(FlxG.camera.zoom < 0.1) FlxG.camera.zoom = 0.1;
			}

			if (FlxG.keys.pressed.I || FlxG.keys.pressed.J || FlxG.keys.pressed.K || FlxG.keys.pressed.L)
			{
				var addToCam:Float = 500 * elapsed;
				if (FlxG.keys.pressed.SHIFT)
					addToCam *= 4;

				if (FlxG.keys.pressed.I)
					camFollow.y -= addToCam;
				else if (FlxG.keys.pressed.K)
					camFollow.y += addToCam;

				if (FlxG.keys.pressed.J)
					camFollow.x -= addToCam;
				else if (FlxG.keys.pressed.L)
					camFollow.x += addToCam;
			}

			if (char.animationsArray.length > 0) {
				var replayAnim = FlxG.keys.justPressed.SPACE;

				if (FlxG.keys.justPressed.W) {
					curAnim -= 1;
					replayAnim = true;
				}

				if (FlxG.keys.justPressed.S) {
					curAnim += 1;
					replayAnim = true;
				}

				if (curAnim < 0)
					curAnim = char.animationsArray.length - 1;

				if (curAnim >= char.animationsArray.length)
					curAnim = 0;

				if (replayAnim) {
					char.playAnim(char.animationsArray[curAnim].anim, true);
					genBoyOffsets();
				}

				var multiplier:Int = FlxG.keys.pressed.SHIFT ? 10 : 1;

				if (FlxG.keys.justPressed.LEFT)
					changeCurOffset(multiplier, 0);

				if (FlxG.keys.justPressed.RIGHT)
					changeCurOffset(-multiplier, 0);

				if (FlxG.keys.justPressed.DOWN)
					changeCurOffset(0, -multiplier);

				if (FlxG.keys.justPressed.UP)
					changeCurOffset(0, multiplier);

				if (FlxG.keys.justPressed.T)
					changeCurOffset(0, 0, true);
			}
		}

		super.update(elapsed);
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

	function saveCharacter() {
		var json = {
			"animations": char.animationsArray,
			"image": char.imageFile,
			"scale": char.baseScale,
			"sing_duration": char.singDuration,
			"healthicon": char.healthIcon,

			"position":	char.positionArray,
			"camera_position": char.cameraPosition,

			"flip_x": char.originalFlipX,
			"no_antialiasing": char.noAntialiasing,
			"healthbar_colors": char.healthColorArray
		};

		var data:String = Json.stringify(json, "\t");

		if (data.length > 0)
		{
			_file = new FileReference();
			_file.addEventListener(Event.COMPLETE, onSaveComplete);
			_file.addEventListener(Event.CANCEL, onSaveCancel);
			_file.addEventListener(IOErrorEvent.IO_ERROR, onSaveError);
			_file.save(data, charName + ".json");
		}
	}

	function ClipboardAdd(prefix:String = ''):String {
		if(prefix.toLowerCase().endsWith('v')) //probably copy paste attempt
		{
			prefix = prefix.substring(0, prefix.length-1);
		}

		var text:String = prefix + Clipboard.text.replace('\n', '');
		return text;
	}
}
