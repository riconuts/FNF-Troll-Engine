package;

import flixel.group.FlxGroup;
#if ACHIEVEMENTS_ALLOWED
import Achievements;
#end
import Cache;
import Conductor.Rating;
import Note.EventNote;
import Section.SwagSection;
import Shaders;
import Song.SwagSong;
import Stage;
import WiggleEffect.WiggleEffectType;
import animateatlas.AtlasFrameMaker;
import editors.*;
import flixel.*;
import flixel.addons.display.*;
import flixel.addons.effects.*;
import flixel.addons.effects.chainable.*;
import flixel.addons.transition.FlxTransitionableState;
import flixel.effects.particles.*;
import flixel.graphics.FlxGraphic;
import flixel.graphics.atlas.FlxAtlas;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.group.FlxSpriteGroup;
import flixel.input.keyboard.FlxKey;
import flixel.math.*;
import flixel.system.FlxAssets.FlxShader;
import flixel.system.FlxSound;
import flixel.system.scaleModes.*;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.ui.FlxBar;
import flixel.util.*;
import haxe.Json;
import lime.utils.Assets;
import modchart.*;
import openfl.Lib;
import openfl.display.BlendMode;
import openfl.display.StageQuality;
import openfl.events.KeyboardEvent;
import openfl.filters.BitmapFilter;
import openfl.filters.ShaderFilter;
import openfl.system.Capabilities;
import openfl.utils.Assets as OpenFlAssets;
import scripts.*;
import scripts.FunkinLua;

using StringTools;
#if desktop
import Discord.DiscordClient;
#end
#if VIDEOS_ALLOWED
import vlc.MP4Handler;
#end

typedef LineData = {
	var character:String;
	var anim:String;
};

class PlayState extends MusicBeatState
{
	// andromeda modcharts :D
	public var modManager:ModManager;

	public var whosTurn:String = '';
	public var focusedChar:Character;
	
	public static var STRUM_X = 42;
	public static var STRUM_X_MIDDLESCROLL = -278;
	public static var arrowSkin:String = '';
	public static var splashSkin:String = '';
	public static var ratingStuff:Array<Array<Dynamic>> = [
		['You Suck!', 0.2], //From 0% to 19%
		['Shit', 0.4], //From 20% to 39%
		['Bad', 0.5], //From 40% to 49%
		['Bruh', 0.6], //From 50% to 59%
		['Meh', 0.69], //From 60% to 68%
		['Nice', 0.7], //69%
		['Good', 0.8], //From 70% to 79%
		['Great', 0.9], //From 80% to 89%
		['Sick!', 1], //From 90% to 99%
		['Perfect!!', 1] //The value on this one isn't used actually, since Perfect is always "1"
	];
	public var modchartTweens:Map<String, FlxTween> = new Map<String, FlxTween>();
	public var modchartSprites:Map<String, ModchartSprite> = new Map<String, ModchartSprite>();
	public var modchartTimers:Map<String, FlxTimer> = new Map<String, FlxTimer>();
	public var modchartSounds:Map<String, FlxSound> = new Map<String, FlxSound>();
	public var modchartTexts:Map<String, ModchartText> = new Map<String, ModchartText>();
	public var modchartSaves:Map<String, FlxSave> = new Map<String, FlxSave>();
	public var modchartObjects:Map<String, FlxSprite> = new Map<String, FlxSprite>();

	public var boyfriendMap:Map<String, Boyfriend> = new Map();
	public var extraMap:Map<String, Character> = new Map();
	public var dadMap:Map<String, Character> = new Map();
	public var gfMap:Map<String, Character> = new Map();
	public var variables:Map<String, Dynamic> = new Map();

	public var BF_X:Float = 770;
	public var BF_Y:Float = 100;
	public var DAD_X:Float = 100;
	public var DAD_Y:Float = 100;
	public var GF_X:Float = 400;
	public var GF_Y:Float = 130;

	public var boyfriendGroup:FlxSpriteGroup;
	public var dadGroup:FlxSpriteGroup;
	public var gfGroup:FlxSpriteGroup;

	public var songSpeedTween:FlxTween;
	public var songSpeed(default, set):Float = 1;
	public var songSpeedType:String = "multiplicative";
	public var noteKillOffset:Float = 350;
	
	public static var curStage:String = '';
	public static var SONG:SwagSong = null;
	public static var isStoryMode:Bool = false;
	public static var storyWeek:Int = 0;
	public static var storyPlaylist:Array<String> = [];

	public var spawnTime:Float = 2000;

	public var tracks:Array<FlxSound> = [];
	public var vocals:FlxSound;

	public var dad:Character = null;
	public var gf:Character = null;
	public var boyfriend:Boyfriend = null;

	public var gfSpeed:Int = 1;

	public var notes = new FlxTypedGroup<Note>();
	public var unspawnNotes:Array<Note> = [];
	public var eventNotes:Array<EventNote> = [];

	public var strumLineNotes:FlxTypedGroup<StrumNote>;
	public var opponentStrums:FlxTypedGroup<StrumNote>;
	public var playerStrums:FlxTypedGroup<StrumNote>;
	public var grpNoteSplashes:FlxTypedGroup<NoteSplash>;

	// does this even make a difference
	public var ratingTxtGroup = new FlxTypedGroup<RatingSprite>();
	public var comboNumGroup = new FlxTypedGroup<RatingSprite>();

	private var curSong:String = "";

	public var iconOffset:Int = 26;
	public var displayedHealth(default, set):Float = 1;
	function set_displayedHealth(value:Float){
		if (!ClientPrefs.hideHud){
			healthBar.value = value;
		}
		displayedHealth = value;

		return value;
	}
	public var health(default, set):Float = 1;
	function set_health(value:Float){
		health = value > 2 ? 2 : value;

		displayedHealth = health;
		
		doDeathCheck(value < health);

		return health;
	}
		
	public var combo:Int = 0;

	public var ratingsData:Array<Rating> = [];
	// public var epics:Int = 0;
	public var sicks:Int = 0;
	public var goods:Int = 0;
	public var bads:Int = 0;
	public var shits:Int = 0;

	private var generatedMusic:Bool = false;
	public var endingSong:Bool = false;
	public var startingSong:Bool = false;
	private var updateTime:Bool = true;
	public static var chartingMode:Bool = false;

	//Gameplay settings
	public var healthGain:Float = 1;
	public var healthLoss:Float = 1;

	public var opponentHPDrain:Float = 0.0;
	public var healthDrain:Float = 0.0;

	public var instakillOnMiss:Bool = false;
	public var cpuControlled(default, set) = false;
	function set_cpuControlled(value){
		cpuControlled = value;

		setOnScripts('botPlay', value);
		
		return value;
	}
	public var disableModcharts:Bool = false;
	public var practiceMode:Bool = false;

	public var botplaySine:Float = 0;
	public var botplayTxt:FlxText;

	public var iconP1:HealthIcon;
	public var iconP2:HealthIcon;

	public var healthBar:FNFHealthBar;
	var songPercent:Float = 0;

	private var timeBarBG:AttachedSprite;
	public var timeBar:FlxBar;
	
	public var camGame:FlxCamera;
	public var camHUD:FlxCamera;
	public var camOverlay:FlxCamera; // shit that should go above all else and not get affected by camHUD changes, but still below camOther (pause menu, etc)
	public var camOther:FlxCamera;

	public var camFollow:FlxPoint;
	public var camFollowPos:FlxObject;
	private static var prevCamFollow:Null<FlxPoint> = null;
	private static var prevCamFollowPos:Null<FlxObject> = null;

	public var camZooming:Bool = false;
	public var camZoomingMult:Float = 1;
	public var camZoomingDecay:Float = 1;
	
	public var cameraSpeed:Float = 1;
	public var defaultCamZoom:Float = 1;

	public var sectionCamera = new FlxPoint(); // default camera
	public var customCamera = new FlxPoint(); // custom camera
	public var cameraPoints:Array<FlxPoint>;

	public function addCameraPoint(point:FlxPoint){
		cameraPoints.remove(point);
		cameraPoints.push(point);
	}

	public var stage:Stage;
	var stageData:StageFile;

	public var scoreTxt:FlxText;
	public var timeTxt:FlxText;

	var scoreTxtTween:FlxTween;

	public var songName:String = "";

	public var songScore:Int = 0;
	public var songHits:Int = 0;
	public var songMisses:Int = 0;

	public var songHighscore:Int = 0;

	public static var campaignScore:Int = 0;
	public static var campaignMisses:Int = 0;
	public static var seenCutscene:Bool = false;
	public static var deathCounter:Int = 0;
	
	private var singAnimations:Array<String> = ['singLEFT', 'singDOWN', 'singUP', 'singRIGHT'];

	public var inCutscene:Bool = false;
	public var skipCountdown:Bool = false;
	var songLength:Float = 0;

	public var boyfriendCameraOffset:Array<Float> = null;
	public var opponentCameraOffset:Array<Float> = null;
	public var girlfriendCameraOffset:Array<Float> = null;

	#if desktop
	// Discord RPC variables
	var detailsText:String = "";
	var detailsPausedText:String = "";
	#end

	//Achievement shit
	var keysPressed:Array<Bool> = [];
	var boyfriendIdleTime:Float = 0.0;
	var boyfriendIdled:Bool = false;

	// Script shit
	public static var instance:PlayState;
	public var funkyScripts:Array<FunkinScript> = [];
	public var hscriptArray:Array<FunkinHScript> = [];
	#if LUA_ALLOWED
	public var luaArray:Array<FunkinLua> = [];
	#end

	public var notetypeScripts:Map<String, FunkinScript> = []; // custom notetypes for scriptVer '1'
	public var eventScripts:Map<String, FunkinScript> = []; // custom events for scriptVer '1'
	
	private var luaDebugGroup:FlxTypedGroup<DebugLuaText>;
	public var introSoundsSuffix:String = '';

	// Debug buttons
	private var debugKeysChart:Array<FlxKey>;
	private var debugKeysCharacter:Array<FlxKey>;

	// Less laggy controls
	private var keysArray:Array<Dynamic>;
	private var controlArray:Array<String>;
	
	function setStageData(stageData:StageFile)
	{
		defaultCamZoom = stageData.defaultZoom;
		FlxG.camera.zoom = defaultCamZoom;

		var color = FlxColor.fromString(stageData.bg_color);
		camGame.bgColor = color != null ? color : FlxColor.BLACK;

		BF_X = stageData.boyfriend[0];
		BF_Y = stageData.boyfriend[1];
		GF_X = stageData.girlfriend[0];
		GF_Y = stageData.girlfriend[1];
		DAD_X = stageData.opponent[0];
		DAD_Y = stageData.opponent[1];

		if(stageData.camera_speed != null)
			cameraSpeed = stageData.camera_speed;

		boyfriendCameraOffset = stageData.camera_boyfriend;
		if(boyfriendCameraOffset == null) //Fucks sake should have done it since the start :rolling_eyes:
			boyfriendCameraOffset = [0, 0];

		opponentCameraOffset = stageData.camera_opponent;
		if(opponentCameraOffset == null)
			opponentCameraOffset = [0, 0];

		girlfriendCameraOffset = stageData.camera_girlfriend;
		if(girlfriendCameraOffset == null)
			girlfriendCameraOffset = [0, 0];

		if(boyfriendGroup==null)
			boyfriendGroup = new FlxSpriteGroup(BF_X, BF_Y);
		else{
			boyfriendGroup.x = BF_X;
			boyfriendGroup.y = BF_Y;
		}
		if(dadGroup==null)
			dadGroup = new FlxSpriteGroup(DAD_X, DAD_Y);
		else{
			dadGroup.x = DAD_X;
			dadGroup.y = DAD_Y;
		}

		if(gfGroup==null)
			gfGroup = new FlxSpriteGroup(GF_X, GF_Y);
		else{
			gfGroup.x = GF_X;
			gfGroup.y = GF_Y;
		}
	}

