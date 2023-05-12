package;

import flixel.util.FlxSpriteUtil.LineStyle;
import openfl.display.BitmapData;
import FreeplayState.FreeplayCategory;
import JudgmentManager.JudgmentData;
import JudgmentManager.Judgment;
import hud.PsychHUD;
import hud.BaseHUD;
import sys.FileSystem;
import sys.io.File;
import flixel.group.FlxGroup;
#if ACHIEVEMENTS_ALLOWED
import Achievements;
#end
import Cache;

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
import hxcodec.VideoHandler;
#end

typedef SongCreditdata = // beacuse SongMetadata is stolen
{
	artist:String,
	charter:String,
	?modcharter:Array<String>,
	?extraInfo:Array<String>,
}

/*
okay SO im gonna explain how these work

All speed changes are stored in an array, .sort()'d by the time
if changes[0].songTime is above conductor.songposition then 
	- it'll remove the first element of changes
	- it'll store the position, songTime and speed of the change somewhere
	- and then it'll songVisualPos = event.position + getVisPos(conductor.songPosition - event.songTime, songSpeed * event.speed)

all notes will also store their visualPos in a variable when creation and then when moving notes it's just
	note.y = note.visualPos - event.position
:3

EDIT: not EXACTLY how it works but its a good enough summary
*/
typedef SpeedEvent =
{
	position:Float, // the y position when the change happens (modManager.getVisPos(songTime))
	songTime:Float, // the song position (conductor.songTime) when the changer happens
	speed:Float // speed mult after the change
}

// Etterna
class Wife3
{
	public static var missWeight:Float = -5.5;
	public static var mineWeight:Float = -7;
	public static var holdDropWeight:Float = -4.5;
	public static var a1 = 0.254829592;
	public static var a2 = -0.284496736;
	public static var a3 = 1.421413741;
	public static var a4 = -1.453152027;
	public static var a5 = 1.061405429;
	public static var p = 0.3275911;

	public static function werwerwerwerf(x:Float):Float
	{
		var sign = 1;
		if (x < 0)sign = -1;
		x = Math.abs(x);
		var t = 1 / (1+p*x);
		var y = 1 - (((((a5*t+a4)*t)+a3)*t+a2)*t+a1)*t*Math.exp(-x*x);
		return sign*y;
	}

	public static var timeScale:Float = 1;
	public static function getAcc(noteDiff:Float, ?ts:Float):Float{ // https://github.com/etternagame/etterna/blob/0a7bd768cffd6f39a3d84d76964097e43011ce33/src/RageUtil/Utils/RageUtil.h
		if(ts==null)ts=timeScale;
		if(ts>1)ts=1;
		var jPow:Float = 0.75;
		var maxPoints:Float = 2.0;
		var ridic:Float = 5 * ts;
		var shit_weight:Float = 200;
		var absDiff = Math.abs(noteDiff);
		var zero:Float = 65 * Math.pow(ts, jPow);
		var dev:Float = 22.7 * Math.pow(ts, jPow);

		if(absDiff<=ridic){
			return maxPoints;
		} else if(absDiff<=zero){
			return maxPoints*werwerwerwerf((zero-absDiff)/dev);
		}else if(absDiff<=shit_weight){
			return (absDiff-zero)*missWeight/(shit_weight-zero);
		}
		return missWeight;
	}


}
class PlayState extends MusicBeatState
{
	public static var difficulty:Int = 1; // for psych mod shit
	public static var difficultyName:String = ''; // for psych mod shit
	public var noteHits:Array<Float> = [];
	public var nps:Int = 0;
	public var currentSV:SpeedEvent = {position: 0, songTime:0, speed: 1};
	public var judgeManager:JudgmentManager;

	var speedChanges:Array<SpeedEvent> = [];
	var subtitles:Null<SubtitleDisplay>;
	
	public var metadata:SongCreditdata; // metadata for the songs (artist, etc)

	// andromeda modcharts :D
	public var modManager:ModManager;

	public var whosTurn:String = '';
	public var focusedChar:Character;

	public static var STRUM_X = 42;
	public static var STRUM_X_MIDDLESCROLL = -278;
	public static var arrowSkin:String = '';
	public static var splashSkin:String = '';

	public var ratingStuff:Array<Array<Dynamic>> = Highscore.grades.get(ClientPrefs.gradeSet);
	
/* 	public static var ratingStuff:Array<Array<Dynamic>> = [
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
	]; */
	
	public var scoreTxt:FlxText = new FlxText(); // just so psych mods n shit dont error
	public var modchartTweens:Map<String, FlxTween> = new Map<String, FlxTween>();
	public var modchartSprites:Map<String, ModchartSprite> = new Map<String, ModchartSprite>();
	public var modchartTimers:Map<String, FlxTimer> = new Map<String, FlxTimer>();
	public var modchartSounds:Map<String, FlxSound> = new Map<String, FlxSound>();
	public var modchartTexts:Map<String, ModchartText> = new Map<String, ModchartText>();
	public var modchartSaves:Map<String, FlxSave> = new Map<String, FlxSave>();
	public var modchartObjects:Map<String, FlxSprite> = new Map<String, FlxSprite>();

	public var boyfriendMap:Map<String, Character> = new Map();
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
	public var boyfriend:Character = null;

	public var gfSpeed:Int = 1;

	public var notes = new FlxTypedGroup<Note>();
	public var unspawnNotes:Array<Note> = [];
	public var allNotes:Array<Note> = []; // all notes

	public var eventNotes:Array<EventNote> = [];

	public var strumLineNotes = new FlxTypedGroup<StrumNote>();
	public var opponentStrums = new FlxTypedGroup<StrumNote>();
	public var playerStrums = new FlxTypedGroup<StrumNote>();

	public var playerField:PlayField;
	public var dadField:PlayField;

	public var playfields = new FlxTypedGroup<PlayField>();
	public var hud:BaseHUD;

	public var grpNoteSplashes = new FlxTypedGroup<NoteSplash>();

	public var stageOpacity:FlxSprite = new FlxSprite();
	
	////

	
	public var ratingTxtGroup = new FlxTypedGroup<RatingSprite>();
	public var comboNumGroup = new FlxTypedGroup<RatingSprite>();
	public var timingTxt:FlxText; // TODO: replace this with the combo numbers maybe
	
	// We could also make it calibri or another custom font?
	// Since as you said, combo numbers could be hard to read
	// (We could also add a dropdown for it? idk lol)
	// -neb

	private var curSong:String = "";

