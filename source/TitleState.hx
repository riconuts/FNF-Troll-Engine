package;

import flixel.addons.transition.FlxTransitionableState;
import flixel.addons.transition.TransitionData;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.graphics.frames.FlxFrame;
import flixel.group.FlxGroup;
import flixel.input.gamepad.FlxGamepad;
import flixel.math.*;
import flixel.system.FlxSound;
import flixel.system.ui.FlxSoundTray;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import haxe.Json;
import openfl.Assets;
import openfl.display.Bitmap;
import openfl.display.BitmapData;

using StringTools;
#if desktop
import Discord.DiscordClient;
import sys.thread.Thread;
#end
#if sys
import sys.FileSystem;
import sys.io.File;
#end

class TitleState extends MusicBeatState
{
	public static var initialized:Bool = false;

	static var curWacky:Array<String> = [];

	static var blackScreen:FlxSprite;
	static var textGroup:FlxGroup;
	static var ngSpr:FlxSprite;

	static var logoBl:RandomTitleLogo;
	static var titleText:FlxSprite;
	static var swagShader:ColorSwap = null;
	static var bg:Stage;

	static var loaded = false;

	//
	var titleTextColors:Array<FlxColor> = [0xFF33FFFF, 0xFF3333CC];
	var titleTextAlphas:Array<Float> = [1, .64];

	// cam shit raaahhhhh
	public var camGame:FlxCamera = new FlxCamera();
	public var camHUD:FlxCamera = new FlxCamera();

	public var camFollow = new FlxPoint(640, 360);
	public var camFollowPos = new FlxObject(640, 360, 1, 1);
	
	static public function load()
	{
		curWacky = FlxG.random.getObject(getIntroTextShit());
		
		// Set up a stage list
		var stages:Array<Array<String>> = []; // [stage name, mod directory]
		
		Paths.currentModDirectory = "";
		for (stage in Stage.getStageList())
			stages.push([stage, ""]);

		#if MODS_ALLOWED
		for (mod in Paths.getModDirectories()){
			Paths.currentModDirectory = mod;
			for (stage in Stage.getStageList(true))
				stages.push([stage, mod]);
		}
		#end

		var randomStage = FlxG.random.getObject(stages); // Get a random stage from the list

		if (randomStage != null){
			Paths.currentModDirectory = randomStage[1];
			bg = new Stage(randomStage[0]);
		}

		// Random logoooo
		swagShader = new ColorSwap();

		logoBl = new RandomTitleLogo();
		logoBl.scrollFactor.set();
		logoBl.screenCenter(XY);
		
		logoBl.shader = swagShader.shader;

		//
		titleText = new FlxSprite(140, 576);
		titleText.frames = Paths.getSparrowAtlas('titleEnter');

		titleText.animation.addByPrefix('idle', "ENTER IDLE", 24);
		titleText.animation.addByPrefix('press', ClientPrefs.flashing ? "ENTER PRESSED" : "ENTER FREEZE", 24);
		titleText.animation.play('idle');

		titleText.updateHitbox();

		//
		blackScreen = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);

		textGroup = new FlxGroup();

		//
		ngSpr = new FlxSprite(0, FlxG.height * 0.52).loadGraphic(Paths.image('newgrounds_logo'));
		ngSpr.visible = false;
		ngSpr.scale.set(0.8, 0.8);
		ngSpr.updateHitbox();
		ngSpr.screenCenter(X);

		MusicBeatState.playMenuMusic(0);

