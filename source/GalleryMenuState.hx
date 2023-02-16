package;

import sowy.*;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.ui.FlxButton;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;

class GalleryMenuState extends MusicBeatState
{
    var options:Array<SowyTextButton> = [];
	var curSelected = 0;

	function goBack()
    {
		MusicBeatState.switchState(new MainMenuState());
    }

    override function create(){
        super.create();

		#if !FLX_NO_MOUSE
        FlxG.mouse.visible = true;
        #end

		var bg = new FlxSprite();
		bg.frames = Paths.getSparrowAtlas("space");
		bg.animation.addByPrefix("space", "space", 30, true);
		bg.animation.play("space", true);
		bg.alpha = 0.5;
		
		if (FlxG.width > FlxG.height)
			bg.setGraphicSize(0, FlxG.height);
		else
			bg.setGraphicSize(FlxG.width, 0);

		bg.updateHitbox();
		bg.screenCenter();
		add(bg);

		var comics = new SowyTextButton(15, 300, 0, "comics", 24, function(){
			MusicBeatState.switchState(new ComicsMenuState());
        });
		comics.label.setFormat(Paths.font("calibri.ttf"), 18, FlxColor.YELLOW, FlxTextAlign.RIGHT, FlxTextBorderStyle.NONE, FlxColor.YELLOW);
        add(comics);

		var jukebox = new SowyTextButton(15, 330, 0, "jukebox", 24, function(){
			MusicBeatState.switchState(new JukeboxState());
        });
		jukebox.label.setFormat(Paths.font("calibri.ttf"), 18, FlxColor.YELLOW, FlxTextAlign.RIGHT, FlxTextBorderStyle.NONE, FlxColor.YELLOW);
		add(jukebox);

		var jukebox = new SowyTextButton(15, 360, 0, "titles", 24, function(){
			// MusicBeatState.switchState(new JukeboxState());
        });
		jukebox.label.setFormat(Paths.font("calibri.ttf"), 18, FlxColor.YELLOW, FlxTextAlign.RIGHT, FlxTextBorderStyle.NONE, FlxColor.YELLOW);
		add(jukebox);

		var cornerLeftText = new SowyTextButton(15, 720, 0, "← BACK", 32, goBack);
		cornerLeftText.label.setFormat(Paths.font("calibri.ttf"), 32, FlxColor.YELLOW, FlxTextAlign.RIGHT, FlxTextBorderStyle.NONE, FlxColor.YELLOW);
		cornerLeftText.y -= cornerLeftText.height + 15;
		add(cornerLeftText);
    }

    override function update(elapsed:Float){
        if (controls.BACK)
			goBack();
        
        super.update(elapsed);
    }
}