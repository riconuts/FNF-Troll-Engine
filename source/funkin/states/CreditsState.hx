package funkin.states;

import flixel.*;
import flixel.math.*;
import flixel.text.FlxText;
import flixel.tweens.*;
import flixel.util.FlxColor;

#if DISCORD_ALLOWED
import funkin.api.Discord.DiscordClient;
#end
#if sys
import sys.io.File;
import sys.FileSystem;
#end

using StringTools;

class CreditsState extends MusicBeatState
{	
	// Removed usehttp since engine no longer has credits baseline
	// Maybe we could add it back some day w/ github contributors n shit tho
	

	var bg:FlxSprite;

	var hintBg:FlxSprite;
	var hintText:FlxText;

	var camFollow = new FlxPoint(FlxG.width * 0.5, FlxG.height * 0.5);
	var camFollowPos = new FlxObject();

	var dataArray:Array<Array<String>> = [];
	var titleArray:Array<Alphabet> = [];
	var iconArray:Array<AttachedSprite> = [];

	var curSelected(default, set):Int = 0;
	
	function set_curSelected(sowy:Int)
	{
		if (dataArray[sowy] == null){ // skip empty spaces and titles
			sowy += (sowy < curSelected) ? -1 : 1;

			// also skip any following spaces
			if (sowy >= titleArray.length)
				sowy = sowy - titleArray.length;
			else if (sowy < 0)
				sowy = titleArray.length + sowy;

			return set_curSelected(sowy); 
		}

		if (sowy >= titleArray.length)
			curSelected = sowy - titleArray.length;
		else if (sowy < 0)
			curSelected = titleArray.length + sowy;
		
		curSelected = sowy;
		updateSelection();

		return curSelected;
	}

	override function startOutro(onOutroFinished:()->Void){
		persistentUpdate = false;
		return onOutroFinished();
	}
	
	var backdrop:flixel.addons.display.FlxBackdrop;

