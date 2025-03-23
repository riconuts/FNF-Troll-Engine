package funkin.states;

using funkin.data.FlxTextFormatData;

import funkin.data.GameplayOption;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.util.FlxColor;

class GameplayChangersSubstate extends MusicBeatSubstate
{
	private var optionsArray:Array<GameplayOption> = [];
	private var curOption:GameplayOption = null;

	private var menu:AlphabetMenu;
	private var checkboxGroup:FlxTypedGroup<CheckboxThingie>;
	private var grpTexts:FlxTypedGroup<AttachedText>;

	////
	private var stypeoption:StringGameplayOption;
	private var speedoption:NumericGameplayOption;

	function onChangeScrollType() {
		var scrollType:String = stypeoption.getValue();
		
		switch(scrollType) {
			case "constant":
				speedoption.displayFormat = "%v";
				speedoption.maxValue = 6;

			case "multiplicative":
				speedoption.displayFormat = "%vX";
				speedoption.maxValue = 3;
			
			default:
				trace("wtf", scrollType);
		}

		if (speedoption.getValue() > speedoption.maxValue) 
			speedoption.setValue(speedoption.maxValue);

		updateTextFrom(speedoption);	
	}

	public function new() {
		super();
		
		stypeoption = new StringGameplayOption('Scroll Type', 'scrolltype', ["multiplicative", "constant"], 'multiplicative');
		stypeoption.onChange = onChangeScrollType;
		optionsArray.push(stypeoption);

		speedoption = new NumericGameplayOption('Scroll Speed', 'scrollspeed', FLOAT, 1);
		speedoption.minValue = 0.5;
		speedoption.decimals = 2;
		optionsArray.push(speedoption);
		
		////
		var option = new NumericGameplayOption('Playback Rate', 'songspeed', FLOAT, 1);
		option.minValue = 0.5;
		option.maxValue = 5;
		option.changeValue = 0.05;
		option.decimals = 2;
		option.displayFormat = '%vX';
		optionsArray.push(option);

		var option = new NumericGameplayOption('Health Gain Multiplier', 'healthgain', FLOAT, 1);
		option.minValue = 0;
		option.maxValue = 5;
		option.changeValue = 0.1;
		option.displayFormat = '%vX';
		optionsArray.push(option);

		var option = new NumericGameplayOption('Health Loss Multiplier', 'healthloss', FLOAT, 1);
		option.minValue = 0.5;
		option.maxValue = 5;
		option.changeValue = 0.1;
		option.displayFormat = '%vX';
		optionsArray.push(option);

		var option = new GameplayOption('Holds Give Health', 'holdsgivehp', BOOL, false);
		optionsArray.push(option);

		var option = new GameplayOption('Instakill on Miss', 'instakill', BOOL, false);
		optionsArray.push(option);

		var option = new GameplayOption('Practice Mode', 'practice', BOOL, false);
		optionsArray.push(option);

		var option = new GameplayOption('Perfect Mode', 'perfect', BOOL, false);
		optionsArray.push(option);

		var option = new GameplayOption('Instant Respawn', 'instaRespawn', BOOL, false);
		optionsArray.push(option);

		var option = new GameplayOption('Botplay', 'botplay', BOOL, false);
		optionsArray.push(option);

		var option = new GameplayOption('Opponent Mode', 'opponentPlay', BOOL, false);
		optionsArray.push(option);

		var option = new GameplayOption('Disable Modcharts', 'disableModcharts', BOOL, false);
		optionsArray.push(option);

		var option = new GameplayOption('Hold Drop Doesn\'t Miss', 'noDropPenalty', BOOL, false);
		optionsArray.push(option);
	}

	override public function create() {
		super.create();

		this.camera = FlxG.cameras.list[FlxG.cameras.list.length - 1];
		
		var bg:FlxSprite = CoolUtil.blankSprite(FlxG.width, FlxG.height, FlxColor.BLACK);
		bg.screenCenter();
		bg.scrollFactor.set();
		bg.cameras = cameras;
		add(bg);
		
		menu = new AlphabetMenu();
		menu.controls = controls;
		menu.cameras = cameras;
		menu.callbacks.onSelect = (idx, item) -> {
			curOption = optionsArray[idx];
			clearHold();
		}
		menu.callbacks.onAccept = (idx, item) ->{
			if (curOption.type != BOOL)
				return;

			FlxG.sound.play(Paths.sound('scrollMenu'));
			curOption.setValue((curOption.getValue() == true) ? false : true);
			curOption.change();
			updateCheckboxFrom(curOption);
		}
		add(menu);

		grpTexts = new FlxTypedGroup<AttachedText>();
		grpTexts.cameras = cameras;
		add(grpTexts);

		checkboxGroup = new FlxTypedGroup<CheckboxThingie>();
		checkboxGroup.cameras = cameras;
		add(checkboxGroup);

		if (this._parentState is PauseSubState) {
			bg.alpha = 0.6;

			var optionDesc = new FlxText(5, FlxG.height - 48, 0, "NOTE: These won't have any effect until you reset the song!", 20);
			optionDesc.applyFormat({
				font: "vcr.ttf",
				antialiasing: false,
			
				size: 16,
				color: 0xFFFFFFFF,
				alignment: CENTER,
			
				borderStyle: OUTLINE,
				borderColor: 0xFF000000
			});
			optionDesc.textField.background = true;
			optionDesc.textField.backgroundColor = FlxColor.BLACK;
			optionDesc.screenCenter(X);
			optionDesc.scrollFactor.set();
			optionDesc.cameras = cameras;
			optionDesc.alpha = 0;
			add(optionDesc);

			var goalY = optionDesc.y;
			optionDesc.screenCenter(X);
			optionDesc.y = goalY - 12;
			optionDesc.alpha = 0;
			FlxTween.tween(optionDesc, {y: goalY, alpha: 1}, 0.35, {ease: FlxEase.quadOut});
		}else {
			bg.alpha = 0.3;
			FlxTween.tween(bg, {alpha: 0.7}, 0.6);
		}

		for (i => option in optionsArray)
		{
			var optionLabel = menu.addTextOption(option.name, null, 0.8);
			optionLabel.scrollFactor.set();
			optionLabel.xAdd = 120;
			optionLabel.x += 200;
			optionLabel.y = optionLabel.targetY - FlxG.height / 3;
			///

			switch(option.type) {
				case BOOL:
					optionLabel.xAdd += 80;

					var checkbox:CheckboxThingie = new CheckboxThingie(optionLabel.x - 105, optionLabel.y, option.getValue() == true);
					checkbox.ID = i;
					checkbox.scrollFactor.set();
					checkbox.sprTracker = optionLabel;
					checkbox.offsetY = -60;
					checkboxGroup.cameras = cameras;
					checkboxGroup.add(checkbox);

					option.checkbox = checkbox;
					updateCheckboxFrom(option);

				default:
					var valueText:AttachedText = new AttachedText('' + option.getValue(), optionLabel.width + 80, true, 0.8);
					valueText.ID = i;
					valueText.scrollFactor.set();
					valueText.sprTracker = optionLabel;
					valueText.copyAlpha = true;
					valueText.cameras = cameras;
					grpTexts.add(valueText);

					option.setChild(valueText);
					updateTextFrom(option);
			}
		}

		onChangeScrollType();
	}

