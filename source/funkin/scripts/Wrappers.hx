package funkin.scripts;

import flixel.util.FlxColor;
import flixel.math.FlxMath;

@:build(funkin.macros.ScriptingMacro.createEnumWrapper(funkin.data.JudgmentManager.Judgment))
class Judgment{}

@:build(funkin.macros.ScriptingMacro.createEnumWrapper(flixel.text.FlxText.FlxTextAlign))
class FlxTextAlign{}

@:build(funkin.macros.ScriptingMacro.createEnumWrapper(openfl.display.BlendMode))
class BlendMode{}

@:build(funkin.macros.ScriptingMacro.createEnumWrapper(flixel.util.FlxAxes))
class FlxAxes {}

typedef FlxTweenType = flixel.tweens.FlxTween; // lol

// stupidity
class SowyColor
{
	// These aren't part of FlxColor but i thought they could be useful
	// honestly we should replace source/flixel/FlxColor.hx or w/e with one with these funcs
	public static function toRGBArray(color:FlxColor, ?resultArray:Array<Int>):Array<Int> {
		var resultArray = resultArray ?? [];
		resultArray[0] = color.red;
		resultArray[1] = color.green;
		resultArray[2] = color.blue;
		resultArray[3] = color.alpha;
		return resultArray;
	}

	public static function toFloatArray(color:FlxColor, ?resultArray:Array<Float>):Array<Float> {
		var resultArray = resultArray ?? [];
		resultArray[0] = color.redFloat;
		resultArray[1] = color.greenFloat;
		resultArray[2] = color.blueFloat;
		resultArray[3] = color.alphaFloat;
		return resultArray;
	}

	// FlxColor.interpolate exists but im keeping this anyways
	public static function lerp(from:FlxColor, to:FlxColor, ratio:Float)
		return FlxColor.fromRGBFloat(FlxMath.lerp(from.redFloat, to.redFloat, ratio), FlxMath.lerp(from.greenFloat, to.greenFloat, ratio),
			FlxMath.lerp(from.blueFloat, to.blueFloat, ratio), FlxMath.lerp(from.alphaFloat, to.alphaFloat, ratio));

	////
	public static function get_red(color:FlxColor)
		return color.red;

	public static function get_green(color:FlxColor)
		return color.green;

	public static function get_blue(color:FlxColor)
		return color.blue;

	public static function set_red(color:FlxColor, val:Int)
	{
		color.red = val;
		return color;
	}

	public static function set_green(color:FlxColor, val:Int)
	{
		color.green = val;
		return color;
	}

	public static function set_blue(color:FlxColor, val:Int)
	{
		color.blue = val;
		return color;
	}

	public static function get_rgb(color:FlxColor)
		return color.rgb;

	public static function get_redFloat(color:FlxColor)
		return color.redFloat;

	public static function get_greenFloat(color:FlxColor)
		return color.greenFloat;

	public static function get_blueFloat(color:FlxColor)
		return color.blueFloat;

	public static function set_redFloat(color:FlxColor, val:Float)
	{
		color.redFloat = val;
		return color;
	}

	public static function set_greenFloat(color:FlxColor, val:Float)
	{
		color.greenFloat = val;
		return color;
	}

	public static function set_blueFloat(color:FlxColor, val:Float)
	{
		color.blueFloat = val;
		return color;
	}

	//
	public static function get_hue(color:FlxColor)
		return color.hue;

	public static function get_saturation(color:FlxColor)
		return color.saturation;

	public static function get_lightness(color:FlxColor)
		return color.lightness;

	public static function get_brightness(color:FlxColor)
		return color.brightness;

	public static function set_hue(color:FlxColor, val:Float)
	{
		color.hue = val;
		return color;
	}

	public static function set_saturation(color:FlxColor, val:Float)
	{
		color.saturation = val;
		return color;
	}

	public static function set_lightness(color:FlxColor, val:Float)
	{
		color.lightness = val;
		return color;
	}

