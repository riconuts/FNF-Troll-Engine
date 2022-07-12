package;

import flixel.FlxBasic;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.addons.transition.FlxTransitionableState;
import flixel.addons.transition.TransitionData;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.group.FlxGroup;
import flixel.input.gamepad.FlxGamepad;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.math.FlxRect;
import flixel.system.FlxSound;
import flixel.system.ui.FlxSoundTray;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import haxe.Json;
import lime.app.Application;
import openfl.Assets;
import openfl.display.Bitmap;
import openfl.display.BitmapData;
import options.GraphicsSettingsSubState;

using StringTools;
#if desktop
import Discord.DiscordClient;
import sys.thread.Thread;
#end
#if MODS_ALLOWED
import sys.FileSystem;
import sys.io.File;
#end
typedef TitleData =
{

	titlex:Float,
	titley:Float,
	startx:Float,
	starty:Float,
	gfx:Float,
	gfy:Float,
	backgroundSprite:String,
	bpm:Int
}
class TitleState extends MusicBeatState
{
	public static var initialized:Bool = false;

	var blackScreen:FlxSprite;
	var credGroup:FlxGroup;
	var credTextShit:Alphabet;
	var textGroup:FlxGroup;
	var ngSpr:FlxSprite;

	var curWacky:Array<String> = [];

	var wackyImage:FlxSprite;

	var mustUpdate:Bool = false;

	var titleJSON:TitleData;

	public static var updateVersion:String = '';

	override public function create():Void
	{
		super.create();

		#if desktop
		FlxG.mouse.visible = false;
		#end

		#if CHECK_FOR_UPDATES
		if(!closedState) {
			trace('checking for update');
			var http = new haxe.Http("https://raw.githubusercontent.com/ShadowMario/FNF-PsychEngine/main/gitVersion.txt");

			http.onData = function (data:String)
			{
				updateVersion = data.split('\n')[0].trim();
				var curVersion:String = MainMenuState.psychEngineVersion.trim();
				trace('version online: ' + updateVersion + ', your version: ' + curVersion);
				if(updateVersion != curVersion) {
					trace('versions arent matching!');
					mustUpdate = true;
				}
			}

			http.onError = function (error) {
				trace('error: $error');
			}

			http.request();
		}
		#end

		curWacky = FlxG.random.getObject(getIntroTextShit());

		// DEBUG BULLSHIT
		swagShader = new ColorSwap();

		titleJSON = Json.parse(Paths.getTextFromFile('images/gfDanceTitle.json'));

		if (FlxG.save.data.weekCompleted != null)
		{
			StoryMenuState.weekCompleted = FlxG.save.data.weekCompleted;
		}

		#if desktop
		if (!DiscordClient.isInitialized)
		{
			DiscordClient.initialize();
			Application.current.onExit.add (function (exitCode) {
				DiscordClient.shutdown();
			});
		}
		#end
		
		startIntro();
	}

	var logoBl:FlxSprite;
	var gfDance:FlxSprite;
	var danceLeft:Bool = false;
	var titleText:FlxSprite;
	var swagShader:ColorSwap = null;
	var bg:TitleStage;

