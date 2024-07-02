package funkin.data;

import flixel.text.FlxText;

@:structInit
@:build(funkin.macros.FlxTextFormatterMacro.build())
class FlxTextFormat{
	public var fieldWidth:Null<Float> = null;
	public var font:Null<String> = null;
	public var size:Null<Int> = null;
	public var color:Null<Int> = null;
	
	public var borderStyle:Null<FlxTextBorderStyle> = null;
	public var borderSize:Null<Float> = null;
	public var borderColor:Null<Int> = null;

	public var bold:Null<Bool> = null;
	public var italic:Null<Bool> = null;
	public var underline:Null<Bool> = null;

	public var antialiasing:Null<Bool> = null;
	public var pixelPerfectRender:Null<Bool> = null;

	public static function applyFormat(textObject:FlxText, textFormat:FlxTextFormat);
}