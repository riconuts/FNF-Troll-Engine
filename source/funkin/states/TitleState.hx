package funkin.states;

import openfl.filters.BlurFilter;
import flixel.addons.transition.FlxTransitionableState;
import flixel.group.FlxGroup;
import flixel.input.gamepad.FlxGamepad;
import flixel.math.*;
import flixel.tweens.*;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import funkin.objects.shaders.ColorSwap;

using StringTools;
#if discord_rpc
import funkin.api.Discord.DiscordClient;
#end
#if sys
import sys.FileSystem;
import sys.io.File;
#end
// used so stages wont break
class FakeCharacter
{
	public function playAnim(AnimName:String, Force:Bool = false, Reversed:Bool = false, Frame:Int = 0):Void{}

	public function new(){}
}

class TitleState extends MusicBeatState
{
	// for stage scripts
	public var gf:FakeCharacter = new FakeCharacter();
	public var dad:FakeCharacter = new FakeCharacter();
	public var boyfriend:FakeCharacter = new FakeCharacter();
	public var inCutscene:Bool = false;

	public static var initialized:Bool = false;

	static var curWacky:Array<String> = [];

	static var blackScreen:FlxSprite;
	static var textGroup:FlxGroup;
	static var ngSpr:FlxSprite;
	static var blurFilter:BlurFilter;

	static var logoBl:TitleLogo;
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
	
	static public function getRandomStage()
	{
		// Set up a stage list
		var stages:Array<Array<String>> = []; // [stage name, mod directory]

		Paths.currentModDirectory = "";
		for (stage in Stage.getTitleStages())
			stages.push([stage, ""]);

		#if MODS_ALLOWED
		for (mod in Paths.getModDirectories())
		{
			Paths.currentModDirectory = mod;
			for (stage in Stage.getTitleStages(true))
				stages.push([stage, mod]);
		}
		#end

		return FlxG.random.getObject(stages); // Get a random stage from the list
	}

	static public function load()
	{
		curWacky = FlxG.random.getObject(getIntroTextShit());
		
		var randomStage = getRandomStage();

		if (randomStage != null)
		{
			Paths.currentModDirectory = randomStage[1];
			bg = new Stage(randomStage[0], false);
			
			#if MULTICORE_LOADING
			var shitToLoad = bg.stageData.preload;
			if (shitToLoad != null) funkin.data.Cache.loadWithList(shitToLoad);
			#end

			bg.startScript(false, ["inTitlescreen" => true]);
		}

		// Random logoooo
		swagShader = new ColorSwap();

		logoBl = new TitleLogo();
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
		titleText.screenCenter(X);

		//
		blackScreen = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
		blackScreen.scale.set(FlxG.width, FlxG.height);
		blackScreen.updateHitbox();

		blurFilter = new BlurFilter(32, 32);

		titleText.visible = false;
		logoBl.visible = false;

		textGroup = new FlxGroup();

		//
		ngSpr = new FlxSprite(0, FlxG.height * 0.52, Paths.image('newgrounds_logo'));
		ngSpr.visible = false;
		ngSpr.scale.set(0.8, 0.8);
		ngSpr.updateHitbox();
		ngSpr.screenCenter(X);

		MusicBeatState.playMenuMusic(0);

		loaded = true;
	}