	function startIntro()
	{
		if (!initialized)
		{
			FlxTransitionableState.defaultTransIn = FadeTransitionSubstate;
			FlxTransitionableState.defaultTransOut = FadeTransitionSubstate;
			
			if(FlxG.sound.music == null) {
				FlxG.sound.playMusic(Paths.music('freakyIntro'), 0, false);
			}
		}

		Conductor.changeBPM(90);//(titleJSON.bpm);
		persistentUpdate = true;
		
		bg = new TitleStage();
		add(bg);

		/*
		if (bg.curStage == 'highzoneShadow')
		{
			highShader = new HighEffect();
			FlxG.camera.setFilters([new ShaderFilter(highShader.shader)]);
		}
		*/

		swagShader = new ColorSwap();

		var titleNames = Paths.getDirs("titles");
		var titleShit = titleNames[FlxG.random.int(0, titleNames.length)];
		
		logoBl = new FlxSprite(0);
		logoBl.frames = Paths.getSparrowAtlas('titles/${titleShit}/logoBumpin');
		logoBl.antialiasing = true;
		logoBl.animation.addByPrefix('bump', 'logo bumpin', 24);
		logoBl.animation.play('bump');
		logoBl.setGraphicSize(Std.int(logoBl.width * 0.72));
		logoBl.scrollFactor.set();
		logoBl.updateHitbox();
		logoBl.screenCenter(XY);

		/*
		gfDance = new FlxSprite(titleJSON.gfx, titleJSON.gfy);
		gfDance.frames = Paths.getSparrowAtlas('gfDanceTitle');
		gfDance.animation.addByIndices('danceLeft', 'gfDance', [30, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14], "", 24, false);
		gfDance.animation.addByIndices('danceRight', 'gfDance', [15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29], "", 24, false);
		gfDance.antialiasing = ClientPrefs.globalAntialiasing;

		add(gfDance);
		gfDance.shader = swagShader.shader;
		*/
		
		add(logoBl);
		logoBl.shader = swagShader.shader;

		titleText = new FlxSprite(titleJSON.startx, titleJSON.starty);
		#if (desktop && MODS_ALLOWED)
		var path = "mods/" + Paths.currentModDirectory + "/images/titleEnter.png";
		//trace(path, FileSystem.exists(path));
		if (!FileSystem.exists(path)){
			path = "mods/images/titleEnter.png";
		}
		//trace(path, FileSystem.exists(path));
		if (!FileSystem.exists(path)){
			path = "assets/images/titleEnter.png";
		}
		//trace(path, FileSystem.exists(path));
		titleText.frames = FlxAtlasFrames.fromSparrow(BitmapData.fromFile(path),File.getContent(StringTools.replace(path,".png",".xml")));
		#else

		titleText.frames = Paths.getSparrowAtlas('titleEnter');
		#end
		titleText.animation.addByPrefix('idle', "Press Enter to Begin", 24);
		titleText.animation.addByPrefix('press', "ENTER PRESSED", 24);
		titleText.antialiasing = ClientPrefs.globalAntialiasing;
		titleText.animation.play('idle');
		titleText.updateHitbox();
		// titleText.screenCenter(X);
		add(titleText);

		var logo:FlxSprite = new FlxSprite().loadGraphic(Paths.image('logo'));
		logo.screenCenter();
		logo.antialiasing = ClientPrefs.globalAntialiasing;
		// add(logo);

		// FlxTween.tween(logoBl, {y: logoBl.y + 50}, 0.6, {ease: FlxEase.quadInOut, type: PINGPONG});
		// FlxTween.tween(logo, {y: logoBl.y + 50}, 0.6, {ease: FlxEase.quadInOut, type: PINGPONG, startDelay: 0.1});

		credGroup = new FlxGroup();
		add(credGroup);
		textGroup = new FlxGroup();

		blackScreen = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		credGroup.add(blackScreen);

		credTextShit = new Alphabet(0, 0, "", true);
		credTextShit.screenCenter();

		// credTextShit.alignment = CENTER;

		credTextShit.visible = false;

		ngSpr = new FlxSprite(0, FlxG.height * 0.52).loadGraphic(Paths.image('newgrounds_logo'));
		add(ngSpr);
		ngSpr.visible = false;
		ngSpr.setGraphicSize(Std.int(ngSpr.width * 0.8));
		ngSpr.updateHitbox();
		ngSpr.screenCenter(X);
		ngSpr.antialiasing = ClientPrefs.globalAntialiasing;

		FlxTween.tween(credTextShit, {y: credTextShit.y + 20}, 2.9, {ease: FlxEase.quadInOut, type: PINGPONG});

		if (initialized)
			skipIntro();
		else
			initialized = true;

		// credGroup.add(credTextShit);
	}

	function getIntroTextShit():Array<Array<String>>
	{
		var fullText:String = Assets.getText(Paths.txt('introText'));

		var firstArray:Array<String> = fullText.split('\n');
		var swagGoodArray:Array<Array<String>> = [];

		for (i in firstArray)
		{
			swagGoodArray.push(i.split('--'));
		}

		return swagGoodArray;
	}

	var transitioning:Bool = false;
	private static var playJingle:Bool = false;

