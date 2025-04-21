package funkin.states;

import funkin.data.CreditsOption;

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

	var hintBg:FlxSprite;
	var hintText:FlxText;

	var camFollow = new FlxPoint(FlxG.width * 0.5, FlxG.height * 0.5);
	var camFollowPos = new FlxObject();

	var dataArray:Array<CreditsOption> = [];
	var titleArray:Array<Alphabet> = [];
	var iconArray:Array<AttachedSprite> = [];

	var curSelected:Int = 0;

	override function startOutro(onOutroFinished:()->Void){
		persistentUpdate = false;
		return onOutroFinished();
	}

	public function new(?options:Array<CreditsOption>) {
		super();

		this.dataArray = options ?? {
			var creditsPath = Paths.getPath('data/credits.txt');
			var rawList = Paths.getContent(creditsPath);
			listFromString(rawList);
		}
	}

	public static function listFromString(string:String):Array<CreditsOption>
	{
		var options = [];

		for (line in CoolUtil.listFromString(string))
			options.push(optionFromString(line));

		return options;
	}

	public static function optionFromString(string:String):CreditsOption
	{
		var option = new CreditsOption();
		var data = string.split("::");

		option.text = data[0] ?? '';
		option.icon = data[1] ?? '';
		option.description = data[2] ?? '';
		option.link = data[3] ?? '';

		if (data.length == 1) {
			// title
			option.bold = true;
			option.centered = true;
			option.selectable = false;
		}

		return option;
	}

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
		var bg = new FlxSprite(Paths.image("tgtmenus/creditsbg"));
		bg.scrollFactor.set();
		bg.screenCenter();

		if (FlxG.height < FlxG.width)
			bg.scale.x = bg.scale.y = (FlxG.height * 1.05) / bg.frameHeight;
		else
			bg.scale.x = bg.scale.y = (FlxG.width * 1.05) / bg.frameWidth;
		
		add(bg);

		var backdrop = new flixel.addons.display.FlxBackdrop(Paths.image('grid'));
		backdrop.velocity.set(30, -30);
		backdrop.scrollFactor.set();
		backdrop.blend = MULTIPLY;
		backdrop.alpha = 0.25;
		backdrop.x -= 10;
		add(backdrop);

		#else
		var bg = new funkin.objects.CoolMenuBG(Paths.image('menuDesat', null, false), 0xFFea71fd);
		add(bg);
		#end

		////
		for (option in dataArray)
			createOption(option);

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
		curSelected = 0;
		changeSelection(0);
	}

	public function changeSelection(val:Int, isAbs:Bool = false) {
		curSelected = isAbs ? val : CoolUtil.updateIndex(curSelected, val, dataArray.length);

		if (!isAbs) {
			FlxG.sound.play(Paths.sound("scrollMenu"), 0.4);

			if (dataArray[curSelected].selectable != true) {
				changeSelection(val < 0 ? -1 : 1);
				return;
			}
		}

		for (id in 0...titleArray.length)
		{
			var difference = Math.abs(curSelected - id);
			var br = 1 - (difference * 0.15 + (difference > 0 ? 0.05 : 0.0));
			
			var title:Alphabet = titleArray[id];
			if (title != null) {
				var data:CreditsOption = dataArray[title.ID];
				
				if (!data.centered)
					title.targetX = 90 + difference * -20;
				if (data.selectable) {
					title.alpha = br;
					title.color = (difference > 0) ? 0xFF000000 : 0xFFFFFFFF;
				}
			}
				
			var icon:AttachedSprite = iconArray[id];
			if (icon != null){
				icon.color = FlxColor.fromRGBFloat(br,br,br);
				icon.alpha = title.alpha;
			}
		}

		var title:Alphabet = titleArray[curSelected];
		if (title != null)
			camFollow.y = title.y + title.height * 0.5 + 20;
		setDescriptionText(dataArray[curSelected].description);
	}

	var realLength:Int = 0;
	var margin = 240;
	public function createOption(data:CreditsOption) {
		if (data.text.trim().length == 0)
			return;

		var id = realLength++;
		var songTitle = new Alphabet(0, margin * id, data.text, data.bold);
		songTitle.ID = id;
		titleArray[id] = songTitle;
		
		if (data.centered) {
			songTitle.screenCenter(X);
			songTitle.targetX = songTitle.x;
		}
		else {
			songTitle.x = 90 + (1 + Math.abs(curSelected - id)) * 30;
			songTitle.targetX = 90;
		}

		var iconPath = "credits/" + data.icon;
		if (Paths.image(iconPath) != null){
			var songIcon = new AttachedSprite(iconPath);

			songIcon.xAdd = songTitle.width + 15; 
			songIcon.yAdd = (-songIcon.height / 2) + 15;
			songIcon.sprTracker = songTitle;

			iconArray[id] = songIcon;
			add(songIcon);
		}

		add(songTitle);
	}

	public function addSong(data:Array<String>, ?folder:String)
	{
		Paths.currentModDirectory = folder == null ? "" : folder;
		createOption(optionFromString(data.join("::")));
	}

	var moveTween:FlxTween;

	function setDescriptionText(text:Null<String>) {
		if (text == null || text.length == 0) {
			hintText.alpha = 0;
			hintText.text = "";
		}else{
			hintText.text = text;

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
		var change = 0;

		if (mouseWheel != 0)
			change -= mouseWheel * speed;

		if (controls.UI_DOWN_P){
			change += speed;
			secsHolding = 0;
		}
		if (controls.UI_UP_P){
			change -= speed;
			secsHolding = 0;
		}

		if (controls.UI_UP || controls.UI_DOWN){
			var checkLastHold:Int = Math.floor((secsHolding - 0.5) * 10);
			secsHolding += elapsed;
			var checkNewHold:Int = Math.floor((secsHolding - 0.5) * 10);

			if(secsHolding > 0.5 && checkNewHold - checkLastHold > 0)
				change += (checkNewHold - checkLastHold) * (controls.UI_UP ? -speed : speed);
		}

		if (change != 0)
			changeSelection(change);

		if (controls.BACK){
			controlLock = true;
			FlxG.sound.play(Paths.sound('cancelMenu'));
			MusicBeatState.switchState(new MainMenuState());
		}

		if (controls.ACCEPT){
			var link:Null<String> = dataArray[curSelected].link;
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