	override public function destroy()
	{
		curWacky = null;
		swagShader = null;

		blurFilter = null;
		blackScreen = null;
		textGroup = null;
		ngSpr = null;
	
		logoBl = null;
		titleText = null;
		bg = null;

		loaded = false;

		return super.destroy();
	}
	var darkness:FlxSprite;
	override public function create():Void
	{
		if (initialized)
			Paths.clearStoredMemory();

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
	
		////
		camGame.filters = [blurFilter];

		////
		if (bg != null && bg.stageData != null){
			camGame.zoom = bg.stageData.defaultZoom;
			if (bg.stageData.title_zoom != null)
				camGame.zoom = bg.stageData.title_zoom;

			var bgColor:Null<FlxColor> = null;
			if (bg.stageData.bg_color != null)
				bgColor = FlxColor.fromString(bg.stageData.bg_color);

			camGame.bgColor = (bgColor != null) ? bgColor : 0xFF000000;

			var camPos = bg.stageData.camera_stage;
			if (camPos == null) camPos = [640, 360];

			camFollow.set(camPos[0], camPos[1]);
			camFollowPos.setPosition(camPos[0], camPos[1]);

			add(bg);
		}else{
			camGame.bgColor = 0xFF000000;
		}

		var scale = 1920 / camGame.zoom;
		darkness = new FlxSprite(0, 0).makeGraphic(1, 1, FlxColor.BLACK);
		darkness.scale.set(scale, scale);
		darkness.updateHitbox();
		darkness.scrollFactor.set(0, 0);
		darkness.screenCenter(XY);
		darkness.alpha = 0.4;
		darkness.cameras = [camGame];
		add(darkness);

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
		if (initialized){
			Paths.clearUnusedMemory();
			skipIntro();
        }else{
			initialized = true;
			MusicBeatState.playMenuMusic(0, true);
		}
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
		if (bg != null && bg.stageScript != null){
			bg.stageScript.set("curDecBeat", curDecBeat);
			bg.stageScript.set("curDecStep", curDecStep);
			bg.stageScript.call('update', [elapsed]);
        }
		if (FlxG.sound.music != null)
			Conductor.songPosition = FlxG.sound.music.time;

		var lerpVal:Float = Math.exp(-elapsed * 2.4);
		camFollowPos.setPosition(
			FlxMath.lerp(camFollow.x,  camFollowPos.x, lerpVal), 
			FlxMath.lerp(camFollow.y,  camFollowPos.y, lerpVal)
		);
		
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

		titleTimer = (titleTimer + elapsed) % 2;

		if (initialized && !transitioning && skippedIntro)
		{
			if(!pressedEnter){
				var timer:Float = titleTimer;
				if (timer >= 1)
					timer = 2 - timer;

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

                remove(darkness);
				camHUD.flash(ClientPrefs.flashing ? FlxColor.WHITE : 0x4CFFFFFF, 1, null, true);
				FlxG.sound.play(Paths.sound('confirmMenu'), 0.7 );

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
		if (skippedIntro)
			if (bg != null && bg.stageScript != null)
			{
				bg.stageScript.set("curBeat", curBeat);
				bg.stageScript.call('onBeatHit', []);
			}
		if (logoBl != null)
			logoBl.time = 0;

		if(!closedState) {
			sickBeats++;
            // this could prob be replaced with a json, yaml or even a whole "TitleSequence" script?? :shrug:
			switch (sickBeats #if tgt * 0.5 #end)
			{
				case 1:
					// MusicBeatState.stopMenuMusic();
					MusicBeatState.playMenuMusic(0, true);

					FlxTween.tween(blackScreen, {alpha: 0.86}, Conductor.crochet * 0.005, {
						ease: FlxEase.quadInOut,
						songBased: true,
					});

				case 2:
					MusicBeatState.playMenuMusic(1, true);

				#if tgt
					createCoolText(['THE FNF TGT TEAM']);
				case 4: addMoreText('presents');
				#else
					//createCoolText(['THE TROLL ENGINE TEAM']); // huge if true

					// should probably do proper code for spacing out the text
					addMoreText('RICONUTS', 0);
					addMoreText('NEBULA_ZORUA', 8);
					addMoreText('AND MORE', 16);
				
				case 4: addMoreText('presents', 75);
				#end
				
				case 5: deleteCoolText();

				////

				case 6: createCoolText(['Without any', 'association to'], -40);
				case 8:
					#if tgt	addMoreText('tailsgetstrolled dot org', -40);
					#else	addMoreText('Newgrounds', -40);
					#end
					ngSpr.visible = true;
				case 9:
					deleteCoolText();
					ngSpr.visible = false;

				////
				
				case 10: createCoolText([curWacky[0]]);
				case 12: addMoreText(curWacky[1]);
				case 13: deleteCoolText();

				////

				#if tgt
				case 14: addMoreText('Tails');
				case 15: addMoreText('Gets');
				case 16: addMoreText('Trolled');
				#else
				case 14: addMoreText('Friday');
				case 15: addMoreText('Night');
				case 16: addMoreText("Funkin");
				#end

				////

				case 17:
					skipIntro();
			}
		}
	}
	var section:Int = -100;
	override function stepHit()
	{
		super.stepHit();

        if (bg != null && bg.stageScript != null)
        {
            if (skippedIntro){
                bg.stageScript.set("curStep", curStep);
                bg.stageScript.call('onStepHit', []);
            }
            var nuSection:Int = Math.floor(curBeat / 4);
            if (section != nuSection)
            {
                section = nuSection;
                if (skippedIntro){
                    bg.stageScript.set("curSection", section);
                    bg.stageScript.call('onSectionHit', []);
                }
            }
        }
	}


	var skippedIntro:Bool = false;
	var increaseVolume:Bool = false;
	function skipIntro():Void
	{
		if (!skippedIntro)
		{
			camGame.filters.remove(blurFilter);

            titleText.visible = true;
			logoBl.visible = true;
			remove(ngSpr);
			remove(blackScreen);
			remove(textGroup);

			camHUD.flash(FlxColor.WHITE, 4);
			
			skippedIntro = true;
		}
	}
}

class TitleLogo extends FlxSprite
{
	public var titleName:String;

	public function new(?X:Float, ?Y:Float, ?Name:String)
	{
		var titleGraphic = Paths.image('logo');

		if (titleGraphic == null || Name != null){
			titleGraphic = Paths.image('titles/${Name != null ? Name : FlxG.random.getObject(getTitlesList())}');
		}

		super(X, Y, titleGraphic);
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
		var foldersToCheck:Array<String> = Paths.getFolders('images/titles');
		
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