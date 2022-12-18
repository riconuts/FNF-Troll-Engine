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
import options.GraphicsSettingsSubState;

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

	var blackScreen:FlxSprite;
	var credGroup:FlxGroup;
	var credTextShit:Alphabet;
	var textGroup:FlxGroup;
	var ngSpr:FlxSprite;

	var titleTextColors:Array<FlxColor> = [0xFF33FFFF, 0xFF3333CC];
	var titleTextAlphas:Array<Float> = [1, .64];

	var curWacky:Array<String> = [];
	
	public static var updateVersion:String = '';

	override function add(Object:FlxBasic)
	{
		if (Std.isOfType(Object, FlxSprite))
			cast(Object, FlxSprite).antialiasing = ClientPrefs.globalAntialiasing;

		return super.add(Object);
	}

	var logoBl:RandomTitleLogo;
	var titleText:FlxSprite;
	var swagShader:ColorSwap = null;
	var bg:Stage;

	// cam shit raaahhhhh
	public var camGame:FlxCamera = new FlxCamera();
	public var camHUD:FlxCamera = new FlxCamera();

	public var camFollow = new FlxPoint(640, 360);
	public var camFollowPos = new FlxObject(640, 360, 1, 1);

	override public function create():Void
	{
		super.create();

		curWacky = FlxG.random.getObject(getIntroTextShit());

		// DEBUG BULLSHIT
		swagShader = new ColorSwap();
		
		persistentUpdate = true;

		FlxTransitionableState.defaultTransIn = FadeTransitionSubstate;
		FlxTransitionableState.defaultTransOut = FadeTransitionSubstate;

		// Set up cameras
		camHUD.bgColor = 0x00000000;
		camGame.follow(camFollowPos);

		FlxG.cameras.reset(camGame);
		FlxG.cameras.add(camHUD, false);

		FlxG.cameras.setDefaultDrawTarget(camGame, true);

		// Set up a stage list
		#if MODS_ALLOWED
		var stages:Array<Array<String>> = []; // [stage name, mod directory]

		for (mod in Paths.getModDirectories()){
			Paths.currentModDirectory = mod;
			for (stage in Stage.getStageList())
				stages.push([stage, mod]);
		}
		#else
		var stages = [["stage1", ""]];
		#end

		var randomStage = stages[FlxG.random.int(0, stages.length - 1)];
		Paths.currentModDirectory = randomStage[1];

		trace(randomStage, Paths.currentModDirectory);

		bg = new Stage(randomStage[0]).buildStage();
		trace(bg.members.length);
		
		camGame.zoom = bg.stageData.defaultZoom;

		var camPos = bg.stageData.camera_stage;
		if (camPos == null)
			camPos = [640, 360];

		camFollow.set(camPos[0], camPos[1]);
		camFollowPos.setPosition(camPos[0], camPos[1]);

		add(bg);

		// Random logoooo
		swagShader = new ColorSwap();

		logoBl = new RandomTitleLogo();
		logoBl.scrollFactor.set();
		logoBl.screenCenter(XY);
		logoBl.cameras = [camHUD];
		add(logoBl);
		logoBl.shader = swagShader.shader;

		//
		titleText = new FlxSprite(100, 576);
		#if (sys && MODS_ALLOWED)
		var path = "mods/" + Paths.currentModDirectory + "/images/titleEnter.png";
		if (!FileSystem.exists(path))
			path = "mods/images/titleEnter.png";
		if (!FileSystem.exists(path))
			path = "assets/images/titleEnter.png";
		titleText.frames = FlxAtlasFrames.fromSparrow(BitmapData.fromFile(path), File.getContent(StringTools.replace(path, ".png", ".xml")));
		#else
		titleText.frames = Paths.getSparrowAtlas('titleEnter');
		#end

		titleText.animation.addByPrefix('idle', "ENTER IDLE", 24);
		titleText.animation.addByPrefix('press', ClientPrefs.flashing ? "ENTER PRESSED" : "ENTER FREEZE", 24);

		titleText.animation.play('idle');
		titleText.updateHitbox();
		titleText.cameras = [camHUD];
		add(titleText);

		//
		credGroup = new FlxGroup();
		credGroup.cameras = [camHUD];
		add(credGroup);

		textGroup = new FlxGroup();
		textGroup.cameras = [camHUD];

		blackScreen = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		credGroup.add(blackScreen);

		credTextShit = new Alphabet(0, 0, "", true);
		credTextShit.screenCenter();
		credTextShit.cameras = [camHUD];
		credTextShit.visible = false;
		FlxTween.tween(credTextShit, {y: credTextShit.y + 20}, 2.9, {ease: FlxEase.quadInOut, type: PINGPONG});

		//
		ngSpr = new FlxSprite(0, FlxG.height * 0.52).loadGraphic(Paths.image('newgrounds_logo'));
		ngSpr.visible = false;
		ngSpr.setGraphicSize(Std.int(ngSpr.width * 0.8));
		ngSpr.updateHitbox();
		ngSpr.screenCenter(X);
		ngSpr.cameras = [camHUD];
		add(ngSpr);

		//
		if (initialized)
			skipIntro();
		else{
			initialized = true;
			MusicBeatState.playMenuMusic(0);
			Conductor.changeBPM(90);
		}		
	}

	function getIntroTextShit():Array<Array<String>>
	{
		var swagGoodArray:Array<Array<String>> = [];

		// add list from the assets folder
		var fullText:String = Assets.getText(Paths.txt('introText'));

		#if MODS_ALLOWED
		for (mod in Paths.getModDirectories())
		{
			Paths.currentModDirectory = mod;
			var path = Paths.modFolders("data/introText.txt");
			var rawFile:Null<String> = null;

			#if sys
			if (FileSystem.exists(path))
				rawFile = File.getContent(path);
			#else
			if (Assets.exists(path))
				rawFile = Assets.getText(path);
			#end

			if (rawFile != null && rawFile.length > 0)
				fullText += '\n${rawFile}';
		}
		Paths.currentModDirectory = '';
		#end

		////
		var firstArray:Array<String> = fullText.split('\n');
		for (i in firstArray)
			swagGoodArray.push(i.split('--'));

		return swagGoodArray;
	}

	var transitioning:Bool = false;
	private static var playJingle:Bool = false;
	var titleTimer:Float = 0;

	override function update(elapsed:Float)
	{
		if (FlxG.sound.music != null)
			Conductor.songPosition = FlxG.sound.music.time;

		var lerpVal:Float = CoolUtil.boundTo(elapsed * 2.4, 0, 1);
		camFollowPos.setPosition(FlxMath.lerp(camFollowPos.x, camFollow.x, lerpVal), FlxMath.lerp(camFollowPos.y, camFollow.y, lerpVal));
		
		var pressedEnter:Bool = FlxG.keys.justPressed.ENTER || (controls != null && controls.ACCEPT);

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

		super.update(elapsed);
	}

	function createCoolText(textArray:Array<String>, ?offset:Float = 0)
	{
		for (i in 0...textArray.length)
		{
			var money:Alphabet = new Alphabet(0, 0, textArray[i], true, false);
			money.screenCenter(X);
			money.y += (i * 60) + 200 + offset;
			if(credGroup != null && textGroup != null) {
				credGroup.add(money);
				textGroup.add(money);
			}
		}
	}

	function addMoreText(text:String, ?offset:Float = 0)
	{
		if(textGroup != null && credGroup != null) {
			var coolText:Alphabet = new Alphabet(0, 0, text, true, false);
			coolText.screenCenter(X);
			coolText.y += (textGroup.length * 60) + 200 + offset;
			credGroup.add(coolText);
			textGroup.add(coolText);
		}
	}

	function deleteCoolText()
	{
		while (textGroup.members.length > 0)
		{
			credGroup.remove(textGroup.members[0], true);
			textGroup.remove(textGroup.members[0], true);
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
			switch (sickBeats)
			{
				case 1:
					FlxG.sound.music.stop();

					MusicBeatState.playMenuMusic(0);

					FlxG.sound.music.fadeIn(4, 0, 0.7);
				case 2:
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
			remove(credGroup);

			camHUD.flash(FlxColor.WHITE, 4);
			
			skippedIntro = true;

			Conductor.changeBPM(180);
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
		
		if (Name != null)
			titleName = Name;
		else{
			var titleNames:Array<String> = getTitlesList();
			trace(titleNames);
			titleName = titleNames[FlxG.random.int(0, titleNames.length - 1)];
		}

		antialiasing = true;

		loadGraphic(Paths.image('titles/${titleName}'));
		updateHitbox();
	}

	public var time:Float = 0;
	public var frameRate:Float = 1 / 24;
	public var size:Float = 0.72;

	override public function update(elapsed:Float){
		//// Title animation!
		time += elapsed;

		var time = time / frameRate;
		var size = size;

		antialiasing = false;

		if (time > 5)
			size *= 1;
		else if (time > 3)
			size *= 1.008;
		else if (time > frameRate)
			size *= 1.038;
		else{
			size *= 0.98;
			antialiasing = ClientPrefs.globalAntialiasing;
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
		if (Paths.currentModDirectory != null && Paths.currentModDirectory.length > 0)
			foldersToCheck.insert(0, Paths.mods(Paths.currentModDirectory + '/images/titles/'));
		#end
		
		#if sys
		for (folder in foldersToCheck){
			if (Paths.exists(folder))
				continue;

			for (file in FileSystem.readDirectory(folder))
				if (!titleNames.contains(file) && file.endsWith('.png'))
					titleNames.push(file.substr(0, file.length - 4));
		}
		#end

		if (titleNames.length < 1)
			titleNames.push("");

		return titleNames;
	}
}