	public static function set_brightness(color:FlxColor, val:Float)
	{
		color.brightness = val;
		return color;
	}

	//
	public static function get_cyan(color:FlxColor)
		return color.cyan;

	public static function get_magenta(color:FlxColor)
		return color.magenta;

	public static function get_yellow(color:FlxColor)
		return color.yellow;

	public static function get_black(color:FlxColor)
		return color.black;

	public static function set_cyan(color:FlxColor, val:Float)
	{
		color.cyan = val;
		return color;
	}

	public static function set_magenta(color:FlxColor, val:Float)
	{
		color.magenta = val;
		return color;
	}

	public static function set_yellow(color:FlxColor, val:Float)
	{
		color.yellow = val;
		return color;
	}

	public static function set_black(color:FlxColor, val:Float)
	{
		color.black = val;
		return color;
	}

	public static function multiply(lhs:FlxColor, rhs:FlxColor):FlxColor
		return FlxColor.fromRGBFloat(lhs.redFloat * rhs.redFloat, lhs.greenFloat * rhs.greenFloat, lhs.blueFloat * rhs.blueFloat);

	public static function add(lhs:FlxColor, rhs:FlxColor):FlxColor
		return FlxColor.fromRGB(lhs.red + rhs.red, lhs.green + rhs.green, lhs.blue + rhs.blue);

	public static function subtract(lhs:FlxColor, rhs:FlxColor):FlxColor
		return FlxColor.fromRGB(lhs.red - rhs.red, lhs.green - rhs.green, lhs.blue - rhs.blue);

	//
	public static function getAnalogousHarmony(color:FlxColor)
		return color.getAnalogousHarmony();

	public static function getComplementHarmony(color:FlxColor)
		return color.getComplementHarmony();

	public static function getSplitComplementHarmony(color:FlxColor)
		return color.getSplitComplementHarmony();

	public static function getTriadicHarmony(color:FlxColor)
		return color.getTriadicHarmony();

	public static function getDarkened(color:FlxColor)
		return color.getDarkened();

	public static function getInverted(color:FlxColor)
		return color.getInverted();

	public static function getLightened(color:FlxColor)
		return color.getLightened();

	public static function to24Bit(color:FlxColor)
		return color.to24Bit();

	public static function getColorInfo(color:FlxColor)
		return color.getColorInfo;

	public static function toHexString(color:FlxColor)
		return color.toHexString();

	public static function toWebString(color:FlxColor)
		return color.toWebString();

	//
	public static final fromCMYK = FlxColor.fromCMYK;
	public static final fromHSL = FlxColor.fromHSL;
	public static final fromHSB = FlxColor.fromHSB;
	public static final fromInt = FlxColor.fromInt;
	public static final fromRGBFloat = FlxColor.fromRGBFloat;
	public static final fromString = FlxColor.fromString;
	public static final fromRGB = FlxColor.fromRGB;

	public static final getHSBColorWheel = FlxColor.getHSBColorWheel;
	public static final interpolate = FlxColor.interpolate;
	public static final gradient = FlxColor.gradient;

	public static final TRANSPARENT:Int = FlxColor.TRANSPARENT;
	public static final BLACK:Int = FlxColor.BLACK;
	public static final WHITE:Int = FlxColor.WHITE;
	public static final GRAY:Int = FlxColor.GRAY;

	public static final GREEN:Int = FlxColor.GREEN;
	public static final LIME:Int = FlxColor.LIME;
	public static final YELLOW:Int = FlxColor.YELLOW;
	public static final ORANGE:Int = FlxColor.ORANGE;
	public static final RED:Int = FlxColor.RED;
	public static final PURPLE:Int = FlxColor.PURPLE;
	public static final BLUE:Int = FlxColor.BLUE;
	public static final BROWN:Int = FlxColor.BROWN;
	public static final PINK:Int = FlxColor.PINK;
	public static final MAGENTA:Int = FlxColor.MAGENTA;
	public static final CYAN:Int = FlxColor.CYAN;
}