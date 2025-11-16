package funkin.objects.ui;

import flixel.addons.ui.FlxUISlider;
import flixel.addons.ui.FlxUITabMenu;
import flixel.addons.ui.FlxUINumericStepper;
import flixel.addons.ui.FlxUITypedButton;
import flixel.addons.ui.FlxUIInputText;
import flixel.addons.ui.FlxInputText;
import flixel.text.FlxText;
import flixel.ui.FlxButton;

/** dont sort my shit **/
class CustomFlxUITabMenu extends FlxUITabMenu {
	override function sortTabs(a, b):Int
		return 0;
}

/**
	Allow mouse wheel to change its value.  
	Prevent value from updating until you press Enter or click out of it.
**/
class CustomFlxUINumericStepper extends FlxUINumericStepper {
	public var hoveringText:Bool = false;

	public function new(X:Float = 0, Y:Float = 0, StepSize:Float = 1, DefaultValue:Float = 0, Min:Float = -999, Max:Float = 999, Decimals:Int = 0,
			Stack:Int = FlxUINumericStepper.STACK_HORIZONTAL, ?TextField:FlxText, ?ButtonPlus:FlxUITypedButton<FlxSprite>, ?ButtonMinus:FlxUITypedButton<FlxSprite>,
			IsPercent:Bool = false) {
		super(X, Y, StepSize, DefaultValue, Min, Max, Decimals, Stack, TextField, ButtonPlus, ButtonMinus, IsPercent);

		if ((text_field is FlxUIInputText))
		{
			var fuit:FlxUIInputText = cast text_field;
			fuit.focusLost = _onInputTextLostFocus.bind(fuit);
		}
	}

	override function update(elapsed:Float) {
		if (hoveringText = FlxG.mouse.overlaps(text_field, text_field.camera)) {
			if (FlxG.mouse.wheel > 0) _onPlus();
			else if (FlxG.mouse.wheel < 0) _onMinus();
		}
		super.update(elapsed);
	}

	override function _onInputTextEvent(text:String, action:String):Void {
		if (action != FlxInputText.ENTER_ACTION)
			return;
		
		super._onInputTextEvent(text, action);
	}

	function _onInputTextLostFocus(fuit:FlxUIInputText):Void {
		value = Std.parseFloat(fuit.text);
		_doCallback(FlxUINumericStepper.EDIT_EVENT);
		_doCallback(FlxUINumericStepper.CHANGE_EVENT);
	}
}

/**
	Allow quick mouse wheel option scrolling without having to open the dropdown
**/
class CustomFlxUIDropDownMenu extends flixel.addons.ui.FlxUIDropDownMenu.FlxUIDropDownMenu {
	override function checkClickOff() {
		if (!dropPanel.visible && header.button.status == FlxButton.HIGHLIGHT)
		{
			if (FlxG.mouse.wheel != 0) {
				var idx:Int = 0;
				for (i => btn in list) {
					if (btn.label.text != selectedLabel) continue;
					idx = i;
					break;
				}
				idx = CoolUtil.updateIndex(idx, -FlxG.mouse.wheel, list.length);
				onClickItem(idx);
			}
		}
		super.checkClickOff();
	}
}

/** 
	Allow mouse wheel to slide the handle
**/
class CustomFlxUISlider extends FlxUISlider {
	public var scrollStep:Float = 0.1;

	override function update(elapsed) {
		if (_justHovered && !dragging && scrollStep != 0.0 && FlxG.mouse.wheel != 0)
		{
			var relativePos:Float = relativePos + FlxG.mouse.wheel * scrollStep;

			value = minValue + (maxValue - minValue) * relativePos;
			if (value < minValue) value = minValue;
			else if (value > maxValue) value = maxValue; 

			if ((setVariable) && (varString != null))
			{
				Reflect.setProperty(_object, varString, value);
			}

			_lastPos = relativePos;

			if (callback != null)
				callback(relativePos);

			handle.x = expectedPos;
		}

		super.update(elapsed);
	}
}