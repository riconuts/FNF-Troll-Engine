package funkin.states;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.util.FlxColor;

using StringTools;

class GameplayChangersSubstate extends MusicBeatSubstate
{
	private var curOption:GameplayOption = null;
	private var curSelected:Int = 0;
	private var optionsArray:Array<Dynamic> = [];

	private var menu:AlphabetMenu;
	private var checkboxGroup:FlxTypedGroup<CheckboxThingie>;
	private var grpTexts:FlxTypedGroup<AttachedText>;

	var goption:GameplayOption;
	var soption:GameplayOption;
	function getOptions()
	{
		goption = new GameplayOption('Scroll Type', 'scrolltype', 'string', 'multiplicative', ["multiplicative", "constant"]);
		optionsArray.push(goption);

		soption = new GameplayOption('Scroll Speed', 'scrollspeed', 'float', 1);
		soption.scrollSpeed = 0.1;
		soption.minValue = 0.5;
		soption.changeValue = 0.05;
		soption.decimals = 2;
		if (goption.getValue() != "constant")
		{
			soption.displayFormat = '%vX';
			soption.maxValue = 3;
		}
		else
		{
			soption.displayFormat = "%v";
			soption.maxValue = 6;
		}
		optionsArray.push(soption);

		
		var option:GameplayOption = new GameplayOption('Playback Rate', 'songspeed', 'float', 1);
		option.scrollSpeed = 1;
		option.minValue = 0.5;
		option.maxValue = 2.5;
		option.changeValue = 0.05;
		option.decimals = 2;
		option.displayFormat = '%vX';
		optionsArray.push(option);
		

		var option:GameplayOption = new GameplayOption('Health Gain Multiplier', 'healthgain', 'float', 1);
		option.scrollSpeed = 2.5;
		option.minValue = 0;
		option.maxValue = 5;
		option.changeValue = 0.1;
		option.displayFormat = '%vX';
		optionsArray.push(option);

		var option:GameplayOption = new GameplayOption('Health Loss Multiplier', 'healthloss', 'float', 1);
		option.scrollSpeed = 2.5;
		option.minValue = 0.5;
		option.maxValue = 5;
		option.changeValue = 0.1;
		option.displayFormat = '%vX';
		optionsArray.push(option);

		//// andromeda engine modifiers!!!!
		var option:GameplayOption = new GameplayOption("Health Drain", 'healthDrain', 'string', 'Disabled', [
			"Disabled",
			"Basic",
			"Average",
			"Heavy"
		]);
		optionsArray.push(option);

		var option:GameplayOption = new GameplayOption("Opponent HP Drain", 'opponentFightsBack', 'bool', false);
		optionsArray.push(option);

		////
		var option:GameplayOption = new GameplayOption('Instakill on Miss', 'instakill', 'bool', false);
		optionsArray.push(option);

		var option:GameplayOption = new GameplayOption('Practice Mode', 'practice', 'bool', false);
		optionsArray.push(option);

		var option:GameplayOption = new GameplayOption('Perfect Mode', 'perfect', 'bool', false);
		optionsArray.push(option);

		var option:GameplayOption = new GameplayOption('Instant Respawn', 'instaRespawn', 'bool', false);
		optionsArray.push(option);

		var option:GameplayOption = new GameplayOption('Botplay', 'botplay', 'bool', false);
		optionsArray.push(option);

		var option:GameplayOption = new GameplayOption('Opponent Mode', 'opponentPlay', 'bool', false);
		optionsArray.push(option);

		//// Niixx
/* 		var option:GameplayOption = new GameplayOption('bitch baby pussy mode', 'disableModcharts', 'bool', false);
		optionsArray.push(option); */


	}

	public function getOptionByName(name:String)
	{
		for(i in optionsArray)
		{
			var opt:GameplayOption = i;
			if (opt.name == name)
				return opt;
		}
		return null;
	}

