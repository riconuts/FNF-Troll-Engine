package funkin.data;

import funkin.objects.CheckboxThingie;
import funkin.objects.Alphabet;

using StringTools;

enum abstract OptionType(String)
{
	var BOOL = 'bool';
	var FLOAT = 'float';
	var INT = 'int';
	var STRING = 'string';
}

enum abstract NumericOptionType(OptionType) to OptionType
{
	var FLOAT = OptionType.FLOAT;
	var INT = OptionType.INT;
}

class StringGameplayOption extends GameplayOption<String>
{
	public var options:Array<String>;
	public var curOption:Int; // menu

	public function new(id:String, options:Array<String>, ?defaultValue:String) {		
		super(id, STRING, defaultValue ?? options[0]);
		
		this.options = options;
		this.curOption = options.indexOf(getValue());
		if (curOption < 0) curOption = 0;
		
		this.displayName += " ";
	}
}

class NumericGameplayOption extends GameplayOption<Float>
{
	public var minValue:Float = 1.0; 
	public var maxValue:Float = 0.0; 
	public var decimals:Int = 1;

	//// menu
	public var changeValue:Float = 0.05; // how much is changed when you tap left/right
	public var scrollSpeed:Float = 0.1; // how fast it scrolls per second while holding left/right

	// private var isPercent:Bool = false;

	public function new(id:String, numberType:NumericOptionType, ?defaultValue:Dynamic) {
		var type:OptionType = numberType;

		switch(numberType) {
			default:
				type = FLOAT;
				if (defaultValue == null) defaultValue = 0.0;

			case INT: 
				type = INT;
				if (defaultValue == null) defaultValue = 0;
			
			/*
			case PERCENT: 
				type = FLOAT;
				if (defaultValue == null) defaultValue = 1.0;

				isPercent = true;
				displayFormat = '%v%';
				changeValue = 0.01;
				minValue = 0;
				maxValue = 1;
				scrollSpeed = 0.5;
				decimals = 2;
			*/
		}

		super(id, type, defaultValue);
	}

	override function setValue(val:Dynamic)
		return super.setValue(type==INT ? Std.int(val) : val);

	/*
	override function getDisplayValue() {
		var val:Float = getValue();
		var strVal:String = switch(type) {
			case INT: Std.string(val);
			default: CoolUtil.coolNumber(isPercent ? val*100.0 : val, decimals);
		}

		return displayFormat.replace('%v', strVal).replace('%d', defaultValue);
	}
	*/
}

class BoolGameplayOption extends GameplayOption<Bool> {
	public var checkbox:CheckboxThingie;

	public function new(id:String, defaultValue:Bool) {
		super(id, BOOL, defaultValue);
	}

	override function updateDisplay() {
		super.updateDisplay();
		if (checkbox != null)
			checkbox.daValue = getValue();
	}
}

class GameplayOption<T:Dynamic>
{
	/** value key from ClientPrefs.gameplaySettings */
	public var id:String;

	/** Display name of this option */
	public var displayName:String;

	/** bool, int, float, string */
	public var type:OptionType;

	public var defaultValue:T;

	/** How String/Float/Int values are shown, %v = Current value, %d = Default value */
	public var displayFormat:String = '%v';

	public function new(id:String, type:OptionType, defaultValue:T) {
		this.id = id;
		this.displayName = Paths.getString('gameplay_modifier_$id') ?? id;
		this.type = type;
		this.defaultValue = defaultValue;

		if (getValue() == null)
			setValue(this.defaultValue);
	}

	public function getValue():T {
		return ClientPrefs.gameplaySettings.get(id);
	}
	public function setValue(value:T) {
		ClientPrefs.gameplaySettings.set(id, value);
	}
	public function getDisplayValue():String {
		return displayFormat.replace('%v', '${getValue()}').replace('%d', '${defaultValue}');
	}

	//// menu

	/** Pressed enter (on Bool type options) or pressed/held left/right (on other types) */
	public var onChange:Void->Void = null;

	public function change() {
		if (onChange != null) {
			onChange();
		}
	}

	public var text(get, set):String; // Everything else will use a text
	private var child:Alphabet;

	public function setChild(child:Alphabet) {
		this.child = child;
	}

	private function get_text()
		return (child!=null) ? child.text : null;
	
	private function set_text(newValue:String = '') {
		if (child != null)
			child.text = newValue;
	
		return newValue;
	}

	public function updateDisplay()
		text = getDisplayValue();
}