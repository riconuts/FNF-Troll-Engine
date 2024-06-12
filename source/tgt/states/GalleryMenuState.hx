package tgt.gallery;

import sowy.*;
import tgt.MenuButton;
import tgt.gallery.*;
import flixel.math.FlxMath;
import flixel.util.FlxGradient;
import flixel.effects.FlxFlicker;
import flixel.tweens.*;
import flixel.group.FlxGroup;
import flixel.addons.display.FlxBackdrop;

class GalleryMenuState extends MusicBeatState
{
	var optionShit:Array<String> = ["comics", "jukebox", "titles"];
	var options = new FlxTypedGroup<MenuButton>();

	static var curSelected:Int = 0;

	function changeSelected(num:Int, ?absolute:Bool){
		var difference = absolute ? Math.abs(curSelected - num) : num;
        if(difference != 0)
			FlxG.sound.play(Paths.sound('scrollMenu'));

		curSelected = absolute==true ? num : curSelected+num;

        if (curSelected < 0 || curSelected >= optionShit.length)
            curSelected = curSelected % optionShit.length;
        if (curSelected < 0)
            curSelected = optionShit.length + curSelected;
		
		updateImage(curSelected);

		for (button in options){
			button.targetX = button.ID == curSelected ? 125 : 50;
		}

		return curSelected;
	}

	var selectedSomethin:Bool = false;

	function goBack(){
		if (selectedSomethin) return;
		selectedSomethin = true;

		FlxG.sound.play(Paths.sound('cancelMenu'));
		MusicBeatState.switchState(new MainMenuState());
		curSelected = 0;
    }

	var magenta:FlxBackdrop;
	var backdrop:FlxBackdrop;

	var cornerLeftText:TGTTextButton;

    override function create()
	{
		#if discord_rpc
		// Updating Discord Rich Presence
		Discord.DiscordClient.changePresence("In the Menus", null);
		#end

		#if !FLX_NO_MOUSE
        FlxG.mouse.visible = true;
        #end

		persistentUpdate = true;

		var bg = new FlxBackdrop();
		bg.frames = Paths.getSparrowAtlas("jukebox/space");
		bg.animation.addByPrefix("space", "space", 50, true);
		bg.animation.play("space");
		bg.screenCenter();
		add(bg);

		add(FlxGradient.createGradientFlxSprite(FlxG.width, FlxG.height, [0xAA000000, 0x55000000, 0xAA000000]));

		for (id in 0...optionShit.length){
			var option = new MenuButton(50, 210+120*id);
			
			option.onOver.callback = ()->{
				if (selectedSomethin) return;
				updateImage(id);
			};
			option.onOut.callback = ()->{
				if (selectedSomethin) return;
				option.targetX = 51;
			};

			option.onUp.callback = onSelected.bind(id);
			option.ID = id;

			option.loadGraphic(Paths.image('tgtmenus/gallerymenu/button_${optionShit[id]}'));
			
			options.add(option);
		}

		add(options);

		changeSelected(curSelected, true);

		cornerLeftText = TGTMenuShit.newBackTextButton(goBack);
		add(cornerLeftText);

		super.create();
    }

	function onSelected(?id:Int)
	{
		if (selectedSomethin) return;

		selectedSomethin = true;

		#if !FLX_NO_MOUSE
        FlxG.mouse.visible = false;
        #end

		FlxG.sound.play(Paths.sound('confirmMenu'));
		updateImage(null);

		if (id==null)
			id = curSelected;

		FlxTween.tween(cornerLeftText, {alpha: 0}, 0.4, {
			ease: FlxEase.quadOut,
			onComplete: (wtf)->{cornerLeftText.kill();}
		});

		options.forEach(function(spr){
			if (id != spr.ID){
				FlxTween.tween(spr, {alpha: 0}, 0.4, {
					ease: FlxEase.quadOut,
					onComplete: function(wtf){spr.kill();}
				});
			}else{
				FlxFlicker.flicker(spr, 1, 0.06, false, false, function(fuu){
					switch(id){
						case 0:
							ComicsMenuState.seenBefore = [];
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
				var newImage = new FlxSprite(
					FlxG.width - 560, 
					0, 
					Paths.image("tgtmenus/gallerymenu/cover_" + name)
				);
				//newImage.antialiasing = ClientPrefs.globalAntialiasing;

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
		if (controls.UI_DOWN_P){
			changeSelected(1);
			secsHolding = 0;
		}
		if (controls.UI_UP_P){
			changeSelected(-1);
			secsHolding = 0;
		}

		if (controls.UI_UP || controls.UI_DOWN){
			var checkLastHold:Int = Math.floor((secsHolding - 0.5) * 10);
			secsHolding += elapsed;
			var checkNewHold:Int = Math.floor((secsHolding - 0.5) * 10);

			if(secsHolding > 0.35 && checkNewHold - checkLastHold > 0)
				changeSelected((checkNewHold - checkLastHold) * (controls.UI_UP ? -1 : 1));
		}

		#if !FLX_NO_MOUSE
		if (FlxG.mouse.wheel != 0)
			changeSelected(-FlxG.mouse.wheel);
		#end

		if (controls.ACCEPT)
			onSelected();

        if (controls.BACK)
			goBack();
        
        super.update(elapsed);
    }
}