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

class StringGameplayOption extends GameplayOption
{
	public var options:Array<String>;
	public var curOption:Int; // menu

	public function new(name:String, variable:String, options:Array<String>, ?defaultValue:String) {		
		super(name, variable, STRING, defaultValue ?? options[0]);
		
		this.options = options;
		this.curOption = options.indexOf(getValue());
		if (curOption < 0) curOption = 0;
		
		this.name += " ";
	}
}

class NumericGameplayOption extends GameplayOption 
{
	public var minValue:Float = 1.0; 
	public var maxValue:Float = 0.0; 
	public var decimals:Int = 1;

	//// menu
	public var changeValue:Float = 0.05; // how much is changed when you tap left/right
	public var scrollSpeed:Float = 0.1; // how fast it scrolls per second while holding left/right

	// private var isPercent:Bool = false;

	public function new(name:String, variable:String, numberType:NumericOptionType, ?defaultValue:Dynamic) {
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

		super(name, variable, type, defaultValue);
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

class GameplayOption
{
	/** value key from ClientPrefs.gameplaySettings */
	private var variable:String = null;

	/** bool, int, float, string */
	public var type:OptionType;

	// 
	public var defaultValue:Dynamic = null;	

	/** Display name of this option */
	public var name:String = 'Unknown';

	/** How String/Float/Int values are shown, %v = Current value, %d = Default value */
	public var displayFormat:String = '%v';

	public function new(name:String, variable:String, type:OptionType, defaultValue:Dynamic) {
		this.name = Paths.getString('gameplay_modifier_$variable', name);
		this.variable = variable;
		this.type = type;
		this.defaultValue = defaultValue;

		if (getValue() == null)
			setValue(this.defaultValue);
	}

	public function getValue():Dynamic {
		return ClientPrefs.gameplaySettings.get(variable);
	}
	public function setValue(value:Dynamic) {
		ClientPrefs.gameplaySettings.set(variable, value);
	}
	public function getDisplayValue():String {
		return displayFormat.replace('%v', getValue()).replace('%d', defaultValue);
	}

	//// menu

	/** Pressed enter (on Bool type options) or pressed/held left/right (on other types) */
	public var onChange:Void->Void = null;

	public function change() {
		if (onChange != null) {
			onChange();
		}
	}

	public var checkbox:CheckboxThingie; // Used for bools
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
}