	override function create()
	{
		#if DISCORD_ALLOWED
		// Updating Discord Rich Presence
		DiscordClient.changePresence("In the Menus", null);
		#end

		persistentUpdate = true;
		
		Paths.clearStoredMemory();
		
		PlayState.isStoryMode = false;

		FlxG.camera.follow(camFollowPos);
		FlxG.camera.bgColor = FlxColor.BLACK;

		////
		camFollowPos.setPosition(camFollow.x, camFollow.y);

		////
		#if tgt
		bg = new FlxSprite(Paths.image("tgtmenus/creditsbg"));
		#else
		// the cool thing from the options state
		var color = 0xFFea71fd; 
		var bgGraphic = Paths.image('menuDesat');
		var adjustColor = new funkin.objects.shaders.AdjustColor();
		adjustColor.contrast = 1.0;
		adjustColor.brightness = -0.125;

		bg = new FlxSprite((FlxG.width - bgGraphic.width) * 0.5, (FlxG.height - bgGraphic.height) * 0.5, bgGraphic);
		bg.shader = adjustColor.shader;
		bg.blend = INVERT;
		bg.color = color;
		bg.alpha = 0.25;
		bg.setColorTransform(-1, -1, -1, 1, Std.int(255 + bg.color.red / 3), Std.int(255 + bg.color.green / 3), Std.int(255 + bg.color.blue / 3), 0);

		var bg2 = new FlxSprite(bg.x, bg.y).makeGraphic(bg.frameWidth, bg.frameHeight, 0x00000000, false, 'OptionsState_bg');
		bg2.blend = MULTIPLY;
		bg2.stamp(bg);

		bg.destroy();
		bg = bg2;

		var grid = new openfl.display.BitmapData(2, 2);
		grid.setPixel32(0, 0, 0xFFC0C0C0);
		grid.setPixel32(1, 1, 0xFFC0C0C0);

		var grid = flixel.graphics.FlxGraphic.fromBitmapData(grid, false, 'OptionsState_grid');

		backdrop = new flixel.addons.display.FlxBackdrop(grid);
		backdrop.scale.x = backdrop.scale.y = FlxG.height / 3;
		backdrop.updateHitbox();
		backdrop.y -= backdrop.height / 2;
		backdrop.velocity.set(30, 30);
		backdrop.antialiasing = true;
		backdrop.color = color;
		backdrop.scrollFactor.set(0, 0);
		backdrop.alpha = 0.5;
		backdrop.blend = ADD;

		var gradient = flixel.util.FlxGradient.createGradientFlxSprite(FlxG.width, FlxG.height, [0xFFFFFFFF, 0xFF000000]);
		gradient.scrollFactor.set(0, 0);
		add(gradient);
		add(backdrop);

		bg.setGraphicSize(0, FlxG.height);
		bg.updateHitbox();
		bg.screenCenter();
		add(bg);
		#end

		bg.screenCenter().scrollFactor.set();

		if (FlxG.height < FlxG.width){
			bg.scale.x = bg.scale.y = (FlxG.height * 1.05) / bg.frameHeight;
		}else{
			bg.scale.x = bg.scale.y = (FlxG.width * 1.05) / bg.frameWidth;
		}

		add(bg);

		#if tgt
		var backdrops = new flixel.addons.display.FlxBackdrop(Paths.image('grid'));
		backdrops.velocity.set(30, -30);
		backdrops.scrollFactor.set();
		backdrops.blend = MULTIPLY;
		backdrops.alpha = 0.25;
		backdrops.x -= 10;
		add(backdrops);
		#end

		////
		function loadLine(line:String, ?folder:String)
			addSong(line.split("::"), folder);

		//// Get credits list

		// TODO: Allow mods to add their own credits

		var creditsPath = Paths.getPath('data/credits.txt');

		for (i in CoolUtil.listFromString(Paths.getContent(creditsPath)))
			loadLine(i);

		////
		hintBg = new FlxSprite(0, FlxG.height - 130).makeGraphic(1, 1);
		hintBg.scale.set(FlxG.width - 100, 120);
		hintBg.updateHitbox();
		hintBg.screenCenter(X);
		hintBg.color = 0xFF000000;
		hintBg.alpha = 0.6;
		hintBg.scrollFactor.set();
		add(hintBg);

		hintText = new FlxText(hintBg.x + 25, hintBg.y + hintBg.height * 0.5 - 16, hintBg.width - 50, "asfgh", 32);
		hintText.setFormat(Paths.font("calibri.ttf"), 32, 0xFFFFFFFF, CENTER);
		hintText.scrollFactor.set();
		add(hintText);
		
		super.create();

		updateSelection();
		curSelected = 0;
	}

	var realIndex:Int = 0;
	var margin = 240;
	public function addSong(data:Array<String>, ?folder:String)
	{
		Paths.currentModDirectory = folder == null ? "" : folder;

		var songTitle:Alphabet; 
		var id = realIndex++;

		if (data.length > 1)
		{
			songTitle = new Alphabet(0, margin * id, data[0], false);
			songTitle.x = 120;
			songTitle.targetX = 90;

			dataArray[id] = data; 

			var iconPath = "credits/" + data[1];
			if (Paths.image(iconPath) != null){
				var songIcon = new AttachedSprite(iconPath);

				songIcon.xAdd = songTitle.width + 15; 
				songIcon.yAdd = (-songIcon.height / 2) + 15;
				songIcon.sprTracker = songTitle;

				iconArray[id] = songIcon;
				add(songIcon);
			}
		}else if (data[0].trim().length == 0){
			return;
		}else{
			songTitle = new Alphabet(0, margin * id, data[0], true);
			songTitle.screenCenter(X);
			songTitle.targetX = songTitle.x;
		}

		songTitle.ID = id;
		titleArray[id] = songTitle;
		add(songTitle);
	}

	var moveTween:FlxTween;
	
