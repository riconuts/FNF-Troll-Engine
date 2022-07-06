package;

import Achievements;
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
import options.OptionsState;

using StringTools;
#if desktop
import Discord.DiscordClient;
#end

class MainMenuState extends MusicBeatState
{
	public static var psychEngineVersion:String = '0.5.2n'; //This is also used for Discord RPC
	public static var curSelected:Int = 0;

	var menuItems:FlxTypedGroup<SowyUIButton>;
	private var camGame:FlxCamera;
	private var camAchievement:FlxCamera;
	
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
		WeekData.loadTheFirstEnabledMod();

		#if desktop
		// Updating Discord Rich Presence
		DiscordClient.changePresence("In the Menus", null);
		
		FlxG.mouse.visible = true;
		#end
		debugKeys = ClientPrefs.copyKey(ClientPrefs.keyBinds.get('debug_1'));

		camGame = new FlxCamera();
		camAchievement = new FlxCamera();
		camAchievement.bgColor.alpha = 0;

		FlxG.cameras.reset(camGame);
		FlxG.cameras.add(camAchievement);
		FlxCamera.defaultCameras = [camGame];

		transIn = FlxTransitionableState.defaultTransIn;
		transOut = FlxTransitionableState.defaultTransOut;

		persistentUpdate = persistentDraw = true;

		var yScroll:Float = Math.max(0.25 - (0.05 * (optionShit.length - 4)), 0.1);
		
		var bg:FlxSprite = new FlxSprite(-80).loadGraphic(Paths.image('newmenuu/mainmenu/menuBG'));
		bg.scrollFactor.set();
		//bg.setGraphicSize(Std.int(bg.width * 1.175));
		bg.updateHitbox();
		bg.screenCenter();
		bg.antialiasing = ClientPrefs.globalAntialiasing;
		add(bg);

		camFollow = new FlxObject(0, 0, 1, 1);
		camFollowPos = new FlxObject(0, 0, 1, 1);
		add(camFollow);
		add(camFollowPos);

		menuItems = new FlxTypedGroup<SowyUIButton>();
		add(menuItems);

		var scale:Float = 1;
		/*if(optionShit.length > 6) {
			scale = 6 / optionShit.length;
		}*/

		for (i in 0...optionShit.length)
		{
			var offset:Float = 108 - (Math.max(optionShit.length, 4) - 4) * 80;
			var menuItem:SowyUIButton = new SowyUIButton(51, (i * 140)  + offset);
			
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

		/*
		var creditButton:FlxUIButton = new FlxUIButton(802, 586);
		creditButton.loadGraphic(Paths.image('newmenuu/mainmenu/credits'));
		creditButton.onUp.callback = function(){
			selectedSomethin = true;
			MusicBeatState.switchState(new CreditsState());
		}
		
		var jukeboxButton:FlxUIButton = new FlxUIButton(988, 586);
		jukeboxButton.loadGraphic(Paths.image('newmenuu/mainmenu/jukebox'));
		jukeboxButton.onUp.callback = function(){
			selectedSomethin = true;
			MusicBeatState.switchState(new CreditsState());
		}

		add(creditButton);
		add(jukeboxButton);
		*/

		FlxG.camera.follow(camFollowPos, null, 1);

		var versionShit:FlxText = new FlxText(12, FlxG.height - 44, 0, "Psych Engine v" + psychEngineVersion, 12);
		versionShit.scrollFactor.set();
		versionShit.setFormat("VCR OSD Mono", 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(versionShit);
		var versionShit:FlxText = new FlxText(12, FlxG.height - 24, 0, "Friday Night Funkin' v" + Application.current.meta.get('version'), 12);
		versionShit.scrollFactor.set();
		versionShit.setFormat("VCR OSD Mono", 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(versionShit);

		// NG.core.calls.event.logEvent('swag').send();

		changeItem();

		#if ACHIEVEMENTS_ALLOWED
		Achievements.loadAchievements();
		var leDate = Date.now();
		if (leDate.getDay() == 5 && leDate.getHours() >= 18) {
			var achieveID:Int = Achievements.getAchievementIndex('friday_night_play');
			if(!Achievements.isAchievementUnlocked(Achievements.achievementsStuff[achieveID][2])) { //It's a friday night. WEEEEEEEEEEEEEEEEEE
				Achievements.achievementsMap.set(Achievements.achievementsStuff[achieveID][2], true);
				giveAchievement();
				ClientPrefs.saveSettings();
			}
		}
		#end

		super.create();
	}

	var selectedSomethin:Bool = false;

	override function update(elapsed:Float)
	{
		if (FlxG.sound.music != null && FlxG.sound.music.volume < 0.8)
		{
			FlxG.sound.music.volume += 0.5 * FlxG.elapsed;
		}

		var lerpVal:Float = CoolUtil.boundTo(elapsed * 7.5, 0, 1);
		camFollowPos.setPosition(FlxMath.lerp(camFollowPos.x, camFollow.x, lerpVal), FlxMath.lerp(camFollowPos.y, camFollow.y, lerpVal));

		if (!selectedSomethin)
		{
			#if desktop
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

			/*
			if (controls.BACK)
			{
				selectedSomethin = true;
				FlxG.sound.play(Paths.sound('cancelMenu'));
				MusicBeatState.switchState(new TitleState());
			}
			*/

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
		if (optionShit[curSelected] == 'promo')
			CoolUtil.browserLoad('http://www.tailsgetstrolled.org/');
		else{
			selectedSomethin = true;

			FlxG.sound.play(Paths.sound('confirmMenu'));
			updateImage(null);

			FlxG.mouse.visible = false;
			
			menuItems.forEach(function(spr:FlxSprite)
			{
				if (curSelected != spr.ID)
				{
					FlxTween.tween(spr, {alpha: 0}, 0.4, {
						ease: FlxEase.quadOut,
						onComplete: function(twn:FlxTween)
						{
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
							case 'credits':
								MusicBeatState.switchState(new CreditsState());
							case 'options':
								LoadingState.loadAndSwitchState(new options.OptionsState());
							#if MODS_ALLOWED
							case 'mods':
								MusicBeatState.switchState(new ModsMenuState());
							#end
							#if ACHIEVEMENTS_ALLOWED
							case 'awards':
								MusicBeatState.switchState(new AchievementsMenuState());
							#end
						}
					});
				}
			});
		}
	}

	var imageMap:Map<String, FlxSprite> = new Map<String, FlxSprite>();
	var curImage:FlxSprite;
	var lastName:String;
	var appaerTween:FlxTween;

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

	function changeItem(huh:Int = 0)
	{
		curSelected += huh;

		if (curSelected >= menuItems.length)
			curSelected = 0;
		if (curSelected < 0)
			curSelected = menuItems.length - 1;

		if (huh != 0) FlxG.sound.play(Paths.sound('scrollMenu'));

		menuItems.forEach(function(spr:SowyUIButton)
		{
			if (spr.ID == curSelected)
				spr.targetX = 151;
			else
				spr.targetX = 51;
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

class SowyUIButton extends FlxUIButton
{
	// what??? 

	public var targetX:Float = 0;
	public var targetY:Float = 0;

	public function new(x:Float, y:Float)
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