	override public function create()
	{
		super.create();

		var cam:FlxCamera = FlxG.cameras.list[FlxG.cameras.list.length - 1];
		this.camera = cam;
		
		var bg:FlxSprite = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		bg.screenCenter();
		bg.scrollFactor.set();
		bg.camera = cam;
		add(bg);
		
		menu = new AlphabetMenu();
		menu.controls = controls;
		menu.cameras = cameras;
		menu.callbacks.onSelect = (idx, item) -> curOption = optionsArray[idx];
		menu.callbacks.onAccept = (idx, item) ->{
			if (curOption.type != 'bool')
				return;

			FlxG.sound.play(Paths.sound('scrollMenu'));
			curOption.setValue((curOption.getValue() == true) ? false : true);
			curOption.change();
			reloadCheckboxes();
		}
		add(menu);

		grpTexts = new FlxTypedGroup<AttachedText>();
		grpTexts.camera = cam;
		add(grpTexts);

		checkboxGroup = new FlxTypedGroup<CheckboxThingie>();
		checkboxGroup.camera = cam;
		add(checkboxGroup);

		if (this._parentState is PauseSubState){
			bg.alpha = 0.6;

			var optionDesc = new FlxText(5, FlxG.height - 48, 0, "NOTE: These won't have any effect until you reset the song!", 20);
			optionDesc.setFormat(Paths.font("vcr.ttf"), #if tgt 20 #else 16 #end, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			optionDesc.textField.background = true;
			optionDesc.textField.backgroundColor = FlxColor.BLACK;
			optionDesc.screenCenter(X);
			optionDesc.scrollFactor.set();
			optionDesc.camera = cam;
			optionDesc.alpha = 0;
			add(optionDesc);

			var goalY = optionDesc.y;
			optionDesc.screenCenter(X);
			optionDesc.y = goalY - 12;
			optionDesc.alpha = 0;
			FlxTween.tween(optionDesc, {y: goalY, alpha: 1}, 0.35, {ease: FlxEase.quadOut});
		}else
		{
			bg.alpha = 0.3;
			FlxTween.tween(bg, {alpha: 0.7}, 0.6);
		}
		
		getOptions();

		for (i in 0...optionsArray.length)
		{
			var optionText = menu.addTextOption(optionsArray[i].name, null, 0.8);
			optionText.scrollFactor.set();
			optionText.xAdd = 120;
			optionText.x += 200;
			optionText.targetX = 225;
			optionText.y = optionText.getTargetY() - FlxG.height / 3;
			///

			if(optionsArray[i].type == 'bool') {
				var checkbox:CheckboxThingie = new CheckboxThingie(optionText.x - 105, optionText.y, optionsArray[i].getValue() == true);
				checkbox.scrollFactor.set();

				checkbox.sprTracker = optionText;
				checkbox.offsetY = -60;
				checkbox.ID = i;
				checkboxGroup.camera = cam;
				checkboxGroup.add(checkbox);
				optionText.xAdd += 80;
			} else {
				var valueText:AttachedText = new AttachedText('' + optionsArray[i].getValue(), optionText.width + 80, true, 0.8);
				valueText.scrollFactor.set();
				valueText.sprTracker = optionText;
				valueText.copyAlpha = true;
				valueText.ID = i;
				valueText.camera = cam;
				grpTexts.add(valueText);
				optionsArray[i].setChild(valueText);
			}
			updateTextFrom(optionsArray[i]);
		}

		reloadCheckboxes();
	}

	var nextAccept:Int = 5;
	var holdTime:Float = 0;
	var holdValue:Float = 0;
	var holdingTimer:Float = 0;
	override function update(elapsed:Float)
	{
		if (goption.getValue() != "constant")
		{
			soption.displayFormat = '%vX';
			soption.maxValue = 3;
		}
		else
		{
			soption.displayFormat = "%v";
			soption.maxValue = 6;
		}

		if (controls.BACK) {
			close();
			ClientPrefs.save();
			FlxG.sound.play(Paths.sound('cancelMenu'));
		}
		else if(nextAccept <= 0)
		{
			if (curOption.type != 'bool')
				updateOption(elapsed);

			if (controls.RESET)
			{
				var leOption:GameplayOption = curOption;
				curOption.setValue(leOption.defaultValue);
				
				if (leOption.type != 'bool')
				{
					if (leOption.type == 'string')
						leOption.curOption = leOption.options.indexOf(leOption.getValue());
					
					updateTextFrom(leOption);
				}

				if (leOption.name == 'Scroll Speed')
				{
					leOption.displayFormat = "%vX";
					leOption.maxValue = 3;
					if (leOption.getValue() > 3)
						leOption.setValue(3);
					
					updateTextFrom(leOption);
				}
				leOption.change();
				
				FlxG.sound.play(Paths.sound('cancelMenu'));
				reloadCheckboxes();
			}
		}

		if(nextAccept > 0) {
			nextAccept -= 1;
		}
		super.update(elapsed);
	}

	function updateOption(elapsed:Float){
		if(controls.UI_LEFT || controls.UI_RIGHT) {
			var pressed = (controls.UI_LEFT_P || controls.UI_RIGHT_P);

			if (holdTime > 0.5 || pressed) {
				holdingTimer += elapsed;
				if(pressed) {
					switch(curOption.type)
					{
						case 'int' | 'float' | 'percent':
							var add = controls.UI_LEFT ? -curOption.changeValue : curOption.changeValue;

							holdValue = curOption.getValue() + add;
							if(holdValue < curOption.minValue) holdValue = curOption.minValue;
							else if (holdValue > curOption.maxValue) holdValue = curOption.maxValue;

							switch(curOption.type)
							{
								case 'int':
									holdValue = Math.round(holdValue);
									curOption.setValue(holdValue);

								case 'float' | 'percent':
									holdValue = FlxMath.roundDecimal(holdValue, curOption.decimals);
									curOption.setValue(holdValue);
							}

						case 'string':
							var num:Int = curOption.curOption; //lol
							if(controls.UI_LEFT_P) --num;
							else num++;

							if(num < 0) {
								num = curOption.options.length - 1;
							} else if(num >= curOption.options.length) {
								num = 0;
							}

							curOption.curOption = num;
							curOption.setValue(curOption.options[num]); //lol
							
							if (curOption.name == "Scroll Type")
							{
								var oOption:GameplayOption = getOptionByName("Scroll Speed");
								if (oOption != null)
								{
									if (curOption.getValue() == "constant")
									{
										oOption.displayFormat = "%v";
										oOption.maxValue = 6;
									}
									else
									{
										oOption.displayFormat = "%vX";
										oOption.maxValue = 3;
										if(oOption.getValue() > 3) oOption.setValue(3);
									}
									updateTextFrom(oOption);
								}
							}
							//trace(curOption.options[num]);
					}
					updateTextFrom(curOption);
					curOption.change();
					FlxG.sound.play(Paths.sound('scrollMenu'));
				} else if(curOption.type != 'string') {
					while(holdingTimer >= 0.05){
						holdingTimer -= 0.05;
						holdValue += curOption.scrollSpeed * (controls.UI_LEFT ? -1 : 1);
						if(holdValue < curOption.minValue) holdValue = curOption.minValue;
						else if (holdValue > curOption.maxValue) holdValue = curOption.maxValue;

						switch(curOption.type)
						{
							case 'int':
								curOption.setValue(Math.round(holdValue));
							
							case 'float' | 'percent':
								curOption.setValue(FlxMath.roundDecimal(holdValue, curOption.decimals));
						}
						updateTextFrom(curOption);
						curOption.change();
					}
				}
			}

			if(curOption.type != 'string') {
				holdTime += elapsed;
			}
		} else if(controls.UI_LEFT_R || controls.UI_RIGHT_R) {
			clearHold();
		}
	}

	function updateTextFrom(option:GameplayOption) {
		var text:String = option.displayFormat;
		var val:Dynamic = option.getValue();
		if(option.type == 'percent') val *= 100;
		var def:Dynamic = option.defaultValue;
		option.text = text.replace('%v', val).replace('%d', def);
	}

	function clearHold()
	{
		if(holdTime > 0.5) {
			FlxG.sound.play(Paths.sound('scrollMenu'));
		}
		holdTime = 0;
		holdingTimer = 0;
	}

	function reloadCheckboxes() {
		for (checkbox in checkboxGroup) {
			checkbox.daValue = (optionsArray[checkbox.ID].getValue() == true);
		}
	}
}

class GameplayOption
{
	private var child:Alphabet;
	public var text(get, set):String;
	public var onChange:Void->Void = null; //Pressed enter (on Bool type options) or pressed/held left/right (on other types)

