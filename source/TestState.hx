package;

import Alphabet;
import Controls;
import TitleState;
import editors.MasterEditorMenu;
import flixel.FlxBasic;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.addons.ui.*;
import flixel.addons.ui.FlxInputText;
import flixel.addons.ui.FlxUI9SliceSprite;
import flixel.addons.ui.FlxUI;
import flixel.addons.ui.FlxUICheckBox;
import flixel.addons.ui.FlxUIInputText;
import flixel.addons.ui.FlxUINumericStepper;
import flixel.addons.ui.FlxUITabMenu;
import flixel.group.FlxGroup;
import flixel.ui.FlxButton;

// cringe

class TestState extends MusicBeatState{
	var UI_box:FlxUITabMenu;
	var alphGroup:FlxTypedGroup<FlxBasic>;
	var titlGroup:FlxTypedGroup<FlxBasic>;

	override function create()
	{
		FlxG.mouse.visible = true;    

		var tabs = [
			{name: 'Alphabet', label: 'Alphabet'},
			{name: 'Title Screen', label: 'Title Screen'}
		];
		UI_box = new FlxUITabMenu(null, tabs, true);
		UI_box.resize(250, 200);
		UI_box.scrollFactor.set();

		UI_box.selected_tab_id = 'Alphabet';

		alphGroup = createAlphabetUI();
		titlGroup = createTitleUI();

        super.create();
    }

	var updateFunction = function(){};
	var lastGroup:FlxTypedGroup<FlxBasic>;
	var curGroup:FlxTypedGroup<FlxBasic>;
	
	override function update(elapsed:Float)
	{
		if (updateFunction != null)
		{
			updateFunction();
		}
		else
		{
			FlxG.sound.muteKeys = StartupState.muteKeys;
			FlxG.sound.volumeDownKeys = StartupState.volumeDownKeys;
			FlxG.sound.volumeUpKeys = StartupState.volumeUpKeys;
            
			if (FlxG.keys.justPressed.ESCAPE)
			{
				MusicBeatState.switchState(new MasterEditorMenu());
				MusicBeatState.playMenuMusic();
			}
		}

		if (UI_box != null){
			switch (UI_box.selected_tab_id){
				case "Alphabet":
					curGroup = alphGroup;
				case "Title Screen":
					curGroup = titlGroup;
			}
		}

		if (curGroup != lastGroup){
			remove(lastGroup);
			add(curGroup);

			lastGroup = curGroup;
		}
        
		super.update(elapsed);
	}
	
	function createAlphabetUI()
	{
		var group = new FlxTypedGroup<FlxBasic>();

		group.add(new FlxSprite(0, 0).makeGraphic(FlxG.width, FlxG.height));
		group.add(UI_box);

		var alphabetInstance = new Alphabet(0, 0, "sowy", true);
		alphabetInstance.screenCenter();
		group.add(alphabetInstance);

		////
		var inputText = new FlxUIInputText(10, 40, 230, 'abcdefghijklmnopqrstuvwxyz', 8);
		var boldCheckbox:FlxUICheckBox = new FlxUICheckBox(10, 70, null, null, "Bold", 100);

		function updateText(){
			//trace("text: " + inputText.text, " bold: " + boldCheckbox.checked);
			
			alphabetInstance.isBold = boldCheckbox.checked;
			alphabetInstance.changeText(inputText.text);
			alphabetInstance.screenCenter();
		}
		updateText();
		
		////
		inputText.focusGained = function(){
			updateFunction = function(){
				FlxG.sound.muteKeys = [];
				FlxG.sound.volumeDownKeys = [];
				FlxG.sound.volumeUpKeys = [];

				if (FlxG.keys.justPressed.ENTER)
				{
					inputText.focusLost();
				}
			}
		};
		inputText.focusLost = function(){
			inputText.hasFocus = false;
			updateFunction = null;
			updateText();
		};
		group.add(inputText);
		
		boldCheckbox.checked = true;
		boldCheckbox.callback = function(){
			updateText();
		};
		group.add(boldCheckbox);

		var woo:Bool = false;
		var changeButton = new FlxButton(10, 100, "toUpperCase", function()
		{
			if (woo)
				inputText.text = inputText.text.toLowerCase();
			else
				inputText.text = inputText.text.toUpperCase();

			woo = !woo;

			updateText();
		});
		group.add(changeButton);

		////
		return group;
	}

	function createTitleUI()
	{
		var group = new FlxTypedGroup<FlxBasic>();
		var titleNames = Paths.getDirs("titles");
		trace(titleNames);

		////
		var bgGroup = new FlxTypedGroup<FlxBasic>();
		group.add(bgGroup);
		var bg = new TitleStage(0);
		bgGroup.add(bg);

		group.add(UI_box);

		var logoBl = new FlxSprite();
		function switchLogo(sowy:Int = 0){
			logoBl.frames = Paths.getSparrowAtlas('titles/${titleNames[sowy]}/logoBumpin');
			logoBl.antialiasing = true;
			logoBl.animation.addByPrefix('bump', 'logo bumpin', 24);
			logoBl.animation.play('bump');
			logoBl.setGraphicSize(Std.int(logoBl.width * 0.72));
			logoBl.scrollFactor.set();
			logoBl.updateHitbox();
			logoBl.screenCenter(XY);
		}
		switchLogo();

		group.add(logoBl);

		////
		var titleStepper = new FlxUINumericStepper(10, 40, 1, 0, 0, titleNames.length-1, 0);
		group.add(titleStepper);
		
		var bgStepper = new FlxUINumericStepper(10, 70, 1, 0, 0, TitleStage.stageNames.length-1, 0);
		group.add(bgStepper);

		var changeButton = new FlxButton(10, 100, "Set", function()
		{
			switchLogo(Std.int(titleStepper.value));
			bgGroup.remove(bg);
			bg.destroy();
			bg = new TitleStage(Std.int(bgStepper.value));
			bgGroup.add(bg);
		});
		group.add(changeButton);

		return group;
	}
}