	var nextAccept:Int = 5;
	override function update(elapsed:Float) {
		if (controls.BACK) {
			close();
			ClientPrefs.save();
			FlxG.sound.play(Paths.sound('cancelMenu'));
		}
		else if(nextAccept <= 0) {
			switch(curOption.type) {
				case FLOAT | INT: updateNumericLR(elapsed);
				case STRING: updateStringLR();
				default:
			}

			if (controls.RESET) {
				setOptionValue(curOption, curOption.defaultValue);
				FlxG.sound.play(Paths.sound('cancelMenu'));
			}
		}

		if (nextAccept > 0)
			nextAccept -= 1;
		
		super.update(elapsed);
	}

	function setOptionValue(leOption:GameplayOption, value:Dynamic) {
		curOption.setValue(value);

		switch(leOption.type) {
			case BOOL: 
				updateCheckboxFrom(leOption);

			case STRING:
				var leOption:StringGameplayOption = cast leOption;
				leOption.curOption = leOption.options.indexOf(leOption.getValue());
				updateTextFrom(leOption);

			case INT | FLOAT:
				updateTextFrom(leOption);
		}

		leOption.change();
	}

	var holdTime:Float = 0;
	var holdValue:Float = 0;
	var holdingTimer:Float = 0;

	function updateStringLR() {
		var strOption:StringGameplayOption = cast curOption;

		if (controls.UI_LEFT_P) {
			strOption.curOption -= 1;
			if (strOption.curOption < 0) 
				strOption.curOption = strOption.options.length - 1;
		}
		else if (controls.UI_RIGHT_P) {
			strOption.curOption += 1;
			if (strOption.curOption >= strOption.options.length) 
				strOption.curOption = 0;
		}
		else return;
		
		strOption.setValue(strOption.options[strOption.curOption]);
		strOption.change();
		updateTextFrom(strOption);
	}

	function updateNumericLR(elapsed:Float) {
		if (controls.UI_LEFT_R || controls.UI_RIGHT_R)
			return clearHold();

		var changeVal:Float = 0;
		if (controls.UI_LEFT) changeVal = -1;
		else if (controls.UI_RIGHT) changeVal = 1;
		else return;

		var numOption:NumericGameplayOption = cast curOption;

		inline function updateHoldValue() {
			if (holdValue < numOption.minValue) holdValue = numOption.minValue;
			else if (holdValue > numOption.maxValue) holdValue = numOption.maxValue;

			numOption.setValue(FlxMath.roundDecimal(holdValue, numOption.decimals));
			numOption.change();
			updateTextFrom(numOption);
		}
		
		if (holdTime == 0.0) {
			holdValue = (numOption.getValue() + numOption.changeValue * changeVal);
			FlxG.sound.play(Paths.sound('scrollMenu'));
			updateHoldValue();
		}
		else if (holdingTimer >= 0.05) {
			if (holdTime < 0.5) {
				holdingTimer = 0.0;
			}else {
				holdValue += (numOption.scrollSpeed * changeVal) * Math.floor(holdingTimer / 0.05);
				holdingTimer %= 0.05;
				updateHoldValue();
			}
		}

		holdingTimer += elapsed;
		holdTime += elapsed;
	}

	function clearHold() {
		if (holdTime > 0.5) {
			FlxG.sound.play(Paths.sound('scrollMenu'));
		}
		holdTime = 0;
		holdingTimer = 0;
	}

	function updateTextFrom(option:GameplayOption) {
		option.text = option.getDisplayValue();
	}

	function updateCheckboxFrom(option:GameplayOption) {
		if (option.checkbox != null) 
			option.checkbox.daValue = option.getValue()==true;
	}
}