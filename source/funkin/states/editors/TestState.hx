package funkin.states.editors;

import funkin.states.TitleState.TitleLogo;
import flixel.util.FlxColor;
import funkin.objects.Alphabet;
import funkin.input.Controls;
import funkin.states.TitleState;
import funkin.states.editors.MasterEditorMenu;
import flixel.addons.ui.*;
import flixel.math.*;
import flixel.group.FlxGroup;
import flixel.ui.FlxButton;

// cringe

class TestState extends MusicBeatState{
	var UI_box:FlxUITabMenu;
	var alphGroup:FlxTypedGroup<FlxBasic>;
	var titlGroup:FlxTypedGroup<FlxBasic>;

	////
	public var camGame:FlxCamera = new FlxCamera();
	public var camHUD:FlxCamera = new FlxCamera();

	var camFollow = new FlxPoint(640, 360);
	var camFollowPos = new FlxObject(640, 360, 1, 1);

	override function create()
	{
		FlxG.mouse.visible = true;

		// Set up cameras
		camGame.bgColor = 0xFF999999;
		camHUD.bgColor = 0x00000000;
		camGame.follow(camFollowPos);

		FlxG.cameras.reset(camGame);
		FlxG.cameras.add(camHUD, false);

		FlxG.cameras.setDefaultDrawTarget(camGame, true);

		////
		var tabs = [
			{name: 'Alphabet', label: 'Alphabet'},
			{name: 'Title Screen', label: 'Title Screen'}
		];
		UI_box = new FlxUITabMenu(null, tabs, true);
		UI_box.resize(250, 200);
		UI_box.scrollFactor.set();
		UI_box.cameras = [camHUD];

		UI_box.selected_tab_id = 'Alphabet';

		alphGroup = createAlphabetUI();
		titlGroup = createTitleUI();

		super.create();
	}

	var updateFunction:Void->Void;
	var lastGroup:FlxTypedGroup<FlxBasic>;
	var curGroup:FlxTypedGroup<FlxBasic>;
	
	override function update(elapsed:Float)
	{
		if (updateFunction != null)
			updateFunction();

		if (FlxG.keys.justPressed.ESCAPE)
		{
			MusicBeatState.switchState(new MasterEditorMenu());
			MusicBeatState.playMenuMusic(true);
		}

		if (UI_box != null){
			switch (UI_box.selected_tab_id){
				case "Alphabet":
					curGroup = alphGroup;
					camGame.bgColor = 0xFF999999;
				case "Title Screen":
					curGroup = titlGroup;
			}
		}

		if (curGroup != lastGroup){
			remove(lastGroup);
			add(curGroup);

			lastGroup = curGroup;
		}

		var lerpVal:Float = CoolUtil.boundTo(elapsed * 2.4, 0, 1);
		camFollowPos.setPosition(FlxMath.lerp(camFollowPos.x, camFollow.x, lerpVal), FlxMath.lerp(camFollowPos.y, camFollow.y, lerpVal));
		
		super.update(elapsed);
	}
	
