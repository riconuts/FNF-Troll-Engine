package;

import sowy.Sowy;
import flixel.group.FlxSpriteGroup;
#if ACHIEVEMENTS_ALLOWED
import Achievements;
#end
import editors.MasterEditorMenu;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.addons.transition.FlxTransitionableState;
import flixel.addons.ui.FlxUIButton;
import flixel.addons.ui.FlxUITypedButton;
import flixel.effects.FlxFlicker;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.input.keyboard.FlxKey;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.ui.FlxButton.FlxTypedButton;
import flixel.ui.FlxButton;
import flixel.util.FlxColor;
import lime.app.Application;
import newoptions.OptionsState;
import sowy.SowyBaseButton;

using StringTools;
#if desktop
import Discord.DiscordClient;
#end

class OldMainMenuState extends MusicBeatState
{
	public static var engineVersion:String = '0.5.2n'; //This is also used for Discord RPC
	public static var curSelected:Int = 0;

	var menuItems:FlxTypedGroup<MainMenuButton>;

	var creditButton:SowyBaseButton;
	var jukeboxButton:SowyBaseButton;
	
	/*
	private var camGame:FlxCamera;
	private var camAchievement:FlxCamera;
	*/
	
	var optionShit:Array<String> = [
		'story_mode',
		'freeplay',
		#if ACHIEVEMENTS_ALLOWED 'awards', #end
		'promo',
		'options'
	];

	var magenta:FlxSprite;
	var camFollow:FlxObject;
	var camFollowPos:FlxObject;
	var debugKeys:Array<FlxKey>;

