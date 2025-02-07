package funkin.data;

import flixel.text.FlxText;
import funkin.Paths;

@:structInit
@:build(funkin.macros.FlxTextFormatDataMacro.build())
class FlxTextFormatData{
	public var fieldWidth:Null<Float> = null;
	public var alignment:Null<FlxTextAlign> = null;

	public var font:Null<String> = null;
	public var size:Null<Int> = null;
	public var color:Null<Int> = null;
	public var alpha:Null<Float> = null;
	public var letterSpacing:Null<Float> = null;
	
	public var borderStyle:Null<FlxTextBorderStyle> = null;
	public var borderSize:Null<Float> = null;
	public var borderColor:Null<Int> = null;

	public var bold:Null<Bool> = null;
	public var italic:Null<Bool> = null;
	public var underline:Null<Bool> = null;

	public var antialiasing:Null<Bool> = null;
	public var pixelPerfectRender:Null<Bool> = null;

	public static function applyFormat(textObject:FlxText, textFormat:FlxTextFormatData);
}