		loaded = true;
	}

	override public function destroy()
	{
		curWacky = [];
		swagShader = null;

		/*
		blackScreen.destroy();
		textGroup.destroy();
		ngSpr.destroy();
	
		logoBl.destroy();
		titleText.destroy();
		bg.destroy();
		*/

		blackScreen = null;
		textGroup = null;
		ngSpr = null;
	
		logoBl = null;
		titleText = null;
		bg = null;

		loaded = false;

		return super.destroy();
	}

	override public function create():Void
	{
		if (!loaded) load();

		if (bg != null)
			bg.buildStage();

		FlxTransitionableState.defaultTransIn = FadeTransitionSubstate;
		FlxTransitionableState.defaultTransOut = FadeTransitionSubstate;

		persistentUpdate = true;

		super.create();

		// Set up cameras
		FlxG.cameras.reset(camGame);
		FlxG.cameras.add(camHUD, false);

		FlxG.cameras.setDefaultDrawTarget(camGame, true);

		camHUD.bgColor = 0x00000000;
		camGame.follow(camFollowPos);

		if (bg != null){
			camGame.zoom = bg.stageData.defaultZoom;

			var color = FlxColor.fromString(bg.stageData.bg_color);
			camGame.bgColor = color != null ? color : FlxColor.BLACK;

			var camPos = bg.stageData.camera_stage;
			if (camPos == null) camPos = [640, 360];

			camFollow.set(camPos[0], camPos[1]);
			camFollowPos.setPosition(camPos[0], camPos[1]);

			add(bg);
		}

		////
		logoBl.cameras = [camHUD];
		titleText.cameras = [camHUD];
		blackScreen.cameras = [camHUD];
		textGroup.cameras = [camHUD];
		ngSpr.cameras = [camHUD];

		add(logoBl);
		add(titleText);
		add(blackScreen);
		add(textGroup);
		add(ngSpr);


		////
		if (initialized)
			skipIntro();
		else{
			initialized = true;
			MusicBeatState.playMenuMusic(0, true);
		}
	}

	override function add(Object:FlxBasic)
	{
		if (Std.isOfType(Object, FlxSprite))
			cast(Object, FlxSprite).antialiasing = ClientPrefs.globalAntialiasing;

		return super.add(Object);
	}

	static function getIntroTextShit():Array<Array<String>>
	{
		var swagGoodArray:Array<Array<String>> = [];

		Paths.currentModDirectory = "";
		var rawFile:Null<String> = Paths.getContent(Paths.txt('introText'));

		if (rawFile != null){
			for (line in rawFile.rtrim().split('\n'))
				swagGoodArray.push(line.split('--'));
		}

		#if MODS_ALLOWED
		for (mod in Paths.getModDirectories()){
			Paths.currentModDirectory = mod;

			var rawFile:Null<String> = Paths.getContent(Paths.modsTxt("introText.txt"));

			if (rawFile != null){
				for (line in rawFile.rtrim().split('\n'))
					swagGoodArray.push(line.split('--'));
			}	
		}
		Paths.currentModDirectory = '';
		#end

		////
		return swagGoodArray;
	}

	var transitioning:Bool = false;
	private static var playJingle:Bool = false;
	var titleTimer:Float = 0;

	override function update(elapsed:Float)
	{
		if (bg != null && bg.stageScript != null)
			bg.stageScript.call('update', [elapsed]);

		if (FlxG.sound.music != null)
			Conductor.songPosition = FlxG.sound.music.time;

		var lerpVal:Float = CoolUtil.boundTo(elapsed * 2.4, 0, 1);
		camFollowPos.setPosition(FlxMath.lerp(camFollowPos.x, camFollow.x, lerpVal), FlxMath.lerp(camFollowPos.y, camFollow.y, lerpVal));
		
		var pressedEnter:Bool = FlxG.keys.justPressed.ENTER || (controls != null && controls.ACCEPT) || FlxG.mouse.justPressed;

		#if mobile
		for (touch in FlxG.touches.list){
			if (touch.justPressed)
				pressedEnter = true;
		}
		#end

		var gamepad:FlxGamepad = FlxG.gamepads.lastActive;
		if (gamepad != null)
		{
			if (gamepad.justPressed.START)
				pressedEnter = true;

			#if switch
			if (gamepad.justPressed.B)
				pressedEnter = true;
			#end
		}

		titleTimer += CoolUtil.boundTo(elapsed, 0, 1);
		if (titleTimer > 2)
			titleTimer -= 2;

		if (initialized && !transitioning && skippedIntro)
		{
			if(!pressedEnter){
				var timer:Float = titleTimer;
				if (timer >= 1)
					timer = (-timer) + 2;

				timer = FlxEase.quadInOut(timer);
				
				titleText.color = FlxColor.interpolate(titleTextColors[0], titleTextColors[1], timer);
				titleText.alpha = FlxMath.lerp(titleTextAlphas[0], titleTextAlphas[1], timer);
			}
			else
			{
				titleText.color = FlxColor.WHITE;
				titleText.alpha = 1;

				if (titleText != null)
					titleText.animation.play('press');

				camHUD.flash(ClientPrefs.flashing ? FlxColor.WHITE : 0x4CFFFFFF, 1);
				FlxG.sound.play(Paths.sound('confirmMenu'), 0.7);

				transitioning = true;

				new FlxTimer().start(1, function(tmr:FlxTimer)
				{
					MusicBeatState.switchState(new MainMenuState());
					closedState = true;
				});
			}
		}

		if (initialized && pressedEnter && !skippedIntro)
			skipIntro();

		if(swagShader != null)
		{
			if(controls.UI_LEFT) swagShader.hue -= elapsed * 0.1;
			if(controls.UI_RIGHT) swagShader.hue += elapsed * 0.1;
		}

		if (bg != null && bg.stageScript != null)
			bg.stageScript.call('onUpdate', [elapsed]);

		super.update(elapsed);
	}

	function createCoolText(textArray:Array<String>, ?offset:Float = 0)
	{
		for (i in 0...textArray.length)
		{
			var money:Alphabet = new Alphabet(0, 0, textArray[i], true, false);
			money.screenCenter(X);
			money.y += (i * 60) + 200 + offset;
			if (textGroup != null) {
				textGroup.add(money);
			}
		}
	}

	function addMoreText(text:String, ?offset:Float = 0)
	{
		if(textGroup != null) {
			var coolText:Alphabet = new Alphabet(0, 0, text, true, false);
			coolText.screenCenter(X);
			coolText.y += (textGroup.length * 60) + 200 + offset;
			textGroup.add(coolText);
		}
	}

	function deleteCoolText()
	{
		while (textGroup.members.length > 0){
			textGroup.remove(textGroup.members[0], true).destroy();
		}
	}

	private var sickBeats:Int = 0; //Basically curBeat but won't be skipped if you hold the tab or resize the screen
	public static var closedState:Bool = false;
	override function beatHit()
	{
		super.beatHit();

		if (logoBl != null)
			logoBl.time = 0;

		if(!closedState) {
			sickBeats++;
			switch (sickBeats * 0.5)
			{
				case 1:
					FlxG.sound.music.stop();
					if (MusicBeatState.menuVox != null)
					{
						MusicBeatState.menuVox.stop();
						MusicBeatState.menuVox.destroy();
						MusicBeatState.menuVox = null;
					}
					
					
					MusicBeatState.playMenuMusic(0, true);
					//FlxG.sound.music.fadeIn(4, 0, 0.7);
				case 2:
					MusicBeatState.playMenuMusic(1, true);
					createCoolText(['THE FNF TGT TEAM']);
				case 4:
					addMoreText('presents');
				case 5:
					deleteCoolText();
				case 6:
					createCoolText(['In association', 'with'], -40);
				case 8:
					addMoreText('tailsgetstrolled dot org', -40);
					ngSpr.visible = true;
				case 9:
					deleteCoolText();
					ngSpr.visible = false;
				case 10:
					createCoolText([curWacky[0]]);
				case 12:
					addMoreText(curWacky[1]);
				case 13:
					deleteCoolText();
				case 14:
					addMoreText('Tails');
				case 15:
					addMoreText('Gets');
				case 16:
					addMoreText('Trolled');
				case 17:
					skipIntro();
			}
		}
	}

	var skippedIntro:Bool = false;
	var increaseVolume:Bool = false;
	function skipIntro():Void
	{
		if (!skippedIntro)
		{
			remove(ngSpr);
			remove(blackScreen);
			remove(textGroup);

			camHUD.flash(FlxColor.WHITE, 4);
			
			skippedIntro = true;
		}
	}
}

