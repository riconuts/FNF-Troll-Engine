package funkin.states;

import flixel.util.FlxTimer;
import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.FlxCamera;
import flixel.addons.transition.FlxTransitionableState;
import flixel.effects.FlxFlicker;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.text.FlxText;
import flixel.math.FlxMath;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import lime.app.Application;
import funkin.states.editors.MasterEditorMenu;
import flixel.input.keyboard.FlxKey;
import funkin.states.base.MusicBeatState.switchState;

using StringTools;

#if DISCORD_ALLOWED
import funkin.api.Discord.DiscordClient;
#end

class MainMenuState extends MusicBeatState
{
	public static var curSelected:Int = 0;

	var optionShit:Array<String> = [
		'storymode',
		'freeplay',
		//'credits',
		//'donate',
		'options',
	];

	var menuItems:FlxTypedGroup<FlxSprite>;
	var bg:FlxSprite;
	var magenta:FlxSprite;
	var camFollow:FlxObject;
	var camFollowPos:FlxObject;
	var debugKeys:Array<FlxKey>;

	var selectedSomethin:Bool = false;

	override function create()
	{
		#if DISCORD_ALLOWED
		// Updating Discord Rich Presence
		DiscordClient.changePresence({details: "In the Menus"});
		#end
		debugKeys = ClientPrefs.copyKey(ClientPrefs.keyBinds.get('debug_1'));

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
			
			menuItem.frames = Paths.getSparrowAtlas('mainmenu/$optionName');
			menuItem.animation.addByPrefix('idle', '$optionName idle', 24);
			menuItem.animation.addByPrefix('selected', '$optionName selected', 24);
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
	var transTwn:FlxTween = null;

	function bgFlicker() {
		magenta.visible = true;
		
		if (ClientPrefs.flashing){
			var loops = Math.floor(1 / 0.24);
			magenta.alpha = 1.0;
			magTwn = FlxTween.tween(magenta, {alpha: 0.0}, 0.12, {
				ease: FlxEase.circIn, 
				type: LOOPING,
				loopDelay: 0.12, 
				onComplete: (twn) -> if (--loops == 0) twn.cancel(),
			});
		}else{
			magenta.alpha = 0.0;
			magTwn = FlxTween.tween(magenta, {alpha: 1.0}, 0.96, {ease: FlxEase.quintOut});
		}
	}

	function onSelected() {		
		var shitToDo:Void -> Void = switch (optionShit[curSelected])
		{
			case 'storymode':
				switchState.bind(new StoryModeState());
			case 'freeplay':
				switchState.bind(new FreeplayState());
			case 'donate':
				return CoolUtil.browserLoad('https://ninja-muffin24.itch.io/funkin');
			case 'credits':
				switchState.bind(new CreditsState());
			case 'options':
				switchState.bind(new funkin.states.options.OptionsState());
			default:
				MusicBeatState.resetState.bind();
		}
		doSelectionTransition(shitToDo);
	}

	function doSelectionTransition(shitToDo:Null<Void -> Void>) {
		FlxG.sound.play(Paths.sound('confirmMenu'));

		selectedSomethin = true;

		////
		var bgScale = bg.scale.x;
		var bgTargetScale = Math.max(FlxG.width / bg.frameWidth, FlxG.height / bg.frameHeight);
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
				FlxTween.tween(spr, {alpha: 0.0}, 0.25, {ease: FlxEase.quadOut, onComplete: _->spr.kill()});
			else {
				transTwn = FlxTween.flicker(spr, 1, 0.12, {endVisibility: false, onComplete: _ -> shitToDo()});
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
				switchState(new TitleState());
			}
			else if (controls.ACCEPT)
			{
				onSelected();
			}
			#if desktop
			else if (FlxG.keys.anyJustPressed(debugKeys))
			{
				selectedSomethin = true;
				switchState(new MasterEditorMenu());
			}
			#end
		}

		super.update(elapsed);
	}

	function changeItem(huh:Int = 0)
	{
		if (huh != 0)
			FlxG.sound.play(Paths.sound('scrollMenu'));
		
		curSelected += huh;

		if (curSelected >= menuItems.length)
			curSelected = 0;
		if (curSelected < 0)
			curSelected = menuItems.length - 1;

		menuItems.forEach((spr:FlxSprite)->{
			if (spr.ID == curSelected) {
				spr.animation.play('selected');
				spr.centerOffsets();

				var add:Float = (menuItems.length > 4) ? (menuItems.length * 8) : 0;
				camFollow.setPosition(spr.getGraphicMidpoint().x, spr.getGraphicMidpoint().y - add);
			}else {
				spr.animation.play('idle');
				spr.updateHitbox();
			}
		});
	}
}