	function createAlphabetUI()
	{
		var group = new FlxTypedGroup<FlxBasic>();
		group.add(UI_box);

		var alphabetBG = new FlxSprite().makeGraphic(1, 1);
		alphabetBG.color = 0xFFFF0000;
		alphabetBG.alpha = 0.6;
		alphabetBG.cameras = [camHUD];
		group.add(alphabetBG);

		var alphabetInstance = new Alphabet(0, 0, "sowy", true);
		alphabetInstance.screenCenter();
		alphabetInstance.cameras = [camHUD];
		group.add(alphabetInstance);

		////
		var inputText = new FlxUIInputText(10, 40, 230, 'abcdefghijklmnopqrstuvwxyz', 8);
		inputText.cameras = [camHUD];
		var boldCheckbox:FlxUICheckBox = new FlxUICheckBox(10, 70, null, null, "Bold", 100);
		boldCheckbox.cameras = [camHUD];

		function updateText(){
			alphabetInstance.bold = boldCheckbox.checked;
			alphabetInstance.text = inputText.text;
			alphabetInstance.screenCenter();

			alphabetBG.scale.set(alphabetInstance.width, alphabetInstance.height);
			alphabetBG.updateHitbox();
			//alphabetBG.screenCenter();
			
			alphabetBG.x = alphabetInstance.x;
			alphabetBG.y = alphabetInstance.y;
			
		}
		updateText();
		
		////
		inputText.focusGained = function(){
			FNFGame.specialKeysEnabled = false;
			updateFunction = function(){ if (FlxG.keys.justPressed.ENTER) inputText.focusLost();}
		};
		inputText.focusLost = function(){
			FNFGame.specialKeysEnabled = true;

			inputText.hasFocus = false;
			updateFunction = null;
			updateText();
		};
		group.add(inputText);
		
		boldCheckbox.callback = updateText;
		group.add(boldCheckbox);

		var woo:Bool = false;
		var changeButton = new FlxButton(10, 100, "toUpperCase");
		changeButton.cameras = [camHUD];
		changeButton.onUp.callback = function()
		{
			inputText.text = woo ? inputText.text.toLowerCase() : inputText.text.toUpperCase();
			changeButton.text = woo ? "toUpperCase" : "toLowerCase";
			woo = !woo;
			
			updateText();
		}
		group.add(changeButton);

		////
		return group;
	}

	function createTitleUI()
	{
		var group = new FlxTypedGroup<FlxBasic>();

		////
		var bgGroup = new FlxTypedGroup<Stage>(1);
		group.add(bgGroup);

		// Warning : Local variable might be used before being initialAAAAAAAA SHUT UP
		var bg:Stage = null;
		var logoBl:TitleLogo = null;

		////
		group.add(UI_box);

		////
		var titleNames = TitleState.TitleLogo.getTitlesList();
		var titleStepper = new FlxUINumericStepper(10, 40, 1, 0, 0, titleNames.length-1, 0);
		titleStepper.cameras = [camHUD];
		group.add(titleStepper);
		
		var stageNames = Stage.getAllStages();
		var bgStepper = new FlxUINumericStepper(10, 70, 1, 0, 0, stageNames.length-1, 0);
		bgStepper.cameras = [camHUD];
		group.add(bgStepper);

		function updateShit(){
			// Logo Update 
			var newLogoName = titleNames[Std.int(titleStepper.value)];
			if (logoBl != null && logoBl.titleName != newLogoName){
				group.remove(logoBl).destroy();
				logoBl = null;
			}
			if (logoBl == null){		
				logoBl = new TitleState.TitleLogo(newLogoName);
				logoBl.cameras = [camHUD];
				logoBl.scrollFactor.set();
				logoBl.screenCenter(XY);
				group.add(logoBl);
			}else
				logoBl.time = 0;

			// Stage Update 
			var newStageName = stageNames[Std.int(bgStepper.value)];

			if (bg != null && bg.curStage != newStageName){
				bgGroup.remove(bg).destroy();
				bg = null;
			}else if (bg != null)
				return;

			bg = new Stage(newStageName).buildStage();

			var bg_color:Null<String> = bg.stageData.bg_color;
			camGame.bgColor = (bg_color==null ? 0xFF999999 : FlxColor.fromString(bg_color)) ?? 0xFF999999;
			camGame.zoom = bg.stageData.defaultZoom;

			var camPos = bg.stageData.camera_stage;
			if (camPos == null) camPos = [640, 360];

			camFollow.set(camPos[0], camPos[1]);
			camFollowPos.setPosition(camPos[0], camPos[1]);

			bgGroup.add(bg);
		}

		var changeButton = new FlxButton(10, 100, "Set", updateShit);
		changeButton.cameras = [camHUD];
		group.add(changeButton);

		updateShit();

		return group;
	}
}