	public var type(get, default):String = 'bool'; //bool, int (or integer), float (or fl), percent, string (or str)
	// Bool will use checkboxes
	// Everything else will use a text

	public var showBoyfriend:Bool = false;
	public var scrollSpeed:Float = 50; //Only works on int/float, defines how fast it scrolls per second while holding left/right

	private var variable:String = null; //Variable from ClientPrefs.hx's gameplaySettings
	public var defaultValue:Dynamic = null;

	public var curOption:Int = 0; //Don't change this
	public var options:Array<String> = null; //Only used in string type
	public var changeValue:Dynamic = 1; //Only used in int/float/percent type, how much is changed when you PRESS
	public var minValue:Dynamic = null; //Only used in int/float/percent type
	public var maxValue:Dynamic = null; //Only used in int/float/percent type
	public var decimals:Int = 1; //Only used in float/percent type

	public var displayFormat:String = '%v'; //How String/Float/Percent/Int values are shown, %v = Current value, %d = Default value
	public var name:String = 'Unknown';

	public function new(name:String, variable:String, type:String = 'bool', defaultValue:Dynamic = 'null variable value', ?options:Array<String> = null)
	{
		this.name = name;
		this.variable = variable;
		this.type = type;
		this.defaultValue = defaultValue;
		this.options = options;

		if(defaultValue == 'null variable value')
		{
			switch(type)
			{
				case 'bool':
					defaultValue = false;
				case 'int' | 'float':
					defaultValue = 0;
				case 'percent':
					defaultValue = 1;
				case 'string':
					defaultValue = '';
					if(options.length > 0) {
						defaultValue = options[0];
					}
			}
		}

		if(getValue() == null) {
			setValue(defaultValue);
		}

		switch(type)
		{
			case 'string':
				this.name += " ";
				var num:Int = options.indexOf(getValue());
				if(num > -1) {
					curOption = num;
				}
	
			case 'percent':
				displayFormat = '%v%';
				changeValue = 0.01;
				minValue = 0;
				maxValue = 1;
				scrollSpeed = 0.5;
				decimals = 2;
		}
	}

	public function change()
	{
		//nothing lol
		if(onChange != null) {
			onChange();
		}
	}

	public function getValue():Dynamic
	{
		return ClientPrefs.gameplaySettings.get(variable);
	}
	public function setValue(value:Dynamic)
	{
		ClientPrefs.gameplaySettings.set(variable, value);
	}

	public function setChild(child:Alphabet)
	{
		this.child = child;
	}

	private function get_text()
	{
		if(child != null) {
			return child.text;
		}
		return null;
	}
	private function set_text(newValue:String = '')
	{
		if(child != null) {
			child.changeText(newValue);
		}
		return null;
	}

	private function get_type()
	{
		var newValue:String = 'bool';
		switch(type.toLowerCase().trim())
		{
			case 'int' | 'float' | 'percent' | 'string': newValue = type;
			case 'integer': newValue = 'int';
			case 'str': newValue = 'string';
			case 'fl': newValue = 'float';
		}
		type = newValue;
		return type;
	}
}