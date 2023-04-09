package gallery;

import flixel.effects.FlxFlicker;
import sowy.*;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.tweens.*;
import gallery.*;
import flixel.group.FlxGroup;
import flixel.ui.FlxButton;

class GalleryMenuState extends MusicBeatState
{
	var optionShit:Array<String> = ["comics", "jukebox", "titles"];
	var options = new FlxTypedGroup<TGTTextButton>();

	var curSelected(default, set):Int;
	function set_curSelected(sowy){
        if (sowy < 0 || sowy >= optionShit.length)
            sowy = sowy % optionShit.length;
        if (sowy < 0)
            sowy = optionShit.length + sowy;


		for (option in options.members)
		{
			if (option.ID == curSelected)
				option.status = FlxButton.NORMAL;
			else if (option.ID == sowy)
				option.status = FlxButton.HIGHLIGHT;
		}

		curSelected = sowy;
		updateImage(curSelected);

		return curSelected;
	}

	var selectedSomethin:Bool = false;

	function goBack(){
		MusicBeatState.switchState(new MainMenuState());
    }

    override function create()
	{
		#if desktop
		// Updating Discord Rich Presence
		Discord.DiscordClient.changePresence("In the Menus", null);
		#end

		#if !FLX_NO_MOUSE
        FlxG.mouse.visible = true;
        #end

		add(new FlxText(10, 24, FlxG.width - 10, "This is still unfinished ok???", 12));

		for (id in 0...optionShit.length){
			var option = new TGTTextButton(64, 300 + 48*id, 0, optionShit[id], 32, onSelected);
			option.label.font = Paths.font("calibri.ttf");

			option.onOver.callback = function(){curSelected = id;};
			
			option.ID = id;
			options.add(option);
		}

		add(options);

		curSelected = 0;

		var cornerLeftText = new TGTTextButton(15, 720, 0, "← BACK", 32, goBack);
		cornerLeftText.label.setFormat(Paths.font("calibri.ttf"), 32, FlxColor.YELLOW, FlxTextAlign.RIGHT, FlxTextBorderStyle.NONE, FlxColor.YELLOW);
		cornerLeftText.y -= cornerLeftText.height + 15;
		add(cornerLeftText);

		super.create();
    }

	function onSelected()
	{
		selectedSomethin = true;

		FlxG.sound.play(Paths.sound('confirmMenu'));
		updateImage(null);

		FlxG.mouse.visible = false;

		options.forEach(function(spr){
			if (curSelected != spr.ID){
				FlxTween.tween(spr, {alpha: 0}, 0.4, {
					ease: FlxEase.quadOut,
					onComplete: function(wtf){spr.kill();}
				});
			}else{
				FlxFlicker.flicker(spr, 1, 0.06, false, false, function(fuu){
					switch(curSelected){
						case 0:
							MusicBeatState.switchState(new ComicsMenuState());
						case 1:
							MusicBeatState.switchState(new JukeboxState());
						case 2:
							MusicBeatState.switchState(new TitleGalleryState());
					}
				});
			}
		});
	}

	var imageMap:Map<String, FlxSprite> = new Map<String, FlxSprite>();
	var curImage:FlxSprite;
	var lastName:String;
	var appaerTween:FlxTween;

	function updateImage(sowyId:Int = null){
		var name:String = sowyId != null ? optionShit[sowyId] : null;

		if (name == lastName)
			return;
		
		lastName = name;

		if (appaerTween != null)
			appaerTween.cancel();

		var prevImage = curImage;
		if (name != null){
			var sowyImage = imageMap.get(name);

			if (sowyImage == null){
				var newImage = new FlxSprite(FlxG.width - 560);
				newImage.loadGraphic(Paths.image("gallerymenu/cover_" + name));
				newImage.antialiasing = ClientPrefs.globalAntialiasing;

				newImage.scrollFactor.set();
				newImage.updateHitbox();
				newImage.screenCenter(Y);

				imageMap.set(name, newImage);

				sowyImage = newImage;
			}

			for (otherImage in imageMap.iterator())
				remove(otherImage);

			add(prevImage);
			add(sowyImage);

			curImage = sowyImage;
			
			sowyImage.alpha = 0;
			appaerTween = FlxTween.tween(sowyImage, {alpha: 1}, 0.1, {ease: FlxEase.quadIn,});
		}
		else if (curImage != null)
			for (daImage in imageMap.iterator())
				if (daImage == curImage)
					FlxTween.tween(daImage, {alpha: 0}, selectedSomethin ? 0.4 : 0.1, {ease: FlxEase.quadOut});
				else
					daImage.alpha = 0;
	}

	var secsHolding = 0.0;
    override function update(elapsed:Float)
	{
		/*
		if (controls.UI_DOWN_P){
			curSelected++;
			secsHolding = 0;
		}
		if (controls.UI_UP_P){
			curSelected--;
			secsHolding = 0;
		}

		if (controls.UI_UP || controls.UI_DOWN){
			var checkLastHold:Int = Math.floor((secsHolding - 0.5) * 10);
			secsHolding += elapsed;
			var checkNewHold:Int = Math.floor((secsHolding - 0.5) * 10);

			if(secsHolding > 0.35 && checkNewHold - checkLastHold > 0)
				curSelected += (checkNewHold - checkLastHold) * (controls.UI_UP ? -1 : 1);
		}
		*/

		if (controls.ACCEPT)
			onSelected();

        if (controls.BACK)
			goBack();
        
        super.update(elapsed);
    }
}