	public var iconOffset:Int = 26;
	public var displayedHealth(default, set):Float = 1;
	function set_displayedHealth(value:Float){
		if (healthBar.alpha > 0){
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

	public var comboBreaks:Int = 0; 
	public var judges:Map<String, Int> = [
		"epic" => 0,
		"sick" => 0,
		"good" => 0,
		"bad" => 0,
		"shit" => 0
	];

	private var generatedMusic:Bool = false;
	public var endingSong:Bool = false;
	public var startingSong:Bool = false;
	private var updateTime:Bool = true;
	public static var chartingMode:Bool = false;

	//Gameplay settings
	public var healthGain:Float = 1;
	public var healthLoss:Float = 1;
	public var playOpponent:Bool = false;
	public var opponentHPDrain:Float = 0.0;
	public var healthDrain:Float = 0.0;

	public var instakillOnMiss:Bool = false;
	public var cpuControlled(default, set) = false;
	function set_cpuControlled(value){
		cpuControlled = value;

		setOnScripts('botPlay', value);

		/// oughhh
		for (playfield in playfields.members){
			if (playfield.isPlayer)
				playfield.autoPlayed = cpuControlled; 
		}

		return value;
	}
	public var saveScore:Bool = true; // whether to save the score. modcharted songs should set this to false if disableModcharts is true
	
	public var disableModcharts:Bool = false;
	public var practiceMode:Bool = false;
	public var perfectMode:Bool = false;
	public var instaRespawn:Bool = false;

	public var healthBar:FNFHealthBar;
	public var healthBarBG:FlxSprite;

	public var iconP1:HealthIcon;
	public var iconP2:HealthIcon;


	var songPercent:Float = 0;

	public var camGame:FlxCamera;
	public var camSubs:FlxCamera; // JUST for subtitles
	public var camStageUnderlay:FlxCamera; // retarded
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
	private var debugKeysBotplay:Array<FlxKey>;
	private var debugKeysCharacter:Array<FlxKey>;

	// Less laggy controls
	private var keysArray:Array<Dynamic>;
	private var controlArray:Array<String>;

	var finishedCreating =false;
	override public function create()
	{
		judgeManager = new JudgmentManager();
		Conductor.safeZoneOffset = ClientPrefs.hitWindow;
		Wife3.timeScale = Conductor.judgeScales.get(ClientPrefs.judgeDiff);
		judgeManager.judgeTimescale = Wife3.timeScale;

		Paths.clearStoredMemory();

		//// Reset to default
		Note.quantShitCache.clear();
		FunkinHScript.defaultVars.clear();

		PauseSubState.songName = null;
		GameOverSubstate.resetVariables();

		////
		FlxG.fixedTimestep = false;
		FlxG.worldBounds.set(0, 0, FlxG.width, FlxG.height);

		persistentUpdate = true;
		persistentDraw = true;

		// for lua
		instance = this;

		if (FlxG.sound.music != null)
			FlxG.sound.music.stop();

		if (MusicBeatState.menuVox != null){
			MusicBeatState.menuVox.stop();
			MusicBeatState.menuVox.destroy();
			MusicBeatState.menuVox = null;
		}

		debugKeysChart = ClientPrefs.copyKey(ClientPrefs.keyBinds.get('debug_1'));
		debugKeysCharacter = ClientPrefs.copyKey(ClientPrefs.keyBinds.get('debug_2'));
		debugKeysBotplay = ClientPrefs.copyKey(ClientPrefs.keyBinds.get('botplay'));

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

		speedChanges.push({
			position: 0,
			songTime: 0,
			speed: 1
		});

		// For the "Just the Two of Us" achievement
		for (i in 0...keysArray.length)
			keysPressed.push(false);

		//// Judgements

		// un-sorry hooda :trollface:

		// TODO: make highscore save differently depending on useEpics & judgement windows 
		// (probably just turn the windows into a string and then use that when loading/saving high scores)

/* 		if(ClientPrefs.useEpics){
			var rating:Rating = new Rating('epic');
			rating.ratingMod = 1;
			rating.score = 500;
			rating.noteSplash = true;
			ratingsData.push(rating);
		}
		

		var rating:Rating = new Rating('sick');
		if(ClientPrefs.useEpics){
			rating.ratingMod = 0.975;
			// maybe make epics have the 350 score etc and make sicks, when epics are on, score less
			// so that max scores stay the same

		}
		ratingsData.push(rating);

		var rating:Rating = new Rating('good');
		rating.ratingMod = 0.7;
		rating.score = 200;
		rating.noteSplash = false;
		rating.health = 0;
		ratingsData.push(rating);

		var rating:Rating = new Rating('bad');
		rating.ratingMod = 0.4;
		rating.score = 100;
		rating.health = -0.06;
		rating.noteSplash = false;
		ratingsData.push(rating);

		var rating:Rating = new Rating('shit');
		rating.ratingMod = 0;
		rating.score = 50;
		rating.noteSplash = false;
		rating.health = -0.15;
		ratingsData.push(rating);
 */
		// Gameplay settings
		healthGain = ClientPrefs.getGameplaySetting('healthgain', 1);
		healthLoss = ClientPrefs.getGameplaySetting('healthloss', 1);
		playOpponent = ClientPrefs.getGameplaySetting('opponentPlay', false);
		instakillOnMiss = ClientPrefs.getGameplaySetting('instakill', false);
		practiceMode = ClientPrefs.getGameplaySetting('practice', false);
		perfectMode = ClientPrefs.getGameplaySetting('perfect', false);
		instaRespawn = ClientPrefs.getGameplaySetting('instaRespawn', false);
		cpuControlled = ClientPrefs.getGameplaySetting('botplay', false);
		disableModcharts = !ClientPrefs.modcharts; //ClientPrefs.getGameplaySetting('disableModcharts', false);

		
		if(perfectMode){
			practiceMode = false;
			instakillOnMiss = true;
		}
		saveScore = !cpuControlled;
		healthDrain = switch(ClientPrefs.getGameplaySetting('healthDrain', "Disabled")){
			default: 0;
			case "Basic": 0.00055;
			case "Average": 0.0007;
			case "Heavy": 0.00085;
		};
		opponentHPDrain = ClientPrefs.getGameplaySetting('opponentFightsBack', false) ? 0.0182 : 0;

		//// Camera shit
		camGame = new FlxCamera();
		camHUD = new FlxCamera();
		camOverlay = new FlxCamera();
		camOther = new FlxCamera();
		camSubs = new FlxCamera();
		camStageUnderlay = new FlxCamera();

		camSubs.bgColor.alpha = 0;
		camStageUnderlay.bgColor.alpha = 0; 
		camHUD.bgColor.alpha = 0; 
		camOverlay.bgColor.alpha = 0;
		camOther.bgColor.alpha = 0;

		FlxG.cameras.reset(camGame);
		FlxG.cameras.add(camStageUnderlay, false);
		FlxG.cameras.add(camHUD, false);
		FlxG.cameras.add(camOverlay, false);
		FlxG.cameras.add(camSubs, false);
		FlxG.cameras.add(camOther, false);

		FlxG.cameras.setDefaultDrawTarget(camGame, true);
		CustomFadeTransition.nextCamera = camOther;

		camFollow = prevCamFollow != null ? prevCamFollow : new FlxPoint();
		camFollowPos = prevCamFollowPos != null ? prevCamFollowPos : new FlxObject(0, 0, 1, 1);

		prevCamFollow = null;
		prevCamFollowPos = null;

		FlxG.camera.follow(camFollowPos, LOCKON, 1);
		FlxG.camera.zoom = defaultCamZoom;
		FlxG.camera.focusOn(camFollow);

		////
		if (SONG == null)
			SONG = Song.loadFromJson('tutorial', 'tutorial');

		if (SONG != null){
			var jason = Paths.songJson(Paths.formatToSongPath(SONG.song) + '/metadata');

			if (!Paths.exists(jason))
				jason = Paths.modsSongJson(Paths.formatToSongPath(SONG.song) + '/metadata');

			if (Paths.exists(jason))
				metadata = cast Json.parse(Paths.getContent(jason));
			else
				trace("No metadata for " + SONG.song + ". Maybe add some?");
			
		}

		Conductor.mapBPMChanges(SONG);
		Conductor.changeBPM(SONG.bpm);

		songName = Paths.formatToSongPath(SONG.song);
		songHighscore = Highscore.getScore(SONG.song);

		////
		arrowSkin = SONG.arrowSkin;
		splashSkin = SONG.splashSkin;

		if (arrowSkin == null || arrowSkin.trim().length == 0)
			arrowSkin = "NOTE_assets";

		if (splashSkin == null || splashSkin.trim().length == 0)
			splashSkin = "noteSplashes";

		// The quant prefix gets handled in the Note class

		//// STAGE SHIT
		if (SONG.stage == null || SONG.stage.length < 1)
			SONG.stage = 'stage';
		curStage = SONG.stage;

		stage = new Stage(curStage);
		stageData = stage.stageData;
		setStageData(stageData);

		//// Asset precaching start
		//// this could be moved to the loadingstate probably
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

		if (ClientPrefs.missVolume != 0){
			shitToLoad.push({path: 'missnote1', type: 'SOUND'});
			shitToLoad.push({path: 'missnote2', type: 'SOUND'});
			shitToLoad.push({path: 'missnote3', type: 'SOUND'});
		}

		/* 
		if (PauseSubState.songName != null)
			shitToLoad.push({path: PauseSubState.songName, type: 'MUSIC'});
		else if (ClientPrefs.pauseMusic != 'None')
			shitToLoad.push({path: Paths.formatToSongPath(ClientPrefs.pauseMusic), type: 'MUSIC'}); 
		*/
		shitToLoad.push({path: "breakfast", type: 'MUSIC'}); 

		if (ClientPrefs.timeBarType != 'Disabled')
			shitToLoad.push({path: "timeBar"});

		////
		if (ClientPrefs.noteSkin == 'Quants'){
			shitToLoad.push({path: 'QUANT$arrowSkin'});
			shitToLoad.push({path: 'QUANT$splashSkin'});
		}else{
			shitToLoad.push({path: arrowSkin});
			shitToLoad.push({path: splashSkin});
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
		for (track in SONG.extraTracks){
			shitToLoad.push({
				path: '$songName/$track',
				type: 'SONG'
			});
		}

		Cache.loadWithList(shitToLoad);
		//// Asset precaching end

		Conductor.songPosition = -5000;

		updateTime = (ClientPrefs.timeBarType != 'Disabled');


		var splash:NoteSplash = new NoteSplash(100, 100, 0);
		splash.alpha = 0.0;
		grpNoteSplashes.add(splash);

		modManager = new ModManager(this);
		setDefaultHScripts("modManager", modManager);

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

			startCharacter(gf);
			gf.scrollFactor.set(0.95, 0.95);
			gfMap.set(gf.curCharacter, gf);
			gfGroup.add(gf);
		}

		dad = new Character(0, 0, SONG.player2);

		if (stageData.camera_opponent != null){
			dad.cameraPosition[0] += stageData.camera_opponent[0];
			dad.cameraPosition[1] += stageData.camera_opponent[1];
		}
		startCharacter(dad, true);
		
		dadMap.set(dad.curCharacter, dad);
		dadGroup.add(dad);

		boyfriend = new Character(0, 0, SONG.player1, true);
		if (stageData.camera_boyfriend != null){
			boyfriend.cameraPosition[0] += stageData.camera_boyfriend[0];
			boyfriend.cameraPosition[1] += stageData.camera_boyfriend[1];
		}
		startCharacter(boyfriend);

		boyfriendMap.set(boyfriend.curCharacter, boyfriend);
		boyfriendGroup.add(boyfriend);

		if(dad.curCharacter.startsWith('gf')) {
			dad.setPosition(GF_X, GF_Y);
			if(gf != null)
				gf.visible = false;
		}
		
		if(ClientPrefs.etternaHUD == 'Advanced')
			hud = new hud.AdvancedHUD(boyfriend.healthIcon, dad.healthIcon, songName);
		else
			hud = new PsychHUD(boyfriend.healthIcon, dad.healthIcon, songName);
		healthBar = hud.healthBar;
		healthBarBG = healthBar.healthBarBG;
		iconP1 = healthBar.iconP1;
		iconP2 = healthBar.iconP2;

		// After all characters being loaded, it makes then invisible 0.01s later so that the player won't freeze when you change characters

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
			if (stage.stageScript is FunkinLua)
				luaArray.push(cast stage.stageScript);
			else
			#end
			hscriptArray.push(cast stage.stageScript);

			funkyScripts.push(stage.stageScript);
		}

		// in case you want to layer shit in a specific way (like in infimario for example)
		// RICO CAN WE STOP USING SLURS IN THE CODE
		// we???
		// fine, can YOU stop using slurs in the code >:(
		if (Globals.Function_Stop != callOnHScripts("onAddSpriteGroups", []))
		{
			add(stage);

			add(gfGroup);
			add(dadGroup);
			add(boyfriendGroup);

			add(stage.foreground);
		}

		// Generate playfields so you can actually, well, play the game
		callOnScripts("prePlayfieldCreation");
		playerField = new PlayField(modManager);
		playerField.modNumber = 0;
		playerField.characters = [boyfriend];
		playerField.isPlayer = !playOpponent;
		playerField.autoPlayed = !playerField.isPlayer || cpuControlled;
		playerField.noteHitCallback = playOpponent ? opponentNoteHit : goodNoteHit;

		dadField = new PlayField(modManager);
		dadField.isPlayer = playOpponent;
		dadField.autoPlayed = !dadField.isPlayer || cpuControlled;
		dadField.modNumber = 1;
		dadField.characters = [dad];
		dadField.noteHitCallback = playOpponent ? goodNoteHit : opponentNoteHit;

		dad.idleWhenHold = !dadField.isPlayer;
		boyfriend.idleWhenHold = !playerField.isPlayer;

		playfields.add(dadField);
		playfields.add(playerField);

		for(field in playfields)
			initPlayfield(field);
		callOnScripts("postPlayfieldCreation");


		////
		cameraPoints = [sectionCamera];
		moveCameraSection(SONG.notes[0]);

		////
		
		hud.songName = SONG.song;
		hud.alpha = ClientPrefs.hudOpacity;
		
		/* This appears above the strumlines despite being added before them?
		var sowy = new FlxSprite().makeGraphic(300, 300);
		sowy.cameras = [camHUD];
		add(sowy);
		*/
		add(hud);

		//
		lastJudge = RatingSprite.newRating();
		ratingTxtGroup.add(lastJudge).kill();
		for (i in 0...3)
			comboNumGroup.add(RatingSprite.newNumber()).kill();
		
		timingTxt = new FlxText();
		timingTxt.setFormat(Paths.font("calibri.ttf"), 28, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		timingTxt.cameras = [camHUD];
		timingTxt.scrollFactor.set();
		timingTxt.borderSize = 1.25;
		
		timingTxt.visible = false;
		timingTxt.alpha = 0;



		// init shit
		health = 1;
		reloadHealthBarColors();

		startingSong = true;


		// SONG SPECIFIC SCRIPTS
		var foldersToCheck:Array<String> = [
			Paths.getPreloadPath('songs/' + songName + '/')
			#if PE_MOD_COMPATIBILITY ,
			Paths.getPreloadPath('data/' + songName + '/')
			#end
		];
		var filesPushed:Array<String> = [];

		#if MODS_ALLOWED
		foldersToCheck.insert(0, Paths.mods('songs/' + songName + '/'));
		#if PE_MOD_COMPATIBILITY
		foldersToCheck.insert(1, Paths.mods('data/' + songName + '/'));
		#end
		if(Paths.currentModDirectory != null && Paths.currentModDirectory.length > 0){
			foldersToCheck.insert(0, Paths.mods(Paths.currentModDirectory + '/songs/' + songName + '/'));
			#if PE_MOD_COMPATIBILITY
			foldersToCheck.insert(1, Paths.mods(Paths.currentModDirectory + '/data/' + songName + '/'));
			#end
		}
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


		var cH = [camHUD];
/* 		if (hitbar != null)
			hitbar.cameras = cH; */
		hud.cameras = cH;
		playerField.cameras = cH;
		dadField.cameras = cH;
		playfields.cameras = cH;
		strumLineNotes.cameras = cH;
		grpNoteSplashes.cameras = cH;
		notes.cameras = cH;
/* 		healthBarBG.cameras = cH;
		healthBar.cameras = cH;
		iconP1.cameras = cH;
		iconP2.cameras = cH; */
/* 		botplayTxt.cameras = cH;
		timeBar.cameras = cH;
		timeBarBG.cameras = cH;
		timeTxt.cameras = cH; */

		// EVENT AND NOTE SCRIPTS WILL GET LOADED HERE
		generateSong(SONG.song);

		#if desktop
		// Discord RPC texts
		detailsText = isStoryMode ? "Story Mode" : "Freeplay";
		detailsPausedText = "Paused - " + detailsText;

		// Updating Discord Rich Presence.
		DiscordClient.changePresence(detailsText, SONG.song, songName);
		#end

		if(!ClientPrefs.controllerMode)
		{
			FlxG.stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyPress);
			FlxG.stage.addEventListener(KeyboardEvent.KEY_UP, onKeyRelease);
		}

		////

		stageOpacity.makeGraphic(1,1,0xFFFFFFFF);
		stageOpacity.color = 0xFF000000;
		stageOpacity.alpha = ClientPrefs.stageOpacity;
		stageOpacity.cameras=[camStageUnderlay]; // just to force it above camGame but below camHUD
		stageOpacity.screenCenter();
		stageOpacity.scale.set(FlxG.width * 100, FlxG.height * 100);
		stageOpacity.scrollFactor.set();

		add(stageOpacity);

		////
		callOnAllScripts('onCreatePost');
		add(strumLineNotes);
		add(playfields);
		add(grpNoteSplashes);
		add(ratingTxtGroup);
		add(comboNumGroup);
		add(timingTxt);

		super.create();

		RecalculateRating();
		startCountdown();

		finishedCreating = true;

		Paths.clearUnusedMemory();

		subtitles = SubtitleDisplay.fromSong(SONG.song);
		if(subtitles!=null){
			add(subtitles);
			subtitles.y = 550;
			subtitles.cameras = [camSubs];
		}

		noteTypeMap.clear();
		noteTypeMap = null;
		eventPushedMap.clear();
		eventPushedMap = null;

		CustomFadeTransition.nextCamera = camOther;
	}

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
		if(boyfriendCameraOffset == null){ //Fucks sake should have done it since the start :rolling_eyes:
			boyfriendCameraOffset = [0, 0];
			stageData.camera_boyfriend = [0, 0];
		}

		opponentCameraOffset = stageData.camera_opponent;
		if(opponentCameraOffset == null){
			opponentCameraOffset = [0, 0];
			stageData.camera_opponent = [0, 0];
		}

		girlfriendCameraOffset = stageData.camera_girlfriend;
		if(girlfriendCameraOffset == null){
			girlfriendCameraOffset = [0, 0];
			stageData.camera_girlfriend = [0, 0];
		}

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

	function set_songSpeed(value:Float):Float
	{
		if(generatedMusic)
		{
			var ratio:Float = value / songSpeed; //funny word huh
/* 			for (note in notes) note.resizeByRatio(ratio);
			for (note in unspawnNotes) note.resizeByRatio(ratio); */
			for(note in allNotes)note.resizeByRatio(ratio);
		}
		songSpeed = value;
		noteKillOffset = 350 / songSpeed;
		return value;
	}

	public function addTextToDebug(text:String, ?color:FlxColor = FlxColor.WHITE) {
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
					var newBoyfriend:Character = new Character(0, 0, newCharacter, true);
					newBoyfriend.cameraPosition[0] += stageData.camera_boyfriend[0];
					newBoyfriend.cameraPosition[1] += stageData.camera_boyfriend[1];

					newBoyfriend.alpha = 0.00001;
					playerField.characters.push(newBoyfriend);

					boyfriendMap.set(newCharacter, newBoyfriend);
					boyfriendGroup.add(newBoyfriend);

					startCharacter(newBoyfriend);
				}

			case 1:
				if(!dadMap.exists(newCharacter)) {
					var newDad:Character = new Character(0, 0, newCharacter);
					newDad.cameraPosition[0] += stageData.camera_opponent[0];
					newDad.cameraPosition[1] += stageData.camera_opponent[1];

					dadField.characters.push(newDad);
					dadMap.set(newCharacter, newDad);
					dadGroup.add(newDad);
					startCharacter(newDad, true);
					newDad.alpha = 0.00001;
				}

			case 2:
				if(gf != null && !gfMap.exists(newCharacter)) {
					var newGf:Character = new Character(0, 0, newCharacter);
					newGf.cameraPosition[0] += stageData.camera_girlfriend[0];
					newGf.cameraPosition[1] += stageData.camera_girlfriend[1];
					newGf.scrollFactor.set(0.95, 0.95);

					newGf.alpha = 0.00001;

					gfMap.set(newCharacter, newGf);
					gfGroup.add(newGf);
					startCharacter(newGf);

				}
		}
	}

	function startCharacter(char:Character, gf:Bool=false){
		startCharacterPos(char, gf);
		startCharacterScript(char);
	}

	function startCharacterScript(char:Character)
	{
		char.startScripts();

		if (char.characterScript != null){
			#if LUA_ALLOWED
			if (char.characterScript is FunkinLua)
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

		var video:VideoHandler = new VideoHandler();
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

		var startCntdown = callOnScripts('onStartCountdown');
		if(startCntdown == Globals.Function_Stop){
			trace("stop");
			trace(startCntdown);
			trace(Globals.Function_Stop);
			return;
		}

		if (skipCountdown || startOnTime > 0)
			skipArrowStartTween = true;

		/* 		
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
		*/

		callOnScripts('preReceptorGeneration');
		//playerField.generateStrums();
		//dadField.generateStrums();
		for(field in playfields.members)
			field.generateStrums();

		callOnScripts('postReceptorGeneration');
		for(field in playfields.members)
			field.fadeIn(isStoryMode || skipArrowStartTween); // TODO: check if its the first song so it should fade the notes in on song 1 of story mode
		modManager.receptors = [playerField.strumNotes, dadField.strumNotes];

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
			
			if (gf != null)
			{
				var gfDanceEveryNumBeats = Math.round(gfSpeed * gf.danceEveryNumBeats);
				if ((gfDanceEveryNumBeats != 0 && tmr.loopsLeft % gfDanceEveryNumBeats == 0) && gf.animation.curAnim != null && !gf.animation.curAnim.name.startsWith("sing") && !gf.stunned)
					gf.dance();
			}

			for(field in playfields){
				for(char in field.characters){
					if(char!=gf){
						if ((char.danceEveryNumBeats != 0 && tmr.loopsLeft % char.danceEveryNumBeats == 0)
							&& char.animation.curAnim != null
							&& !char.animation.curAnim.name.startsWith('sing')
							&& !char.stunned)
						{
							char.dance();
						}

					}
				}
			}


			var sprImage:Null<String> = introAlts[swagCounter];
			if (sprImage != null){
				if (countdownTwn != null)
					countdownTwn.cancel();

				countdownSpr = new FlxSprite(0, 0, Paths.image(sprImage));
				countdownSpr.scrollFactor.set();
				countdownSpr.updateHitbox();
				countdownSpr.cameras = [camHUD];

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

/* 			notes.forEachAlive(function(note:Note) {
				if(ClientPrefs.opponentStrums || note.mustPress)
				{
					note.copyAlpha = false;
					note.alpha = note.multAlpha;
					if(ClientPrefs.middleScroll && !note.mustPress) {
						note.alpha *= 0.35;
					}
				}
			}); */

			callOnHScripts('onCountdownTick', [swagCounter, tmr]);
			#if LUA_ALLOWED
			callOnLuas('onCountdownTick', [swagCounter]);
			#end

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

		var i:Int = allNotes.length - 1;
		while (i >= 0) {
			var daNote:Note = allNotes[i];
			if(daNote.strumTime - 350 < time)
			{
				daNote.ignoreNote = true;
				if (modchartObjects.exists('note${daNote.ID}'))
					modchartObjects.remove('note${daNote.ID}');
				for (field in playfields)
					field.removeNote(daNote);




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

		var speedMult = 1;

		FlxG.timeScale = speedMult;

		FlxG.sound.playMusic(Paths.inst(PlayState.SONG.song), 1, false);
		FlxG.sound.music.pitch = speedMult;
		FlxG.sound.music.onComplete = function(){finishSong(false);};
		vocals.play();
		vocals.pitch = speedMult;
		for (track in tracks){
			track.play();
			track.pitch = speedMult;
		}

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
		hud.songLength = songLength;
		hud.songStarted();

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
					var returnVal:Dynamic = true;

					#if LUA_ALLOWED
					if (eventScript.scriptType == 'lua')
						returnVal = callScript(eventScript, "shouldPush", [event.value1, event.value2]);
					else #end
						returnVal = callScript(eventScript, "shouldPush", [event]);

					if(returnVal == Globals.Function_Continue)return true;
					return returnVal != false;
				}
		}
		return true;
	}

	function getEvents(){
		var songData = SONG;
		var events:Array<EventNote> = [];

		if (#if MODS_ALLOWED Paths.exists(Paths.modsSongJson(songName + '/events')) || #if PE_MOD_COMPATIBILITY Paths.exists(Paths.modsJson(songName + '/events')) || #end #end Paths.exists(Paths.songJson(songName + '/events')))
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
				if (!shouldPush(subEvent))
					continue;
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
			#if PE_MOD_COMPATIBILITY
			var fuck = ["notetypes","custom_notetypes"];
			for(file in fuck){
				var baseScriptFile:String = '$file/$notetype';
			#else
				var baseScriptFile:String = 'notetypes/$notetype';
			#end
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
							var script = new FunkinLua(file, notetype, #if(PE_MOD_COMPATIBILITY) true #else false #end);
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
			#if PE_MOD_COMPATIBILITY
			}
			#end
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
			
			#if PE_MOD_COMPATIBILITY
			var fuck = ["events","custom_events"];
			for(file in fuck){
				var baseScriptFile:String = '$file/$event';
			#else
				var baseScriptFile:String = 'events/$event';
			#end
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
			#if PE_MOD_COMPATIBILITY
			}
			#end
		}

		for(subEvent in getEvents()){
			try{
				subEvent.strumTime -= eventNoteEarlyTrigger(subEvent);
				eventNotes.push(subEvent);
				eventPushed(subEvent);
			}catch(e:Dynamic){
				trace(e);
			}
		}

		if (eventNotes.length > 1)
			eventNotes.sort(sortByTime);


		speedChanges.sort(svSort);

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
				if (allNotes.length > 0)
					oldNote = allNotes[Std.int(allNotes.length - 1)];
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
				swagNote.ID = allNotes.length;
				modchartObjects.set('note${swagNote.ID}', swagNote);


				if(swagNote.fieldIndex==-1 && swagNote.field==null)
					swagNote.field = swagNote.mustPress ? playerField : dadField;

				if(swagNote.field!=null)
					swagNote.fieldIndex = playfields.members.indexOf(swagNote.field);


				var playfield:PlayField = playfields.members[swagNote.fieldIndex];

				if (playfield!=null){
					playfield.queue(swagNote); // queues the note to be spawned
					allNotes.push(swagNote); // just for the sake of convenience
				}else{
					swagNote.destroy();
					continue;
				}

				#if LUA_ALLOWED
				if(swagNote.noteScript != null && swagNote.noteScript.scriptType == 'lua'){
					callScript(swagNote.noteScript, 'setupNote', [
						allNotes.indexOf(swagNote),
						Math.abs(swagNote.noteData),
						swagNote.noteType,
						swagNote.isSustainNote,
						swagNote.ID
					]);
				}
				#end

				var floorSus:Int = Math.round(susLength);
				if(floorSus > 0) {
					for (susNote in 0...floorSus)
					{
						oldNote = allNotes[Std.int(allNotes.length - 1)];

						var sustainNote:Note = new Note(daStrumTime + (Conductor.stepCrochet * susNote) + (Conductor.stepCrochet), daNoteData, oldNote, true);
						sustainNote.mustPress = gottaHitNote;
						sustainNote.gfNote = swagNote.gfNote;
						sustainNote.noteType = type;
						if(sustainNote==null || !sustainNote.alive)
							break;
						sustainNote.ID = allNotes.length;
						modchartObjects.set('note${sustainNote.ID}', sustainNote);
						sustainNote.scrollFactor.set();
						swagNote.tail.push(sustainNote);
						swagNote.unhitTail.push(sustainNote);
						sustainNote.parent = swagNote;
						//allNotes.push(sustainNote);
						sustainNote.fieldIndex = swagNote.fieldIndex;
						playfield.queue(sustainNote);
						allNotes.push(sustainNote);
						#if LUA_ALLOWED
						if (sustainNote.noteScript != null && sustainNote.noteScript.scriptType == 'lua'){
							callScript(sustainNote.noteScript, 'setupNote', [
								allNotes.indexOf(sustainNote),
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
					}
				}

				if (swagNote.mustPress)
				{
					swagNote.x += FlxG.width * 0.5; // general offset
				}

			}
			daBeats += 1;
		}

		// playerCounter += 1;

		allNotes.sort(sortByShit);

		for(fuck in allNotes)
			unspawnNotes.push(fuck);
		
		for (field in playfields.members)
		{
			var goobaeg:Array<Note> = [];
			for(column in field.noteQueue){
				if(column.length>=2){
					for(nIdx in 1...column.length){
						var last = column[nIdx-1];
						var current = column[nIdx];
						if(last==null || current==null)continue;
						if(last.isSustainNote || current.isSustainNote)continue; // holds only get fukt if their parents get fukt
						if(!last.alive || !current.alive)continue; // just incase
						if (Math.abs(last.strumTime - current.strumTime) <= Conductor.stepCrochet / (192 / 16)){
							if(last.sustainLength < current.sustainLength) // keep the longer hold
								field.removeNote(last);
							else{
								current.kill();
								goobaeg.push(current); // mark to delete after, cant delete here because otherwise it'd fuck w/ stuff	
							}
						}

					}
				}
			}
			for(note in goobaeg)
				field.removeNote(note);

		}

		#if(LUA_ALLOWED && PE_MOD_COMPATIBILITY)
		for(key => script in notetypeScripts){
			if(script.scriptType == 'lua'){
				script.call("onCreate");
				trace(script.scriptName);
			}
		}
		#end
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

	public function getNoteInitialTime(time:Float)
	{
		var event:SpeedEvent = getSV(time);
		return getTimeFromSV(time, event);
	}

	public inline function getTimeFromSV(time:Float, event:SpeedEvent)
		return event.position + (modManager.getBaseVisPosD(time - event.songTime, 1) * event.speed);

	public function getSV(time:Float){
		var event:SpeedEvent = {
			position: 0,
			songTime: 0,
			speed: 1
		};
		for (shit in speedChanges)
		{
			if (shit.songTime <= time && shit.songTime >= shit.songTime)
				event = shit;
		}

		return event;
	}


	public inline function getVisualPosition()
		return getTimeFromSV(Conductor.songPosition, currentSV);
	

	function eventPushed(event:EventNote) {
		switch(event.event){
			case 'Mult SV' | 'Constant SV':
				var speed:Float = 1;
				if(event.event == 'Constant SV'){
					var b = Std.parseFloat(event.value1);
					if(Math.isNaN(b))speed = songSpeed;
					speed = songSpeed / b;
				}else{
					speed = Std.parseFloat(event.value1);
					if(Math.isNaN(speed))speed = 1;
				}

				speedChanges.sort(svSort);
				speedChanges.push({
					position: getNoteInitialTime(event.strumTime),
					songTime: event.strumTime,
					speed: speed
				});
				
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

	public function optionsChanged(options:Array<String>){
		hud.changedOptions(options);
		for(note in allNotes)
			note.updateColours();
		if (options.length > 0){
			updateTime = (ClientPrefs.timeBarType != 'Disabled');
			
			var reBind:Bool = false;
			PlayState.instance.callOnScripts('optionsChanged', [options]);
			for(opt in options){
				if(opt.startsWith("bind")){
					reBind = true;
				}
			}

			for(field in playfields){
				field.noteField.optimizeHolds = ClientPrefs.optimizeHolds;
				field.noteField.drawDistMod = ClientPrefs.drawDistanceModifier;
				field.noteField.holdSubdivisions = Std.int(ClientPrefs.holdSubdivs) + 1;
			}
			

			if(reBind){
				debugKeysChart = ClientPrefs.copyKey(ClientPrefs.keyBinds.get('debug_1'));
				debugKeysCharacter = ClientPrefs.copyKey(ClientPrefs.keyBinds.get('debug_2'));
				debugKeysBotplay = ClientPrefs.copyKey(ClientPrefs.keyBinds.get('botplay'));

				keysArray = [
					ClientPrefs.copyKey(ClientPrefs.keyBinds.get('note_left')),
					ClientPrefs.copyKey(ClientPrefs.keyBinds.get('note_down')),
					ClientPrefs.copyKey(ClientPrefs.keyBinds.get('note_up')),
					ClientPrefs.copyKey(ClientPrefs.keyBinds.get('note_right'))
				];

				// unpress everything
				for (field in playfields.members)
				{
					if (field.inControl && !field.autoPlayed && field.isPlayer)
					{
						for (idx in 0...field.keysPressed.length)
							field.keysPressed[idx] = false;

						for (obj in field.strumNotes)
						{
							obj.playAnim("static");
							obj.resetAnim = 0;
						}
					}
				}
			}
		}
		

	}

	override function draw(){
		stageOpacity.alpha = ClientPrefs.stageOpacity;
		super.draw();
	}

	function eventNoteEarlyTrigger(event:EventNote):Float {
		var returnedValue:Float = 0;
		var currentRV:Float = callOnAllScripts('eventEarlyTrigger', [event.event, event.value1, event.value2]);

		if (eventScripts.exists(event.event)){
			var eventScript:Dynamic = eventScripts.get(event.event);
			#if LUA_ALLOWED
			if(eventScript.scriptType == 'lua')
				returnedValue = callScript(eventScript, "getOffset", [event.value1, event.value2]);
			else
			#end
				returnedValue = callScript(eventScript, "getOffset", [event]);
		}
		if(currentRV!=0 && returnedValue==0)returnedValue = currentRV;

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

	
	function svSort(Obj1:SpeedEvent, Obj2:SpeedEvent):Int
	{
		return FlxSort.byValues(FlxSort.ASCENDING, Obj1.songTime, Obj2.songTime);
	}

	public var skipArrowStartTween:Bool = false; //for lua
	private function generateStaticArrows(player:Int):Void
	{
/* 		var targetAlpha:Float = 1;
		if (player < 1){
			if(!ClientPrefs.opponentStrums) targetAlpha = 0;
			else if(ClientPrefs.middleScroll) targetAlpha = 0.35;
		}

		for (i in 0...4){
			var babyArrow:StrumNote = new StrumNote(
				ClientPrefs.middleScroll ? STRUM_X_MIDDLESCROLL : STRUM_X,
				ClientPrefs.downScroll ? FlxG.height - 162 : 50,
				i
			);

			babyArrow.downScroll = ClientPrefs.downScroll;

			if (!isStoryMode && !skipArrowStartTween)
			{
				//babyArrow.y -= 10;
				babyArrow.alpha = 0;
				FlxTween.tween(babyArrow, {alpha: targetAlpha}, 1, {ease: FlxEase.circOut, startDelay: 0.5 + (0.2 * i)});
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
		} */
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
				resyncVocals();

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

			hud.alpha = ClientPrefs.hudOpacity;


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
		if (health > 0)
			DiscordClient.changePresence(detailsPausedText, SONG.song, Paths.formatToSongPath(SONG.song));
		#end

		super.onFocusLost();
	}


	// good to call this whenever you make a playfield
	public function initPlayfield(field:PlayField){
		field.judgeManager = judgeManager;

		field.noteRemoved.add((note:Note, field:PlayField) -> {
			if(modchartObjects.exists('note${note.ID}'))modchartObjects.remove('note${note.ID}');
			allNotes.remove(note);
			unspawnNotes.remove(note);
			notes.remove(note);
		});
		field.noteMissed.add((daNote:Note, field:PlayField) -> {
			if (field.isPlayer && !field.autoPlayed && !daNote.ignoreNote && !endingSong && (daNote.tooLate || !daNote.wasGoodHit))
				noteMiss(daNote, field);

		});
		field.noteSpawned.add((dunceNote:Note, field:PlayField) -> {
			callOnHScripts('onSpawnNote', [dunceNote]);
			#if LUA_ALLOWED
			callOnLuas('onSpawnNote', [
				allNotes.indexOf(dunceNote),
				dunceNote.noteData,
				dunceNote.noteType,
				dunceNote.isSustainNote
			]);
			#end

			notes.add(dunceNote);
			var index:Int = unspawnNotes.indexOf(dunceNote);
			unspawnNotes.splice(index, 1);

			callOnHScripts('onSpawnNotePost', [dunceNote]);
			if (dunceNote.noteScript != null)
			{
				var script:FunkinScript = dunceNote.noteScript;

				#if LUA_ALLOWED
				if (script.scriptType == 'lua')
				{
					callScript(script, 'postSpawnNote', [
						notes.members.indexOf(dunceNote),
						Math.abs(dunceNote.noteData),
						dunceNote.noteType,
						dunceNote.isSustainNote,
						dunceNote.ID
					]);
				}
				else
				#end
				callScript(script, "postSpawnNote", [dunceNote]);
			}
		});
	}

	function resyncVocals():Void
	{
		if(finishTimer != null || transitioning)
			return;

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
	var resyncTimer:Float = 0;
	var prevNoteCount:Int = 0;

	override public function update(elapsed:Float)
	{
		hud.updateTime = updateTime;

		for(field in playfields)
			field.noteField.songSpeed = songSpeed;


		setOnScripts('curDecStep', curDecStep);
		setOnScripts('curDecBeat', curDecBeat);
		#if(LUA_ALLOWED && PE_MOD_COMPATIBILITY)
		for (key => script in notetypeScripts){
			if(script.scriptType=='lua')script.call("onUpdate", [elapsed]); // for backwards compat w/ psych lua
		}
		#end

		#if(LUA_ALLOWED && PE_MOD_COMPATIBILITY)
		for (key => script in eventScripts){
			if(script.scriptType=='lua')script.call("onUpdate", [elapsed]); // for backwards compat w/ psych lua
		}
		#end

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

		for (key => script in notetypeScripts){
			script.call("update", [elapsed]);
		}

		for (key => script in eventScripts){
			eventScripts.get(key).call("update", [elapsed]);
		}

		callOnHScripts('update', [elapsed]);



	/* 	for (shit in speedChanges)
		{
			if (shit.songTime <= Conductor.songPosition)
				event = shit;
			else
				break;
		} */
/* 		if(speedChanges.length > 1){
			if(speedChanges[1].songTime < Conductor.songPosition)
				while (speedChanges.length > 1 && speedChanges[1].songTime < Conductor.songPosition)
					speedChanges.shift();
		} */
		

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

		}
		camOverlay.zoom = camHUD.zoom;
		camOverlay.angle = camHUD.angle;

		if(noteHits.length > 0){
			while (noteHits.length > 0 && (noteHits[0] + 2000) < Conductor.songPosition)
				noteHits.shift();
		}

		nps = Math.floor(noteHits.length / 2);
		FlxG.watch.addQuick("notes per second", nps);
		hud.nps = nps;
		if(hud.npsPeak < nps)
			hud.npsPeak = nps;
		
		if (!endingSong){
			//// time travel
			if (!startingSong #if !debug && chartingMode #end){
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

			if (FlxG.keys.anyJustPressed(debugKeysBotplay))
				cpuControlled = !cpuControlled;
			

			// RESET = Quick Game Over Screen
			if (controls.RESET && canReset && !inCutscene && startedCountdown)
				health = 0;
			//	Death checks are now done after when your health is modified, rather than every frame

			if (controls.PAUSE)
				pause();
		}

		////
		if (startedCountdown)
		{
			var addition:Float = elapsed * 1000;
			if(FlxG.sound.music.playing){
				if(FlxG.sound.music.time == Conductor.lastSongPos)
					resyncTimer += addition;
				else
					resyncTimer = 0;
				
				Conductor.songPosition = FlxG.sound.music.time + resyncTimer;
				Conductor.lastSongPos = FlxG.sound.music.time;
				if (Math.abs(vocals.time - FlxG.sound.music.time) > 25)
					vocals.time = FlxG.sound.music.time;
				
			}else
				Conductor.songPosition += addition;
		}

		hud.updateTime = updateTime;

		if (startingSong)
		{
			if (startedCountdown && Conductor.songPosition >= 0)
				startSong();
			else if(!startedCountdown)
				Conductor.songPosition = -Conductor.crochet * 5;
		}

		FlxG.watch.addQuick("beatShit", curBeat);
		FlxG.watch.addQuick("stepShit", curStep);

		currentSV = getSV(Conductor.songPosition);
		Conductor.visualPosition = getVisualPosition();
		FlxG.watch.addQuick("visualPos", Conductor.visualPosition);

		super.update(elapsed);
		modManager.updateTimeline(curDecStep);
		modManager.update(elapsed);

		// TODO: rewrite this a little bit cus of multSpeed and noteSpawnTime being able to be per-player and per-note n all that
		// just so that if the top note spawns later, it wont fuck up other notes which should spawn sooner.

/* 		if (unspawnNotes[0] != null)
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
		} */

/* 		opponentStrums.forEachAlive(function(strum:StrumNote)
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
 */
		strumLineNotes.sort(sortByOrderStrumNote);

		if (generatedMusic)
		{
			if (!inCutscene){
				keyShit();
			}

			for(field in playfields){
				if(field.isPlayer){
					for(char in field.characters){
						if (char.animation.curAnim != null
							&& char.holdTimer > Conductor.stepCrochet * (0.0011 / FlxG.sound.music.pitch) * char.singDuration
								&& char.animation.curAnim.name.startsWith('sing')
								&& !char.animation.curAnim.name.endsWith('miss')
								&& (char.idleWhenHold || !pressedGameplayKeys.contains(true)))
							char .dance();

					}
				}
			}
		}
		checkEventNote();

		setOnScripts('cameraX', camFollowPos.x);
		setOnScripts('cameraY', camFollowPos.y);
		callOnScripts('onUpdatePost', [elapsed]);
		#if(LUA_ALLOWED && PE_MOD_COMPATIBILITY)
		for (key => script in notetypeScripts){
			if(script.scriptType=='lua')script.call("onUpdatePost", [elapsed]); // for backwards compat w/ psych lua
		}
		#end
		#if(LUA_ALLOWED && PE_MOD_COMPATIBILITY)
		for (key => script in eventScripts){
			if(script.scriptType=='lua')script.call("onUpdatePost", [elapsed]); // for backwards compat w/ psych lua
		}
		#end
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

				if(instaRespawn){
					isDead = true;
					MusicBeatState.resetState(true);
					return true;
				}else{
					var char = playOpponent ? dad : boyfriend;
					openSubState(new GameOverSubstate(
						char.getScreenPosition().x - char.positionArray[0],
						char.getScreenPosition().y - char.positionArray[1],
						camFollowPos.x,
						camFollowPos.y,
						char.isPlayer
					));
				}

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
					hud.iconP1.changeIcon(boyfriend.healthIcon);
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
					hud.iconP2.changeIcon(dad.healthIcon);
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

	public function triggerEventNote(eventName:String = "", value1:String = "", value2:String = "") {
		//trace('Event: ' + eventName + ', Value 1: ' + value1 + ', Value 2: ' + value2 + ', at Time: ' + Conductor.songPosition);

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
				if(ClientPrefs.camZoomP > 0 && FlxG.camera.zoom < 1.35) {
					var camZoom:Float = Std.parseFloat(value1);
					var hudZoom:Float = Std.parseFloat(value2);
					if(Math.isNaN(camZoom)) camZoom = 0.015;
					if(Math.isNaN(hudZoom)) hudZoom = 0.03;

					FlxG.camera.zoom += camZoom * ClientPrefs.camZoomP;
					camHUD.zoom += hudZoom * ClientPrefs.camZoomP;
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

				var isNan1 = Math.isNaN(val1);
				var isNan2 = Math.isNaN(val2);

				if (isNan1 && isNan2) 
					cameraPoints.remove(customCamera);
				else{
					if (!isNan1) customCamera.x = val1;
					if (!isNan2) customCamera.y = val2;
					addCameraPoint(customCamera);
				}

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
		if(eventScripts.exists(eventName)){
			var script = eventScripts.get(eventName);
			#if LUA_ALLOWED
			if(script.scriptType == 'lua')
				callScript(script, "onEvent", [eventName, value1, value2]);
			else
			#end
				callScript(script, "onTrigger", [value1, value2]);
		}
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

	/**
		Returns an array with the characters camera focus positions.
	**/
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
		FlxG.sound.music.pause();

		vocals.volume = 0;
		vocals.pause();

		for (track in tracks){
			track.volume = 0;
			track.pause();
		}

		////
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
			/*for (daNote in allNotes) {
				if(daNote.strumTime < songLength - Conductor.safeZoneOffset) {
					health -= 0.05 * healthLoss;
				}
			}*/
			for(field in playfields.members){
				if(field.isPlayer){
					for(daNote in field.spawnedNotes){
						if(daNote.strumTime < songLength - Conductor.safeZoneOffset) {
							health -= 0.05 * healthLoss;
						}
					}
				}
			}

			if(doDeathCheck())
				return;
		}

		hud.songEnding();
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
			// Save song score and rating.
			if (SONG.validScore){
				var percent:Float = ratingPercent;

				if(Math.isNaN(percent)) percent = 0;

				if (!playOpponent && saveScore && ratingFC!='Fail')
					Highscore.saveScore(SONG.song, songScore, percent);
			}


			transitioning = true;

			if (chartingMode)
			{
				openChartEditor();
				return;
			}

			if (isStoryMode)
			{
				// TODO: add a modcharted variable which songs w/ modcharts should set to true, then make it so if modcharts are disabled the score wont get added
				// same check should be in the saveScore check above too
				if (ratingFC != 'Fail')
					campaignScore += songScore;
				campaignMisses += songMisses;

				storyPlaylist.remove(storyPlaylist[0]);

				if (storyPlaylist.length <= 0)
				{
					//// WEEK END

					// Save week score
					if (ChapterData.curChapter != null && !playOpponent){
						if(!ClientPrefs.getGameplaySetting('practice', false) && !ClientPrefs.getGameplaySetting('botplay', false)) {
							Highscore.saveWeekScore(ChapterData.curChapter.directory, campaignScore);
							
							StoryMenuState.weekCompleted.set(ChapterData.curChapter.directory, true);
							FlxG.save.data.weekCompleted = StoryMenuState.weekCompleted;

							FlxG.save.flush();
						}
					}

					if(FlxTransitionableState.skipNextTransIn)
						CustomFadeTransition.nextCamera = null;

					cancelMusicFadeTween();

					function gotoMenus(){
						MusicBeatState.switchState(new StoryMenuState());
						MusicBeatState.playMenuMusic(1, true);
					}

					#if VIDEOS_ALLOWED
					var videoPath:String = Paths.video('${Paths.formatToSongPath(SONG.song)}-end');
					if (Paths.exists(videoPath))
						MusicBeatState.switchState(new VideoPlayerState(videoPath, gotoMenus));
					else
						gotoMenus();
					#else
					gotoMenus();
					#end
				}
				else
				{
					var nextSong = PlayState.storyPlaylist[0];
					trace('LOADING NEXT SONG: $nextSong');

					prevCamFollow = camFollow;
					prevCamFollowPos = camFollowPos;

					/*
					FlxTransitionableState.skipNextTransIn = true;
					FlxTransitionableState.skipNextTransOut = true;
					*/

					cancelMusicFadeTween();
					FlxG.sound.music.stop();

					function playNextSong(){
						PlayState.SONG = Song.loadFromJson(nextSong, nextSong);
						LoadingState.loadAndSwitchState(new PlayState());
					}

					#if VIDEOS_ALLOWED
					var videoPath:String = Paths.video('${Paths.formatToSongPath(nextSong)}');
					if (Paths.exists(videoPath))
						MusicBeatState.switchState(new VideoPlayerState(videoPath, playNextSong));
					else
						playNextSong();
					#else
					playNextSong();
					#end
				}
			}
			else
			{
				trace('WENT BACK TO FREEPLAY??');
				cancelMusicFadeTween();

				if(FlxTransitionableState.skipNextTransIn)
					CustomFadeTransition.nextCamera = null;
				
				MusicBeatState.switchState(new FreeplayState());
				MusicBeatState.playMenuMusic(1, true);
			}
		}
	}

	public function KillNotes() {
		while(allNotes.length > 0) {
			var daNote:Note = allNotes[0];
			daNote.active = false;
			daNote.visible = false;

			daNote.kill();
			notes.remove(daNote, true);
			// daNote.destroy();
		}
		allNotes = [];
		unspawnNotes = [];
		for(field in playfields){
			field.clearDeadNotes();
			field.spawnedNotes = [];
			field.noteQueue = [[], [], [], []];
		}

		eventNotes = [];
	}

	public var totalPlayed:Float = 0;
	public var totalNotesHit:Float = 0.0;

	var lastJudge:RatingSprite;
	var lastCombos:Array<RatingSprite> = [];

	var msNumber = 0;
	var msTotal = 0.0;

	private function showJudgment(image:String){
		var rating:RatingSprite;

		var time = (Conductor.stepCrochet * 0.001);

		if (ClientPrefs.simpleJudge)
		{
			rating = lastJudge;
			rating.moves = false;
			rating.revive();

			if (rating.tween != null)
			{
				rating.tween.cancel();
				rating.tween.destroy();
			}

			rating.scale.set(0.7 * 1.1, 0.7 * 1.1);

			rating.tween = FlxTween.tween(rating.scale, {x: 0.7, y: 0.7}, 0.1, {
				ease: FlxEase.quadOut,
				onComplete: function(tween:FlxTween)
				{
					if (!rating.alive)
						return;

					rating.tween = FlxTween.tween(rating.scale, {x: 0, y: 0}, time, {
						startDelay: time * 8,
						ease: FlxEase.quadIn,
						onComplete: function(tween:FlxTween)
						{
							rating.kill();
						}
					});
				}
			});
		}
		else
		{
			rating = ratingTxtGroup.recycle(RatingSprite, RatingSprite.newRating);
			rating.moves = true;
			rating.acceleration.y = 550;
			rating.velocity.set(FlxG.random.int(-10, 10), -FlxG.random.int(140, 175));

			rating.alpha = 1;

			rating.tween = FlxTween.tween(rating, {alpha: 0}, 0.2, {
				startDelay: Conductor.crochet * 0.001,
				onComplete: function(wtf)
				{
					rating.kill();
				}
			});
		}

		rating.loadGraphic(Paths.image(image));
		rating.updateHitbox();

		rating.screenCenter();
		rating.x += ClientPrefs.comboOffset[0];
		rating.y -= ClientPrefs.comboOffset[1];

		ratingTxtGroup.remove(rating, true);
		ratingTxtGroup.add(rating);
	}

	private function showCombo(?combo:Int){
		if(combo==null)combo=this.combo;
		if (ClientPrefs.simpleJudge)
		{
			for (prevCombo in lastCombos)
			{
				prevCombo.kill();
			}
			if (combo == 0)
				return;
		}
		else if (combo < 10 && combo != 0)
			return;

		var separatedScore:Array<String> = Std.string(combo).split("");
		while (separatedScore.length < 3)
			separatedScore.unshift("0");

		var daLoop:Int = 0;

		// did you goto MS Paint and get colours from there lol
		var comboColor = !ClientPrefs.coloredCombos ? 0xFFFFFFFF : switch (ratingFC)
		{ // so the color doesn't get calculated for every number ig
			case 'KFC':
				hud.judgeColours.get("epic");
			case 'AFC':
				hud.judgeColours.get("sick");
			case 'CFC'| "SDC":
				hud.judgeColours.get("good");
			default:
				FlxColor.WHITE;
		}; // this could prob be set in recalculateRating tbh lol

		for (i in separatedScore)
		{
			var numScore:RatingSprite = comboNumGroup.recycle(RatingSprite, RatingSprite.newNumber);
			numScore.revive();
			numScore.loadGraphic(Paths.image('num' + i));

			numScore.color = comboColor;
			numScore.screenCenter();
			numScore.x += ClientPrefs.comboOffset[2] + 43 * daLoop;
			numScore.y -= ClientPrefs.comboOffset[3];
			numScore.ID = daLoop;
			numScore.moves = !ClientPrefs.simpleJudge;
			if (numScore.tween != null)
			{
				numScore.tween.cancel();
				numScore.tween.destroy();
			}

			comboNumGroup.remove(numScore, true);
			comboNumGroup.add(numScore);

			if (ClientPrefs.simpleJudge)
			{
				numScore.scale.x = 0.5 * 1.25;
				numScore.scale.y = 0.5 * 0.75;

				/* numScore.alpha = 0.6; */
				numScore.tween = FlxTween.tween(numScore, {"scale.x": 0.5, "scale.y": 0.5 /* , alpha: 1 */}, 0.2, {
					ease: FlxEase.circOut
				});

				lastCombos.push(numScore);
			}
			else
			{
				
				numScore.acceleration.y = FlxG.random.int(200, 300);
				numScore.velocity.set(FlxG.random.float(-10, 10), -FlxG.random.int(140, 160));

				numScore.alpha = 1;
				numScore.tween = FlxTween.tween(numScore, {alpha: 0}, 0.2, {
					onComplete: function(wtf)
					{
						numScore.kill();
					},
					startDelay: Conductor.crochet * 0.002
				});
			}

			daLoop++;
		}
	}

	private function applyJudgmentData(judgeData:JudgmentData, diff:Float, ?show:Bool = true){
		if(judgeData==null){
			trace("you didnt give a valid JudgmentData to applyJudgmentData!");
			return;
		}
		if (!cpuControlled)songScore += judgeData.score;
		health += (judgeData.health * 0.02) * (judgeData.health < 0 ? healthLoss : healthGain);
		songHits++;


		if(ClientPrefs.wife3){
			if (judgeData.wifePoints == null)
				totalNotesHit += Wife3.getAcc(diff);
			else
				totalNotesHit += judgeData.wifePoints;
			totalPlayed += 2;
		}else{
			totalNotesHit += judgeData.accuracy * 0.01;
			totalPlayed++;
		}

		if (!hud.judgements.exists(judgeData.internalName))
			hud.judgements.set(judgeData.internalName, 0);
		
		hud.judgements.set(judgeData.internalName, hud.judgements.get(judgeData.internalName) + 1);

		switch(judgeData.comboBehaviour){
			default:
				combo++;
			case BREAK:
				breakCombo();
			case IGNORE:
		}

		if (!judges.exists(judgeData.internalName))
			judges.set(judgeData.internalName, 0);

		judges.set(judgeData.internalName, judges.get(judgeData.internalName) + 1);
		
		RecalculateRating();

		if(show){
			if(judgeData.hideJudge!=true)
				showJudgment(judgeData.internalName);
			if(judgeData.comboBehaviour != IGNORE)
				showCombo();
		}
	}

	private function applyNoteJudgment(note:Note):Null<JudgmentData>
	{
		if(note.hitResult.judgment == UNJUDGED)return null;
		var judgeData:JudgmentData = judgeManager.judgmentData.get(note.hitResult.judgment);
		if(judgeData==null)return null;

		if (callOnHScripts("preApplyJudgment", [note, judgeData]) == Globals.Function_Stop)
			return null;

		var mutatedJudgeData:Dynamic = callOnHScripts("mutateJudgeData", [note, judgeData]);
		if(mutatedJudgeData != null && mutatedJudgeData != Globals.Function_Continue)
			judgeData = cast mutatedJudgeData; // so you can return your own custom judgements or w/e

		applyJudgmentData(judgeData, note.hitResult.hitDiff, true);

		callOnHScripts("postApplyJudgment", [note, judgeData]);
		
		return judgeData;
	}

	private function applyJudgment(judge:Judgment, ?diff:Float = 0, ?show:Bool = true)
		applyJudgmentData(judgeManager.judgmentData.get(judge), diff);

	var msJudges = [];

	private function judge(note:Note, field:PlayField=null){
		if (field == null)
			field = getFieldFromNote(note);

		var hitTime = note.hitResult.hitDiff + ClientPrefs.ratingOffset;
		var judgeData:JudgmentData = applyNoteJudgment(note);
		if(judgeData==null)return;

		note.ratingMod = judgeData.accuracy * 0.01;
		note.rating = judgeData.internalName;
		if (judgeData.noteSplash && !note.noteSplashDisabled)
			spawnNoteSplashOnNote(note, field);
		
		msJudges.push({hitTime: hitTime, strumTime: note.strumTime});

		if(ClientPrefs.showMS && (field==null || !field.autoPlayed))
		{
			FlxTween.cancelTweensOf(timingTxt);
			FlxTween.cancelTweensOf(timingTxt.scale);
			
			timingTxt.text = '${FlxMath.roundDecimal(hitTime, 2)}ms';
			timingTxt.screenCenter();
			timingTxt.x += ClientPrefs.comboOffset[4];
			timingTxt.y -= ClientPrefs.comboOffset[5];

			timingTxt.color = hud.judgeColours.get(judgeData.internalName);

			timingTxt.visible = true;
			timingTxt.alpha = 1;
			timingTxt.y -= 8;
			timingTxt.scale.set(1, 1);
			
			var time = (Conductor.stepCrochet * 0.001);
			FlxTween.tween(timingTxt, 
				{y: timingTxt.y + 8}, 
				0.1,
				{onComplete: function(_){
					if (ClientPrefs.simpleJudge){
						FlxTween.tween(timingTxt.scale, {x: 0, y: 0}, time, {
							ease: FlxEase.quadIn,
							onComplete: function(_){timingTxt.visible = false;},
							startDelay: time * 8
						});
					}else{
						FlxTween.tween(timingTxt, {alpha: 0}, time, {
							// ease: FlxEase.circOut,
							onComplete: function(_){timingTxt.visible = false;},
							startDelay: time * 8
						});
					}
				}}
			);
		}

		hud.noteJudged(judgeData, note, field);
	}
	// time to rewrite this!
/* 	private function popUpScore(note:Note, field:PlayField=null):Void
	{
		if(field==null)
			field = getFieldFromNote(note);
		

		var hitTime = note.hitResult.hitDiff + ClientPrefs.ratingOffset;
		var noteDiff:Float = Math.abs(hitTime);

		vocals.volume = 1;

		//tryna do MS based judgment due to popular demand
		var daRating:Rating = Conductor.judgeNote(noteDiff);

		hud.noteJudged(daRating, note, field);

		var ratingMod = daRating.ratingMod;
		if (ClientPrefs.wife3)
			ratingMod = Wife3.getAcc(hitTime);
		
		note.ratingMod = ratingMod;
		
		if(!note.ratingDisabled) daRating.increase();
		note.rating = daRating.name;

		if(!hud.judgements.exists(daRating.name))
			hud.judgements.set(daRating.name, 0);
		hud.judgements.set(daRating.name, hud.judgements.get(daRating.name) + 1);

		if(daRating.noteSplash && !note.noteSplashDisabled)
			spawnNoteSplashOnNote(note, field);

		var hitHealth = note.ratingHealth.get(note.rating);
		if((daRating.health<0 && ClientPrefs.wife3) || note.breaksCombo)
			breakCombo();
		else
			combo++;

		health += (hitHealth == null ? daRating.health : hitHealth) * healthGain;
		
		if(!practiceMode && !field.autoPlayed)
			songScore += daRating.score;

		if(!note.ratingDisabled)
		{
			totalNotesHit += ratingMod;
			songHits++;
			totalPlayed += ClientPrefs.wife3 ? 2 : 1;
			RecalculateRating();
		}
		
		var time = (Conductor.stepCrochet * 0.001);

		showJudgment(daRating.image);
		////
		msTotal += hitTime;
		msNumber++;

		if(ClientPrefs.showMS && (field==null || !field.autoPlayed))
		{
			FlxTween.cancelTweensOf(timingTxt);
			FlxTween.cancelTweensOf(timingTxt.scale);
			
			timingTxt.text = '${FlxMath.roundDecimal(hitTime, 2)}ms';
			timingTxt.screenCenter();
			timingTxt.x += ClientPrefs.comboOffset[4];
			timingTxt.y -= ClientPrefs.comboOffset[5];

			timingTxt.color = hud.judgeColours.get(daRating.name);

			timingTxt.visible = true;
			timingTxt.alpha = 1;
			timingTxt.y -= 8;
			timingTxt.scale.set(1, 1);
			
			FlxTween.tween(timingTxt, 
				{y: timingTxt.y + 8}, 
				0.1,
				{onComplete: function(_){
					if (ClientPrefs.simpleJudge){
						FlxTween.tween(timingTxt.scale, {x: 0, y: 0}, time, {
							ease: FlxEase.quadIn,
							onComplete: function(_){timingTxt.visible = false;},
							startDelay: time * 8
						});
					}else{
						FlxTween.tween(timingTxt, {alpha: 0}, time, {
							// ease: FlxEase.circOut,
							onComplete: function(_){timingTxt.visible = false;},
							startDelay: time * 8
						});
					}
				}}
			);
		}

		////
		showCombo();
	} */

	public var strumsBlocked:Array<Bool> = [];
	var pressed:Array<FlxKey> = [];

	private function onKeyPress(event:KeyboardEvent):Void
	{
		var eventKey:FlxKey = event.keyCode;
		var data:Int = getKeyFromEvent(eventKey);

		if (startedCountdown && !paused && data > -1 && !pressed.contains(eventKey)){
			pressed.push(eventKey);
			var hitNotes:Array<Note> = [];
			if(strumsBlocked[data]) return;

			callOnScripts('onKeyPress', [data]);

			for(field in playfields.members){
				if(!field.autoPlayed && field.isPlayer && field.inControl){
					field.keysPressed[data] = true;
					if(generatedMusic && !endingSong){
						var note:Note = field.input(data);
						if(note==null){
							var spr:StrumNote = field.strumNotes[data];
							if (spr != null && spr.animation.curAnim.name != 'confirm')
							{
								spr.playAnim('pressed');
								spr.resetAnim = 0;
							}
						}else
							hitNotes.push(note);

					}
				}
			}
			if(hitNotes.length==0){
				callOnScripts('onGhostTap', [data]);
				if (!ClientPrefs.ghostTapping)
				{
					noteMissPress(data);
					callOnScripts('noteMissPress', [data]);
				}
			}
		}
	}
	private function onKeyRelease(event:KeyboardEvent):Void
	{
		var eventKey:FlxKey = event.keyCode;
		var key:Int = getKeyFromEvent(eventKey);
		if(pressed.contains(eventKey))pressed.remove(eventKey);
		if(startedCountdown && key > -1)
		{
			// doesnt matter if THIS is done while paused
			// only worry would be if we implemented Lifts
			// but afaik we arent doing that
			// (though could be interesting to add)
			for(field in playfields.members){
				if (field.inControl && !field.autoPlayed && field.isPlayer)
				{
					field.keysPressed[key] = false;
					var spr:StrumNote = field.strumNotes[key];
					if (spr != null)
					{
						spr.playAnim('static');
						spr.resetAnim = 0;
					}
				}
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

			if (parsedHoldArray.contains(true) && !endingSong) {
				#if ACHIEVEMENTS_ALLOWED
				var achieve:String = checkForAchievement(['oversinging']);
				if (achieve != null) {
					startAchievement(achieve);
				}
				#end
			}


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

	function breakCombo(){
		comboBreaks++;
		combo = 0;
		while (lastCombos.length > 0)
			lastCombos.shift().kill();
		RecalculateRating();
	}

	function noteMiss(daNote:Note, field:PlayField, ?mine:Bool=false):Void { //You didn't hit the key and let it go offscreen, also used by Hurt Notes
		//Dupe note remove
		//field.spawnedNotes.forEachAlive(function(note:Note) {
		for(note in field.spawnedNotes){
			if(!note.alive || daNote.tail.contains(note) || note.isSustainNote) continue;
			if (daNote != note && field.isPlayer && daNote.noteData == note.noteData && Math.abs(daNote.strumTime - note.strumTime) < 1) 
				field.removeNote(note);
			
		}
		if (daNote.sustainLength > 0 && ClientPrefs.wife3)
			daNote.hitResult.judgment = DROPPED_HOLD;
		else
			daNote.hitResult.judgment = MISS;

		if(callOnHScripts("preNoteMiss", [daNote, field]) == Globals.Function_Stop)
			return;
		#if LUA_ALLOWED
		if(callOnLuas('preNoteMiss', [notes.members.indexOf(daNote), daNote.noteData, daNote.noteType, daNote.isSustainNote, daNote.ID]) == Globals.Function_Stop)
			return;
		#end
		
		if (daNote.noteScript!=null)
		{
			var script:Dynamic = daNote.noteScript;

			#if LUA_ALLOWED
			if (script.scriptType == 'lua')
			{
				if(callScript(script, 'preNoteMiss', [
					notes.members.indexOf(daNote),
					Math.abs(daNote.noteData),
					daNote.noteType,
					daNote.isSustainNote,
					daNote.ID
				]) == Globals.Function_Stop)
				return;
			}
			else
			#end
			if(callScript(script, "preNoteMiss", [daNote, field]) == Globals.Function_Stop)
				return;
		}

		////
		if(!daNote.isSustainNote && daNote.unhitTail.length > 0){
			for(tail in daNote.unhitTail){
				tail.tooLate = true;
				tail.blockHit = true;
				tail.ignoreNote = true;
				//health -= daNote.missHealth * healthLoss; // this is kinda dumb tbh no other VSRG does this just FNF
			}
		}

		if(!daNote.noMissAnimation)
		{
			var chars:Array<Character> = daNote.characters;

			if (daNote.gfNote && gf != null)
				chars.push(gf);
			else if (chars.length == 0)
				chars = field.characters;

			if (combo > 10 && gf!=null && chars.contains(gf) == false && gf.animOffsets.exists('sad'))
			{
				gf.playAnim('sad');
				gf.specialAnim = true;
			}

			for(char in chars){
				if(char != null && char.animTimer <= 0 && !char.voicelining)
				{
					var daAlt = (daNote.noteType == 'Alt Animation') ? '-alt' : '';
					var animToPlay:String = singAnimations[Std.int(Math.abs(daNote.noteData))] + daAlt + 'miss';

					char.playAnim(animToPlay, true);

					if (!char.hasMissAnimations)
						char.color = 0xFFC6A6FF;
				}	
			}
		}


/* 		breakCombo();
		
		health -= daNote.missHealth * healthLoss;	 */
		
		if (!mine){
			songMisses++;
			applyJudgment(daNote.hitResult.judgment);
		}else{
			applyJudgment(MISS_MINE);
			health -= daNote.missHealth * healthLoss;
		}
		
		vocals.volume = 0;

/* 		if(!practiceMode) 
			songScore -= 10; */

/* 		if(!daNote.isSustainNote ){
			if (daNote.sustainLength > 0 && ClientPrefs.wife3)
			{
				totalPlayed += 2;
				totalNotesHit += Wife3.holdDropWeight;
			}else{
				totalPlayed += ClientPrefs.wife3?2:1;
				if(ClientPrefs.wife3)
					totalNotesHit += mine?Wife3.mineWeight:Wife3.missWeight;
			}
			
			if(!mine)showJudgment("miss");
			RecalculateRating();
		} */

		if (!daNote.isSustainNote && ClientPrefs.missVolume > 0) // i missed this sound
			FlxG.sound.play(Paths.soundRandom('missnote', 1, 3), FlxG.random.float(ClientPrefs.missVolume * 0.9, ClientPrefs.missVolume * 1));

		if(instakillOnMiss)
			doDeathCheck(true);

		////
		callOnHScripts("noteMiss", [daNote, field]);
		#if LUA_ALLOWED
		callOnLuas('noteMiss', [notes.members.indexOf(daNote), daNote.noteData, daNote.noteType, daNote.isSustainNote, daNote.ID]);
		#end
		////
		if (daNote.noteScript != null)
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
				callScript(script, "noteMiss", [daNote, field]);
		}
	}

	function noteMissPress(direction:Int = 1):Void //You pressed a key when there was no notes to press for this key
	{
		if(ClientPrefs.ghostTapping) return; //fuck it

		health -= 0.05 * healthLoss;
		if(instakillOnMiss)
		{
			vocals.volume = 0;
			doDeathCheck(true);
		}

		if (combo > 10 && gf != null && gf.animOffsets.exists('sad')){
			gf.playAnim('sad');
			gf.specialAnim = true;
		}
		
/* 		combo = 0;
		while (lastCombos.length > 0)
			lastCombos.shift().kill(); */
		breakCombo();

		if(!practiceMode) songScore -= 10;
		if(!endingSong) songMisses++;
		
		// i dont think this should reduce acc lol
		//totalPlayed++;
		//RecalculateRating();

		FlxG.sound.play(Paths.soundRandom('missnote', 1, 3), ClientPrefs.missVolume*FlxG.random.float(0.9, 1));

		for (field in playfields.members)
		{
			if (!field.isPlayer)
				continue;

			for(char in field.characters)
			{
				if(char.animTimer <= 0 && !char.voicelining)
				{
					char.playAnim(singAnimations[Std.int(Math.abs(direction))] + 'miss', true);
					if(!char.hasMissAnimations)
						char.color = 0xFFC6A6FF;	
				}
			}
		}

		vocals.volume = 0;

		callOnScripts('noteMissPress', [direction]);
	}

	function opponentNoteHit(note:Note, field:PlayField):Void
	{
		if (Paths.formatToSongPath(SONG.song) != 'tutorial')
			camZooming = true;

		// Script shit
		var isSus:Bool = note.isSustainNote; //GET OUT OF MY HEAD, GET OUT OF MY HEAD, GET OUT OF MY HEAD
		var leData:Int = Math.round(Math.abs(note.noteData));
		var leType:String = note.noteType;

		if (note.noteScript != null)
		{
			var script:FunkinScript = note.noteScript;
			#if LUA_ALLOWED
			if (script.scriptType == 'lua')
				if (callScript(script, 'preOpponentNoteHit', [notes.members.indexOf(note), leData, leType, isSus, note.ID]) == Globals.Function_Stop)
					return;
				else
			#end
			if (callScript(script, "preOpponentNoteHit", [note, field]) == Globals.Function_Stop)
				return;
		}
		if (callOnHScripts("preOpponentNoteHit", [note, field]) == Globals.Function_Stop)
			return;
		#if LUA_ALLOWED
		if (callOnLuas('preOpponentNoteHit', [notes.members.indexOf(note), leData, leType, isSus, note.ID]) == Globals.Function_Stop)
			return;
		#end

		var chars:Array<Character> = note.characters;
		if (note.gfNote)
			chars.push(gf);
		else if (chars.length == 0)
			chars = field.characters;

		for(char in chars){
			char.callOnScripts("playNote", [note, field]);

			if(note.noteType == 'Hey!' && char.animOffsets.exists('hey')) {
				char.playAnim('hey', true);
				char.specialAnim = true;
				char.heyTimer = 0.6;
			} else if(!note.noAnimation) {
				var animToPlay:String = singAnimations[Std.int(Math.abs(note.noteData))];

				var curSection = SONG.notes[curSection];
				if ((curSection != null && curSection.altAnim) || note.noteType == 'Alt Animation')
					animToPlay += '-alt';

				if (char != null && char.animTimer <= 0 && !char.voicelining){
					char.playAnim(animToPlay, true);
					char.holdTimer = 0;
					char.callOnScripts("playNoteAnim", [animToPlay, note]);
				}
			}
		}

		if (SONG.needsVoices)
			vocals.volume = 1;

		if (note.visible){
			var time:Float = 0.15;
			if (note.isSustainNote && !note.animation.curAnim.name.endsWith('end'))
			time += 0.15;

			StrumPlayAnim(field, Std.int(Math.abs(note.noteData)) % 4, time, note);
		}

		note.hitByOpponent = true;

		callOnHScripts("opponentNoteHit", [note, field]);
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
				callScript(script, "opponentNoteHit", [note, field]);
		}

					

		if (!note.isSustainNote && note.sustainLength == 0)
		{
			if (opponentHPDrain > 0 && health > opponentHPDrain)
				health -= opponentHPDrain;

			field.removeNote(note);
		}
		else if (note.isSustainNote)
			if (note.parent.unhitTail.contains(note))
				note.parent.unhitTail.remove(note);
		
	}

	function goodNoteHit(note:Note, field:PlayField):Void
	{
		
		if (note.wasGoodHit || (field.autoPlayed && (note.ignoreNote || note.breaksCombo)))
			return;

		if(!note.isSustainNote)
			noteHits.push(Conductor.songPosition);

		if (ClientPrefs.hitsoundVolume > 0 && !note.hitsoundDisabled)
			FlxG.sound.play(Paths.sound('hitsound'), ClientPrefs.hitsoundVolume);

		// Strum animations
		if (note.visible){
			if(field.autoPlayed){
				var time:Float = 0.15;
				if(note.isSustainNote && !note.animation.curAnim.name.endsWith('end'))
					time += 0.15;

				StrumPlayAnim(field, Std.int(Math.abs(note.noteData)) % 4, time, note);
			}else{
				var spr = field.strumNotes[note.noteData];
				if(spr != null && field.keysPressed[note.noteData])
					spr.playAnim('confirm', true, note);
			}
		}

		// Script shit

		var isSus:Bool = note.isSustainNote; //GET OUT OF MY HEAD, GET OUT OF MY HEAD, GET OUT OF MY HEAD
		var leData:Int = Math.round(Math.abs(note.noteData));
		var leType:String = note.noteType;

		if (note.noteScript != null)
		{
			var script:FunkinScript = note.noteScript;
			#if LUA_ALLOWED
			if (script.scriptType == 'lua')
				if (callScript(script, 'preGoodNoteHit', [notes.members.indexOf(note), leData, leType, isSus, note.ID]) == Globals.Function_Stop)
					return;
				else
			#end
			if (callScript(script, "preGoodNoteHit", [note, field]) == Globals.Function_Stop)
				return;
		}
		if (callOnHScripts("preGoodNoteHit", [note, field]) == Globals.Function_Stop)
			return;
		#if LUA_ALLOWED
		if (callOnLuas('preGoodNoteHit', [notes.members.indexOf(note), leData, leType, isSus, note.ID]) == Globals.Function_Stop)
			return;
		#end

		if (cpuControlled)saveScore = false; // if botplay hits a note, then you lose scoring

		// tbh I hate hitCuasesMiss lol its retarded
		// added a shitty judge to deal w/ it tho!!
 		if(note.hitResult.judgment == MISS_MINE) {
			noteMiss(note, field, true);

			if (!note.noMissAnimation)
			{
				switch (note.noteType)
				{
					case 'Hurt Note': // Hurt note
						var chars:Array<Character> = note.characters;
						if (note.gfNote)
							chars.push(gf);
						else if (chars.length == 0)
							chars = field.characters;

						for(char in chars){
							if (char.animation.getByName('hurt') != null){
								char.playAnim('hurt', true);
								char.specialAnim = true;
							}
						}

				}
			}

			note.wasGoodHit = true;
			if (!note.isSustainNote && note.tail.length==0)
				field.removeNote(note);
			else if(note.isSustainNote){
				if (note.parent != null)
					if (note.parent.unhitTail.contains(note))
						note.parent.unhitTail.remove(note);
				
			}
			return;
		} 

		// TODO: rewrite judgement code since i hate it -neb
		if (!note.isSustainNote)
			judge(note, field);
		

		// Sing animations


		var chars:Array<Character> = note.characters;
		if (note.gfNote)
			chars.push(gf);
		else if(chars.length==0)
			chars = field.characters;


		for(char in chars)
			char.callOnScripts("playNote", [note]);


		if(!note.noAnimation) {
			var animToPlay:String = singAnimations[Std.int(Math.abs(note.noteData))];

			var curSection = SONG.notes[curSection];
			if ((curSection != null && curSection.altAnim) || note.noteType == 'Alt Animation')
				animToPlay += '-alt';
			
			for(char in chars){
				if (char != null && char.animTimer <= 0 && !char.voicelining){
					char.playAnim(animToPlay, true);
					char.holdTimer = 0;
					char.callOnScripts("playNoteAnim", [animToPlay, note]);
				}
			}

			if(note.noteType == 'Hey!') {
				for(char in chars){
					if (char.animTimer <= 0 && !char.voicelining){
						if(char.animOffsets.exists('hey')) {
							char.playAnim('hey', true);
							char.specialAnim = true;
							char.heyTimer = 0.6;
						}
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
		callOnHScripts("goodNoteHit", [note, field]);
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
				callScript(script, "goodNoteHit", [note, field]);
		}
		if (!note.isSustainNote && note.tail.length == 0)
			field.removeNote(note);
		else if (note.isSustainNote)
		{
			if (note.parent != null)
				if (note.parent.unhitTail.contains(note))
					note.parent.unhitTail.remove(note);
		}
	}

	function getFieldFromNote(note:Note){

		for (playfield in playfields)
		{
			if (playfield.hasNote(note))
				return playfield;
		}

		return playfields.members[0];
	}

	public function spawnNoteSplashOnNote(note:Note, ?field:PlayField) {
		if(ClientPrefs.noteSplashes && note != null) {
			if(field==null)
				field = getFieldFromNote(note);

			var strum:StrumNote = field.strumNotes[note.noteData];
			if(strum != null) {
				spawnNoteSplash(strum.x + strum.width * 0.5, strum.y + strum.height * 0.5, note.noteData, field, note);
			}
		}
	}

	public function spawnNoteSplash(x:Float, y:Float, data:Int, field:PlayField, ?note:Note = null) {
		field.spawnSplash(data, splashSkin, note);
	}

	private var preventLuaRemove:Bool = false;
	override function destroy() 
	{
		// Could probably do a results screen like the one on kade engine but for freeplay only. I think that could be cool.
		// ^ I was JUST thinking this. We can show the average NPS, accuracy, grade, judge counters, etc
		// I think just in general adding more stats could be neat & since we have the new options menu we can just put it in UI in a seperate category
		// so you can set exactly which stats show up in the scoretxt, etc

		/*
		trace(msJudges.length / {
			var total = 0.0;
			for (n in msJudges) total+=n;
			total;
		});*/

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

	var lastStepHit:Int = -9999;
	override function stepHit()
	{
		super.stepHit();
		if(curStep == lastStepHit) 
			return;
		
		hud.stepHit(curStep);
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

		if(lastBeatHit >= curBeat) 
			return;
	
		
		hud.beatHit(curBeat);

		if (camZooming && ClientPrefs.camZoomP>0 && FlxG.camera.zoom < 1.35 && zoomEveryBeat > 0 && curBeat % zoomEveryBeat == 0)
		{
			FlxG.camera.zoom += 0.015 * camZoomingMult * ClientPrefs.camZoomP;
			camHUD.zoom += 0.03 * camZoomingMult * ClientPrefs.camZoomP;
		}

		if (gf != null)
		{
			var gfDanceEveryNumBeats = Math.round(gfSpeed * gf.danceEveryNumBeats);
			if ((gfDanceEveryNumBeats != 0 && curBeat % gfDanceEveryNumBeats == 0) && gf.animation.curAnim != null && !gf.animation.curAnim.name.startsWith("sing") && !gf.stunned)
				gf.dance();
		}
		
		for(field in playfields)
		{
			for(char in field.characters)
			{
				if(char!=gf)
				{
					if ((char.danceEveryNumBeats != 0 && curBeat % char.danceEveryNumBeats == 0)
						&& char.animation.curAnim != null
						&& !char.animation.curAnim.name.startsWith('sing')
						&& !char.stunned)
					{
						char.dance();
					}
				}
			}
		}

		lastBeatHit = curBeat;

		setOnScripts('curBeat', curBeat); //DAWGG?????
		callOnScripts('onBeatHit');
	}

	override function sectionHit(){
		var sectionNumber = curSection;
		var curSection = SONG.notes[sectionNumber];

		if (curSection == null)
			return;

		if (curSection.changeBPM)
		{
			Conductor.changeBPM(curSection.bpm);
			
			setOnScripts('curBpm', Conductor.bpm);
			setOnScripts('crochet', Conductor.crochet);
			setOnScripts('stepCrochet', Conductor.stepCrochet);
		}
		
		setOnLuas("curSection", sectionNumber);
		setOnHScripts("curSection", curSection);
		setOnScripts('sectionNumber', sectionNumber);

		setOnScripts('mustHitSection', curSection.mustHitSection == true);
		setOnScripts('altAnim', curSection.altAnim == true);
		setOnScripts('gfSection', curSection.gfSection  == true);

		if (lastSection != sectionNumber)
		{
			lastSection = sectionNumber;
			callOnScripts("onSectionHit");
		}

		if (generatedMusic && !endingSong)
		{
			moveCameraSection(curSection);
		}
	}

	inline public function callOnAllScripts(event:String, ?args:Array<Dynamic>, ignoreStops:Bool = false, ?exclusions:Array<String>, ?scriptArray:Array<Dynamic>,
			?vars:Map<String, Dynamic>):Dynamic
			return callOnScripts(event,args,ignoreStops,exclusions,scriptArray,vars,false);

	public function callOnScripts(event:String, ?args:Array<Dynamic>, ignoreStops:Bool = false, ?exclusions:Array<String>, ?scriptArray:Array<Dynamic>,
			?vars:Map<String, Dynamic>, ?ignoreSpecialShit:Bool = true):Dynamic
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
			var ret:Dynamic = script.call(event, args, vars);
			if (ret == Globals.Function_Halt)
			{
				ret = returnVal;
				if (!ignoreStops)
					return returnVal;
			};
			if (ret != Globals.Function_Continue && ret!=null){
				returnVal = ret;
			}
		}
		
		if(returnVal==null)returnVal = Globals.Function_Continue;
		return returnVal;
	}

	public function setOnScripts(variable:String, value:Dynamic, ?scriptArray:Array<Dynamic>)
	{
		if (scriptArray == null)
			scriptArray = funkyScripts;

		for (script in scriptArray){
			script.set(variable, value);
			// trace('set $variable, $value, on ${script.scriptName}');
		}	
	}

	public function callScript(script:Dynamic, event:String, args:Array<Dynamic>):Dynamic
	{
		if((script is FunkinScript)){
			return callOnScripts(event, args, true, [], [script], false);
		}
		else if((script is Array)){
			return callOnScripts(event, args, true, [], script, false);
		}
		else if((script is String)){
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
	public function callOnHScripts(event:String, ?args:Array<Dynamic>, ?vars:Map<String, Dynamic>, ignoreStops = false, ?exclusions:Array<String>):Dynamic
		return callOnScripts(event, args, ignoreStops, exclusions, hscriptArray, vars);
	
	public function setOnHScripts(variable:String, arg:Dynamic)
		return setOnScripts(variable, arg, hscriptArray);

	public function setDefaultHScripts(variable:String, arg:Dynamic){
		FunkinHScript.defaultVars.set(variable, arg);
		return setOnScripts(variable, arg, hscriptArray);
	}
	#end

	#if LUA_ALLOWED
	public function callOnLuas(event:String, ?args:Array<Dynamic>, ignoreStops = false, ?exclusions:Array<String>):Dynamic
		return callOnScripts(event, args, ignoreStops, exclusions, luaArray);
	
	public function setOnLuas(variable:String, arg:Dynamic)
		setOnScripts(variable, arg, luaArray);
	#end

	function StrumPlayAnim(field:PlayField, id:Int, time:Float, ?note:Note) {
		var spr:StrumNote = field.strumNotes[id];

		if(spr != null) {
			spr.playAnim('confirm', true, note);
			spr.resetAnim = time;
		}
	}

	public var ratingName:String = '?';
	public var ratingPercent(default,set):Float;
	public var ratingFC:String;

	function set_ratingPercent(val:Float){
		if(perfectMode && val<1){
			health = -100;
			doDeathCheck(true);
		}
		return ratingPercent = val;
	}
	public function RecalculateRating() {
		setOnScripts('score', songScore);
		setOnScripts('misses', songMisses);
		setOnScripts('comboBreaks', comboBreaks);
		setOnScripts('hits', songHits);

		var ret:Dynamic = callOnScripts('onRecalculateRating');
		
		if(ret != Globals.Function_Stop)
		{
			if(totalPlayed < 1) //Prevent divide by 0
				ratingName = '?';
			else
			{
				// Rating Percent
				if(ClientPrefs.wife3)
					ratingPercent = totalNotesHit / totalPlayed;
				else
					ratingPercent = Math.min(1, Math.max(0, totalNotesHit / totalPlayed));
				//trace((totalNotesHit / totalPlayed) + ', Total: ' + totalPlayed + ', notes hit: ' + totalNotesHit);

				// Rating Name
				if(ratingPercent >= 1)
					ratingName = ratingStuff[0][0]; //Uses first string
				else
				{
					ratingName = ratingStuff[ratingStuff.length-1][0];
					for (i in 0...ratingStuff.length)
					{
						if(ratingPercent >= ratingStuff[i][1])
						{
							ratingName = ratingStuff[i][0];
							break;
						}
					}
				}
			}

			// Rating FC
			ratingFC = "Clear";
			if(comboBreaks <= 0){
			if (judges.get("epic") > 0) ratingFC = "KFC";
			if (judges.get("sick") > 0) ratingFC = "AFC";
			if (judges.get("good") > 0 && judges.get("good") < 10) ratingFC = "SDC";
			else if (judges.get("good") >= 10) ratingFC = "CFC";
			if (judges.get("bad") > 0 || judges.get("shit") > 0) ratingFC = "FC";
			}else{
				if (comboBreaks < 10 && songScore >= 0) ratingFC = "SDCB";
				else if (songScore < 0 || comboBreaks >= 10 && ratingPercent <= 0)ratingFC = "Fail";
			}
		}
		// maybe move all of this to a stats class that I can easily give to objects?
		hud.ratingFC = ratingFC;
		hud.grade = ratingName;
		hud.ratingPercent = ratingPercent;
		hud.misses = songMisses;
		hud.combo = combo;
		hud.comboBreaks = comboBreaks;
		hud.judgements.set("miss", songMisses);
		hud.judgements.set("cb", comboBreaks);
		hud.totalNotesHit = totalNotesHit;
		hud.totalPlayed = totalPlayed;
		hud.score = songScore;
		
		hud.recalculateRating();

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

				if(FlxG.sound.music != null) 
				{
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
	public var isOpponentMode:Bool = false; // going insane

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
		//healthBarBG.loadGraphic(Paths.image('healthBar'));
		healthBarBG.makeGraphic(600, 18);
		healthBarBG.color = 0xFF000000;
		healthBarBG.screenCenter(X);
		healthBarBG.scrollFactor.set();
		healthBarBG.antialiasing = false;

		//
		iconP1 = new HealthIcon(bfHealthIcon, true);
		iconP2 = new HealthIcon(dadHealthIcon, false);
		leftIcon = iconP2;
		rightIcon = iconP1;

		//
		isOpponentMode = PlayState.instance.playOpponent;

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
		antialiasing = false;
		scrollFactor.set();
		alpha = ClientPrefs.hpOpacity;
		visible = alpha > 0;
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
		var val = isOpponentMode ? max-val : val;

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

		alpha = ClientPrefs.hpOpacity;

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