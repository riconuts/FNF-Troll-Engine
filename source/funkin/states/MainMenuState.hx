package funkin.states;

import flixel.util.FlxTimer;
import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.FlxCamera;
import flixel.addons.transition.FlxTransitionableState;
import flixel.effects.FlxFlicker;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.text.FlxText;
import flixel.math.FlxMath;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import lime.app.Application;
import funkin.states.editors.MasterEditorMenu;
import flixel.input.keyboard.FlxKey;

using StringTools;

#if DISCORD_ALLOWED
import funkin.api.Discord.DiscordClient;
#end

class MainMenuState extends MusicBeatState
{
	public static var curSelected:Int = 0;

	var menuItems:FlxTypedGroup<FlxSprite>;
	private var camGame:FlxCamera;
	
	var optionShit:Array<String> = [
		'story_mode',
		'freeplay',
		//#if MODS_ALLOWED 'mods', #end
		// 'credits',
		//#if !switch 'donate', #end
		'options'
	];

	var bg:FlxSprite;
	var magenta:FlxSprite;
	var camFollow:FlxObject;
	var camFollowPos:FlxObject;
	var debugKeys:Array<FlxKey>;

	override function create()
	{
		#if DISCORD_ALLOWED
		// Updating Discord Rich Presence
		DiscordClient.changePresence("In the Menus", null);
		#end
		debugKeys = ClientPrefs.copyKey(ClientPrefs.keyBinds.get('debug_1'));

		camGame = new FlxCamera();

		FlxG.cameras.reset(camGame);
		FlxG.cameras.setDefaultDrawTarget(camGame, true);

		transIn = FlxTransitionableState.defaultTransIn;
		transOut = FlxTransitionableState.defaultTransOut;

		persistentUpdate = persistentDraw = true;

		camFollow = new FlxObject(0, 0, 1, 1);
		camFollowPos = new FlxObject(0, 0, 1, 1);
		add(camFollow);
		add(camFollowPos);

		FlxG.camera.follow(camFollowPos, null, 1);

		////
		var yScroll:Float = Math.max(0.1, 0.25 - (0.05 * (optionShit.length - 4)));
		
		bg = new FlxSprite(0, 0, Paths.image('menuBG'));
		bg.scrollFactor.set(0, yScroll);
		bg.screenCenter();
		bg.scale.x = bg.scale.y = 1.175;
		add(bg);

		magenta = new FlxSprite(0, 0, Paths.image('menuDesat'));
		magenta.scrollFactor.set(0, yScroll);
		magenta.screenCenter();
		magenta.scale.x = magenta.scale.y = bg.scale.x;
		magenta.visible = false;
		magenta.color = 0xFFfd719b;
		add(magenta);

		menuItems = new FlxTypedGroup<FlxSprite>();
		add(menuItems);

		var offset:Float = 108 - (Math.max(optionShit.length, 4) - 4) * 80;
		var scr:Float = (optionShit.length < 6) ? 0 : (optionShit.length - 4) * 0.135;
		for (i => optionName in optionShit)
		{
			var menuItem:FlxSprite = new FlxSprite(0, (i * 140) + offset);
			
			menuItem.frames = Paths.getSparrowAtlas('mainmenu/menu_$optionName');
			menuItem.animation.addByPrefix('idle', '$optionName basic', 24);
			menuItem.animation.addByPrefix('selected', '$optionName white', 24);
			menuItem.animation.play('idle');

			menuItem.scrollFactor.set(0, scr);
			menuItem.updateHitbox();
			menuItem.screenCenter(X);

			menuItem.ID = i;
			menuItems.add(menuItem);
		}

		var versionShit:FlxText = new FlxText(12, FlxG.height - 44, 0, 'Troll Engine ' + Main.Version.displayedVersion, 12);
		versionShit.scrollFactor.set();
		versionShit.setFormat("VCR OSD Mono", 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(versionShit);

		var versionShit:FlxText = new FlxText(12, FlxG.height - 24, 0, "Friday Night Funkin' v" + Application.current.meta.get('version'), 12);
		versionShit.scrollFactor.set();
		versionShit.setFormat("VCR OSD Mono", 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(versionShit);
		
		changeItem();

		super.create();

		if (FlxG.sound.music == null || !FlxG.sound.music.playing)
			MusicBeatState.playMenuMusic();

		var curMusicVolume = FlxG.sound.music.volume; 
		if (curMusicVolume < 0.8){
			FlxG.sound.music.fadeIn((0.8 - curMusicVolume) * 2.0, curMusicVolume, 0.8);
		}

		Paths.clearUnusedMemory();
	}

	var magTwn:FlxTween = null;
	function magentaFlicker(?tmr){
		if (magTwn != null) magTwn.cancel();
		
		magenta.alpha = 1.0;
		magTwn = FlxTween.tween(magenta, {alpha: 0}, 0.12, {ease: FlxEase.circIn});
	}
	
	function bgFlicker() {
		magenta.visible = true;
		
		if (ClientPrefs.flashing){
			magentaFlicker();
			new FlxTimer().start(0.24, magentaFlicker, Math.floor(1 / 0.24));
		}else{
			magenta.alpha = 0.0;
			FlxTween.tween(magenta, {alpha: 1.0}, 0.96, {ease: FlxEase.quintOut});
		}
	}

	var selectedSomethin:Bool = false;

	function onSelected(){
		if (optionShit[curSelected] == 'donate')
		{
			CoolUtil.browserLoad('https://ninja-muffin24.itch.io/funkin');
			return;
		}

		selectedSomethin = true;

		////
		var bgScale = bg.scale.x;
		var bgTargetScale = (FlxG.height / bg.frameHeight);
		var bgScroll = bg.scrollFactor.y;
		FlxTween.num(0.0, 1.0, 0.25, {ease: FlxEase.backOut}, (progress:Float) ->
		{
			var progress = progress / 1.125;

			var scale = FlxMath.lerp(bgScale, bgTargetScale, progress);
			magenta.scale.x = magenta.scale.y = bg.scale.x = bg.scale.y = scale;

			var scroll = FlxMath.lerp(bgScroll, 0.0, progress);
			bg.scrollFactor.y = magenta.scrollFactor.y = scroll;
		});

		bgFlicker();

		////

		menuItems.forEach((spr:FlxSprite)->{
			if (curSelected != spr.ID)
			{
				FlxTween.tween(spr, {alpha: 0.0}, 0.25, {
					ease: FlxEase.quadOut,
					onComplete: (twn:FlxTween) ->
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
						/* #if MODS_ALLOWED
						case 'mods':
							MusicBeatState.switchState(new ModsMenuState());
						#end */
						case 'credits':
							MusicBeatState.switchState(new CreditsState());
						case 'options':
							LoadingState.loadAndSwitchState(new funkin.states.options.OptionsState());
					}
				});
			}
		});
	}

	override function update(elapsed:Float)
	{
		var lerpVal:Float = CoolUtil.boundTo(elapsed * 7.5, 0, 1);
		camFollowPos.setPosition(FlxMath.lerp(camFollowPos.x, camFollow.x, lerpVal), FlxMath.lerp(camFollowPos.y, camFollow.y, lerpVal));

		if (!selectedSomethin)
		{
			if (controls.UI_UP_P)
			{
				FlxG.sound.play(Paths.sound('scrollMenu'));
				changeItem(-1);
			}

			if (controls.UI_DOWN_P)
			{
				FlxG.sound.play(Paths.sound('scrollMenu'));
				changeItem(1);
			}

			if (controls.BACK)
			{
				selectedSomethin = true;
				FlxG.sound.play(Paths.sound('cancelMenu'));
				MusicBeatState.switchState(new TitleState());
			}
			else if (controls.ACCEPT)
			{
				FlxG.sound.play(Paths.sound('confirmMenu'));
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

	function changeItem(huh:Int = 0)
	{
		curSelected += huh;

		if (curSelected >= menuItems.length)
			curSelected = 0;
		if (curSelected < 0)
			curSelected = menuItems.length - 1;

		menuItems.forEach((spr:FlxSprite)->{
			if (spr.ID == curSelected)
			{
				spr.animation.play('selected');
				spr.centerOffsets();

				var add:Float = (menuItems.length > 4) ? (menuItems.length * 8) : 0;
				camFollow.setPosition(spr.getGraphicMidpoint().x, spr.getGraphicMidpoint().y - add);
			}else{
				spr.animation.play('idle');
				spr.updateHitbox();
			}
		});
	}
}