	function updateSelection(playSound:Bool = true)
	{
		if (playSound)
			FlxG.sound.play(Paths.sound("scrollMenu"), 0.4 );

		// selectedSong = titleArray[curSelected];

		for (id in 0...titleArray.length)
		{
			var title:Alphabet = titleArray[id];
			var data:Array<String> = dataArray[id];
			var icon:AttachedSprite = iconArray[id];

			if (data == null){ // for the category titles, whatevrr !!!
				
			}else if (id == curSelected){
				title.alpha = 1;
				title.targetX = 90;
				title.color = 0xFFFFFFFF;

				if (icon != null)
					icon.color = 0xFFFFFFFF;

				var descText = data[2];
				if (descText == null){
					hintText.alpha = 0;
					hintText.text = "";
				}else{
					hintText.text = descText;

					hintBg.scale.y = 30 + hintText.height;
					hintBg.updateHitbox();
					hintBg.y = FlxG.height - hintBg.height - 10;

					hintText.y = hintBg.y + hintBg.height * 0.5 - hintText.height * 0.5;

					//// FUCK
					var sby = hintBg.y + 15;
					var eby = hintBg.y;
					var sty = hintText.y + 15;
					var ety = hintText.y;
					var sba = hintBg.alpha;
					if (moveTween != null)
						moveTween.cancel();
					moveTween = FlxTween.num(0, 1, 0.25, {ease: FlxEase.sineOut}, function(v){
						hintBg.y = FlxMath.lerp(sby, eby, v);
						hintText.y = FlxMath.lerp(sty, ety, v);
						hintBg.alpha = FlxMath.lerp(sba, 0.6, v);
					});
				}

				camFollow.y = title.y + title.height * 0.5 + 20;
			}else{
				var difference = Math.abs(curSelected - id);
				
				title.targetX = 90 + difference * -20;
				title.alpha = (1 - difference * 0.15);
				title.color = 0xFF000000;
				
				if (icon != null){
					var br = 1-(difference * 0.15 + 0.05);
					icon.color = FlxColor.fromRGBFloat(br,br,br);
				}
			}

			if (icon != null)
				icon.alpha = title.alpha;
		}
	}
	
	var secsHolding:Float = 0;
	var controlLock:Bool = false;
	override function update(elapsed:Float)
	{
		var targetVolume:Float =  0.7;
		if (FlxG.sound.music != null && FlxG.sound.music.volume < targetVolume)
			FlxG.sound.music.volume += 0.5 * FlxG.elapsed;

		if (FlxG.sound.music.volume > targetVolume)
			FlxG.sound.music.volume = targetVolume;

		//// update camera
		var farAwaySpeedup = 0.002 * Math.max(0, Math.abs(camFollowPos.y - camFollow.y) - 360);
		var lerpVal = Math.exp(-elapsed * (9.6 + farAwaySpeedup));
		camFollowPos.setPosition(
			FlxMath.lerp(camFollow.x, camFollowPos.x, lerpVal), 
			FlxMath.lerp(camFollow.y, camFollowPos.y, lerpVal)
		);

		////
		if (!controlLock){
		var speed = FlxG.keys.pressed.SHIFT ? 2 : 1;

		var mouseWheel = FlxG.mouse.wheel;
		if (mouseWheel != 0)
			curSelected -= mouseWheel * speed;

		if (controls.UI_DOWN_P){
			curSelected += speed;
			secsHolding = 0;
		}
		if (controls.UI_UP_P){
			curSelected -= speed;
			secsHolding = 0;
		}

		if (controls.UI_UP || controls.UI_DOWN){
			var checkLastHold:Int = Math.floor((secsHolding - 0.5) * 10);
			secsHolding += elapsed;
			var checkNewHold:Int = Math.floor((secsHolding - 0.5) * 10);

			if(secsHolding > 0.5 && checkNewHold - checkLastHold > 0)
				curSelected += (checkNewHold - checkLastHold) * (controls.UI_UP ? -speed : speed);
		}

		if (controls.BACK){
			controlLock = true;
			FlxG.sound.play(Paths.sound('cancelMenu'));
			MusicBeatState.switchState(new MainMenuState());
		}

		if (controls.ACCEPT){
			var link:Null<String> = dataArray[curSelected][3];
			if (link != null && link.length > 0)
				CoolUtil.browserLoad(link);
		}

		#if tgt
		if (FlxG.keys.justPressed.NINE)
		{
			for (item in titleArray)
			{
				if (item != null && !item.isBold)
					item.x += 50;
			}

			for (icon in iconArray)
			{
				if (icon != null)
					icon.loadGraphic(Paths.image('credits/peak'));
			}
		}
		#end
		}
		
		super.update(elapsed);
	}
}