	override function create()
	{
		Paths.loadTheFirstEnabledMod();

		#if desktop
		// Updating Discord Rich Presence
		DiscordClient.changePresence("In the Menus", null);
		#end

		#if !FLX_NO_MOUSE
		FlxG.mouse.visible = true;
		#end

		debugKeys = ClientPrefs.copyKey(ClientPrefs.keyBinds.get('debug_1'));

		FlxG.camera.bgColor = FlxColor.BLACK;

		transIn = FlxTransitionableState.defaultTransIn;
		transOut = FlxTransitionableState.defaultTransOut;

		persistentUpdate = persistentDraw = true;

		var yScroll:Float = Math.max(0.25 - (0.05 * (optionShit.length - 4)), 0.1);
		
		var bg:FlxSprite = new FlxSprite().loadGraphic(Paths.image('newmenuu/mainmenu/menuBG'));
		bg.scrollFactor.set();
		bg.updateHitbox();
		bg.screenCenter();
		bg.antialiasing = ClientPrefs.globalAntialiasing;
		add(bg);

		camFollow = new FlxObject(0, 0, 1, 1);
		camFollowPos = new FlxObject(0, 0, 1, 1);
		add(camFollow);
		add(camFollowPos);

		menuItems = new FlxTypedGroup<MainMenuButton>();
		add(menuItems);

		var scale:Float = 1;
		/*if(optionShit.length > 6) {
			scale = 6 / optionShit.length;
		}*/

		for (i in 0...optionShit.length)
		{
			var offset:Float = 108 - (Math.max(optionShit.length, 4) - 4) * 80;
			var menuItem:MainMenuButton = new MainMenuButton(51, (i * 140) + offset);
			
			menuItem.loadGraphic(Paths.image('newmenuu/mainmenu/menu_' + optionShit[i]));
			menuItem.antialiasing = ClientPrefs.globalAntialiasing;

			menuItem.scale.x = scale;
			menuItem.scale.y = scale;
			
			menuItem.ID = i;

			menuItem.onOver.callback = function(){
				if (selectedSomethin) return;
				//FlxG.sound.play(Paths.sound('scrollMenu'));
				//menuItem.targetX = menuItem.x;
				updateImage(menuItem.ID);
			};
			menuItem.onOut.callback = function(){
				if (selectedSomethin) return;
				menuItem.targetX = 51;
			};
			menuItem.onUp.callback = function(){
				if (selectedSomethin) return;
				curSelected = menuItem.ID;
				onSelected();
			};
			
			menuItems.add(menuItem);

			var scr:Float = (optionShit.length - 4) * 0.135;
			if(optionShit.length < 6) scr = 0;

			menuItem.scrollFactor.set(0, scr);
			menuItem.updateHitbox();
		}
		
		creditButton = new SowyBaseButton(802, 586, function(){
			selectedSomethin = true;
			MusicBeatState.switchState(new CreditsState());
		});
		creditButton.loadGraphic(Paths.image('newmenuu/mainmenu/credits'));
		add(creditButton);
		
		jukeboxButton = new SowyBaseButton(988, 586);
		jukeboxButton.loadGraphic(Paths.image('newmenuu/mainmenu/comics'));
		jukeboxButton.onUp.callback = function(){
			selectedSomethin = true;
			MusicBeatState.switchState(new gallery.GalleryMenuState());
		}
		add(jukeboxButton);

		FlxG.camera.follow(camFollowPos, null, 1);

		#if !final
		var versionShit = new FlxText(12, FlxG.height - 44, 0, "Build Date: " + Sowy.getBuildDate(), 16);
		versionShit.setFormat(Paths.font("calibri.ttf"), 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		versionShit.scrollFactor.set();
		add(versionShit);
		#end
		
		var versionShit = new FlxText(12, FlxG.height - 24, 0, "Tails Gets Trolled v" + Application.current.meta.get('version'), 16);
		versionShit.setFormat(Paths.font("calibri.ttf"), 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		versionShit.scrollFactor.set();
		add(versionShit);

		changeItem();

		MusicBeatState.playMenuMusic();

		super.create();
	}

	var selectedSomethin:Bool = false;

	override function update(elapsed:Float)
	{
		if (FlxG.sound.music != null && FlxG.sound.music.volume < 0.8)
		{
			FlxG.sound.music.volume += 0.5 * FlxG.elapsed;
		}

		if (FlxG.keys.justPressed.CONTROL)
			Paths.clearUnusedMemory();

		var lerpVal:Float = CoolUtil.boundTo(elapsed * 7.5, 0, 1);
		camFollowPos.setPosition(FlxMath.lerp(camFollowPos.x, camFollow.x, lerpVal), FlxMath.lerp(camFollowPos.y, camFollow.y, lerpVal));

		if (!selectedSomethin)
		{
			#if !FLX_NO_MOUSE
			if (FlxG.mouse.wheel != 0)
			{
				changeItem(FlxG.mouse.wheel);
			}
			#end

			if (controls.UI_UP_P)
			{
				changeItem(-1);
			}

			if (controls.UI_DOWN_P)
			{			
				changeItem(1);
			}

			if (controls.BACK)
			{
				selectedSomethin = true;
				FlxG.sound.play(Paths.sound('cancelMenu'));
				MusicBeatState.switchState(new TitleState());
			}

			if (controls.ACCEPT)
			{
				onSelected();
			}
			#if desktop
			else if (FlxG.keys.anyJustPressed(debugKeys))
			{
				selectedSomethin = true;
				MusicBeatState.switchState(new MasterEditorMenu());
			}
			#end
		}

		super.update(elapsed);
	}

	function onSelected(){
		if (optionShit[curSelected] == 'promo'){
			CoolUtil.browserLoad('http://www.tailsgetstrolled.org/');
			return;
		}
	
		selectedSomethin = true;

		FlxG.sound.play(Paths.sound('confirmMenu'));
		updateImage(null);

		FlxG.mouse.visible = false;

		for (spr in [creditButton, jukeboxButton])
			FlxTween.tween(spr, {alpha: 0}, 0.4, {
				ease: FlxEase.quadOut,
				onComplete: function(twn:FlxTween){
					spr.kill();
				}
			});

		
		menuItems.forEach(function(spr)
		{
			if (curSelected != spr.ID)
			{
				FlxTween.tween(spr, {alpha: 0}, 0.4, {
					ease: FlxEase.quadOut,
					onComplete: function(twn:FlxTween){
						spr.kill();
					}
				});
			}
			else
			{
				FlxFlicker.flicker(spr, 1, 0.06, false, false, function(flick:FlxFlicker)
				{
					switch (optionShit[curSelected])
					{
						case 'story_mode':
							MusicBeatState.switchState(new StoryMenuState());
						case 'freeplay':
							MusicBeatState.switchState(new FreeplayState());
						case 'options':
							LoadingState.loadAndSwitchState(new newoptions.OptionsState());
					}
				});
			}
		});
	}

	var imageMap:Map<String, FlxSprite> = new Map<String, FlxSprite>();
	var curImage:FlxSprite;
	var lastName:String;
	var appaerTween:FlxTween;

	var kirbCollision:FlxTypedGroup<SowyBaseButton>;

	function updateImage(sowyId:Int = null){
		var name:String = sowyId != null ? "cover_" + optionShit[sowyId] : null;

		if (name == lastName)
			return;
		else
			lastName = name;

		if (appaerTween != null)
			appaerTween.cancel();

		var prevImage = curImage;
		if (name != null){
			var sowyImage = imageMap.get(name);

			if (sowyImage == null){
				var newImage = new FlxSprite(FlxG.width - 560);
				newImage.loadGraphic(Paths.image("newmenuu/mainmenu/" + name));
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

			if (name == "cover_freeplay"){
				if (kirbCollision == null){
					kirbCollision = new FlxTypedGroup();

					var totalSqueaks = 0;
					var squeak = function(){
						totalSqueaks++;

						if (totalSqueaks > 4){
							FlxG.sound.play(Paths.sound("pop"));
							sowyImage.loadGraphic(Paths.image("newmenuu/mainmenu/cover_freeplay_alt"));
							
							for (collision in kirbCollision.members)
								collision.destroy();
							kirbCollision.clear();

							return;
						}

						FlxG.sound.play(Paths.soundRandom("squeak", 1, 3), 1, false, true, function(){
							totalSqueaks--;
						});
					}

					kirbCollision.add(new SowyBaseButton(sowyImage.x + 26, sowyImage.y + 4, squeak)).makeGraphic(106, 54, 0x00000000); // head
					kirbCollision.add(new SowyBaseButton(sowyImage.x + 13, sowyImage.y + 57, squeak)).makeGraphic(42, 61, 0x00000000); // mike
					kirbCollision.add(new SowyBaseButton(sowyImage.x + 55, sowyImage.y + 57, squeak)).makeGraphic(89, 98, 0x00000000); // body
				}

				add(kirbCollision);
			}else if (kirbCollision != null)
				remove(kirbCollision);

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

	override function destroy()
	{
		for (image in imageMap)
			image.destroy();

		return super.destroy();
	}

	function changeItem(huh:Int = 0)
	{
		curSelected += huh;

		if (curSelected >= menuItems.length)
			curSelected = 0;
		if (curSelected < 0)
			curSelected = menuItems.length - 1;

		if (huh != 0) FlxG.sound.play(Paths.sound('scrollMenu'));

		menuItems.forEach(function(spr){
			spr.targetX = spr.ID == curSelected ? 151 : 51;
		});

		updateImage(curSelected);
	}

	#if ACHIEVEMENTS_ALLOWED
	// Unlocks "Freaky on a Friday Night" achievement
	function giveAchievement() {
		add(new AchievementObject('friday_night_play', camAchievement));
		FlxG.sound.play(Paths.sound('confirmMenu'), 0.7);
		trace('Giving achievement "friday_night_play"');
	}
	#end
}

class MainMenuButton extends SowyBaseButton
{
	// what??? 

	public var targetX:Float = 0;
	public var targetY:Float = 0;

	public function new(x:Float = 0, y:Float = 0)
	{
		targetX = x;
		targetY = y;
		super(x, y);
	}

	override function update(elapsed:Float)
	{
		x = Std.int(FlxMath.lerp(x, targetX, CoolUtil.boundTo(elapsed * 10.2, 0, 1)));
		y = Std.int(FlxMath.lerp(y, targetY, CoolUtil.boundTo(elapsed * 10.2, 0, 1)));
		super.update(elapsed);
	}
}