// ...kinda unnecessary to make a whole class
class RandomTitleLogo extends FlxSprite
{
	public var titleName:String;

	public function new(?X:Float, ?Y:Float, ?Name:String)
	{
		super(X, Y);
		
		titleName = Name != null ? Name : FlxG.random.getObject(getTitlesList());

		loadGraphic(Paths.image('titles/${titleName}'));
		updateHitbox();

		antialiasing = true;
	}

	public var time:Float = 0;
	public var frameRate:Float = 1 / 24;
	public var size:Float = 0.72;

	override public function update(elapsed:Float){
		//// Title animation!
		time += elapsed;

		var time = time / frameRate;
		var size = size;

		if (time > 5){
			
		}else if (time > 3)
			size *= 1.008;
		else if (time > 1)
			size *= 1.038;
		else{
			size *= 0.98;
		}

		scale.set(size, size);

		super.update(elapsed);
	}

	public static function getTitlesList():Array<String>
	{
		var titleNames:Array<String> = [];
		var foldersToCheck:Array<String> = [Paths.getPreloadPath('images/titles/')];

		#if MODS_ALLOWED
		foldersToCheck.insert(0, Paths.mods('images/titles/'));
		foldersToCheck.insert(0, Paths.mods('global/images/titles/'));
		if (Paths.currentModDirectory != null && Paths.currentModDirectory.length > 0)
			foldersToCheck.insert(0, Paths.mods(Paths.currentModDirectory + '/images/titles/'));
		#end
		
		for (folder in foldersToCheck){
			Paths.iterateDirectory(folder, function(path:String){
				var file = new haxe.io.Path(path);

				if (!titleNames.contains(file.file) && file.ext == "png")
					titleNames.push(file.file);
			});
		}

		if (titleNames.length < 1)
			titleNames.push("");

		return titleNames;
	}
}