	var finishedCreating =false;
	override public function create()
	{
		Note.quantShitCache.clear();
		FunkinHScript.defaultVars.clear();
		Paths.clearStoredMemory();

		// for lua
		instance = this;

		if (FlxG.sound.music != null)
			FlxG.sound.music.stop();

		if(MusicBeatState.menuVox!=null){
			MusicBeatState.menuVox.stop();
			MusicBeatState.menuVox.destroy();
			MusicBeatState.menuVox = null;
		}

		debugKeysChart = ClientPrefs.copyKey(ClientPrefs.keyBinds.get('debug_1'));
		debugKeysCharacter = ClientPrefs.copyKey(ClientPrefs.keyBinds.get('debug_2'));

		keysArray = [
			ClientPrefs.copyKey(ClientPrefs.keyBinds.get('note_left')),
			ClientPrefs.copyKey(ClientPrefs.keyBinds.get('note_down')),
			ClientPrefs.copyKey(ClientPrefs.keyBinds.get('note_up')),
			ClientPrefs.copyKey(ClientPrefs.keyBinds.get('note_right'))
		];

		controlArray = [
			'NOTE_LEFT',
			'NOTE_DOWN',
			'NOTE_UP',
			'NOTE_RIGHT'
		];

		// For the "Just the Two of Us" achievement
		for (i in 0...keysArray.length)
			keysPressed.push(false);

		//// Ratings

		/* sorry hooda
		var rating:Rating = new Rating('epic');
		rating.ratingMod = 1;
		rating.score = 500;
		rating.noteSplash = true;
		ratingsData.push(rating);
		*/

		var rating:Rating = new Rating('sick');
		/*
		rating.ratingMod = 0.9825;
		rating.score = 350;
		rating.noteSplash = true;
		*/
		ratingsData.push(rating);

		var rating:Rating = new Rating('good');
		rating.ratingMod = 0.7;
		rating.score = 200;
		rating.noteSplash = false;
		ratingsData.push(rating);

		var rating:Rating = new Rating('bad');
		rating.ratingMod = 0.4;
		rating.score = 100;
		rating.noteSplash = false;
		ratingsData.push(rating);

		var rating:Rating = new Rating('shit');
		rating.ratingMod = 0;
		rating.score = 50;
		rating.noteSplash = false;
		ratingsData.push(rating);

		// Gameplay settings
		healthGain = ClientPrefs.getGameplaySetting('healthgain', 1);
		healthLoss = ClientPrefs.getGameplaySetting('healthloss', 1);
		instakillOnMiss = ClientPrefs.getGameplaySetting('instakill', false);
		practiceMode = ClientPrefs.getGameplaySetting('practice', false);
		cpuControlled = ClientPrefs.getGameplaySetting('botplay', false);
		disableModcharts = ClientPrefs.getGameplaySetting('disableModcharts', false);

		healthDrain = switch(ClientPrefs.getGameplaySetting('healthDrain', "Disabled")){
			default: 0;
			case "Basic": 0.00055;
			case "Average": 0.0007;
			case "Heavy": 0.00085;
		};
		opponentHPDrain = ClientPrefs.getGameplaySetting('opponentFightsBack', false) ? 0.0182 : 0;
		
		// Camera shit
		camGame = new FlxCamera();
		camHUD = new FlxCamera();
		if (ClientPrefs.midScroll){ // fucking modchart system
			if (ClientPrefs.downScroll){
				camHUD.y += 6;
				camHUD.y -= (camHUD.height - 112) * 0.5;
				camHUD.height += Math.ceil(-camHUD.y);
			}else{
				camHUD.y -= 50;
				camHUD.y += (camHUD.height - 112) * 0.5;
			}
		}

		camOverlay = new FlxCamera();
		camOther = new FlxCamera();
		camOverlay.bgColor.alpha = 0;
		camHUD.bgColor.alpha = 0;
		camOther.bgColor.alpha = 0;

		FlxG.cameras.reset(camGame);
		FlxG.cameras.add(camHUD, false);
		FlxG.cameras.add(camOverlay, false);
		FlxG.cameras.add(camOther, false);

		FlxG.cameras.setDefaultDrawTarget(camGame, true);
		CustomFadeTransition.nextCamera = camOther;

		camFollow = prevCamFollow != null ? prevCamFollow : new FlxPoint(); 
		camFollowPos = prevCamFollowPos != null ? prevCamFollowPos : new FlxObject(0, 0, 1, 1);
		add(camFollowPos);

		FlxG.camera.follow(camFollowPos, LOCKON, 1);
		FlxG.camera.zoom = defaultCamZoom;
		FlxG.camera.focusOn(camFollow);

		////
		FlxG.fixedTimestep = false;
		FlxG.worldBounds.set(0, 0, FlxG.width, FlxG.height);

		persistentUpdate = true;
		persistentDraw = true;

		////
		if (SONG == null)
			SONG = Song.loadFromJson('tutorial', 'tutorial');

		Conductor.mapBPMChanges(SONG);
		Conductor.changeBPM(SONG.bpm);

		songName = Paths.formatToSongPath(SONG.song);
		songHighscore = Highscore.getScore(SONG.song);

		arrowSkin = SONG.arrowSkin;
		splashSkin = SONG.splashSkin;

		if (arrowSkin == null || arrowSkin.trim().length == 0)
			arrowSkin = "NOTE_assets";

		if (splashSkin == null || splashSkin.trim().length == 0)
			splashSkin = "noteSplashes";

		// The quant prefix gets handled in the Note class

		#if desktop
		// Discord RPC texts
		detailsText = isStoryMode ? "Story Mode" : "Freeplay";
		detailsPausedText = "Paused - " + detailsText;
		#end

		// Reset to default
		PauseSubState.songName = null; 
		GameOverSubstate.resetVariables();
		
		// STAGE SHIT
		if (SONG.stage == null || SONG.stage.length < 1)
			SONG.stage = 'stage';
		curStage = SONG.stage;

		stage = new Stage(curStage);
		stageData = stage.stageData;
		setStageData(stageData);

		//// Asset loading start
		var shitToLoad:Array<AssetPreload> = [
			{path: "sick"},
			{path: "good"},
			{path: "bad"},
			{path: "shit"},
			{path: "healthBar"}
			//,{path: "combo"}
		];

		for (number in 0...10)
			shitToLoad.push({path: 'num$number'});
		
		if (ClientPrefs.hitsoundVolume > 0)
			shitToLoad.push({path: 'hitsound', type: 'SOUND'});

		// PRECACHING MISS SOUNDS BECAUSE I THINK THEY CAN LAG PEOPLE AND FUCK THEM UP IDK HOW HAXE WORKS
		shitToLoad.push({path: 'missnote1', type: 'SOUND'});
		shitToLoad.push({path: 'missnote2', type: 'SOUND'});
		shitToLoad.push({path: 'missnote3', type: 'SOUND'});

		if (PauseSubState.songName != null)
			shitToLoad.push({path: PauseSubState.songName, type: 'MUSIC'});
		else if (ClientPrefs.pauseMusic != 'None')
			shitToLoad.push({path: Paths.formatToSongPath(ClientPrefs.pauseMusic), type: 'MUSIC'});

		if (ClientPrefs.timeBarType != 'Disabled')
			shitToLoad.push({path: "timeBar"});

		////
		if (ClientPrefs.noteSkin == 'Quants'){
			shitToLoad.push({path: 'QUANT$arrowSkin'});
			shitToLoad.push({path: 'QUANT$arrowSkin'});
		}else{
			shitToLoad.push({path: arrowSkin});
			shitToLoad.push({path: arrowSkin});
		}
		
		////
		if (stageData.preloadStrings != null)
		{
			var lib = stageData.directory.trim().length > 0 ? stageData.directory : null;
			for (i in stageData.preloadStrings)
				shitToLoad.push({path: i, library: lib});
		}

		if (stageData.preload != null)
		{
			for (i in stageData.preload)
				shitToLoad.push(i);
		}

		var characters:Array<String> = [SONG.player1, SONG.player2];
		if (!stageData.hide_girlfriend)
		{
			characters.push(SONG.gfVersion);
		}

		for (character in characters)
		{
			for (data in Character.returnCharacterPreload(character))
				shitToLoad.push(data);
		}

		for (event in getEvents())
		{
			for (data in preloadEvent(event))
			{ // preloads everythin for events
				if (!shitToLoad.contains(data))
					shitToLoad.push(data);
			}
		}

		shitToLoad.push({
			path: '$songName/Inst',
			type: 'SONG'
		});

		if (SONG.needsVoices)
			shitToLoad.push({
				path: '$songName/Voices',
				type: 'SONG'
			});

		// extra tracks (ex: die batsards bullet track)
		for (track in SONG.extraTracks)
			shitToLoad.push({
				path: '$songName/$track',
				type: 'SONG'
			});

		// moved all of this to its own preload class
		Cache.loadWithList(shitToLoad);
		
		//// Asset loading end

		Conductor.songPosition = -5000;

		updateTime = (ClientPrefs.timeBarType != 'Disabled');

		timeTxt = new FlxText(STRUM_X + (FlxG.width * 0.5) - 248, (ClientPrefs.downScroll ? FlxG.height - 44 : 19) , 400, "", 32);
		timeTxt.setFormat(Paths.font("calibri.ttf"), 32, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		timeTxt.scrollFactor.set();
		timeTxt.alpha = 0;
		timeTxt.borderSize = 2;
		timeTxt.visible = updateTime;
			
		if (ClientPrefs.timeBarType == 'Song Name')
		{
			timeTxt.text = SONG.song;
			timeTxt.size = 24;
			timeTxt.y += 3;
		}

		timeBarBG = new AttachedSprite('timeBar');
		timeBarBG.x = timeTxt.x;
		timeBarBG.y = timeTxt.y + (timeTxt.height * 0.25);
		timeBarBG.scrollFactor.set();
		timeBarBG.alpha = 0;
		timeBarBG.visible = updateTime;
		timeBarBG.color = FlxColor.BLACK;
		timeBarBG.xAdd = -5;
		timeBarBG.yAdd = -5;
		add(timeBarBG);

		timeBar = new FlxBar(timeBarBG.x + 5, timeBarBG.y + 5, LEFT_TO_RIGHT, Std.int(timeBarBG.width - 10), Std.int(timeBarBG.height - 10), this,
			'songPercent', 0, 1);
		timeBar.scrollFactor.set();
		timeBar.createFilledBar(0xFF000000, 0xFFFFFFFF);
		timeBar.numDivisions = 800; //How much lag this causes?? Should i tone it down to idk, 400 or 200?
		timeBar.alpha = 0;
		timeBar.visible = updateTime;

		add(timeBar);
		add(timeTxt);
		timeBarBG.sprTracker = timeBar;

		//
		botplayTxt = new FlxText(400, timeBarBG.y + (ClientPrefs.downScroll ? -78 : 55), FlxG.width - 800, "[BUTTPLUG]", 32);
		botplayTxt.setFormat(Paths.font("calibri.ttf"), 32, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		botplayTxt.scrollFactor.set();
		botplayTxt.borderSize = 1.25;
		botplayTxt.visible = cpuControlled;
		add(botplayTxt);

		//
		strumLineNotes = new FlxTypedGroup<StrumNote>();
		add(strumLineNotes);
		grpNoteSplashes = new FlxTypedGroup<NoteSplash>();
		add(grpNoteSplashes);

		var splash:NoteSplash = new NoteSplash(100, 100, 0);
		grpNoteSplashes.add(splash);
		splash.alpha = 0.0;

		opponentStrums = new FlxTypedGroup<StrumNote>();
		playerStrums = new FlxTypedGroup<StrumNote>();

		#if LUA_ALLOWED
		luaDebugGroup = new FlxTypedGroup<DebugLuaText>();
		luaDebugGroup.cameras = [camOther];
		add(luaDebugGroup);
		#end

		//// Characters
		var gfVersion:String = SONG.gfVersion;
		if(gfVersion == null || gfVersion.length < 1){	
			/* gfVersion = 'gf';
			SONG.gfVersion = gfVersion; //Fix for the Chart Editor */
		}
		else if (stageData.hide_girlfriend != true)
		{
			gf = new Character(0, 0, gfVersion);

			if (stageData.camera_girlfriend != null){
				gf.cameraPosition[0] += stageData.camera_girlfriend[0];
				gf.cameraPosition[1] += stageData.camera_girlfriend[1];
			}

			startCharacterPos(gf);
			gf.scrollFactor.set(0.95, 0.95);

			gfMap.set(gf.curCharacter, gf);
			gfGroup.add(gf);
		}

		dad = new Character(0, 0, SONG.player2);

		if (stageData.camera_opponent != null){
			dad.cameraPosition[0] += stageData.camera_opponent[0];
			dad.cameraPosition[1] += stageData.camera_opponent[1];
		}
		startCharacterPos(dad, true);

		dadMap.set(dad.curCharacter, dad);
		dadGroup.add(dad);

		boyfriend = new Boyfriend(0, 0, SONG.player1);
		if (stageData.camera_boyfriend != null){
			boyfriend.cameraPosition[0] += stageData.camera_boyfriend[0];
			boyfriend.cameraPosition[1] += stageData.camera_boyfriend[1];
		}
		startCharacterPos(boyfriend);

		boyfriendMap.set(boyfriend.curCharacter, boyfriend);
		boyfriendGroup.add(boyfriend);

		if(dad.curCharacter.startsWith('gf')) {
			dad.setPosition(GF_X, GF_Y);
			if(gf != null)
				gf.visible = false;
		}

		// After all characters being loaded, it makes then invisible 0.01s later so that the player won't freeze when you change characters

		cameraPoints = [sectionCamera];
		
		// moveCamera(gf != null ? gf : dad);
		moveCameraSection(SONG.notes[0]);

		////
		healthBar = new FNFHealthBar(boyfriend.healthIcon, dad.healthIcon);
		var healthBarBG = healthBar.healthBarBG;
		iconP1 = healthBar.iconP1;
		iconP2 = healthBar.iconP2;

		add(healthBarBG);
		add(healthBar);
		add(iconP1);
		add(iconP2);

		scoreTxt = new FlxText(0, healthBarBG.y + 48, FlxG.width, "", 20);
		scoreTxt.setFormat(Paths.font("calibri.ttf"), 20, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		scoreTxt.scrollFactor.set();
		scoreTxt.borderSize = 1.25;
		scoreTxt.visible = !ClientPrefs.hideHud;
		add(scoreTxt);

		//
		lastJudge = RatingSprite.newRating();
		ratingTxtGroup.add(lastJudge).kill();
		for (i in 0...3)
			comboNumGroup.add(RatingSprite.newNumber()).kill();
		

		add(ratingTxtGroup);
		add(comboNumGroup);

		// init shit
		health = 1;
		reloadHealthBarColors();

		startingSong = true;

		modManager = new ModManager(this);
		setDefaultHScripts("modManager", modManager);

		var cH = [camHUD];
		strumLineNotes.cameras = cH;
		grpNoteSplashes.cameras = cH;
		notes.cameras = cH;
		healthBarBG.cameras = cH;
		healthBar.cameras = cH;
		iconP1.cameras = cH;
		iconP2.cameras = cH;
		scoreTxt.cameras = cH;
		botplayTxt.cameras = cH;
		timeBar.cameras = cH;
		timeBarBG.cameras = cH;
		timeTxt.cameras = cH;

		//// LOAD SCRIPTS

		// "GLOBAL" SCRIPTS
		var filesPushed:Array<String> = [];
		var foldersToCheck:Array<String> = [Paths.getPreloadPath('scripts/')];

		#if MODS_ALLOWED
		foldersToCheck.insert(0, Paths.mods('scripts/'));
		foldersToCheck.insert(0, Paths.mods('global/scripts/'));
		if(Paths.currentModDirectory != null && Paths.currentModDirectory.length > 0)
			foldersToCheck.insert(0, Paths.mods(Paths.currentModDirectory + '/scripts/'));
		#end

		for (folder in foldersToCheck)
		{
			Paths.iterateDirectory(folder, function(file:String)
			{	
				if(filesPushed.contains(file))
					return;

				#if LUA_ALLOWED
				if(file.endsWith('.lua')) {
					var script = new FunkinLua(folder + file);
					luaArray.push(script);
					funkyScripts.push(script);
					filesPushed.push(file);
				}
				else #end if(file.endsWith('.hscript')) {
					var script = FunkinHScript.fromFile(folder + file);
					hscriptArray.push(script);
					funkyScripts.push(script);
					filesPushed.push(file);
				}				
			});
		}
		
		// STAGE SCRIPTS
		stage.buildStage();
		if (stage.stageScript != null){
			#if LUA_ALLOWED
			if (stage.stageScript.scriptType == "lua")
				luaArray.push(cast stage.stageScript);
			else
			#end
			hscriptArray.push(cast stage.stageScript);

			funkyScripts.push(stage.stageScript);
		}

		// in case you want to layer the characters in a specific way (like in infimario for example)
		// RICO CAN WE STOP USING SLURS IN THE CODE
		if (Globals.Function_Stop != callOnHScripts("onAddSpriteGroups", []))
		{
			add(stage);

			add(gfGroup);
			add(dadGroup);
			add(boyfriendGroup);

			add(stage.foreground);
		}

		if (gf != null) startCharacterScript(gf);
		startCharacterScript(dad);
		startCharacterScript(boyfriend);

		// SONG SPECIFIC SCRIPTS
		var foldersToCheck:Array<String> = [Paths.getPreloadPath('songs/' + songName + '/')];
		var filesPushed:Array<String> = [];

		#if MODS_ALLOWED
		foldersToCheck.insert(0, Paths.mods('songs/' + songName + '/'));
		if(Paths.currentModDirectory != null && Paths.currentModDirectory.length > 0)
			foldersToCheck.insert(0, Paths.mods(Paths.currentModDirectory + '/songs/' + songName + '/'));
		#end
		
		for (folder in foldersToCheck)
		{
			Paths.iterateDirectory(folder, function(file:String)
			{
				if(filesPushed.contains(file))
					return;

				#if LUA_ALLOWED
				if(file.endsWith('.lua'))
				{
					var script = new FunkinLua(folder + file);
					luaArray.push(script);
					funkyScripts.push(script);
					filesPushed.push(file);	
				}
				else #end if(file.endsWith('.hscript'))
				{
					var script = FunkinHScript.fromFile(folder + file);
					hscriptArray.push(script);
					funkyScripts.push(script);
					filesPushed.push(file);
				}
			});
		}

		// EVENT AND NOTE SCRIPTS WILL GET LOADED HERE
		generateSong(SONG.song);

		#if desktop
		// Updating Discord Rich Presence.
		DiscordClient.changePresence(detailsText, SONG.song, songName);
		#end

		if(!ClientPrefs.controllerMode)
		{
			FlxG.stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyPress);
			FlxG.stage.addEventListener(KeyboardEvent.KEY_UP, onKeyRelease);
		}

		Conductor.safeZoneOffset = ClientPrefs.safeFrames / 60 * 1000;

		callOnScripts('onCreatePost');
		super.create();

		RecalculateRating();
		startCountdown();

		finishedCreating = true;

		Paths.clearUnusedMemory();

		noteTypeMap.clear();
		noteTypeMap = null;
		eventPushedMap.clear();
		eventPushedMap = null;

		CustomFadeTransition.nextCamera = camOther;
	}

	function set_songSpeed(value:Float):Float
	{
		if(generatedMusic)
		{
			var ratio:Float = value / songSpeed; //funny word huh
			for (note in notes) note.resizeByRatio(ratio);
			for (note in unspawnNotes) note.resizeByRatio(ratio);
		}
		songSpeed = value;
		noteKillOffset = 350 / songSpeed;
		return value;
	}

	public function addTextToDebug(text:String) {
		#if LUA_ALLOWED
		luaDebugGroup.forEachAlive(function(spr:DebugLuaText) {
			spr.y += 20;
		});

		if(luaDebugGroup.members.length > 34) {
			var blah = luaDebugGroup.members[34];
			blah.destroy();
			luaDebugGroup.remove(blah);
		}
		luaDebugGroup.insert(0, new DebugLuaText(text, luaDebugGroup));
		#end
	}

	public function reloadHealthBarColors() {
		if(callOnHScripts('reloadHealthBarColors', [healthBar]) != Globals.Function_Stop){
			healthBar.createFilledBar(
				FlxColor.fromRGB(dad.healthColorArray[0], dad.healthColorArray[1], dad.healthColorArray[2]),
				FlxColor.fromRGB(boyfriend.healthColorArray[0], boyfriend.healthColorArray[1], boyfriend.healthColorArray[2])
			);
		}

		healthBar.updateBar();
	}

	public function addCharacterToList(newCharacter:String, type:Int) {
		switch(type) {
			case 0:
				if(!boyfriendMap.exists(newCharacter)) {
					var newBoyfriend:Boyfriend = new Boyfriend(0, 0, newCharacter);
					boyfriend.cameraPosition[0] += stageData.camera_boyfriend[0];
					boyfriend.cameraPosition[1] += stageData.camera_boyfriend[1];

					newBoyfriend.alpha = 0.00001;

					boyfriendMap.set(newCharacter, newBoyfriend);
					boyfriendGroup.add(newBoyfriend);

					startCharacterPos(newBoyfriend);
					startCharacterScript(newBoyfriend);
				}

			case 1:
				if(!dadMap.exists(newCharacter)) {
					var newDad:Character = new Character(0, 0, newCharacter);
					dad.cameraPosition[0] += stageData.camera_opponent[0];
					dad.cameraPosition[1] += stageData.camera_opponent[1];

					dadMap.set(newCharacter, newDad);
					dadGroup.add(newDad);
					startCharacterPos(newDad, true);
					newDad.alpha = 0.00001;
					startCharacterScript(newDad);
				}

			case 2:
				if(gf != null && !gfMap.exists(newCharacter)) {
					var newGf:Character = new Character(0, 0, newCharacter);
					gf.cameraPosition[0] += stageData.camera_girlfriend[0];
					gf.cameraPosition[1] += stageData.camera_girlfriend[1];
					newGf.scrollFactor.set(0.95, 0.95);

					newGf.alpha = 0.00001;

					gfMap.set(newCharacter, newGf);
					gfGroup.add(newGf);
					startCharacterPos(newGf);

					startCharacterScript(newGf);
				}
		}
	}

	function startCharacterScript(char:Character)
	{
		char.startScripts();
		
		if (char.characterScript != null){
			#if LUA_ALLOWED
			if (char.characterScript.scriptType == "lua")
				luaArray.push(cast char.characterScript);
			else
			#end
			hscriptArray.push(cast char.characterScript);

			funkyScripts.push(char.characterScript);
		}
	}

	public function getLuaObject(tag:String, text:Bool=true):FlxSprite {
		if(modchartObjects.exists(tag))return modchartObjects.get(tag);
		if(modchartSprites.exists(tag))return modchartSprites.get(tag);
		if(text && modchartTexts.exists(tag))return modchartTexts.get(tag);
		return null;
	}

	function startCharacterPos(char:Character, ?gfCheck:Bool = false) {
		if(gfCheck && char.curCharacter.startsWith('gf')) { //IF DAD IS GIRLFRIEND, HE GOES TO HER POSITION
			char.setPosition(GF_X, GF_Y);
			char.scrollFactor.set(0.95, 0.95);
			char.danceEveryNumBeats = 2;
		}
		char.x += char.positionArray[0];
		char.y += char.positionArray[1];
	}

	public function startVideo(name:String)
	{
		#if VIDEOS_ALLOWED
		inCutscene = true;

		var filepath:String = Paths.video(name);
		if (!Paths.exists(filepath))
		{
			FlxG.log.warn('Couldnt find video file: ' + name);
			startAndEnd();
			return;
		}

		var video:MP4Handler = new MP4Handler();
		video.playVideo(filepath);
		video.finishCallback = function()
		{
			startAndEnd();
			return;
		}
		#else
		FlxG.log.warn('Video not supported!');
		startAndEnd();
		return;
		#end
	}

	function startAndEnd()
	{
		if(endingSong){
			endSong();
		}
		else{
			startCountdown();
		}
	}

	/*
	function songIntroCutscene(){
		var daSong:String = Paths.formatToSongPath(curSong);
		if (isStoryMode && !seenCutscene)
		{
			switch (daSong)
			{
				default:
					startCountdown();
			}
			seenCutscene = true;
		}
		else
		{
			startCountdown();
		}
	}
	*/
	
	var startTimer:FlxTimer;
	var finishTimer:FlxTimer = null;

	// For being able to mess with the sprites on Lua
	public var introAlts:Array<Null<String>> = [null, 'ready', 'set', 'go'];

	public var countdownSpr:FlxSprite;
	var countdownTwn:FlxTween;
	public static var startOnTime:Float = 0;

	public function startCountdown():Void
	{
		if(startedCountdown) {
			callOnScripts('onStartCountdown');
			return;
		}

		inCutscene = false;

		if(callOnScripts('onStartCountdown') == Globals.Function_Stop)
			return;

		if (skipCountdown || startOnTime > 0) 
			skipArrowStartTween = true;

		generateStaticArrows(0);
		generateStaticArrows(1);
		for (i in 0...playerStrums.length) {
			setOnScripts('defaultPlayerStrumX' + i, playerStrums.members[i].x);
			setOnScripts('defaultPlayerStrumY' + i, playerStrums.members[i].y);
		}
		for (i in 0...opponentStrums.length) {
			setOnScripts('defaultOpponentStrumX' + i, opponentStrums.members[i].x);
			setOnScripts('defaultOpponentStrumY' + i, opponentStrums.members[i].y);
		}

		modManager.receptors = [playerStrums.members, opponentStrums.members];

		callOnScripts('preModifierRegister');
		modManager.registerDefaultModifiers();
		callOnScripts('postModifierRegister');

		startedCountdown = true;
		Conductor.songPosition = 0;
		Conductor.songPosition -= Conductor.crochet * 5;
		setOnScripts('startedCountdown', true);
		callOnScripts('onCountdownStarted');

		if(startOnTime < 0) 
			startOnTime = 0;

		if (startOnTime > 0) {
			clearNotesBefore(startOnTime);
			setSongTime(startOnTime - 350);
			return;
		}
		else if (skipCountdown)
		{
			setSongTime(0);
			return;
		}

		// Load all of the countdown intro assets!!!!!
		var shitToLoad:Array<AssetPreload> = [
			{path: 'intro3', type: "SOUND"},
			{path: 'intro2', type: "SOUND"},
			{path: 'intro1', type: "SOUND"},
			{path: 'introGo', type: "SOUND"}
		];
		for (introPath in introAlts){
			if (introPath != null)
				shitToLoad.push({path: introPath});
		}
		Cache.loadWithList(shitToLoad);

		// Do the countdown.
		var swagCounter:Int = 0;
		startTimer = new FlxTimer().start(Conductor.crochet * 0.001, function(tmr:FlxTimer)
		{
			if (gf != null && tmr.loopsLeft % Math.round(gfSpeed * gf.danceEveryNumBeats) == 0 && gf.animation.curAnim != null && !gf.animation.curAnim.name.startsWith("sing") && !gf.stunned)
			{
				gf.dance();
			}
			if (tmr.loopsLeft % boyfriend.danceEveryNumBeats == 0 && boyfriend.animation.curAnim != null && !boyfriend.animation.curAnim.name.startsWith('sing') && !boyfriend.stunned)
			{
				boyfriend.dance();
			}
			if (tmr.loopsLeft % dad.danceEveryNumBeats == 0 && dad.animation.curAnim != null && !dad.animation.curAnim.name.startsWith('sing') && !dad.stunned)
			{
				dad.dance();
			}

			var sprImage:Null<String> = introAlts[swagCounter];
			if (sprImage != null){
				if (countdownTwn != null)
					countdownTwn.cancel();

				countdownSpr = new FlxSprite(0, 0, Paths.image(sprImage));
				countdownSpr.scrollFactor.set();
				countdownSpr.updateHitbox();
				
				countdownSpr.screenCenter();
				countdownSpr.antialiasing = ClientPrefs.globalAntialiasing;
				
				insert(members.indexOf(notes), countdownSpr);

				countdownTwn = FlxTween.tween(countdownSpr, {alpha: 0}, Conductor.crochet * 0.001, {
					ease: FlxEase.cubeInOut,
					onComplete: function(twn){
						countdownTwn.destroy();
						countdownTwn = null;
						remove(countdownSpr).destroy();
					}
				});
			}

			switch (swagCounter){
				case 0:
					FlxG.sound.play(Paths.sound('intro3' + introSoundsSuffix), 0.6);
				case 1:
					FlxG.sound.play(Paths.sound('intro2' + introSoundsSuffix), 0.6);
				case 2:
					FlxG.sound.play(Paths.sound('intro1' + introSoundsSuffix), 0.6);
				case 3:
					FlxG.sound.play(Paths.sound('introGo' + introSoundsSuffix), 0.6);
			}

			notes.forEachAlive(function(note:Note) {
				if(ClientPrefs.opponentStrums || note.mustPress)
				{
					note.copyAlpha = false;
					note.alpha = note.multAlpha;
					if(ClientPrefs.middleScroll && !note.mustPress) {
						note.alpha *= 0.35;
					}
				}
			});
		
			callOnScripts('onCountdownTick', [swagCounter, tmr]);

			swagCounter += 1;
		}, 5);
	
	}
	
	public function addBehindGF(obj:FlxObject)
	{
		insert(members.indexOf(gfGroup), obj);
	}
	public function addBehindBF(obj:FlxObject)
	{
		insert(members.indexOf(boyfriendGroup), obj);
	}
	public function addBehindDad(obj:FlxObject)
	{
		insert(members.indexOf(dadGroup), obj);
	}

	public function clearNotesBefore(time:Float)
	{
		var i:Int = unspawnNotes.length - 1;
		while (i >= 0) {
			var daNote:Note = unspawnNotes[i];
			if(daNote.strumTime - 350 < time)
			{
				daNote.active = false;
				daNote.visible = false;
				daNote.ignoreNote = true;

				if(modchartObjects.exists('note${daNote.ID}'))modchartObjects.remove('note${daNote.ID}');
				daNote.kill();
				unspawnNotes.remove(daNote);
				daNote.destroy();
			}
			--i;
		}

		i = notes.length - 1;
		while (i >= 0) {
			var daNote:Note = notes.members[i];
			if(daNote.strumTime - 350 < time)
			{
				daNote.active = false;
				daNote.visible = false;
				daNote.ignoreNote = true;

				if(modchartObjects.exists('note${daNote.ID}'))modchartObjects.remove('note${daNote.ID}');
				daNote.kill();
				notes.remove(daNote, true);
				daNote.destroy();
			}
			--i;
		}
	}

	public function setSongTime(time:Float)
	{
		if(time < 0) time = 0;

		FlxG.sound.music.pause();
		vocals.pause();
		for (track in tracks)
			track.pause();

		FlxG.sound.music.time = time;
		FlxG.sound.music.play();

		vocals.time = time;
		vocals.play();
		for (track in tracks){
			track.time = time;
			track.play();
		}		

		Conductor.songPosition = time;
		songTime = time;
	}

	var previousFrameTime:Int = 0;
	//var lastReportedPlayheadPosition:Int = 0;
	var songTime:Float = 0;

	function startSong():Void
	{
		startingSong = false;

		previousFrameTime = FlxG.game.ticks;
		//lastReportedPlayheadPosition = 0;

		FlxG.sound.playMusic(Paths.inst(PlayState.SONG.song), 1, false);
		FlxG.sound.music.onComplete = function(){finishSong(false);};
		vocals.play();
		for (track in tracks)
			track.play();	

		if(startOnTime > 0)
		{
			setSongTime(startOnTime - 500);
		}
		startOnTime = 0;

		if(paused) {
			//trace('Oopsie doopsie! Paused sound');
			FlxG.sound.music.pause();
			vocals.pause();
			for (track in tracks)
				track.play();		
		}

		// Song duration in a float, useful for the time left feature
		songLength = FlxG.sound.music.length;
		FlxTween.tween(timeBar, {alpha: 1}, 0.5, {ease: FlxEase.circOut});
		FlxTween.tween(timeTxt, {alpha: 1}, 0.5, {ease: FlxEase.circOut});

		#if desktop
		// Updating Discord Rich Presence (with Time Left)
		DiscordClient.changePresence(detailsText, SONG.song, Paths.formatToSongPath(SONG.song), true, songLength);
		#end
		setOnScripts('songLength', songLength);
		callOnScripts('onSongStart');
	}

	var debugNum:Int = 0;
	private var noteTypeMap:Map<String, Bool> = new Map<String, Bool>();
	private var eventPushedMap:Map<String, Bool> = new Map<String, Bool>();

	function shouldPush(event:EventNote){
		switch(event.event){
			default:
				if (eventScripts.exists(event.event))
				{
					var eventScript:FunkinScript = eventScripts.get(event.event);
					var returnVal:Any = true;
					
					#if LUA_ALLOWED
					if (eventScript.scriptType == 'lua')
						returnVal = callScript(eventScript, "shouldPush", [event.value1, event.value2]); 
					else #end
						returnVal = callScript(eventScript, "shouldPush", [event]); 

					//trace(returnVal, returnVal != false, fuck);
					return returnVal != false;
				}
		}
		return true;
	}

	function getEvents(){
		var songData = SONG;
		var events:Array<EventNote> = [];

		if (#if MODS_ALLOWED Paths.exists(Paths.modsSongJson(songName + '/events')) || #end Paths.exists(Paths.songJson(songName + '/events')))	
		{
			var eventsData:Array<Dynamic> = Song.loadFromJson('events', songName).events;
			for (event in eventsData) //Event Notes
			{
				for (i in 0...event[1].length)
				{
					var newEventNote:Array<Dynamic> = [event[0], event[1][i][0], event[1][i][1], event[1][i][2]];
					var subEvent:EventNote = {
						strumTime: newEventNote[0] + ClientPrefs.noteOffset,
						event: newEventNote[1],
						value1: newEventNote[2],
						value2: newEventNote[3]
					};
					if(!shouldPush(subEvent))continue;
					events.push(subEvent);
				}
			}
		}

		for (event in songData.events) //Event Notes
		{
			for (i in 0...event[1].length)
			{
				var newEventNote:Array<Dynamic> = [event[0], event[1][i][0], event[1][i][1], event[1][i][2]];
				var subEvent:EventNote = {
					strumTime: newEventNote[0] + ClientPrefs.noteOffset,
					event: newEventNote[1],
					value1: newEventNote[2],
					value2: newEventNote[3]
				};
				if(!shouldPush(subEvent))continue;
				events.push(subEvent);
			}
		}


		return events;
	}

	private function generateSong(dataPath:String):Void
	{
		songSpeedType = ClientPrefs.getGameplaySetting('scrolltype','multiplicative');

		switch(songSpeedType)
		{
			case "multiplicative":
				songSpeed = SONG.speed * ClientPrefs.getGameplaySetting('scrollspeed', 1);
			case "constant":
				songSpeed = ClientPrefs.getGameplaySetting('scrollspeed', 1);
		}

		var songData = SONG;
		Conductor.changeBPM(songData.bpm);

		curSong = songData.song;

		FlxG.sound.list.add(new FlxSound().loadEmbedded(Paths.inst(PlayState.SONG.song)));

		if (SONG.needsVoices)
			vocals = new FlxSound().loadEmbedded(Paths.voices(PlayState.SONG.song));
		else
			vocals = new FlxSound();
		FlxG.sound.list.add(vocals);

		if (SONG.extraTracks != null){
			for (trackName in SONG.extraTracks){
				var newTrack = new FlxSound().loadEmbedded(Paths.track(PlayState.SONG.song, trackName));
				tracks.push(newTrack);
				FlxG.sound.list.add(newTrack);
			}
		}

		add(notes);

		var noteData:Array<SwagSection>;

		// NEW SHIT
		noteData = songData.notes;

		var playerCounter:Int = 0;
		var daBeats:Int = 0; // Not exactly representative of 'daBeats' lol, just how much it has looped

		// loads note types
		for (section in noteData)
		{
			for (songNotes in section.sectionNotes)
			{
				var type:Dynamic = songNotes[3];
				//if(!Std.isOfType(type, String)) type = editors.ChartingState.noteTypeList[type];

				if (!noteTypeMap.exists(type)) {
					firstNotePush(type);
					noteTypeMap.set(type, true);
				}
			}
		}

		for (notetype in noteTypeMap.keys())
		{
			var doPush:Bool = false;
			var baseScriptFile:String = 'notetypes/' + notetype;
			var exts = ["hscript" #if LUA_ALLOWED , "lua" #end];
			for (ext in exts)
			{
				if (doPush)
					break;
				var baseFile = '$baseScriptFile.$ext';
				var files = [#if MODS_ALLOWED Paths.modFolders(baseFile), #end Paths.getPreloadPath(baseFile)];
				for (file in files)
				{
					if (!Paths.exists(file))
						continue;
				
					#if LUA_ALLOWED
					if (ext == 'lua')
					{
						var script = new FunkinLua(file, notetype);
						luaArray.push(script);
						funkyScripts.push(script);
						notetypeScripts.set(notetype, script);
						doPush = true;
					}
					else #end if (ext == 'hscript')
					{
						var script = FunkinHScript.fromFile(file, notetype);
						hscriptArray.push(script);
						funkyScripts.push(script);
						notetypeScripts.set(notetype, script);
						doPush = true;
					}
					if (doPush)
						break;
				}
			}
		}

		// loads events
		for(event in getEvents()){
			if (!eventPushedMap.exists(event.event))
			{
				eventPushedMap.set(event.event, true);
				firstEventPush(event);
			}
		}
		
		for (event in eventPushedMap.keys())
		{
			var doPush:Bool = false;
			var baseScriptFile:String = 'events/' + event;
			var exts = ["hscript" #if LUA_ALLOWED , "lua" #end];
			for (ext in exts)
			{
				if (doPush)
					break;
				var baseFile = '$baseScriptFile.$ext';
				var files = [#if MODS_ALLOWED Paths.modFolders(baseFile), #end Paths.getPreloadPath(baseFile)];
				for (file in files)
				{
					if (!Paths.exists(file))
						continue;

					#if LUA_ALLOWED
					if (ext == 'lua')
					{
						var script = new FunkinLua(file, event);
						luaArray.push(script);
						funkyScripts.push(script);
						eventScripts.set(event, script);
						script.call("onLoad");
						doPush = true;
					}
					else #end if (ext == 'hscript')
					{
						var script = FunkinHScript.fromFile(file, event);
						hscriptArray.push(script);
						funkyScripts.push(script);
						eventScripts.set(event, script);

						script.call("onLoad");
						
						doPush = true;
					}

					if (doPush)
						break;
				}
			}
		}
		
		for(subEvent in getEvents()){
			subEvent.strumTime -= eventNoteEarlyTrigger(subEvent);
			eventNotes.push(subEvent);
			eventPushed(subEvent);
		}
		if(eventNotes.length > 1) { //No need to sort if there's a single one or none at all
			eventNotes.sort(sortByTime);
		}

		var lastBFNotes:Array<Note> = [null, null, null, null];
		var lastDadNotes:Array<Note> = [null, null, null, null];
		var lastGFNotes:Array<Note> = [null, null, null, null];
		// Should populate these w/ nulls depending on keycount -neb
		for (section in noteData)
		{
			for (songNotes in section.sectionNotes)
			{
				var daStrumTime:Float = songNotes[0];
				var daNoteData:Int = Std.int(songNotes[1] % 4);

				var gottaHitNote:Bool = section.mustHitSection;

				if (songNotes[1] > 3)
				{
					gottaHitNote = !section.mustHitSection;
				}

				var oldNote:Note;
				if (unspawnNotes.length > 0)
					oldNote = unspawnNotes[Std.int(unspawnNotes.length - 1)];
				else
					oldNote = null;

				var type:Dynamic = songNotes[3];
				//if(!Std.isOfType(type, String)) type = editors.ChartingState.noteTypeList[type];

				// TODO: maybe make a checkNoteType n shit but idfk im lazy
				// or maybe make a "Transform Notes" event which'll make notes which don't change texture change into the specified one

				var swagNote:Note = new Note(daStrumTime, daNoteData, oldNote);
				swagNote.mustPress = gottaHitNote;
				swagNote.sustainLength = songNotes[2];
				
				swagNote.gfNote = (section.gfSection && (songNotes[1]<4));
				swagNote.noteType = type;
				swagNote.scrollFactor.set();

				var susLength:Float = swagNote.sustainLength;

				susLength = susLength / Conductor.stepCrochet;
				swagNote.ID = unspawnNotes.length;
				modchartObjects.set('note${swagNote.ID}', swagNote);
				unspawnNotes.push(swagNote);

				#if LUA_ALLOWED
				if(swagNote.noteScript != null && swagNote.noteScript.scriptType == 'lua'){
					callScript(swagNote.noteScript, 'setupNote', [
						unspawnNotes.indexOf(swagNote),
						Math.abs(swagNote.noteData),
						swagNote.noteType,
						swagNote.isSustainNote,
						swagNote.ID
					]);
				}
				#end

				var floorSus:Int = Math.round(susLength);
				if(floorSus > 0) {
					for (susNote in 0...floorSus+1)
					{
						oldNote = unspawnNotes[Std.int(unspawnNotes.length - 1)];

						var sustainNote:Note = new Note(daStrumTime + (Conductor.stepCrochet * susNote) + (Conductor.stepCrochet / FlxMath.roundDecimal(songSpeed, 2)), daNoteData, oldNote, true);
						sustainNote.mustPress = gottaHitNote;
						sustainNote.gfNote = swagNote.gfNote;
						sustainNote.noteType = type;
						if(sustainNote==null || !sustainNote.alive)
							break;
						sustainNote.ID = unspawnNotes.length;
						modchartObjects.set('note${sustainNote.ID}', sustainNote);
						sustainNote.scrollFactor.set();
						swagNote.tail.push(sustainNote);
						sustainNote.parent = swagNote;
						unspawnNotes.push(sustainNote);
						
						#if LUA_ALLOWED
						if (sustainNote.noteScript != null && sustainNote.noteScript.scriptType == 'lua'){
							callScript(sustainNote.noteScript, 'setupNote', [
								unspawnNotes.indexOf(sustainNote),
								Math.abs(sustainNote.noteData),
								sustainNote.noteType,
								sustainNote.isSustainNote,
								sustainNote.ID
							]);
						}
						#end

						if (sustainNote.mustPress)
						{
							sustainNote.x += FlxG.width * 0.5; // general offset
						}
						else if(ClientPrefs.middleScroll)
						{
							sustainNote.x += 310;
							if(daNoteData > 1) //Up and Right
							{
								sustainNote.x += FlxG.width * 0.5 + 25;
							}
						}
					}
				}

				if (swagNote.mustPress)
				{
					swagNote.x += FlxG.width * 0.5; // general offset
				}
				else if(ClientPrefs.middleScroll)
				{
					swagNote.x += 310;
					if(daNoteData > 1) //Up and Right
					{
						swagNote.x += FlxG.width * 0.5 + 25;
					}
				}

			}
			daBeats += 1;
		}
		// playerCounter += 1;

		unspawnNotes.sort(sortByShit);

		var goobaeg:Array<Note> = [];
		for (swagNote in unspawnNotes)
		{
			var arr = lastBFNotes;

			if (!swagNote.mustPress)
				arr = lastDadNotes;
			if (swagNote.gfNote)
				arr = lastGFNotes;
			// eradicates stacked notes
			var lastNote = arr[swagNote.noteData];
			if (lastNote != null)
			{
				if (Math.abs(swagNote.strumTime - lastNote.strumTime) <= 6)
				{
					trace("grabbed note, prev " + lastNote.strumTime + ", current " + swagNote.strumTime);
					goobaeg.push(swagNote);
					continue;
				}
			}
			arr[swagNote.noteData] = swagNote;
		}
		for (note in goobaeg)
		{
			trace("destroyed note at " + note.strumTime);
			note.kill();
			note.destroy();
			unspawnNotes.remove(note);
		}
		
		if(eventNotes.length > 1) //No need to sort if there's a single one or none at all
			eventNotes.sort(sortByTime);

		checkEventNote();
		generatedMusic = true;
	}

	// everything returned here gets preloaded by the preloader up-top ^
	function preloadEvent(event:EventNote):Array<AssetPreload>{
		var preload:Array<AssetPreload> = [];

		switch(event.event){
			case "Change Character":
				return Character.returnCharacterPreload(event.value2);
		}

		return preload;
	}

	function eventPushed(event:EventNote) {
		switch(event.event){
			case 'Change Character':
				var charType:Int = 0;
				switch(event.value1.toLowerCase()) {
					case 'gf' | 'girlfriend' | '1':
						charType = 2;
					case 'dad' | 'opponent' | '0':
						charType = 1;
					default:
						charType = Std.parseInt(event.value1);
						if(Math.isNaN(charType)) charType = 0;
				}

				addCharacterToList(event.value2, charType);
			default:
				if (eventScripts.exists(event.event))
				{
					var eventScript:FunkinScript = eventScripts.get(event.event);

					#if LUA_ALLOWED
					if (eventScript.scriptType == 'lua')
						callScript(eventScript, "onPush",[event.value1, event.value2]); 
					else
					#end
						callScript(eventScript, "onPush", [event]); 
				}

		}
	}

	function firstNotePush(type:String){
		switch(type){
			default:
				if (notetypeScripts.exists(type))
				{
					callScript(notetypeScripts.get(type), "onLoad", []);
				}
		}
	}

	function firstEventPush(event:EventNote){
		switch (event.event)
		{
			default:
				// should PROBABLY turn this into a function, callEventScript(eventNote, "func") or something, idk
				if (eventScripts.exists(event.event))
				{
					var eventScript:Dynamic = eventScripts.get(event.event);

					#if LUA_ALLOWED
					if (eventScript.scriptType == 'lua')
						callScript(eventScript, "onLoad", [event.value1, event.value2]);
					else
					#end
						callScript(eventScript, "onLoad", [event]);
				}
		}
	}

	function eventNoteEarlyTrigger(event:EventNote):Float {
		var returnedValue:Float = callOnScripts('eventEarlyTrigger', [event.event, event.value1, event.value2]);

		if (eventScripts.exists(event.event)){
			var eventScript:Dynamic = eventScripts.get(event.event);
			#if LUA_ALLOWED
			if(eventScript.scriptType == 'lua')
				returnedValue = callScript(eventScript, "getOffset", [event.value1, event.value2]);
			else
			#end
				returnedValue = callScript(eventScript, "getOffset", [event]);
		}
		if(returnedValue != 0)
			return returnedValue;

		switch(event.event) {
			case 'Kill Henchmen': //Better timing so that the kill sound matches the beat intended
				return 280; //Plays 280ms before the actual position
		}
		return 0;
	}

	function sortByShit(Obj1:Note, Obj2:Note):Int
	{
		return FlxSort.byValues(FlxSort.ASCENDING, Obj1.strumTime, Obj2.strumTime);
	}

	function sortByOrderNote(wat:Int, Obj1:Note, Obj2:Note):Int
	{
		return FlxSort.byValues(FlxSort.ASCENDING, Obj1.zIndex, Obj2.zIndex);
	}

	function sortByOrderStrumNote(wat:Int, Obj1:StrumNote, Obj2:StrumNote):Int
	{
		return FlxSort.byValues(FlxSort.DESCENDING, Obj1.zIndex, Obj2.zIndex);
	}

	function sortByTime(Obj1:EventNote, Obj2:EventNote):Int
	{
		return FlxSort.byValues(FlxSort.ASCENDING, Obj1.strumTime, Obj2.strumTime);
	}

	public var skipArrowStartTween:Bool = false; //for lua
	private function generateStaticArrows(player:Int):Void
	{
		var targetAlpha:Float = 1;
		if (player < 1){
			if(!ClientPrefs.opponentStrums) targetAlpha = 0;
			else if(ClientPrefs.middleScroll) targetAlpha = 0.35;
		}

		for (i in 0...4){
			var babyArrow:StrumNote = new StrumNote(
				ClientPrefs.middleScroll ? STRUM_X_MIDDLESCROLL : STRUM_X, 
				ClientPrefs.downScroll ? FlxG.height - 162 : 50, 
				i, 
				player
			);

			babyArrow.downScroll = ClientPrefs.downScroll;

			if (!isStoryMode && !skipArrowStartTween)
			{
				//babyArrow.y -= 10;
				babyArrow.alpha = 0;
				FlxTween.tween(babyArrow, {/*y: babyArrow.y + 10,*/ alpha: targetAlpha}, 1, {ease: FlxEase.circOut, startDelay: 0.5 + (0.2 * i)});
			}
			else
			{
				babyArrow.alpha = targetAlpha;
			}

			if (player == 1)
			{
				playerStrums.add(babyArrow);
			}
			else
			{
				if(ClientPrefs.middleScroll)
				{
					babyArrow.x += 310;
					if(i > 1) { //Up and Right
						babyArrow.x += FlxG.width * 0.5 + 25;
					}
				}
				opponentStrums.add(babyArrow);
			}

			strumLineNotes.add(babyArrow);
			babyArrow.postAddedToGroup();
		}
	}

	override function openSubState(SubState:FlxSubState)
	{
		if (paused)
		{
			if (FlxG.sound.music != null)
			{
				FlxG.sound.music.pause();
				vocals.pause();
				for (track in tracks)
					track.pause();
			}

			if (startTimer != null && !startTimer.finished)
				startTimer.active = false;
			if (finishTimer != null && !finishTimer.finished)
				finishTimer.active = false;
			if (songSpeedTween != null)
				songSpeedTween.active = false;
			

			var chars:Array<Character> = [boyfriend, gf, dad];
			for (char in chars) {
				if(char != null && char.colorTween != null) {
					char.colorTween.active = false;
				}
			}

			for (tween in modchartTweens) {
				tween.active = false;
			}
			for (timer in modchartTimers) {
				timer.active = false;
			}
		}

		super.openSubState(SubState);
	}

	override function closeSubState()
	{
		if (paused)
		{
			if (FlxG.sound.music != null && !startingSong)
			{
				resyncVocals();
			}

			if (startTimer != null && !startTimer.finished)
				startTimer.active = true;
			if (finishTimer != null && !finishTimer.finished)
				finishTimer.active = true;
			if (songSpeedTween != null)
				songSpeedTween.active = true;

			var chars:Array<Character> = [boyfriend, gf, dad];
			for (char in chars) {
				if(char != null && char.colorTween != null) {
					char.colorTween.active = true;
				}
			}

			for (tween in modchartTweens) {
				tween.active = true;
			}
			for (timer in modchartTimers) {
				timer.active = true;
			}
			paused = false;
			callOnScripts('onResume');

			#if desktop
			if (startTimer != null && startTimer.finished)
			{
				DiscordClient.changePresence(detailsText, SONG.song, Paths.formatToSongPath(SONG.song), true, songLength - Conductor.songPosition - ClientPrefs.noteOffset);
			}
			else
			{
				DiscordClient.changePresence(detailsText, SONG.song, Paths.formatToSongPath(SONG.song));
			}
			#end
		}

		super.closeSubState();
	}

	override public function onFocus():Void
	{
		#if desktop
		if (health > 0 && !paused)
		{
			if (Conductor.songPosition > 0.0)
			{
				DiscordClient.changePresence(detailsText, SONG.song, Paths.formatToSongPath(SONG.song), true, songLength - Conductor.songPosition - ClientPrefs.noteOffset);
			}
			else
			{
				DiscordClient.changePresence(detailsText, SONG.song, Paths.formatToSongPath(SONG.song));
			}
		}
		#end

		super.onFocus();
	}

	override public function onFocusLost():Void
	{	
		#if desktop
		DiscordClient.changePresence(detailsPausedText, SONG.song, Paths.formatToSongPath(SONG.song));
		#end

		#if !debug
		// pause();
		#end

		super.onFocusLost();
	}

	function resyncVocals():Void
	{
		if(finishTimer != null) return;

		vocals.pause();
		for (track in tracks)
			track.pause();

		FlxG.sound.music.play();
		Conductor.songPosition = FlxG.sound.music.time;
		vocals.time = Conductor.songPosition;
		vocals.play();
		for (track in tracks){
			track.time = Conductor.songPosition;
			track.play();
		}
	}

	public var paused:Bool = false;
	public var canReset:Bool = true;
	var startedCountdown:Bool = false;
	var canPause:Bool = true;

	override public function update(elapsed:Float)
	{
		if (FlxG.keys.justPressed.NINE)
			iconP1.swapOldIcon();

		setOnScripts('curDecStep', curDecStep);
		setOnScripts('curDecBeat', curDecBeat);

		callOnScripts('onUpdate', [elapsed]);

		if (FlxG.sound.music.playing && !inCutscene && health > healthDrain)
		{
			health -= healthDrain * (elapsed / (1/60));
		}

		if(!inCutscene) {
			var lerpVal:Float = CoolUtil.boundTo(elapsed * 2.4 * cameraSpeed, 0, 1);

			var xOff:Float = 0;
			var yOff:Float = 0;

			if (ClientPrefs.directionalCam && focusedChar != null){
				xOff = focusedChar.camOffX;
				yOff = focusedChar.camOffY;
			}

			var currentCameraPoint = cameraPoints[cameraPoints.length-1];
			if (currentCameraPoint != null)
				camFollow.copyFrom(currentCameraPoint);

			camFollowPos.setPosition(
				FlxMath.lerp(camFollowPos.x, camFollow.x + xOff, lerpVal), 
				FlxMath.lerp(camFollowPos.y, camFollow.y + yOff, lerpVal)
			);

			if (!startingSong
				&& !endingSong
				&& boyfriend != null
				&& boyfriend.animation.curAnim != null && boyfriend.animation.curAnim.name.startsWith('idle')) {
				boyfriendIdleTime += elapsed;
				if(boyfriendIdleTime >= 0.15) { // Kind of a mercy thing for making the achievement easier to get as it's apparently frustrating to some playerss
					boyfriendIdled = true;
				}
			} else {
				boyfriendIdleTime = 0;
			}
		}

		for (key in notetypeScripts.keys())
			notetypeScripts.get(key).call("update", [elapsed]);
		
		for (key in eventScripts.keys())
			eventScripts.get(key).call("update", [elapsed]);

		callOnHScripts('update', [elapsed]);

		//// certified cr classic
		scoreTxt.text = (songHighscore != 0 && songScore > songHighscore ? 'Hi-score: ' : 'Score: ')
			+ '$songScore | Misses: $songMisses | Rating: '
			+ (ratingName != '?' ? Highscore.floorDecimal(ratingPercent * 100, 2) + '% - $ratingFC' : ratingName);

		if(botplayTxt.visible) {
			botplaySine += 180 * elapsed;
			botplayTxt.alpha = 1 - Math.sin((Math.PI * botplaySine) / 180);
		}

		super.update(elapsed);

		////
		if (!endingSong){
			//// time travel
			if (!startingSong && chartingMode){
				if (FlxG.keys.justPressed.ONE) {
					KillNotes();
					FlxG.sound.music.onComplete();
				}else if(FlxG.keys.justPressed.TWO) { //Go 10 seconds into the future :O
					setSongTime(Conductor.songPosition + 10000);
					clearNotesBefore(Conductor.songPosition);
				}
			}

			//// editors
			if (FlxG.keys.anyJustPressed(debugKeysChart))
				openChartEditor();

			if (FlxG.keys.anyJustPressed(debugKeysCharacter))
			{
				persistentUpdate = false;
				paused = true;
				cancelMusicFadeTween();
				MusicBeatState.switchState(new CharacterEditorState(SONG.player2));
			}
		
			// RESET = Quick Game Over Screen
			if (!ClientPrefs.noReset && controls.RESET && canReset && !inCutscene && startedCountdown)
				health = 0;
			//	Death checks are now done after when your health is modified, rather than every frame

			if (controls.PAUSE)
				pause();
		}

		////
		if (startingSong)
		{
			if (startedCountdown)
			{
				Conductor.songPosition += FlxG.elapsed * 1000;
				if (Conductor.songPosition >= 0)
					startSong();
			}
		}
		else
		{
			Conductor.songPosition += FlxG.elapsed * 1000;

			if (!paused)
			{
				songTime += FlxG.game.ticks - previousFrameTime;
				previousFrameTime = FlxG.game.ticks;

				// Interpolation type beat
				if (Conductor.lastSongPos != Conductor.songPosition)
				{
					songTime = (songTime + Conductor.songPosition) * 0.5;
					Conductor.lastSongPos = Conductor.songPosition;
					// Conductor.songPosition += FlxG.elapsed * 1000;
					// trace('MISSED FRAME');
				}

				if(updateTime) {
					var curTime:Float = Conductor.songPosition - ClientPrefs.noteOffset;
					if(curTime < 0) curTime = 0;

					songPercent = (curTime / songLength);

					if (chartingMode)
						timeTxt.text = '${FlxMath.roundDecimal(curTime * 0.001, 2)} / ${FlxMath.roundDecimal(songLength * 0.001, 2)}';
					else if(ClientPrefs.timeBarType != 'Song Name'){
						var secondsTotal:Int = Math.floor((ClientPrefs.timeBarType == 'Time Elapsed' ? curTime : songLength - curTime) * 0.001);
						if(secondsTotal < 0) secondsTotal = 0;
						
						timeTxt.text = FlxStringUtil.formatTime(secondsTotal, false);
					}
				}
			}

			// Conductor.lastSongPos = FlxG.sound.music.time;
		}

		if (camZooming)
		{
			var lerpVal = CoolUtil.boundTo(1 - (elapsed * 3.125 * camZoomingDecay), 0, 1);

			camGame.zoom = FlxMath.lerp(
				1 * defaultCamZoom, 
				camGame.zoom, 
				lerpVal
			);
			camHUD.zoom = FlxMath.lerp(
				1, 
				camHUD.zoom, 
				lerpVal
			);
			
			camOverlay.zoom = camHUD.zoom;
		}

		FlxG.watch.addQuick("beatShit", curBeat);
		FlxG.watch.addQuick("stepShit", curStep);
		
		modManager.updateTimeline(curDecStep);
		modManager.update(elapsed);

		// TODO: rewrite this a little bit cus of multSpeed and noteSpawnTime being able to be per-player and per-note n all that
		// just so that if the top note spawns later, it wont fuck up other notes which should spawn sooner.

		if (unspawnNotes[0] != null)
		{
			var noteSpawnTime = modManager.get("noteSpawnTime"); // ermmmm, what the flip.
			var time:Float = noteSpawnTime == null ? spawnTime : (noteSpawnTime.getValue(0) + noteSpawnTime.getValue(1)) / 2; // averages the spawn times
			// TODO: make this per-player instead of averaging it
			if (songSpeed < 1 && songSpeed != 0)
				time /= songSpeed;
			if (unspawnNotes[0].multSpeed < 1)
				time /= unspawnNotes[0].multSpeed;

			while (unspawnNotes.length > 0 && unspawnNotes[0].strumTime - Conductor.songPosition < time)
			{
				var dunceNote:Note = unspawnNotes[0];
				notes.insert(0, dunceNote);
				dunceNote.spawned = true;

				callOnHScripts('onSpawnNote', [dunceNote]);
				#if LUA_ALLOWED
				callOnLuas('onSpawnNote', [notes.members.indexOf(dunceNote), dunceNote.noteData, dunceNote.noteType, dunceNote.isSustainNote]);
				#end	

				var index:Int = unspawnNotes.indexOf(dunceNote);
				unspawnNotes.splice(index, 1);

				callOnHScripts('onSpawnNotePost', [dunceNote]);
				if (dunceNote.noteScript != null)
				{
					var script:FunkinScript = dunceNote.noteScript;

					#if LUA_ALLOWED
					if (script.scriptType == 'lua'){
						callScript(script, 'postSpawnNote', [
							notes.members.indexOf(dunceNote),
							Math.abs(dunceNote.noteData),
							dunceNote.noteType,
							dunceNote.isSustainNote,
							dunceNote.ID
						]);
					}else
					#end
						callScript(script, "postSpawnNote", [dunceNote]);
				}
			}
		}

		opponentStrums.forEachAlive(function(strum:StrumNote)
		{
			var pos = modManager.getPos(0, 0, 0, curDecBeat, strum.noteData, 1, strum, [], strum.vec3Cache);
			modManager.updateObject(curDecBeat, strum, pos, 1);
			strum.x = pos.x;
			strum.y = pos.y;
			strum.z = pos.z;
		});

		playerStrums.forEachAlive(function(strum:StrumNote)
		{
			var pos = modManager.getPos(0, 0, 0, curDecBeat, strum.noteData, 0, strum, [], strum.vec3Cache);
			modManager.updateObject(curDecBeat, strum, pos, 0);
			strum.x = pos.x;
			strum.y = pos.y;
			strum.z = pos.z;
		});

		strumLineNotes.sort(sortByOrderStrumNote);

		if (generatedMusic)
		{
			if (!inCutscene){
				if (!cpuControlled)
					keyShit();
				else if (boyfriend.animation.curAnim != null && boyfriend.holdTimer > Conductor.stepCrochet * (0.0011 / FlxG.sound.music.pitch) * boyfriend.singDuration && boyfriend.animation.curAnim.name.startsWith('sing') && !boyfriend.animation.curAnim.name.endsWith('miss') && (boyfriend.idleWhenHold || !pressedGameplayKeys.contains(true)))
					boyfriend.dance();
			}

			// var fakeCrochet:Float = (60 / SONG.bpm) * 1000;
			notes.sort(sortByOrderNote);
			notes.forEachAlive(function(daNote:Note)
			{
				if (songSpeed != 0){
					var strumGroup:FlxTypedGroup<StrumNote> = playerStrums;
					if (!daNote.mustPress)
						strumGroup = opponentStrums;

					var strumX:Float = strumGroup.members[daNote.noteData].x;
					var strumY:Float = strumGroup.members[daNote.noteData].y;
					var strumAngle:Float = strumGroup.members[daNote.noteData].angle;
					var strumAlpha:Float = strumGroup.members[daNote.noteData].alpha;
					// var strumDirection:Float = strumGroup.members[daNote.noteData].direction;
					// var strumScroll:Bool = strumGroup.members[daNote.noteData].downScroll;

					strumX += daNote.offsetX;
					strumY += daNote.offsetY;
					strumAngle += daNote.offsetAngle;
					strumAlpha *= daNote.multAlpha;
					var pN:Int = daNote.mustPress ? 0 : 1; // xd

					var speed = songSpeed * daNote.multSpeed;
					var pos = modManager.getPos(daNote.strumTime, modManager.getVisPos(Conductor.songPosition, daNote.strumTime, speed),
						daNote.strumTime - Conductor.songPosition, curDecBeat, daNote.noteData, pN, daNote, [], daNote.vec3Cache);

					modManager.updateObject(curDecBeat, daNote, pos, pN);
					pos.x += daNote.offsetX;
					pos.y += daNote.offsetY;
					daNote.x = pos.x;
					daNote.y = pos.y;
					daNote.z = pos.z;
					if (daNote.isSustainNote)
					{
						var futureSongPos = Conductor.songPosition + 75;
						var diff = daNote.strumTime - futureSongPos;
						var vDiff = modManager.getVisPos(futureSongPos, daNote.strumTime, speed);

						var nextPos = modManager.getPos(daNote.strumTime, vDiff, diff, Conductor.getStep(futureSongPos) * 0.25, daNote.noteData, pN, daNote, [],
							daNote.vec3Cache);
						nextPos.x += daNote.offsetX;
						nextPos.y += daNote.offsetY;
						var diffX = (nextPos.x - pos.x);
						var diffY = (nextPos.y - pos.y);
						var rad = Math.atan2(diffY, diffX);
						var deg = rad * (180 / Math.PI);
						if (deg != 0)
							daNote.mAngle = (deg + 90);
						else
							daNote.mAngle = 0;
					}
				}

				if (!daNote.mustPress && daNote.wasGoodHit && !daNote.hitByOpponent && !daNote.ignoreNote)
				{
					opponentNoteHit(daNote);
				}

				if (!daNote.blockHit && daNote.mustPress && cpuControlled && daNote.canBeHit)
				{
					if (daNote.isSustainNote){
						if (daNote.canBeHit)
							goodNoteHit(daNote);
					}
					else if (daNote.strumTime <= Conductor.songPosition || daNote.isSustainNote)
					{
						goodNoteHit(daNote);
					}
				}

				// Kill extremely late notes and cause misses
				if(daNote.garbage){
					daNote.active = false;
					daNote.visible = false;

					daNote.kill();
					notes.remove(daNote, true);
					daNote.destroy();
				}else{
					if (Conductor.songPosition > noteKillOffset + daNote.strumTime && daNote.active)
					{
						if (daNote.mustPress && !cpuControlled && !daNote.ignoreNote && !endingSong && (daNote.tooLate || !daNote.wasGoodHit))
						{
							noteMiss(daNote);
						}

						daNote.active = false;
						daNote.visible = false;

						daNote.kill();
						notes.remove(daNote, true);
						daNote.destroy();
					}
				}
			});
		}
		checkEventNote();

		setOnScripts('cameraX', camFollowPos.x);
		setOnScripts('cameraY', camFollowPos.y);
		callOnScripts('onUpdatePost', [elapsed]);
	}

	function openChartEditor()
	{
		persistentUpdate = false;
		paused = true;
		cancelMusicFadeTween();
		MusicBeatState.switchState(new ChartingState());

		#if desktop
		DiscordClient.changePresence("Chart Editor", null, null, true);
		#end
	}

	public var isDead:Bool = false; //Don't mess with this on Lua!!!
	function doDeathCheck(?skipHealthCheck:Bool = false) {
		if (
			(
				(skipHealthCheck && instakillOnMiss) 
				|| health <= 0
			) 
			&& !practiceMode 
			&& !isDead
		)
		{
			var ret:Dynamic = callOnScripts('onGameOver');
			if(ret != Globals.Function_Stop) {
				boyfriend.stunned = true;
				deathCounter++;

				paused = true;

				vocals.stop();
				FlxG.sound.music.stop();
				for (track in tracks)
					track.stop();

				for (tween in modchartTweens)
					tween.active = true;
				for (timer in modchartTimers) 
					timer.active = true;
				
				persistentUpdate = false;
				persistentDraw = false;

				openSubState(new GameOverSubstate(
					boyfriend.getScreenPosition().x - boyfriend.positionArray[0], 
					boyfriend.getScreenPosition().y - boyfriend.positionArray[1], 
					camFollowPos.x, 
					camFollowPos.y
				));

				#if desktop
				// Game Over doesn't get his own variable because it's only used here
				DiscordClient.changePresence("Game Over - " + detailsText, SONG.song, Paths.formatToSongPath(SONG.song));
				#end
				isDead = true;
				return true;
			}
		}
		return false;
	}

	public function checkEventNote() {
		while(eventNotes.length > 0) {
			var daEvent = eventNotes[0];

			if(Conductor.songPosition < daEvent.strumTime)
				break;

			var value1:Null<String> = daEvent.value1;
			if(value1 == null) value1 = '';

			var value2:Null<String> = daEvent.value2;
			if(value2 == null) value2 = '';

			triggerEventNote(daEvent.event, value1, value2);
			eventNotes.shift();
		}
	}

	public function getControl(key:String) {
		var pressed:Bool = Reflect.getProperty(controls, key);
		//trace('Control result: ' + pressed);
		return pressed;
	}

	function changeCharacter(name:String, charType:Int){
		switch(charType) {
			case 0:
				if(boyfriend.curCharacter != name) {
					var shiftFocus:Bool = focusedChar==boyfriend;
					var oldChar = boyfriend;
					if(!boyfriendMap.exists(name)) {
						addCharacterToList(name, charType);
					}

					var lastAlpha:Float = boyfriend.alpha;
					boyfriend.alpha = 0.00001;
					boyfriend = boyfriendMap.get(name);
					boyfriend.alpha = lastAlpha;
					if(shiftFocus)focusedChar=boyfriend;
					iconP1.changeIcon(boyfriend.healthIcon);
				}
				setOnScripts('boyfriendName', boyfriend.curCharacter);

			case 1:
				if(dad.curCharacter != name) {
					var shiftFocus:Bool = focusedChar==dad;
					var oldChar = dad;
					if(!dadMap.exists(name)) {
						addCharacterToList(name, charType);
					}

					var wasGf:Bool = dad.curCharacter.startsWith('gf');
					var lastAlpha:Float = dad.alpha;
					dad.alpha = 0.00001;
					dad = dadMap.get(name);
					if(!dad.curCharacter.startsWith('gf')) {
						if(wasGf && gf != null) {
							gf.visible = true;
						}
					} else if(gf != null) {
						gf.visible = false;
					}
					if(shiftFocus)focusedChar=dad;
					dad.alpha = lastAlpha;
					iconP2.changeIcon(dad.healthIcon);
				}
				setOnScripts('dadName', dad.curCharacter);

			case 2:
				if(gf != null)
				{
					if(gf.curCharacter != name)
					{
						var shiftFocus:Bool = focusedChar==gf;
						var oldChar = gf;
						if(!gfMap.exists(name))
						{
							addCharacterToList(name, charType);
						}

						var lastAlpha:Float = gf.alpha;
						gf.alpha = 0.00001;
						gf = gfMap.get(name);
						gf.alpha = lastAlpha;
						if(shiftFocus)focusedChar=gf;
					}
					setOnScripts('gfName', gf.curCharacter);
				}
		}
		reloadHealthBarColors();
	}

	public function triggerEventNote(eventName:String, value1:String, value2:String) {
		trace('Event: ' + eventName + ', Value 1: ' + value1 + ', Value 2: ' + value2 + ', at Time: ' + Conductor.songPosition);

		switch(eventName) {
			case 'Change Focus':
				switch(value1.toLowerCase().trim()){
					case 'dad' | 'opponent':
						if (callOnScripts('onMoveCamera', ["dad"]) != Globals.Function_Stop)
							moveCamera(dad);
					case 'gf':
						if (callOnScripts('onMoveCamera', ["gf"]) != Globals.Function_Stop)
							moveCamera(gf);
					default:
						if (callOnScripts('onMoveCamera', ["bf"]) != Globals.Function_Stop)
							moveCamera(boyfriend);
				}
			case 'Game Flash':
				var dur:Float = Std.parseFloat(value2);
				if(Math.isNaN(dur)) dur = 0.5;

				var col:Null<FlxColor> = FlxColor.fromString(value1);
				if (col == null) col = 0xFFFFFFFF;

				FlxG.camera.flash(col, dur, null, true);
			case 'Hey!':
				var value:Int = 2;
				switch(value1.toLowerCase().trim()) {
					case 'bf' | 'boyfriend' | '0':
						value = 0;
					case 'gf' | 'girlfriend' | '1':
						value = 1;
				}

				var time:Float = Std.parseFloat(value2);
				if(Math.isNaN(time) || time <= 0) time = 0.6;

				if(value != 0) {
					if(dad.curCharacter.startsWith('gf')) { //Tutorial GF is actually Dad! The GF is an imposter!! ding ding ding ding ding ding ding, dindinding, end my suffering
						dad.playAnim('cheer', true);
						dad.specialAnim = true;
						dad.heyTimer = time;
					} else if (gf != null) {
						gf.playAnim('cheer', true);
						gf.specialAnim = true;
						gf.heyTimer = time;
					}
				}
				if(value != 1) {
					boyfriend.playAnim('hey', true);
					boyfriend.specialAnim = true;
					boyfriend.heyTimer = time;
				}

			case 'Set GF Speed':
				var value:Int = Std.parseInt(value1);
				if(Math.isNaN(value) || value < 1) value = 1;
				gfSpeed = value;
			case 'Add Camera Zoom':
				if(ClientPrefs.camZooms && FlxG.camera.zoom < 1.35) {
					var camZoom:Float = Std.parseFloat(value1);
					var hudZoom:Float = Std.parseFloat(value2);
					if(Math.isNaN(camZoom)) camZoom = 0.015;
					if(Math.isNaN(hudZoom)) hudZoom = 0.03;

					FlxG.camera.zoom += camZoom;
					camHUD.zoom += hudZoom;
				}
			case 'Play Animation':
				//trace('Anim to play: ' + value1);
				var char:Character = dad;
				switch(value2.toLowerCase().trim()) {
					case 'bf' | 'boyfriend':
						char = boyfriend;
					case 'gf' | 'girlfriend':
						char = gf;
					default:
						var val2:Int = Std.parseInt(value2);
						if(Math.isNaN(val2)) val2 = 0;

						switch(val2) {
							case 1: char = boyfriend;
							case 2: char = gf;
						}
				}

				if (char != null){
					char.playAnim(value1, true);
					char.specialAnim = true;
				}


			case 'Camera Follow Pos':
				var val1:Float = Std.parseFloat(value1);
				var val2:Float = Std.parseFloat(value2);

				if(Math.isNaN(val1)) val1 = 0;
				if(Math.isNaN(val2)) val2 = 0;
				
				if(!Math.isNaN(Std.parseFloat(value1)) || !Math.isNaN(Std.parseFloat(value2))) {
					customCamera.x = val1;
					customCamera.y = val2;
					addCameraPoint(customCamera);
				}else
					cameraPoints.remove(customCamera);

			case 'Alt Idle Animation':
				var char:Character = dad;
				switch(value1.toLowerCase()) {
					case 'gf' | 'girlfriend':
						char = gf;
					case 'boyfriend' | 'bf':
						char = boyfriend;
					default:
						var val:Int = Std.parseInt(value1);
						if(Math.isNaN(val)) val = 0;

						switch(val) {
							case 1: char = boyfriend;
							case 2: char = gf;
						}
				}

				if (char != null)
				{
					char.idleSuffix = value2;
					char.recalculateDanceIdle();
				}

			case 'Screen Shake':
				var valuesArray:Array<String> = [value1, value2];
				var targetsArray:Array<FlxCamera> = [camGame, camHUD];
				for (i in 0...targetsArray.length) {
					var split:Array<String> = valuesArray[i].split(',');
					var duration:Float = 0;
					var intensity:Float = 0;
					if(split[0] != null) duration = Std.parseFloat(split[0].trim());
					if(split[1] != null) intensity = Std.parseFloat(split[1].trim());
					if(Math.isNaN(duration)) duration = 0;
					if(Math.isNaN(intensity)) intensity = 0;

					if(duration > 0 && intensity != 0) {
						targetsArray[i].shake(intensity, duration);
					}
				}

			case 'Change Character':
				var charType:Int = 0;
				switch(value1) {
					case 'gf' | 'girlfriend':
						charType = 2;
					case 'dad' | 'opponent':
						charType = 1;
					default:
						charType = Std.parseInt(value1);
						if(Math.isNaN(charType)) charType = 0;
				}

				var curChar:Character = boyfriend;
				switch(charType){
					case 2:
						curChar = gf;
					case 1:
						curChar = dad;
					case 0:
						curChar = boyfriend;
				}

				var newCharacter:String = value2;
				var anim:String = '';
				var frame:Int = 0;
				if(newCharacter.startsWith(curChar.curCharacter) || curChar.curCharacter.startsWith(newCharacter)){
					if(curChar.animation!=null && curChar.animation.curAnim!=null){
						anim = curChar.animation.curAnim.name;
						frame = curChar.animation.curAnim.curFrame;
					}
				}

				changeCharacter(value2, charType);
				if(anim!=''){
					var char:Character = boyfriend;
					switch(charType){
						case 2:
							char = gf;
						case 1:
							char = dad;
						case 0:
							char = boyfriend;
					}

					if(char.animation.getByName(anim)!=null){
						char.playAnim(anim, true);
						char.animation.curAnim.curFrame = frame;
					}
				}

			case 'Change Scroll Speed':
				if (songSpeedType == "constant")
					return;
				var val1:Float = Std.parseFloat(value1);
				var val2:Float = Std.parseFloat(value2);
				if(Math.isNaN(val1)) val1 = 1;
				if(Math.isNaN(val2)) val2 = 0;

				var newValue:Float = SONG.speed * ClientPrefs.getGameplaySetting('scrollspeed', 1) * val1;

				if(val2 <= 0)
				{
					songSpeed = newValue;
				}
				else
				{
					songSpeedTween = FlxTween.tween(this, {songSpeed: newValue}, val2, {ease: FlxEase.linear, onComplete:
						function (twn:FlxTween)
						{
							songSpeedTween = null;
						}
					});
				}

			case 'Set Property':
				var value2:Dynamic = value2;
				switch (value2){
					case "true":
						value2 = true;
					case "false":
						value2 = false;
				}

				var killMe:Array<String> = value1.split('.');
				try{
					if(killMe.length > 1) 
						FunkinLua.setVarInArray(FunkinLua.getPropertyLoopThingWhatever(killMe, true, true), killMe[killMe.length - 1], value2);
					else 
						FunkinLua.setVarInArray(this, value1, value2);			
				}catch (e:haxe.Exception){

				}
		}
		callOnScripts('onEvent', [eventName, value1, value2]);
		if(eventScripts.exists(eventName))
			callScript(eventScripts.get(eventName), "onTrigger", [value1, value2]);
	}

	//// Kinda rewrote the camera shit so that its 'easier' to mod
	public function moveCameraSection(section:SwagSection)
	{
		if (section.gfSection && gf != null){
			if (callOnScripts('onMoveCamera', ["gf"]) != Globals.Function_Stop)
				moveCamera(gf);
		}else if (section.mustHitSection){
			if (callOnScripts('onMoveCamera', ["bf"]) != Globals.Function_Stop)
				moveCamera(boyfriend);
		}else{
			if (callOnScripts('onMoveCamera', ["dad"]) != Globals.Function_Stop)
				moveCamera(dad);			
		}
	}
	public function moveCamera(?char:Character)
	{
		focusedChar = char;
		if (char != null){
			var cam = getCharacterCamera(char);
			sectionCamera.set(cam[0], cam[1]);
		}
	}
	static public function getCharacterCamera(char:Character) {
		return [
			char.x + char.width * 0.5 + (char.cameraPosition[0] + 150) * char.xFacing,
			char.y + char.height * 0.5 + char.cameraPosition[1] - 100
		];
	}

	public function finishSong(?ignoreNoteOffset:Bool = false):Void
	{
		var finishCallback:Void->Void = endSong; //In case you want to change it in a specific song.

		updateTime = false;
		FlxG.sound.music.volume = 0;
		vocals.volume = 0;
		vocals.pause();
		for (track in tracks){
			track.volume = 0;
			track.pause();
		}

		if(ClientPrefs.noteOffset <= 0 || ignoreNoteOffset) {
			finishCallback();
		} else {
			finishTimer = new FlxTimer().start(ClientPrefs.noteOffset / 1000, function(tmr:FlxTimer) {
				finishCallback();
			});
		}
	}


	public var transitioning = false;
	public function endSong():Void
	{
		//Should kill you if you tried to cheat
		if(!startingSong) {
			notes.forEach(function(daNote:Note) {
				if(daNote.strumTime < songLength - Conductor.safeZoneOffset) {
					health -= 0.05 * healthLoss;
				}
			});
			for (daNote in unspawnNotes) {
				if(daNote.strumTime < songLength - Conductor.safeZoneOffset) {
					health -= 0.05 * healthLoss;
				}
			}

			if(doDeathCheck())
				return;
		}

		timeBarBG.visible = false;
		timeBar.visible = false;
		timeTxt.visible = false;
		canPause = false;
		endingSong = true;
		camZooming = false;
		inCutscene = false;
		updateTime = false;

		deathCounter = 0;
		seenCutscene = false;

		#if ACHIEVEMENTS_ALLOWED
		if(achievementObj != null) {
			return;
		} else {
			var achieve:String = checkForAchievement(['week1_nomiss', 'week2_nomiss', 'week3_nomiss', 'week4_nomiss',
				'week5_nomiss', 'week6_nomiss', 'ur_bad',
				'ur_good', 'hype', 'two_keys', 'toastie', 'debugger']);

			if(achieve != null) {
				startAchievement(achieve);
				return;
			}
		}
		#end

		#if (LUA_ALLOWED || hscript)
		var ret:Dynamic = callOnScripts('onEndSong');
		#else
		var ret:Dynamic = Globals.Function_Continue;
		#end

		if(ret != Globals.Function_Stop && !transitioning) {
			#if !switch
			if (SONG.validScore)
			{
				var percent:Float = ratingPercent;
				if(Math.isNaN(percent)) percent = 0;
				Highscore.saveScore(SONG.song, songScore, percent);	
			}
			#end

			if (chartingMode)
			{
				openChartEditor();
				return;
			}

			if (isStoryMode)
			{
				campaignScore += songScore;
				campaignMisses += songMisses;

				storyPlaylist.remove(storyPlaylist[0]);

				if (storyPlaylist.length <= 0)
				{
					MusicBeatState.playMenuMusic(1, true);

					cancelMusicFadeTween();
					if(FlxTransitionableState.skipNextTransIn) {
						CustomFadeTransition.nextCamera = null;
					}
					MusicBeatState.switchState(new StoryMenuState());

					// if ()
					if(!ClientPrefs.getGameplaySetting('practice', false) && !ClientPrefs.getGameplaySetting('botplay', false)) {
						StoryMenuState.weekCompleted.set(ChapterData.curChapter.directory, true);

						if (SONG.validScore && ChapterData.curChapter != null)
							Highscore.saveWeekScore(ChapterData.curChapter.directory, campaignScore);

						FlxG.save.data.weekCompleted = StoryMenuState.weekCompleted;
						FlxG.save.flush();
					}
				}
				else
				{
					trace('LOADING NEXT SONG');
					trace(Paths.formatToSongPath(PlayState.storyPlaylist[0]));

					FlxTransitionableState.skipNextTransIn = true;
					FlxTransitionableState.skipNextTransOut = true;

					prevCamFollow = camFollow;
					prevCamFollowPos = camFollowPos;

					PlayState.SONG = Song.loadFromJson(PlayState.storyPlaylist[0], PlayState.storyPlaylist[0]);
					FlxG.sound.music.stop();

					cancelMusicFadeTween();
					LoadingState.loadAndSwitchState(new PlayState());
				}
			}
			else
			{
				trace('WENT BACK TO FREEPLAY??');
				cancelMusicFadeTween();
				if(FlxTransitionableState.skipNextTransIn) {
					CustomFadeTransition.nextCamera = null;
				}
				MusicBeatState.playMenuMusic(1, true);
				MusicBeatState.switchState(new FreeplayState());
			}
			transitioning = true;
		}
	}

	#if ACHIEVEMENTS_ALLOWED
	var achievementObj:AchievementObject = null;
	function startAchievement(achieve:String) {
		achievementObj = new AchievementObject(achieve, camOther);
		achievementObj.onFinish = achievementEnd;
		add(achievementObj);
		trace('Giving achievement ' + achieve);
	}
	function achievementEnd():Void
	{
		achievementObj = null;
		if(endingSong && !inCutscene) {
			endSong();
		}
	}
	#end

	public function KillNotes() {
		while(notes.length > 0) {
			var daNote:Note = notes.members[0];
			daNote.active = false;
			daNote.visible = false;

			if(modchartObjects.exists('note${daNote.ID}'))modchartObjects.remove('note${daNote.ID}');
			daNote.kill();
			notes.remove(daNote, true);
			daNote.destroy();
		}
		unspawnNotes = [];
		eventNotes = [];
	}

	public var totalPlayed:Int = 0;
	public var totalNotesHit:Float = 0.0;

	var lastJudge:RatingSprite;
	var lastCombos:Array<RatingSprite> = [];

	private function popUpScore(note:Note = null):Void
	{
		var noteDiff:Float = Math.abs(note.strumTime - Conductor.songPosition + ClientPrefs.ratingOffset);
		//trace(noteDiff);

		vocals.volume = 1;

		//tryna do MS based judgment due to popular demand
		var daRating:Rating = Conductor.judgeNote(note, noteDiff);

		totalNotesHit += daRating.ratingMod;
		note.ratingMod = daRating.ratingMod;
		if(!note.ratingDisabled) daRating.increase();
		note.rating = daRating.name;

		if(daRating.noteSplash && !note.noteSplashDisabled)
			spawnNoteSplashOnNote(note);

		if(!practiceMode && !cpuControlled) {
			songScore += daRating.score;

			if(!note.ratingDisabled)
			{
				songHits++;
				totalPlayed++;
				RecalculateRating();
			}

			if(ClientPrefs.scoreZoom)
			{
				if(scoreTxtTween != null) scoreTxtTween.cancel();
				
				scoreTxt.scale.x = 1.075;
				scoreTxt.scale.y = 1.075;
				scoreTxtTween = FlxTween.tween(scoreTxt.scale, {x: 1, y: 1}, 0.2, {
					onComplete: function(twn:FlxTween) {
						scoreTxtTween = null;
					}
				});
			}
		}
		
		////
		var rating:RatingSprite;

		if (ClientPrefs.simpleJudge){
			rating = lastJudge;
			rating.revive();

			if (rating.tween != null){
				rating.tween.cancel();
				rating.tween.destroy();
			}

			rating.scale.set(0.7*1.1,0.7*1.1);
			
			rating.tween = FlxTween.tween(rating.scale, {x: 0.7, y: 0.7}, 0.1, {
				ease: FlxEase.quadOut,
				onComplete: function(tween:FlxTween){
					if (!rating.alive)
						return;

					rating.tween = FlxTween.tween(rating.scale, {x: 0, y: 0}, 0.2, {
						startDelay: 0.6,
						ease: FlxEase.quadIn,
						onComplete: function(tween:FlxTween){rating.kill();}		
					});
				}	
			});

		}else{
			rating = ratingTxtGroup.recycle(RatingSprite, RatingSprite.newRating);
			
			rating.acceleration.y = 550;
			rating.velocity.set(-FlxG.random.int(0, 10), -FlxG.random.int(140, 175));

			rating.alpha = 1;

			rating.tween = FlxTween.tween(rating, {alpha: 0}, 0.2, {
				startDelay: Conductor.crochet * 0.001,
				onComplete: function(wtf){rating.kill();}
			});
		}

		rating.loadGraphic(Paths.image(daRating.image));
		rating.updateHitbox();
		
		rating.screenCenter();
		rating.x += ClientPrefs.comboOffset[0];
		rating.y -= ClientPrefs.comboOffset[1];

		ratingTxtGroup.remove(rating, true);
		ratingTxtGroup.add(rating);

		////
		if (ClientPrefs.simpleJudge){
			for (prevCombo in lastCombos){
				prevCombo.kill();
			}
		}else if (combo < 10 && combo != 0)
			return;

		var separatedScore:Array<String> = Std.string(combo).split("");
		while (separatedScore.length < 3)
			separatedScore.unshift("0");

		var daLoop:Int = 0;
		for (i in separatedScore)
		{
			var numScore:RatingSprite = comboNumGroup.recycle(RatingSprite, RatingSprite.newNumber);
			numScore.loadGraphic(Paths.image('num' + i));

			numScore.screenCenter();
			numScore.x += ClientPrefs.comboOffset[2] + 43 * daLoop;
			numScore.y -= ClientPrefs.comboOffset[3];

			if (numScore.tween != null){
				numScore.tween.cancel();
				numScore.tween.destroy();
			}

			comboNumGroup.remove(numScore, true);
			comboNumGroup.add(numScore);

			if(ClientPrefs.simpleJudge){
				numScore.scale.x = 0.5 * 1.25;
				numScore.scale.y = 0.5 * 0.75;
				
				numScore.alpha = 0.6;
				numScore.tween = FlxTween.tween(numScore, {"scale.x": 0.5, "scale.y": 0.5, alpha: 1}, 0.2, {
					ease: FlxEase.circOut
				});

				lastCombos.push(numScore);
			}else{
				numScore.acceleration.y = FlxG.random.int(200, 300);
				numScore.velocity.set(FlxG.random.float(-5, 5), -FlxG.random.int(140, 160));

				numScore.alpha = 1;
				numScore.tween = FlxTween.tween(numScore, {alpha: 0}, 0.2, {
					onComplete: function(wtf){numScore.kill();},
					startDelay: Conductor.crochet * 0.002
				});
			}

			daLoop++;
		}
	}

	public var strumsBlocked:Array<Bool> = [];
	private function onKeyPress(event:KeyboardEvent):Void
	{
		var eventKey:FlxKey = event.keyCode;
		var key:Int = getKeyFromEvent(eventKey);
		//trace('Pressed: ' + eventKey);

		if (!cpuControlled && startedCountdown && !paused && key > -1 && (FlxG.keys.checkStatus(eventKey, JUST_PRESSED) || ClientPrefs.controllerMode))
		{
			if(!boyfriend.stunned && generatedMusic && !endingSong)
			{
				//more accurate hit time for the ratings?
				var lastTime:Float = Conductor.songPosition;
				Conductor.songPosition = FlxG.sound.music.time;

				var canMiss:Bool = !ClientPrefs.ghostTapping;

				// heavily based on my own code LOL if it aint broke dont fix it
				var pressNotes:Array<Note> = [];
				//var notesDatas:Array<Int> = [];
				var notesStopped:Bool = false;

				var sortedNotesList:Array<Note> = [];
				notes.forEachAlive(function(daNote:Note)
				{
					if (strumsBlocked[daNote.noteData] != true && daNote.canBeHit && daNote.mustPress && !daNote.tooLate && !daNote.wasGoodHit && !daNote.isSustainNote && !daNote.blockHit)
					{
						if(daNote.noteData == key)
						{
							sortedNotesList.push(daNote);
							//notesDatas.push(daNote.noteData);
						}
						canMiss = true;
					}
				});
				sortedNotesList.sort(sortHitNotes);

				if (sortedNotesList.length > 0) {
					for (epicNote in sortedNotesList)
					{
						for (doubleNote in pressNotes) {
							if (Math.abs(doubleNote.strumTime - epicNote.strumTime) < 1) {
								doubleNote.kill();
								notes.remove(doubleNote, true);
								doubleNote.destroy();
							} else
								notesStopped = true;
						}

						// eee jack detection before was not super good
						if (!notesStopped) {
							goodNoteHit(epicNote);
							pressNotes.push(epicNote);
						}

					}
				}
				else{
					callOnScripts('onGhostTap', [key]);
					if (canMiss)
						noteMissPress(key);
				}

				// I dunno what you need this for but here you go
				//									- Shubs

				// Shubs, this is for the "Just the Two of Us" achievement lol
				//									- Shadow Mario
				keysPressed[key] = true;

				//more accurate hit time for the ratings? part 2 (Now that the calculations are done, go back to the time it was before for not causing a note stutter)
				Conductor.songPosition = lastTime;
			}

			var spr:StrumNote = playerStrums.members[key];
			if(strumsBlocked[key] != true && spr != null && spr.animation.curAnim.name != 'confirm')
			{
				spr.playAnim('pressed');
				spr.resetAnim = 0;
			}
			callOnScripts('onKeyPress', [key]);
		}
		//trace('pressed: ' + controlArray);
	}

	function sortHitNotes(a:Note, b:Note):Int
	{
		if (a.lowPriority && !b.lowPriority)
			return 1;
		else if (!a.lowPriority && b.lowPriority)
			return -1;

		return FlxSort.byValues(FlxSort.ASCENDING, a.strumTime, b.strumTime);
	}

	private function onKeyRelease(event:KeyboardEvent):Void
	{
		var eventKey:FlxKey = event.keyCode;
		var key:Int = getKeyFromEvent(eventKey);
		if(!cpuControlled && startedCountdown && !paused && key > -1)
		{
			var spr:StrumNote = playerStrums.members[key];
			if(spr != null)
			{
				spr.playAnim('static');
				spr.resetAnim = 0;
			}
			callOnScripts('onKeyRelease', [key]);
		}
		//trace('released: ' + controlArray);
	}

	private function getKeyFromEvent(key:FlxKey):Int
	{
		if(key != NONE)
		{
			for (i in 0...keysArray.length)
			{
				for (j in 0...keysArray[i].length)
				{
					if(key == keysArray[i][j])
					{
						return i;
					}
				}
			}
		}
		return -1;
	}

	// Hold notes
	public static var pressedGameplayKeys:Array<Bool> = [];

	private function keyShit():Void
	{
		// HOLDING
		var parsedHoldArray:Array<Bool> = parseKeys();
		pressedGameplayKeys = parsedHoldArray;
		
		// TO DO: Find a better way to handle controller inputs, this should work for now
		if (ClientPrefs.controllerMode)
		{
			var parsedArray:Array<Bool> = parseKeys('_P');
			if (parsedArray.contains(true))
			{
				for (i in 0...parsedArray.length)
				{
					if (parsedArray[i] && strumsBlocked[i] != true)
						onKeyPress(new KeyboardEvent(KeyboardEvent.KEY_DOWN, true, true, -1, keysArray[i][0]));
				}
			}
		}

		// FlxG.watch.addQuick('asdfa', upP);
		if (startedCountdown && !boyfriend.stunned && generatedMusic)
		{
			// rewritten inputs???
			
			notes.forEachAlive(function(daNote:Note)
			{
				// hold note functions
				if (strumsBlocked[daNote.noteData] != true && daNote.isSustainNote && parsedHoldArray[daNote.noteData] && daNote.canBeHit
				&& daNote.mustPress && !daNote.tooLate && !daNote.wasGoodHit && !daNote.blockHit) {
					goodNoteHit(daNote);
				}
			});

			if (parsedHoldArray.contains(true) && !endingSong) {
				#if ACHIEVEMENTS_ALLOWED
				var achieve:String = checkForAchievement(['oversinging']);
				if (achieve != null) {
					startAchievement(achieve);
				}
				#end
			}
			
			if (boyfriend.animation.curAnim != null && boyfriend.holdTimer > Conductor.stepCrochet * (0.0011 / FlxG.sound.music.pitch) * boyfriend.singDuration && boyfriend.animation.curAnim.name.startsWith('sing') && !boyfriend.animation.curAnim.name.endsWith('miss') && (boyfriend.idleWhenHold || !pressedGameplayKeys.contains(true)))
				boyfriend.dance();
			
		}

		// TO DO: Find a better way to handle controller inputs, this should work for now
		if (ClientPrefs.controllerMode || strumsBlocked.contains(true))
		{
			var parsedArray:Array<Bool> = parseKeys('_R');
			if (parsedArray.contains(true))
			{
				for (i in 0...parsedArray.length)
				{
					if (parsedArray[i] || strumsBlocked[i] == true)
						onKeyRelease(new KeyboardEvent(KeyboardEvent.KEY_UP, true, true, -1, keysArray[i][0]));
				}
			}
		}
	}

	private function parseKeys(?suffix:String = ''):Array<Bool>
	{
		var ret:Array<Bool> = [];
		for (i in 0...controlArray.length)
			ret[i] = Reflect.getProperty(controls, controlArray[i] + suffix);
		return ret;
	}

	function noteMiss(daNote:Note):Void { //You didn't hit the key and let it go offscreen, also used by Hurt Notes
		//Dupe note remove
		notes.forEachAlive(function(note:Note) {
			if (daNote != note && daNote.mustPress && daNote.noteData == note.noteData && daNote.isSustainNote == note.isSustainNote && Math.abs(daNote.strumTime - note.strumTime) < 1) {
				if(modchartObjects.exists('note${note.ID}'))modchartObjects.remove('note${note.ID}');
				note.kill();
				notes.remove(note, true);
				note.destroy();
			}
		});

		if (ClientPrefs.ghostTapping && !daNote.isSustainNote) // i missed this sound
			FlxG.sound.play(Paths.soundRandom('missnote', 1, 3), FlxG.random.float(0.1, 0.2));

		combo = 0;
		while (lastCombos.length > 0)
			lastCombos.shift().kill();	
		
		health -= daNote.missHealth * healthLoss;
		
		if(instakillOnMiss)
		{
			vocals.volume = 0;
			//doDeathCheck(true);
		}

		//For testing purposes
		//trace(daNote.missHealth);
		songMisses++;
		vocals.volume = 0;
		if(!practiceMode) songScore -= 10;

		totalPlayed++;
		RecalculateRating();

		var char:Character = boyfriend;
		if(daNote.gfNote)char = gf;

		if(char != null && !daNote.noMissAnimation && char.hasMissAnimations)
		{
			if(char.animTimer <= 0 && !char.voicelining){
				var daAlt = '';
				if(daNote.noteType == 'Alt Animation') daAlt = '-alt';

				var animToPlay:String = singAnimations[Std.int(Math.abs(daNote.noteData))] + 'miss' + daAlt;
				char.playAnim(animToPlay, true);
			}
		}

		callOnHScripts("noteMiss", [daNote]);
		#if LUA_ALLOWED
		callOnLuas('noteMiss', [notes.members.indexOf(daNote), daNote.noteData, daNote.noteType, daNote.isSustainNote, daNote.ID]);
		#end	
	
		//// KE SUSTAIN NOTES
		var num = 0;
		for (child in (daNote.isSustainNote ? daNote.parent.tail : daNote.tail)){
			child.tooLate = true;
			child.ignoreNote = true;
			child.blockHit = true;
			num++;
		}

		if (num > 0){
			health -= 0.2;
			totalPlayed += num;
			songScore -= num * 10;
		}
			
		////
		if (daNote.noteScript!=null)
		{
			var script:Dynamic = daNote.noteScript;

			#if LUA_ALLOWED
			if (script.scriptType == 'lua')
			{
				callScript(script, 'noteMiss', [
					notes.members.indexOf(daNote),
					Math.abs(daNote.noteData),
					daNote.noteType,
					daNote.isSustainNote,
					daNote.ID
				]);
			}
			else
			#end
				callScript(script, "noteMiss", [daNote]);
		}
	}

	function noteMissPress(direction:Int = 1):Void //You pressed a key when there was no notes to press for this key
	{
		if(ClientPrefs.ghostTapping) return; //fuck it

		if (!boyfriend.stunned)
		{
			health -= 0.05 * healthLoss;
			if(instakillOnMiss)
			{
				vocals.volume = 0;
				//doDeathCheck(true);
			}

			if (combo > 5 && gf != null && gf.animOffsets.exists('sad'))
			{
				gf.playAnim('sad');
			}
			combo = 0;
			while (lastCombos.length > 0)
				lastCombos.shift().kill();	

			if(!practiceMode) songScore -= 10;
			if(!endingSong) {
				songMisses++;
			}
			totalPlayed++;
			RecalculateRating();

			FlxG.sound.play(Paths.soundRandom('missnote', 1, 3), FlxG.random.float(0.1, 0.2));

			/*boyfriend.stunned = true;

			// get stunned for 1/60 of a second, makes you able to
			new FlxTimer().start(1 / 60, function(tmr:FlxTimer)
			{
				boyfriend.stunned = false;
			});*/

			if(boyfriend.hasMissAnimations) {
				if(boyfriend.animTimer <= 0 && !boyfriend.voicelining)
					boyfriend.playAnim(singAnimations[Std.int(Math.abs(direction))] + 'miss', true);
			}
			vocals.volume = 0;
		}

		callOnScripts('noteMissPress', [direction]);
	}

	function opponentNoteHit(note:Note):Void
	{
		if (Paths.formatToSongPath(SONG.song) != 'tutorial')
			camZooming = true;

		var char:Character = note.gfNote ? gf : dad;

		char.callOnScripts("playNote", [note]);

		if(note.noteType == 'Hey!' && char.animOffsets.exists('hey')) {
			char.playAnim('hey', true);
			char.specialAnim = true;
			char.heyTimer = 0.6;
		} else if(!note.noAnimation) {
			var altAnim:String = "";

			var curSection = SONG.notes[curSection];
			if (curSection != null && (curSection.altAnim || note.noteType == 'Alt Animation')) 
				altAnim = '-alt';

			var animToPlay:String = singAnimations[Std.int(Math.abs(note.noteData))] + altAnim;

			if (char != null && char.animTimer <= 0 && !char.voicelining){
				char.playAnim(animToPlay, true);
				char.holdTimer = 0;
				char.callOnScripts("playNoteAnim", [animToPlay, note]);
			}
		}

		if (SONG.needsVoices)
			vocals.volume = 1;
		
		if (note.visible){
			var time:Float = 0.15;
			if (note.isSustainNote && !note.animation.curAnim.name.endsWith('end'))
			time += 0.15;

			StrumPlayAnim(true, Std.int(Math.abs(note.noteData)), time, note);
		}

		note.hitByOpponent = true;

		callOnHScripts("opponentNoteHit", [note]);
		#if LUA_ALLOWED
		callOnLuas('opponentNoteHit', [notes.members.indexOf(note), Math.abs(note.noteData), note.noteType, note.isSustainNote, note.ID]);
		#end

		if (note.noteScript != null)
		{
			var script:Dynamic = note.noteScript;

			#if LUA_ALLOWED
			if (script.scriptType == 'lua'){
				callScript(script, 'opponentNoteHit',
				[
					notes.members.indexOf(note),
					Math.abs(note.noteData),
					note.noteType,
					note.isSustainNote,
					note.ID
				]);
			}
			else
			#end
				callScript(script, "opponentNoteHit", [note]); 
		}
		if (!note.isSustainNote)
		{
			if (opponentHPDrain > 0 && health > opponentHPDrain)
				health -= opponentHPDrain;

			if(modchartObjects.exists('note${note.ID}'))modchartObjects.remove('note${note.ID}');
			note.kill();
			notes.remove(note, true);
			note.destroy();
		}
	}

	function goodNoteHit(note:Note):Void
	{
		if (note.wasGoodHit || (cpuControlled && (note.ignoreNote || note.hitCausesMiss)))
			return;

		if (ClientPrefs.hitsoundVolume > 0 && !note.hitsoundDisabled)
			FlxG.sound.play(Paths.sound('hitsound'), ClientPrefs.hitsoundVolume);

		// Strum animations
		if (note.visible){
			if(cpuControlled){
				var time:Float = 0.15;
				if(note.isSustainNote && !note.animation.curAnim.name.endsWith('end'))
					time += 0.15;

				StrumPlayAnim(false, Std.int(Math.abs(note.noteData)), time, note);
			}else{
				var spr = playerStrums.members[note.noteData];
				if(spr != null)
					spr.playAnim('confirm', true, note);
			}
		}

		//
		if(note.hitCausesMiss) {
			noteMiss(note);

			if(!note.noteSplashDisabled && !note.isSustainNote)
				spawnNoteSplashOnNote(note);

			if (!note.noMissAnimation)
			{
				switch (note.noteType)
				{
					case 'Hurt Note': // Hurt note
						if (boyfriend.animation.getByName('hurt') != null){
							boyfriend.playAnim('hurt', true);
							boyfriend.specialAnim = true;
						}
				}
			}

			note.wasGoodHit = true;
			if (!note.isSustainNote)
			{
				if(modchartObjects.exists('note${note.ID}'))modchartObjects.remove('note${note.ID}');
				note.kill();
				notes.remove(note, true);
				note.destroy();
			}
			return;
		}

		if (!note.isSustainNote)
		{
			combo++;
			popUpScore(note);
		}

		var hitHealth = note.ratingHealth.get(note.rating);
		health += hitHealth == null ? 0 : hitHealth * healthGain;

		// Sing animations

		var char = note.gfNote ? gf : boyfriend;
		char.callOnScripts("playNote", [note]);

		if(!note.noAnimation) {
			var daAlt = note.noteType == 'Alt Animation' ? '-alt' : '';
			var animToPlay:String = singAnimations[Std.int(Math.abs(note.noteData))];

			if (char != null && char.animTimer <= 0 && !char.voicelining){
				char.playAnim(animToPlay + daAlt, true);
				char.holdTimer = 0;
				char.callOnScripts("playNoteAnim", [animToPlay + daAlt, note]);
			}

			if(note.noteType == 'Hey!') {
				if (boyfriend.animTimer <= 0 && !boyfriend.voicelining){
					if(boyfriend.animOffsets.exists('hey')) {
						boyfriend.playAnim('hey', true);
						boyfriend.specialAnim = true;
						boyfriend.heyTimer = 0.6;
					}
				}
				if(gf != null && gf.animOffsets.exists('cheer')) {
					gf.playAnim('cheer', true);
					gf.specialAnim = true;
					gf.heyTimer = 0.6;
				}
			}
		}
		note.wasGoodHit = true;
		vocals.volume = 1;

		// Script shit
		callOnHScripts("goodNoteHit", [note]);
		#if LUA_ALLOWED
		var isSus:Bool = note.isSustainNote; //GET OUT OF MY HEAD, GET OUT OF MY HEAD, GET OUT OF MY HEAD
		var leData:Int = Math.round(Math.abs(note.noteData));
		var leType:String = note.noteType;
		callOnLuas('goodNoteHit', [notes.members.indexOf(note), leData, leType, isSus, note.ID]);
		#end
		
		if (note.noteScript != null)
		{
			var script:FunkinScript = note.noteScript;
			#if LUA_ALLOWED
			if (script.scriptType == 'lua')
				callScript(script, 'goodNoteHit',
					[notes.members.indexOf(note), leData, leType, isSus, note.ID]); 
			else
			#end
				callScript(script, "goodNoteHit", [note]);
		}
		if (!note.isSustainNote){
			if(modchartObjects.exists('note${note.ID}'))modchartObjects.remove('note${note.ID}');
			note.kill();
			notes.remove(note, true);
			note.destroy();
		}
	}

	public function spawnNoteSplashOnNote(note:Note) {
		if(ClientPrefs.noteSplashes && note != null) {
			var strum:StrumNote = playerStrums.members[note.noteData];
			if(strum != null) {
				var mid = strum.getMidpoint();
				spawnNoteSplash(mid.x, mid.y, note.noteData, note);
			}
		}
	}

	public function spawnNoteSplash(x:Float, y:Float, data:Int, ?note:Note = null) {
		var skin:String = splashSkin;
		var hue:Float = ClientPrefs.arrowHSV[data % 4][0] / 360;
		var sat:Float = ClientPrefs.arrowHSV[data % 4][1] / 100;
		var brt:Float = ClientPrefs.arrowHSV[data % 4][2] / 100;

		if(note != null) {
			skin = note.noteSplashTexture;
			hue = note.noteSplashHue;
			sat = note.noteSplashSat;
			brt = note.noteSplashBrt;
		}

		var splash:NoteSplash = grpNoteSplashes.recycle(NoteSplash);
		splash.setupNoteSplash(x, y, data, skin, hue, sat, brt);
		grpNoteSplashes.add(splash);
	}

	private var preventLuaRemove:Bool = false;
	override function destroy() {
		preventLuaRemove = true;
		
		for(script in funkyScripts){
			script.call("onDestroy");
			script.stop();
		}
		hscriptArray = [];
		funkyScripts = [];
		#if LUA_ALLOWED
		luaArray = [];
		#end

		notetypeScripts.clear();
		eventScripts.clear();
		if(!ClientPrefs.controllerMode)
		{
			FlxG.stage.removeEventListener(KeyboardEvent.KEY_DOWN, onKeyPress);
			FlxG.stage.removeEventListener(KeyboardEvent.KEY_UP, onKeyRelease);
		}
		super.destroy();
	}

	public static function cancelMusicFadeTween() {
		if(FlxG.sound.music.fadeTween != null) {
			FlxG.sound.music.fadeTween.cancel();
		}
		FlxG.sound.music.fadeTween = null;
	}

	#if LUA_ALLOWED
	public function removeLua(lua:FunkinLua) {
		if(luaArray != null && !preventLuaRemove) {
			luaArray.remove(lua);
		}
	}
	#end

	var lastStepHit:Int = -1;
	override function stepHit()
	{
		super.stepHit();


		if (Math.abs(FlxG.sound.music.time - (Conductor.songPosition - Conductor.offset)) > 20
			|| (SONG.needsVoices && Math.abs(vocals.time - (Conductor.songPosition - Conductor.offset)) > 20))
		{
			resyncVocals();
		}
		for (track in tracks)
			track.time = FlxG.sound.music.time;

		if(curStep == lastStepHit) {
			return;
		}

		lastStepHit = curStep;
		setOnScripts('curStep', curStep);
		callOnScripts('onStepHit');
	}

	var lastBeatHit:Int = -1;

	public var zoomEveryBeat:Int = 4;

	var lastSection:Int = -1;
	override function beatHit()
	{
		super.beatHit();

		if(lastBeatHit >= curBeat) {
			//trace('BEAT HIT: ' + curBeat + ', LAST HIT: ' + lastBeatHit);
			return;
		}

		if (generatedMusic)
		{
			//notes.sort(FlxSort.byY, ClientPrefs.downScroll ? FlxSort.ASCENDING : FlxSort.DESCENDING);
		}

		if (camZooming && ClientPrefs.camZooms && FlxG.camera.zoom < 1.35 && zoomEveryBeat > 0 && curBeat % zoomEveryBeat == 0)
		{
			FlxG.camera.zoom += 0.015 * camZoomingMult;
			camHUD.zoom += 0.03 * camZoomingMult;
		}

		healthBar.iconScale = 1.2;

		if (gf != null && curBeat % Math.round(gfSpeed * gf.danceEveryNumBeats) == 0 && gf.animation.curAnim != null && !gf.animation.curAnim.name.startsWith("sing") && !gf.stunned)
		{
			gf.dance();
		}
		if (curBeat % boyfriend.danceEveryNumBeats == 0 && boyfriend.animation.curAnim != null && !boyfriend.animation.curAnim.name.startsWith('sing') && !boyfriend.stunned)
		{
			boyfriend.dance();
		}
		if (curBeat % dad.danceEveryNumBeats == 0 && dad.animation.curAnim != null && !dad.animation.curAnim.name.startsWith('sing') && !dad.stunned)
		{
			dad.dance();
		}

		lastBeatHit = curBeat;

		setOnScripts('curBeat', curBeat); //DAWGG?????
		callOnScripts('onBeatHit');
	}

	override function sectionHit(){
		var curSection = SONG.notes[curSection];
		if (curSection != null)
		{
			if (curSection.changeBPM)
			{
				Conductor.changeBPM(curSection.bpm);
				// FlxG.log.add('CHANGED BPM!');
				setOnScripts('curBpm', Conductor.bpm);
				setOnScripts('crochet', Conductor.crochet);
				setOnScripts('stepCrochet', Conductor.stepCrochet);
			}
			setOnScripts('mustHitSection', curSection.mustHitSection);
			setOnScripts('altAnim', curSection.altAnim);
			setOnScripts('gfSection', curSection.gfSection);
			// else
			// Conductor.changeBPM(SONG.bpm);
			setOnScripts("sectionNumber", Math.floor(curStep / 16));
			setOnHScripts("curSection", curSection);
			if (lastSection != Math.floor(curStep / 16))
			{
				lastSection = Math.floor(curStep / 16);
				callOnHScripts("sectionChanged", [curSection]);
				#if LUA_ALLOWED
				callOnLuas("sectionChanged", [Math.floor(curStep / 16)]);
				#end
			}
		}
		// FlxG.log.add('change bpm' + SONG.notes[Std.int(curStep / 16)].changeBPM);

		if (generatedMusic && curSection != null && !endingSong)
		{
			moveCameraSection(curSection);
		}
	}

	public function callOnScripts(event:String, ?args:Array<Dynamic>, ignoreStops:Bool = false, ?exclusions:Array<String>, ?scriptArray:Array<Dynamic>,
			?ignoreSpecialShit:Bool = true)
	{
		var args:Array<Dynamic> = args != null ? args : [];
		
		if (scriptArray == null)
			scriptArray = funkyScripts;
		if(exclusions==null)exclusions = [];
		var returnVal:Dynamic = Globals.Function_Continue;
		for (script in scriptArray)
		{
			if (exclusions.contains(script.scriptName)
				|| ignoreSpecialShit
				&& (notetypeScripts.exists(script.scriptName) || eventScripts.exists(script.scriptName) ) )
			{
				continue;
			}
			var ret:Dynamic = script.call(event, args);
			if (ret == Globals.Function_Halt)
			{
				ret = returnVal;
				if (!ignoreStops)
					return returnVal;
			};
			if (ret != Globals.Function_Continue && ret!=null)
				returnVal = ret;
		}
		if(returnVal==null)returnVal = Globals.Function_Continue;
		return returnVal;
	}

	public function setOnScripts(variable:String, arg:Dynamic, ?scriptArray:Array<Dynamic>)
	{
		if (scriptArray == null)
			scriptArray = funkyScripts;

		for (script in scriptArray)
			script.set(variable, arg);
	}

	public function callScript(script:Dynamic, event:String, args:Array<Dynamic>): Dynamic{
		if((script is FunkinScript)){
			return callOnScripts(event, args, true, [], [script], false);
		}else if((script is Array)){
			return callOnScripts(event, args, true, [], script, false);
		}else if((script is String)){
			var scripts:Array<FunkinScript> = [];
			for(scr in funkyScripts){
				if(scr.scriptName == script)
					scripts.push(scr);
			}
			return callOnScripts(event, args, true, [], scripts, false);
		}
		return Globals.Function_Continue;
	}

	#if hscript
	public function callOnHScripts(event:String, args:Array<Dynamic>, ignoreStops = false, ?exclusions:Array<String>){
		return callOnScripts(event, args, ignoreStops, exclusions, hscriptArray);
	}
	public function setOnHScripts(variable:String, arg:Dynamic){
		return setOnScripts(variable, arg, hscriptArray);
	}

	public function setDefaultHScripts(variable:String, arg:Dynamic){
		FunkinHScript.defaultVars.set(variable, arg);
		return setOnScripts(variable, arg, hscriptArray);
	}
	#end

	#if LUA_ALLOWED
	public var closeLuas:Array<FunkinLua> = [];

	public function callOnLuas(event:String, args:Array<Dynamic>, ignoreStops = false, ?exclusions:Array<String>){
		return callOnScripts(event, args, ignoreStops, exclusions, luaArray);
	}
	public function setOnLuas(variable:String, arg:Dynamic){
		setOnScripts(variable, arg, luaArray);	
	}
	#end

	function StrumPlayAnim(isDad:Bool, id:Int, time:Float, ?note:Note) {
		var spr:StrumNote = null;
		if(isDad)
			spr = opponentStrums.members[id];
		else
			spr = playerStrums.members[id];

		if(spr != null) {
			spr.playAnim('confirm', true, note);
			spr.resetAnim = time;
		}
	}

	public var ratingName:String = '?';
	public var ratingPercent:Float;
	public var ratingFC:String;
	public function RecalculateRating() {
		setOnScripts('score', songScore);
		setOnScripts('misses', songMisses);
		setOnScripts('hits', songHits);

		var ret:Dynamic = callOnScripts('onRecalculateRating');
		if(ret != Globals.Function_Stop)
		{
			if(totalPlayed < 1) //Prevent divide by 0
				ratingName = '?';
			else
			{
				// Rating Percent
				ratingPercent = Math.min(1, Math.max(0, totalNotesHit / totalPlayed));
				//trace((totalNotesHit / totalPlayed) + ', Total: ' + totalPlayed + ', notes hit: ' + totalNotesHit);

				// Rating Name
				if(ratingPercent >= 1)
				{
					ratingName = ratingStuff[ratingStuff.length-1][0]; //Uses last string
				}
				else
				{
					for (i in 0...ratingStuff.length-1)
					{
						if(ratingPercent < ratingStuff[i][1])
						{
							ratingName = ratingStuff[i][0];
							break;
						}
					}
				}
			}

			// Rating FC
			ratingFC = "";
			//if (epics > 0) ratingFC = "EFC";
			if (sicks > 0) ratingFC = "SFC";
			if (goods > 0) ratingFC = "GFC";
			if (bads > 0 || shits > 0) ratingFC = "FC";
			if (songMisses > 0 && songMisses < 10) ratingFC = "SDCB";
			else if (songMisses >= 10) ratingFC = "Clear";
		}
		setOnScripts('rating', ratingPercent);
		setOnScripts('ratingName', ratingName);
		setOnScripts('ratingFC', ratingFC);
	}

	// Shader stuff from andromeda or V3 idrk
	private var camShaders = [];
	private var hudShaders = [];

	public function addCameraEffect(effect:ShaderEffect)
	{
		camShaders.push(effect);

		var newCamEffects:Array<BitmapFilter> = [];
		for (i in camShaders)
			newCamEffects.push(new ShaderFilter(i.shader));

		camGame.setFilters(newCamEffects);
	}
	public function removeCameraEffect(effect:ShaderEffect)
	{
		camShaders.remove(effect);

		var newCamEffects:Array<BitmapFilter> = [];
		for (i in camShaders)
			newCamEffects.push(new ShaderFilter(i.shader));

		camGame.setFilters(newCamEffects);
	}

	public function addHUDEffect(effect:ShaderEffect)
	{
		hudShaders.push(effect);

		var newCamEffects:Array<BitmapFilter> = [];
		for (i in hudShaders)
			newCamEffects.push(new ShaderFilter(i.shader));

		camHUD.setFilters(newCamEffects);
	}
	public function removeHUDEffect(effect:ShaderEffect)
	{
		hudShaders.remove(effect);

		var newCamEffects:Array<BitmapFilter> = [];
		for (i in hudShaders)
			newCamEffects.push(new ShaderFilter(i.shader));

		camHUD.setFilters(newCamEffects);
	}

	////
	public function pause(?OpenPauseMenu = true){
		if (startedCountdown && canPause && health > 0 && !paused)
		{
			if(callOnScripts('onPause') != Globals.Function_Stop) {
				persistentUpdate = false;
				persistentDraw = true;
				paused = true;

				// 0 chance for Gitaroo Man easter egg

				if(FlxG.sound.music != null) {
					FlxG.sound.music.pause();
					vocals.pause();
					for (track in tracks)
						track.pause();
				}

				if (OpenPauseMenu)
					openSubState(new PauseSubState(boyfriend.getScreenPosition().x, boyfriend.getScreenPosition().y));

				#if desktop
				DiscordClient.changePresence(detailsPausedText, SONG.song, Paths.formatToSongPath(SONG.song));
				#end
			}
		}
	}

	override public function switchTo(nextState: Dynamic){
		pressedGameplayKeys = [];
		FunkinHScript.defaultVars.clear();
		return super.switchTo(nextState);
	}
	
}

// mental gymnastics
class FNFHealthBar extends FlxBar{
	public var healthBarBG:FlxSprite;

	public var iconP1:HealthIcon;
	public var iconP2:HealthIcon;

	var leftIcon:HealthIcon;
	var rightIcon:HealthIcon;

	public var iconOffset:Int = 26;

	// public var value:Float = 1;

	override function set_flipX(value:Bool){
		iconP1.flipX = value;
		iconP2.flipX = value;

		// aughhh
		if (flipX){
			leftIcon = iconP1;
			rightIcon = iconP2;
		}else{
			leftIcon = iconP2;
			rightIcon = iconP1;
		}

		updateHealthBarPos();

		return super.set_flipX(value);
	}

	override function set_visible(value:Bool){
		healthBarBG.visible = value;
		iconP1.visible = value;
		iconP2.visible = value;

		return super.set_visible(value);
	}

	override function set_alpha(value:Float){
		healthBarBG.alpha = value;
		iconP1.alpha = value;
		iconP2.alpha = value;

		return super.set_alpha(value);
	}

	public function new(bfHealthIcon = "face", dadHealthIcon = "face")
	{
		//
		healthBarBG = new FlxSprite(0, FlxG.height * (ClientPrefs.downScroll ? 0.11 : 0.89));
		healthBarBG.loadGraphic(Paths.image('healthBar')); 
		healthBarBG.screenCenter(X);
		healthBarBG.scrollFactor.set();

		//
		iconP1 = new HealthIcon(bfHealthIcon, true);
		iconP2 = new HealthIcon(dadHealthIcon, false);
		leftIcon = iconP2;
		rightIcon = iconP1;

		//
		super(
			healthBarBG.x + 5, healthBarBG.y + 5, 
			RIGHT_TO_LEFT, 
			Std.int(healthBarBG.width - 10), Std.int(healthBarBG.height - 10), 
			null, null, 
			0, 2
		);
		value = 1;

		//
		iconP2.setPosition(
			healthBarPos - 75 - iconOffset * 2,
			y - 75
		);
		iconP1.setPosition(
			healthBarPos - iconOffset,
			y - 75
		);

		//
		scrollFactor.set();
		visible = !ClientPrefs.hideHud;
		alpha = ClientPrefs.healthBarAlpha;
	}

	public var iconScale(default, set) = 1.0;
	function set_iconScale(value:Float){
		iconP1.scale.set(value, value);
		iconP2.scale.set(value, value);

		iconP1.updateHitbox();
		iconP2.updateHitbox();

		return iconScale = value;
	}

	private var healthBarPos:Float;
	private function updateHealthBarPos()
	{
		healthBarPos = x + width * (flipX ? value * 0.5 : 1 - value * 0.5) ;
	}

	override function set_value(val:Float){
		iconP1.animation.curAnim.curFrame = val < 0.4 ? 1 : 0; // 20% ?
		iconP2.animation.curAnim.curFrame = val > 1.6 ? 1 : 0; // 80% ?

		super.set_value(val);

		updateHealthBarPos();

		return value;
	}

	override function update(elapsed:Float)
	{
		if (!visible){
			super.update(elapsed);
			return;
		}

		healthBarBG.setPosition(x - 5, y - 5);
		
		if (iconScale != 1){
			iconScale = FlxMath.lerp(1, iconScale, CoolUtil.boundTo(1 - (elapsed * 9), 0, 1));

			var scaleOff = 75 * iconScale;
			leftIcon.x = healthBarPos - scaleOff - iconOffset * 2;
			rightIcon.x = healthBarPos + scaleOff - 75 - iconOffset;
		}
		else
		{
			leftIcon.x = healthBarPos - 75 - iconOffset * 2;
			rightIcon.x = healthBarPos - iconOffset;
		}

		super.update(elapsed);
	}
}

class RatingSprite extends FlxSprite
{
	public var tween:FlxTween;
	
	public function new(){
		super();
		moves = !ClientPrefs.simpleJudge;

		antialiasing = ClientPrefs.globalAntialiasing;
		//cameras = [ClientPrefs.simpleJudge ? PlayState.instance.camHUD : PlayState.instance.camGame];
		cameras = [PlayState.instance.camHUD];

		scrollFactor.set();
	}

	override public function kill(){
		if (tween != null){
			tween.cancel();
			tween.destroy();
		}
		return super.kill();
	}

	public static function newRating()
	{
		var rating = new RatingSprite();
		// rating.acceleration.y = 550;
		rating.scale.set(0.7, 0.7);

		return rating;
	}

	public static function newNumber()
	{
		var numScore = new RatingSprite();
		numScore.scale.set(0.5, 0.5);

		return numScore;
	}
}