	override function update(elapsed:Float)
	{
		if (FlxG.sound.music != null)
			Conductor.songPosition = FlxG.sound.music.time;
		// FlxG.watch.addQuick('amp', FlxG.sound.music.amplitude);

		var controls = controls;
		var pressedEnter:Bool = FlxG.keys.justPressed.ENTER || (controls != null && controls.ACCEPT);

		#if mobile
		for (touch in FlxG.touches.list)
		{
			if (touch.justPressed)
			{
				pressedEnter = true;
			}
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

		if (initialized && !transitioning && skippedIntro)
		{
			if(pressedEnter)
			{
				exitState();
			}
		}

		if (initialized && pressedEnter && !skippedIntro)
		{
			skipIntro();
		}

		if(swagShader != null)
		{
			if(controls.UI_LEFT) swagShader.hue -= elapsed * 0.1;
			if(controls.UI_RIGHT) swagShader.hue += elapsed * 0.1;
		}

		super.update(elapsed);
	}

	function exitState(){
		if (closedState) return;

		if(titleText != null) titleText.animation.play('press');

		FlxG.camera.flash(FlxColor.WHITE, 1);
		FlxG.sound.play(Paths.sound('confirmMenu'), 0.7);

		transitioning = true;

		new FlxTimer().start(1, function(tmr:FlxTimer)
		{
			if (mustUpdate) {
				MusicBeatState.switchState(new OutdatedState());
			} else {
				MusicBeatState.switchState(new MainMenuState());
			}
			closedState = true;
		});
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

		if(logoBl != null)
			logoBl.animation.play('bump', true);

		/*
		if(gfDance != null) {
			danceLeft = !danceLeft;
			if (danceLeft)
				gfDance.animation.play('danceRight');
			else
				gfDance.animation.play('danceLeft');
		}
		*/

		if(!closedState) {
			sickBeats++;
			switch (sickBeats)
			{
				case 1:
					FlxG.sound.music.stop();
					FlxG.sound.playMusic(Paths.music('freakyIntro'), 0, false);
					FlxG.sound.music.fadeIn(4, 0, 0.7);
					FlxG.sound.music.onComplete = function name() {
						FlxG.sound.playMusic(Paths.music('freakyMenu'), 1, true);
						exitState();
					}		
				case 2:
					createCoolText(['', '', '', '']);
				case 4:
					addMoreText('present');
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
			FlxG.camera.flash(FlxColor.WHITE, 4);
			
			skippedIntro = true;

			Conductor.changeBPM(180);
		}
	}
}

// copied from v3 because im a lazy ass
class TitleStage extends FlxTypedGroup<FlxBasic> {
	public static var stageNames:Array<String> = [
		"hillzoneTails",
		"hillzoneTailsSwag",
		"hillzoneSonic",
		"hillzoneShadow",
		"highzoneShadow",
		"hillzoneDarkSonic",
	];

	public var foreground:FlxTypedGroup<FlxBasic> = new FlxTypedGroup<FlxBasic>();

	public var defaultCamZoom:Float = 1;
	public var curStage:String = '';

	public function new(){
		super();
		curStage = stageNames[FlxG.random.int(0, stageNames.length)];

		switch (curStage)
		{
			case 'hillzoneTails':
				defaultCamZoom = 1;
				var bg:FlxSprite = new FlxSprite(-600, -200).loadGraphic(Paths.image('titlebg/chapter1/sky'));
				bg.antialiasing = true;
				bg.scrollFactor.set(0.4, 0.4);
				bg.active = false;
				add(bg);

				var stageFront:FlxSprite = new FlxSprite(-650, 600).loadGraphic(Paths.image('titlebg/chapter1/grass'));
				stageFront.setGraphicSize(Std.int(stageFront.width * 1.1));
				stageFront.updateHitbox();
				stageFront.antialiasing = true;
				stageFront.scrollFactor.set(0.9, 0.9);
				stageFront.active = false;
				add(stageFront);

				var stageCurtains:FlxSprite = new FlxSprite(-450, -150).loadGraphic(Paths.image('titlebg/chapter1/foreground'));
				stageCurtains.setGraphicSize(Std.int(stageCurtains.width * 0.87));
				stageCurtains.updateHitbox();
				stageCurtains.antialiasing = true;
				stageCurtains.scrollFactor.set(1.3, 1.3);
				stageCurtains.active = false;

				foreground.add(stageCurtains);
			case 'hillzoneTailsSwag':
				defaultCamZoom = 1;
				var bg:FlxSprite = new FlxSprite(-600, -200).loadGraphic(Paths.image('titlebg/chapter1/skySwag'));
				bg.antialiasing = true;
				bg.scrollFactor.set(0.4, 0.4);
				bg.active = false;
				add(bg);

				var stageFront:FlxSprite = new FlxSprite(-650, 600).loadGraphic(Paths.image('titlebg/chapter1/grassSwag'));
				stageFront.setGraphicSize(Std.int(stageFront.width * 1.1));
				stageFront.updateHitbox();
				stageFront.antialiasing = true;
				stageFront.scrollFactor.set(0.9, 0.9);
				stageFront.active = false;
				add(stageFront);

				var stageCurtains:FlxSprite = new FlxSprite(-450, -150).loadGraphic(Paths.image('titlebg/chapter1/foregroundSwag'));
				stageCurtains.setGraphicSize(Std.int(stageCurtains.width * 0.87));
				stageCurtains.updateHitbox();
				stageCurtains.antialiasing = true;
				stageCurtains.scrollFactor.set(1.3, 1.3);
				stageCurtains.active = false;

				foreground.add(stageCurtains);
			case 'hillzoneSonic':
				defaultCamZoom = 1;
				var bg:FlxSprite = new FlxSprite(-600, -200).loadGraphic(Paths.image('titlebg/chapter2/sky'));
				bg.antialiasing = true;
				bg.scrollFactor.set(0.4, 0.4);
				bg.active = false;
				add(bg);

				var stageFront:FlxSprite = new FlxSprite(-650, 600).loadGraphic(Paths.image('titlebg/chapter2/grass'));
				stageFront.setGraphicSize(Std.int(stageFront.width * 1.1));
				stageFront.updateHitbox();
				stageFront.antialiasing = true;
				stageFront.scrollFactor.set(0.9, 0.9);
				stageFront.active = false;
				add(stageFront);

				var stageCurtains:FlxSprite = new FlxSprite(-450, -150).loadGraphic(Paths.image('titlebg/chapter2/foreground'));
				stageCurtains.setGraphicSize(Std.int(stageCurtains.width * 0.87));
				stageCurtains.updateHitbox();
				stageCurtains.antialiasing = true;
				stageCurtains.scrollFactor.set(1.3, 1.3);
				stageCurtains.active = false;

				foreground.add(stageCurtains);
			case 'hillzoneShadow':
				defaultCamZoom = .9;
				var bg:FlxSprite = new FlxSprite(-835, -550).loadGraphic(Paths.image('titlebg/chapter3/shadowbg'));
				bg.antialiasing = true;
				bg.scrollFactor.set(1.05, 1.05);
				bg.active = false;
				add(bg);

				var thisthing:FlxSprite = new FlxSprite(-880, -730).loadGraphic(Paths.image('titlebg/chapter3/shadowbg3'));
				thisthing.antialiasing = true;
				thisthing.scrollFactor.set(1.025, 1.025);
				thisthing.active = false;
				add(thisthing);

				var thisotherthing:FlxSprite = new FlxSprite(-815, -375).loadGraphic(Paths.image('titlebg/chapter3/shadowbg2'));
				thisotherthing.antialiasing = true;
				thisotherthing.scrollFactor.set(1.025, 1.025);
				thisotherthing.active = false;
				add(thisotherthing);

				var grass:FlxSprite = new FlxSprite(-815, 450).loadGraphic(Paths.image('titlebg/chapter3/shadowbg4'));
				grass.antialiasing = true;
				grass.active = false;
				add(grass);
			case 'highzoneShadow':
				defaultCamZoom = .9;
				var bg:FlxSprite = new FlxSprite(-350, -200).loadGraphic(Paths.image('titlebg/chapter3/stageback_HS'));
				bg.antialiasing = true;
				bg.scrollFactor.set(0.4, 0.4);
				bg.active = false;
				add(bg);

				var stageFront:FlxSprite = new FlxSprite(-725, 600).loadGraphic(Paths.image('titlebg/chapter3/stagefront_HS'));
				stageFront.setGraphicSize(Std.int(stageFront.width * 1.1));
				stageFront.updateHitbox();
				stageFront.antialiasing = true;
				stageFront.scrollFactor.set(1, 1);
				stageFront.active = false;
				add(stageFront);
			case 'hillzoneDarkSonic':
				defaultCamZoom = 1;
				
				var sky:FlxSprite = new FlxSprite().loadGraphic(Paths.image("titlebg/chapter3/tfbbg3"));
				sky.antialiasing=true;
				sky.scrollFactor.set(.3,.3);
				sky.x = -458;
				sky.y = -247;
				add(sky);

				var bg:FlxSprite = new FlxSprite().loadGraphic(Paths.image("titlebg/chapter3/tfbbg2"));
				bg.antialiasing=true;
				bg.scrollFactor.set(.7,.7);
				bg.x = -480.5;
				bg.y = 410;
				add(bg);

				var fg:FlxSprite = new FlxSprite().loadGraphic(Paths.image("titlebg/chapter3/tfbbg"));
				fg.antialiasing=true;
				fg.scrollFactor.set(1, 1);
				fg.x = -541;
				fg.y = -96.5;
				add(fg);
			case 'blank':

		}
	}
}
