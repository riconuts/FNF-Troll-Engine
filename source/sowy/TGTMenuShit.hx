package sowy;

import flixel.text.FlxText;

class TGTMenuShit
{
    public static var YELLOW = 0xFFF4CC34;
    public static var BLUE = 0xFF00AAFF;

    public static function newBackTextButton(?backFunction:Void->Void)
    {
        var cornerLeftText = new TGTTextButton(20, FlxG.height, 0, "← BACK", 32, backFunction);
		cornerLeftText.label.setFormat(Paths.font("calibri.ttf"), 32, YELLOW, FlxTextAlign.RIGHT, FlxTextBorderStyle.NONE, YELLOW);
		cornerLeftText.label.underline = true;
		cornerLeftText.y -= cornerLeftText.height + 15;

        return cornerLeftText;
    }
}