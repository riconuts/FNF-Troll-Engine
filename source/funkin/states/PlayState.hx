package funkin.states;

import funkin.objects.playfields.PlayField.NoteCallback;
import funkin.data.CharacterData;
import funkin.data.Cache;
import funkin.data.Song;
import funkin.data.BaseSong;
import funkin.data.Section;
import funkin.objects.notes.Note;
import funkin.objects.notes.NoteSplash;
import funkin.objects.notes.StrumNote;
import funkin.objects.Stage;
import funkin.objects.Character;
import funkin.objects.RatingGroup;
import funkin.objects.hud.*;
import funkin.objects.playfields.*;
import funkin.data.Stats;
import funkin.data.JudgmentManager;
import funkin.data.Highscore;
import funkin.data.WeekData;
import funkin.states.GameOverSubstate;
import funkin.states.PauseSubState;
import funkin.modchart.Modifier;
import funkin.modchart.ModManager;
import funkin.states.editors.*;
import funkin.states.options.*;
import funkin.scripts.*;
import funkin.scripts.Util;
import funkin.scripts.Util as ScriptingUtil;
import funkin.scripts.FunkinScript.ScriptType;
import flixel.*;
import flixel.util.*;
import flixel.util.FlxSignal.FlxTypedSignal;
import flixel.math.*;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.addons.transition.FlxTransitionableState;
import flixel.group.FlxGroup;
import flixel.group.FlxSpriteGroup;
import flixel.input.keyboard.FlxKey;
import flixel.input.gamepad.FlxGamepadInputID;
import flixel.text.FlxText;
import flixel.ui.FlxBar;

import haxe.Json;

import lime.media.openal.AL;
import lime.media.openal.ALFilter;
import lime.media.openal.ALEffect;

import openfl.events.KeyboardEvent;
import openfl.filters.BitmapFilter;
import openfl.filters.ShaderFilter;

using StringTools;
using funkin.CoolerStringTools;

#if DISCORD_ALLOWED
import funkin.api.Discord.DiscordClient;
#end

#if (!VIDEOS_ALLOWED) typedef VideoHandler = Dynamic;
#elseif (hxCodec >= "3.0.0") import hxcodec.flixel.FlxVideo as VideoHandler;
#elseif (hxCodec >= "2.6.1") import hxcodec.VideoHandler as VideoHandler;
#elseif (hxCodec == "2.6.0") import VideoHandler;
#elseif (hxCodec) import vlc.MP4Handler as VideoHandler; 
#elseif (hxvlc) import hxvlc.flixel.FlxVideo as VideoHandler;
#end

enum abstract CharacterType(Int) from Int to Int {
	var BF = 0;
	var DAD = 1;
	var GF = 2;

	public static function fromString(str:String):CharacterType {
		return switch (str.toLowerCase().trim()) {
			case 'bf'	| 'boyfriend'	| '0': BF;
			case 'dad'	| 'opponent'	| '1': DAD;	
			case 'gf'	| 'girlfriend'	| '2': GF;
			default: -1;
		}
	}
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
	position:Float, // the y position where the change happens (modManager.getVisPos(songTime))
	startTime:Float, // the song position (conductor.songTime) where the change starts
	#if EASED_SVs
	startSpeed:Float, // the previous event's speed
	?endTime:Float, // the song position (conductor.songTime) when the change ends
	?easeFunc:EaseFunction,
	#end
	speed:Float // speed mult after the change
}

@:noScripting
class PlayState extends MusicBeatState
{
	public static function loadPlaylist(playlist:Array<BaseSong>, chartId:String) {
		PlayState.loadSong(playlist[0], chartId);
		PlayState.songPlaylist = playlist;
		PlayState.songPlaylistIdx = 0;	
	}

	private static function loadSong(song:BaseSong, chartId:String) {
		Paths.currentModDirectory = song.folder;
		PlayState.song = song;
		PlayState.SONG = song.getSwagSong(chartId);
		PlayState.difficultyName = chartId;
	}

	public var extraData:Map<String, Dynamic> = [];

	var legacyOnCreatePost:Bool = true; // Can be set by scripts to make onCreatePost be called where it used to be (before the countdown and super.create)
	// NOTE: Make this false probably before 1.0 or 1.1 releases
	// true by default rn just for the sake of not breaking things
	// You can set it to false in a script if you wanna make sure things dont break when its false tho

	public static var instance:PlayState;

	public static var SONG:SwagSong = null;
	public static var songPlaylist:Array<BaseSong> = [];
	public static var songPlaylistIdx = 0;

	public static var song:BaseSong;

	public static var difficultyName:String = 'normal'; // should NOT be set to "" when playing normal diff!!!!!

	public static var isStoryMode:Bool = false;
	// public static var storyWeek:Int = 0;
	public static var campaignScore:Int = 0;
	public static var campaignMisses:Int = 0;
	public static var deathCounter:Int = 0;
	
	public static var chartingMode:Bool = false;
	public static var startOnTime:Float = 0;

	public static var seenCutscene:Bool = false;
	public static var postSongVideo:String = '';
	
	public static var curStage:String = 'stage';
	public static var arrowSkin:String = 'NOTE_assets'; // dont check for this being null, playstate should not let these be null or an empty string
	public static var splashSkin:String = 'noteSplashes'; // dont check for this being null, playstate should not let these be null or an empty string
	public static var keyCount:Int = 4;

	////
	public var showDebugTraces:Bool = #if debug true #else Main.showDebugTraces #end;

	public var health(default, set):Float = 1.0;
	public var maxHealth:Float = 2.0;

	/** Health value to be displayed on the HUD **/
	public var displayedHealth(default, set):Float = 1.0;

	//// Gameplay settings
	public var healthGain:Float = 1.0;
	public var healthLoss:Float = 1.0;
	public var healthDrain:Float = 0.0;
	public var opponentHPDrain:Float = 0.0;
	public var holdsGiveHP:Bool = false;

	public var songSpeed(default, set):Float = 1.0;
	public var songSpeedType:String = "multiplicative";
	public var noteKillOffset:Float = 350;
	public var playbackRate(default, set):Float = 1.0;

	public var disableModcharts:Bool = false;
	public var practiceMode:Bool = false;
	public var perfectMode:Bool = false;
	public var instaRespawn:Bool = false;
	public var cpuControlled(default, set) = false;

	public var noDropPenalty:Bool = false;
	public var playOpponent:Bool = false;
	public var instakillOnMiss:Bool = false;

	/** Songs can force this off prior to countdown start and modchart generation **/
	public var centerNotefield:Bool = false;
	/** Whether to save the score. modcharted songs should set this to false if disableModcharts is true **/
	public var saveScore:Bool = true;
	
	#if ALLOW_DEPRECATION
	@:deprecated public var midScroll(get, set):Bool;
	@:noCompletion function get_midScroll() return centerNotefield;
	@:noCompletion function set_midScroll(v) return centerNotefield = v;
	#end

	////
	public var worldCombos:Bool = false;
	public var showRating:Bool = true;
	public var showCombo:Bool = false;
	public var showComboNum:Bool = true;

	var lastJudge:RatingSprite;
	var lastCombos:Array<RatingSprite> = [];

	public var skipCountdown:Bool = false;
	public var skipArrowStartTween:Bool = false;

	////
	public var displayedSong:String;
	public var displayedDifficulty:String;
	public var metadata:SongMetadata; // metadata for the songs (artist, etc)

	public var stats:Stats;
	public var ratingStuff:Array<Array<Dynamic>>;
	public var noteHits:Array<Float> = [];
	public var nps:Int = 0;
	
	public var trackMap = new Map<String, FlxSound>();
	public var tracks:Array<FlxSound> = [];

	public var instTracks:Array<FlxSound>;
	public var playerTracks:Array<FlxSound>;
	public var opponentTracks:Array<FlxSound>;

	public var inst:FlxSound;
	public var vocals:FlxSound;
	
	public var hitsound:FlxSound;

	var sndFilter:ALFilter = AL.createFilter();
	var sndEffect:ALEffect = AL.createEffect();

	////
	public var camGame:FlxCamera;
	public var camStageUnderlay:FlxCamera; // retarded
	public var camHUD:FlxCamera;
	public var camOverlay:FlxCamera; // shit that should go above all else and not get affected by camHUD changes, but still below camOther (pause menu, etc)
	public var camOther:FlxCamera;

	public var camFollow:FlxPoint;
	public var camFollowPos:FlxObject;
	private static var prevCamFollow:Null<FlxPoint> = null;
	private static var prevCamFollowPos:Null<FlxObject> = null;

	public var camZooming:Bool = false;
	public var camZoomingMult:Float = 1.0;
	public var camZoomingDecay:Float = 1.0;

	public var cameraSpeed:Float = 1.0;
	public var defaultCamZoom:Float = 1.0;
	public var defaultHudZoom:Float = 1.0;

	public var sectionCamera = new FlxPoint(); // Default camera focus point
	public var customCamera = new FlxPoint(); // Used for the 'Camera Follow Pos' event
	public var cameraPoints:Array<FlxPoint>;

	public function addCameraPoint(point:FlxPoint){
		cameraPoints.remove(point);
		cameraPoints.push(point);
	}

	////
	public var stage:Stage;
	private var stageData:StageFile;

	public var BF_X:Float = 770;
	public var BF_Y:Float = 100;
	public var DAD_X:Float = 100;
	public var DAD_Y:Float = 100;
	public var GF_X:Float = 400;
	public var GF_Y:Float = 130;

	public var dad:Character = null;
	public var gf:Character = null;
	public var boyfriend:Character = null;

	public var boyfriendGroup:FlxSpriteGroup;
	public var dadGroup:FlxSpriteGroup;
	public var gfGroup:FlxSpriteGroup;

	//// Used for character change events	
	public var boyfriendMap:Map<String, Character> = new Map();
	public var dadMap:Map<String, Character> = new Map();
	public var gfMap:Map<String, Character> = new Map();
	public var extraMap:Map<String, Character> = new Map();

	public var boyfriendCameraOffset:Array<Float> = null;
	public var opponentCameraOffset:Array<Float> = null;
	public var girlfriendCameraOffset:Array<Float> = null;

	// Default sing animations. You should be using playfield.singAnimations instead!!
	#if ALLOW_DEPRECATION
	public var singAnimations:Array<String> = ["singLEFT", "singDOWN", "singUP", "singRIGHT"];
	#end
	public var focusedChar:Character;
	public var gfSpeed:Int = 1;

	public var notes = new FlxTypedGroup<Note>();
	public var unspawnNotes:Array<Note> = [];
	public var allNotes:Array<Note> = []; // all notes
	public var eventNotes:Array<PsychEvent> = [];

	var speedChanges:Array<SpeedEvent> = [];
	public var currentSV:SpeedEvent = {position: 0, startTime: 0, speed: 1 #if EASED_SVs , startSpeed: 1 #end};
	public var judgeManager:JudgmentManager;

	public var modManager:ModManager;
	public var notefields = new NotefieldRenderer();
	public var playfields = new FlxTypedGroup<PlayField>();
	public var grpNoteSplashes = new FlxTypedGroup<NoteSplash>();

	public var playerField:PlayField;
	public var dadField:PlayField;

	/** Group instance containing HUD objects **/
	public var hud:BaseHUD; // perhaps this and 'hudSkins' could and/or should be fused together
	
	public var ratingGroup:RatingGroup;
	public var timingTxt:FlxText;

	/** debugPrint text container **/
	#if(HSCRIPT_ALLOWED)
	private var luaDebugGroup:FlxTypedGroup<DebugText> = new FlxTypedGroup<DebugText>();
	#end

	////
	public var songId:String = "";
	public var songLength:Float = 0;
	public var songHighscore:Int = 0;
	public var songTrackNames:Array<String> = [];

	#if ALLOW_DEPRECATION
	/** Formatted song name **/
	@:deprecated("songName is deprecated! use songId instead!")
	public var songName(get, never):String;
	function get_songName() return songId;
	#end

	////
	private var generatedMusic:Bool = false;
	public var startingSong:Bool = false;
	public var inCutscene:Bool = false;
	public var endingSong:Bool = false;

	public var songHits:Int = 0;
	public var songMisses:Int = 0;

	var finishTimer:FlxTimer = null;
	public var curCountdown:Countdown;
	public var songSpeedTween:FlxTween;
	
	public var introAlts:Array<Null<String>> = ["onyourmarks", 'ready', 'set', 'go'];
	public var introSnds:Array<Null<String>> = ["intro3", 'intro2', 'intro1', 'introGo'];
	public var introSoundsSuffix:String = '';
	
	public var countdownSpr:Null<FlxSprite>;
	public var countdownSnd:Null<FlxSound>;
	public var countdownTwn:FlxTween;
	
	public var startedOnTime:Float = 0;

	// Debug buttons
	private var debugKeysChart:Array<FlxKey>;
	private var debugKeysBotplay:Array<FlxKey>;
	private var debugKeysCharacter:Array<FlxKey>;

	// Less laggy controls
	private var keysArray:Array<Array<FlxKey>>;
	private var buttonsArray:Array<Array<FlxGamepadInputID>>;

	// nightmarevision compatibility shit !
	#if NMV_MOD_COMPATIBILITY
	public var whosTurn:String = 'dad';
	public var defaultCamZoomAdd:Float = 0;
	@:isVar public var beatsPerZoom(get, set):Int = 4;
	@:noCompletion function get_beatsPerZoom()return zoomEveryBeat;
	@:noCompletion function set_beatsPerZoom(val:Int)return zoomEveryBeat = val;
	#end

	////
	@:isVar public var songScore(get, set):Int = 0;
	@:isVar public var totalPlayed(get, set):Float = 0;
	@:isVar public var totalNotesHit(get, set):Float = 0.0;
	@:isVar public var combo(get, set):Int = 0;
	@:isVar public var cbCombo(get, set):Int = 0;
	@:isVar public var ratingName(get, set):String = '?';
	@:isVar public var ratingPercent(get, set):Float;
	@:isVar public var ratingFC(get, set):String;
	
	@:noCompletion public inline function get_songScore()
		return ClientPrefs.showWifeScore ? Math.floor(stats.totalNotesHit * 200) : stats.score; // Alot of the time, songScore is used in HUDs
	@:noCompletion public inline function get_totalPlayed()return stats.totalPlayed;
	@:noCompletion public inline function get_totalNotesHit()return stats.totalNotesHit;
	@:noCompletion public inline function get_combo()return stats.combo;
	@:noCompletion public inline function get_cbCombo()return stats.cbCombo;
	@:noCompletion public inline function get_ratingName()return stats.grade;
	@:noCompletion public inline function get_ratingPercent()return stats.ratingPercent;
	@:noCompletion public inline function get_ratingFC()return stats.clearType;

	@:noCompletion public inline function set_songScore(val:Int)return stats.score = val;
	@:noCompletion public inline function set_totalPlayed(val:Float)return stats.totalPlayed = val;
	@:noCompletion public inline function set_totalNotesHit(val:Float)return stats.totalNotesHit = val;
	@:noCompletion public inline function set_combo(val:Int)return stats.combo = val;
	@:noCompletion public inline function set_cbCombo(val:Int)return stats.cbCombo = val;
	@:noCompletion public inline function set_ratingName(val:String)return stats.grade = val;
	@:noCompletion public inline function set_ratingPercent(val:Float)return stats.ratingPercent = val;
	@:noCompletion public inline function set_ratingFC(val:String)return stats.clearType = val;

	#if DISCORD_ALLOWED
	// Discord RPC variables
	var updateDiscordRPC:Bool = true;
	var detailsText:String = "";
	var detailsPausedText:String = "";
	var stateText:String = "";
	#end

	//// Script shit
	public var funkyScripts:Array<FunkinScript> = [];
	public var hscriptArray:Array<FunkinHScript> = [];

	public var scriptsToClose:Array<FunkinScript> = [];

	public var signals = new PlayStateSignals();

	////
	var noteTypeMap:Map<String, Bool> = [];
	var eventPushedMap:Map<String, Bool> = [];
	
	// used by lua scripts
	public var modchartTweens:Map<String, FlxTween> = new Map();
	public var modchartSprites:Map<String, ModchartSprite> = new Map();
	public var modchartTimers:Map<String, FlxTimer> = new Map();
	public var modchartSounds:Map<String, FlxSound> = new Map();
	public var modchartTexts:Map<String, ModchartText> = new Map();
	public var modchartSaves:Map<String, FlxSave> = new Map();
	public var modchartObjects:Map<String, FlxSprite> = new Map();

	public var notetypeScripts:Map<String, FunkinHScript> = []; // custom notetypes for scriptVer '1'
	public var eventScripts:Map<String, FunkinHScript> = []; // custom events for scriptVer '1'
	public var hudSkinScripts:Map<String, FunkinHScript> = []; // Doing this so you can do shit like i.e having it swap between pixel and normal HUD

	public var hudSkin(default, set):String;
	public var hudSkinScript:FunkinHScript; // this is the HUD skin used for countdown, judgements, etc

	////
	@:noCompletion function set_hudSkin(value:String){
		var script = getHudSkinScript(value);
		
		if (hudSkinScript != null)
			hudSkinScript.call("onSkinUnload");
		
		hudSkinScript = script;

		if(script != null)script.call("onSkinLoad");
		return hudSkin = value;
	}

	@:noCompletion function set_health(value:Float){
		health = FlxMath.bound(value, 0, maxHealth);
		displayedHealth = health;

		return health;
	}

	@:noCompletion function set_displayedHealth(value:Float){
		hud.displayedHealth = value;
		displayedHealth = value;

		return value;
	}

	@:noCompletion function set_cpuControlled(value:Bool):Bool {
		cpuControlled = value;

		setOnScripts('botPlay', value);

		/// oughhh
		for (playfield in playfields.members){
			if (playfield.isPlayer)
				playfield.autoPlayed = cpuControlled; 
		}

		return value;
	}

	@:noCompletion function set_songSpeed(value:Float):Float
	{
		songSpeed = value;
		noteKillOffset = 350 / songSpeed;
		return value;
	}

	// Loading
	var shitToLoad:Array<AssetPreload> = [];
	var finishedCreating = false;
	
	public var offset:Float = 0;

	override public function create()
	{
		print('\nCreating PlayState\n');
		Highscore.loadData();
		
		this.songSyncMode = SongSyncMode.fromString(ClientPrefs.songSyncMode);

		Conductor.cleanup();
		Conductor.safeZoneOffset = ClientPrefs.hitWindow;
		Wife3.timeScale = Wife3.judgeScales.get(ClientPrefs.judgeDiff);
		PBot.missThreshold = Math.max(160, ClientPrefs.hitWindow);

		ratingStuff = Highscore.grades.get(ClientPrefs.gradeSet);
		stats = new Stats(ClientPrefs.accuracyCalc, ratingStuff);
		stats.useFlags = ClientPrefs.gradeSet == 'Etterna';

		judgeManager = new JudgmentManager();
		judgeManager.judgeTimescale = Wife3.timeScale;
		
		modManager = new ModManager(this);

		OptionsSubstate.resetRestartRecomendations();
		Paths.clearStoredMemory();
		#if MODS_ALLOWED
		Paths.preLoadContent = [];
		Paths.postLoadContent = [];
		Paths.pushGlobalContent();
		#end

		//// Reset to default
		PauseSubState.songName = null;
		GameOverSubstate.resetVariables();

		////
		FlxG.fixedTimestep = false;
		FlxG.worldBounds.set(0, 0, FlxG.width, FlxG.height);

		persistentUpdate = true;
		persistentDraw = true;

		MusicBeatState.stopMenuMusic();

		updateKeybinds();

		speedChanges.push({
			position: -6000 * 0.45,
			startTime: -6000,
			speed: 1, 
			#if EASED_SVs
			startSpeed: 1,
			#end
		});

		#if EASED_SVs
		resetSVDeltas();
		#end
		
		//// Gameplay settings
		if (!isStoryMode){
			playbackRate = ClientPrefs.getGameplaySetting('songspeed', playbackRate);
			healthGain = ClientPrefs.getGameplaySetting('healthgain', healthGain);
			healthLoss = ClientPrefs.getGameplaySetting('healthloss', healthLoss);
			holdsGiveHP = ClientPrefs.getGameplaySetting('holdsgivehp', holdsGiveHP);
			playOpponent = ClientPrefs.getGameplaySetting('opponentPlay', playOpponent);
			instakillOnMiss = ClientPrefs.getGameplaySetting('instakill', instakillOnMiss);
			practiceMode = ClientPrefs.getGameplaySetting('practice', practiceMode);
			perfectMode = ClientPrefs.getGameplaySetting('perfect', perfectMode);
			instaRespawn = ClientPrefs.getGameplaySetting('instaRespawn', instaRespawn);
			cpuControlled = ClientPrefs.getGameplaySetting('botplay', cpuControlled);
			disableModcharts = ClientPrefs.getGameplaySetting('disableModcharts', false);
			noDropPenalty = ClientPrefs.getGameplaySetting('noDropPenalty', false);
			centerNotefield = ClientPrefs.centerNotefield;

			#if tgt
			playbackRate *= (ClientPrefs.ruin ? 0.8 : 1);
			#end

			healthDrain = 0.0;
			opponentHPDrain = 0.0;
		}

		FlxG.timeScale = playbackRate;
		
		if (perfectMode){
			practiceMode = false;
			instakillOnMiss = true;
		}
		saveScore = true; //!cpuControlled;

		//// Camera shit
		camGame = new FlxCamera();
		camHUD = new FlxCamera();
		camOverlay = new FlxCamera();
		camOther = new FlxCamera();
		camStageUnderlay = new FlxCamera();

		camHUD.bgColor = 0; 
		camOverlay.bgColor = 0;
		camOther.bgColor = 0;
		camStageUnderlay.bgColor = 0;

		FlxG.cameras.reset(camGame);
		FlxG.cameras.add(camStageUnderlay, false);
		FlxG.cameras.add(camHUD, false);
		FlxG.cameras.add(camOverlay, false);
		FlxG.cameras.add(camOther, false);

		FlxG.cameras.setDefaultDrawTarget(camGame, true);

		camFollow = prevCamFollow != null ? prevCamFollow : new FlxPoint();
		camFollowPos = prevCamFollowPos != null ? prevCamFollowPos : new FlxObject();

		camGame.follow(camFollowPos, LOCKON, 1);
		camGame.focusOn(camFollow);
		camGame.zoom = defaultCamZoom;

		////
		if (SONG == null){
			throw 'No chart data available';
		}
		
		songId = (song?.songId) ?? Paths.formatToSongPath(SONG.song);
		songHighscore = Highscore.getScore(songId, difficultyName);

		offset = SONG.offset ?? 0.0;
		Conductor.mapBPMChanges(SONG);
		Conductor.changeBPM(SONG.bpm);
		Conductor.songPosition = Conductor.crochet * -5;
		Conductor.updateSteps();

		metadata = song?.getMetadata(difficultyName);
		if (showDebugTraces && metadata == null)
			trace('No metadata for $songId. Maybe add some?');

		if (isStoryMode) {
			postSongVideo = Paths.formatToSongPath('$songId-end');
			skipArrowStartTween = (songPlaylistIdx > 0);
		}

		for (groupName in Reflect.fields(SONG.tracks)) {
			var trackGroup:Array<String> = Reflect.field(SONG.tracks, groupName);
			for (trackName in trackGroup) {
				if (trackMap.exists(trackName))
					continue;

				trackMap.set(trackName, null);
				songTrackNames.push(trackName);
			}
		}
		
		PlayState.keyCount = SONG.keyCount;
		StrumNote.defaultStaticAnimNames = ['arrowLEFT', 'arrowDOWN', 'arrowUP', 'arrowRIGHT']; 
		StrumNote.defaultPressAnimNames = ["left press", "down press", "up press", "right press"];
		StrumNote.defaultConfirmAnimNames = ["left confirm", "down confirm", "up confirm", "right confirm"];
		Note.defaultNoteAnimNames = ['purple0', 'blue0', 'green0', 'red0'];
		Note.defaultHoldAnimNames = ['purple hold piece', 'blue hold piece', 'green hold piece', 'red hold piece'];
		Note.defaultTailAnimNames = ['purple hold end', 'blue hold end', 'green hold end', 'red hold end'];
		Note.spriteScale = (4 / keyCount) * 0.7;
		Note.swagWidth = Note.spriteScale * 160;
		/**
		 * Note texture asset names
		 * The quant prefix gets handled by the Note class
		 */
		arrowSkin = SONG.arrowSkin;
		splashSkin = SONG.splashSkin;

		hudSkin = SONG.hudSkin;
		curStage = SONG.stage;

		////
		instance = this;
		setDefaultHScripts("modManager", modManager);
		setDefaultHScripts("judgeManager", judgeManager);
		setDefaultHScripts("newPlayField", newPlayfield);
		setDefaultHScripts("initPlayfield", initPlayfield);

		//// GLOBAL SONG SCRIPTS
		var filesPushed:Array<String> = [];
		for (folder in Paths.getFolders('scripts')) {
			//// Create scripts in order from the list file first
			for (name in CoolUtil.coolTextFile(folder + 'orderList.txt')) {
				for(ext in Paths.HSCRIPT_EXTENSIONS) {
					var fileName = '$name.$ext';
					var filePath = folder + fileName;

					if (Paths.exists(filePath) && !filesPushed.contains(fileName)) {
						createHScript(filePath);
						filesPushed.push(fileName);
					}
				}
			}

			//// Create the rest of scripts that weren't on the order list
			Paths.iterateDirectory(folder, (file:String) -> {
				if (Paths.isHScript(file) && !filesPushed.contains(file)) {
					createHScript(folder + file);
					filesPushed.push(file);
				}
			});
		}
		//trace("Loaded global scripts in order:" + filesPushed);

		//// STAGE SCRIPTS
		stage = new Stage(curStage, true);
		stageData = stage.stageData;

		if (stage.stageScript != null){
			hscriptArray.push(stage.stageScript);
			funkyScripts.push(stage.stageScript);
		}

		setStageData(stageData);

		// SONG SPECIFIC SCRIPTS
		var foldersToCheck:Array<String> = Paths.getFolders('songs/$songId');

		var filesPushed:Array<String> = [];
		for (folder in foldersToCheck) {
			Paths.iterateDirectory(folder, (file:String) -> {
				if (Paths.isHScript(file) && !filesPushed.contains(file)) {
					createHScript(folder + file);
					filesPushed.push(file);
				}
			});
		}

		//// Asset precaching start		
		for (judgeData in judgeManager.judgmentData)
			shitToLoad.push({path: judgeData.internalName});

		for (i in 0...10)
			shitToLoad.push({path: 'num$i'});

		for (i in 1...3) // TODO: Be able to add more than 3 miss sounds
			shitToLoad.push({path: 'missnote$i', type: 'SOUND'});

		shitToLoad.push({path: 'hitsound', type: 'SOUND'});
		shitToLoad.push({path: "healthBar"});
		shitToLoad.push({path: "timeBar"});

		/* 
		if (PauseSubState.songName != null)
			shitToLoad.push({path: PauseSubState.songName, type: 'MUSIC'});
		else if (ClientPrefs.pauseMusic != 'None')
			shitToLoad.push({path: Paths.formatToSongPath(ClientPrefs.pauseMusic), type: 'MUSIC'}); 
		shitToLoad.push({path: "breakfast", type: 'MUSIC'}); 
		*/

		////
		if (ClientPrefs.noteSkin == 'Quants'){
			shitToLoad.push({path: 'QUANT$arrowSkin'});
			shitToLoad.push({path: 'QUANT$splashSkin'});
		}else{
			shitToLoad.push({path: arrowSkin});
			shitToLoad.push({path: splashSkin});
		}

		////
		if (stageData.preloadStrings != null) {
			var lib = stageData.directory != "" ? stageData.directory : null;
			for (i in stageData.preloadStrings)
				shitToLoad.push({path: i, library: lib});
		}

		if (stageData.preload != null)
		{
			for (i in stageData.preload)
				shitToLoad.push(i);
		}

		inline function preloadCharacter(character:String):Void {
			if (character != null) {
				for (data in CharacterData.returnCharacterPreload(character))
					shitToLoad.push(data);
			}
		}
		preloadCharacter(SONG.player1);
		preloadCharacter(SONG.player2);
		if (!stageData.hide_girlfriend)
			preloadCharacter(SONG.gfVersion);

		for (track in songTrackNames){
			shitToLoad.push({
				path: '$songId/$track',
				type: 'SONG'
			});
		}

		Paths.getAllStrings();
		Cache.loadWithList(shitToLoad);
		shitToLoad = [];

		//// Asset precaching end

		var splash:NoteSplash = new NoteSplash(100, 100, 0);
		splash.alpha = 0.0;

		grpNoteSplashes.cameras = [camHUD];
		grpNoteSplashes.add(splash);

		////
		var stringId:String = 'difficultyName_$difficultyName';
		displayedDifficulty = Paths.getString(stringId, difficultyName.replace("-"," ").capitalize());
		
		displayedSong = metadata?.songName ?? songId.replace("-"," ").capitalize();

		if (hud == null) {
			// TODO: replace songId with the song object !?!?
			switch(ClientPrefs.etternaHUD){
				case 'Advanced': hud = new AdvancedHUD(songId, stats);
				case 'Kade': hud = new KadeHUD(songId, stats);
				case 'Classic': hud = new ClassicHUD(songId, stats);
				default: hud = new TraditionalHUD(songId, stats);
			}
		}
		hud.cameras = [camHUD];
		hud.alpha = ClientPrefs.hudOpacity;
		add(hud);

		//// Characters

		if (SONG.player1 != null) {
			changeCharacter(SONG.player1, BF);
		}

		if (SONG.player2 != null) {
			changeCharacter(SONG.player2, DAD);
		}

		if (SONG.gfVersion != null && stageData.hide_girlfriend != true) {
			changeCharacter(SONG.gfVersion, GF);
		}

		////
		stage.buildStage();

		// in case you want to layer characters or objects in a specific way (like in infimario for example)
		// RICO CAN WE STOP USING SLURS IN THE CODE
		// we???
		// fine, can YOU stop using slurs in the code >:(
		if (Globals.Function_Stop != callOnHScripts("onAddSpriteGroups"))
		{
			add(stage);

			add(gfGroup);
			add(dadGroup);
			add(boyfriendGroup);

			add(stage.foreground);
		}
		
		//// Generate playfields so you can actually, well, play the game
		#if ALLOW_DEPRECATION
		callOnScripts("prePlayfieldCreation"); // backwards compat
		// TODO: add deprecation messages to function callbacks somehow
		#end
		callOnScripts("onPlayfieldCreation"); // you should use this
		playfields.cameras = [camHUD];
		notes.cameras = [camHUD];
		add(notes);

		modManager.playerAmount = 2;
		for (i in 0...modManager.playerAmount)
			newPlayfield();
		
		playerField = playfields.members[0];
		if (playerField != null) {
			playerField.characters = [for(ch in boyfriendMap) ch];
			playerField.isPlayer = !playOpponent;
			playerField.autoPlayed = !playerField.isPlayer || cpuControlled;
			playerField.noteHitCallback = playOpponent ? opponentNoteHit : goodNoteHit;
		}

		dadField = playfields.members[1];
		if (dadField != null) {
			dadField.characters = [for(ch in dadMap) ch];
			dadField.isPlayer = playOpponent;
			dadField.autoPlayed = !dadField.isPlayer || cpuControlled;
			dadField.noteHitCallback = playOpponent ? goodNoteHit : opponentNoteHit;
		}
		
		#if ALLOW_DEPRECATION
		callOnScripts("postPlayfieldCreation"); // backwards compat
		#end
		callOnScripts("onPlayfieldCreationPost");

		////
		cameraPoints = [sectionCamera];
		moveCameraSection(SONG.notes[0]);

		////
		ratingGroup = new RatingGroup();
		ratingGroup.cameras = [worldCombos ? camGame : camHUD];
		lastJudge = ratingGroup.lastJudge;

		timingTxt = new FlxText();
		timingTxt.setFormat(Paths.font("vcr.ttf"), 28, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		timingTxt.cameras = ratingGroup.cameras;
		timingTxt.scrollFactor.set();
		timingTxt.borderSize = 1.25;
		
		timingTxt.visible = false;
		timingTxt.alpha = 0;

		// init shit
		health = 1.0;
		reloadHealthBarColors();

		startingSong = true;

		// EVENT AND NOTE SCRIPTS WILL GET LOADED HERE
		generateSong();

		#if DISCORD_ALLOWED
		// Discord RPC texts
		stateText = '${displayedSong} [$displayedDifficulty]';
		
		detailsText = isStoryMode ? "Story Mode" : "Freeplay";
		detailsPausedText = "Paused - " + detailsText;

		updateSongDiscordPresence();
		#end

		if (!ClientPrefs.controllerMode)
			addKeyboardEvents();

		////
		if(legacyOnCreatePost) // Just incase shit breaks???
			callOnAllScripts('onCreatePost');

		add(ratingGroup);
		add(timingTxt);
		add(playfields);
		add(notefields);
		add(grpNoteSplashes);

		luaDebugGroup.cameras = [camOther];
		add(luaDebugGroup);

		////
		#if !tgt
		if (prevCamFollowPos != null)
		{
			// do nothing
		}
		else if(SONG.notes[0].mustHitSection)
		{
			if (boyfriend != null) {
				var cam = (dad ?? boyfriend).getCamera();
				camFollow.set(cam[0], cam[1]);
	
				var cam = boyfriend.getCamera();
				sectionCamera.set(cam[0], cam[1]); 
			}
		}
		else if(SONG.notes[0].gfSection && gf != null)
		{
			if (gf != null) {
				var cam = (boyfriend ?? gf).getCamera();
				camFollow.set(cam[0], cam[1]); 
				
				var cam = gf.getCamera();
				sectionCamera.set(cam[0], cam[1]); 
			}
		}
		else
		{
			if (dad != null) {
				var cam = (boyfriend ?? dad).getCamera();
				camFollow.set(cam[0], cam[1]);
	
				var cam = dad.getCamera();
				sectionCamera.set(cam[0], cam[1]); 
			}

		}
		camFollowPos.setPosition(camFollow.x, camFollow.y);
		#end

		//// nulling them here so stage scripts can use them as a starting camera position
		prevCamFollow = null;
		prevCamFollowPos = null;

		// Load the countdown intro assets!!!!!

		if (hudSkinScript != null && hudSkinScript.exists("introSnds"))
			introSnds = hudSkinScript.get("introSnds");

		if (hudSkinScript != null && hudSkinScript.exists("introAlts"))
			introAlts = hudSkinScript.get("introAlts");

		for (introSndPath in introSnds){
			if (introSndPath != null)
				shitToLoad.push({path: introSndPath, type: "SOUND"});
		}
		for (introImgPath in introAlts){
			if (introImgPath != null)
				shitToLoad.push({path: introImgPath});
		}

		Cache.loadWithList(shitToLoad);
		shitToLoad = [];

		super.create();

		RecalculateRating();
		startCountdown();

		if(!legacyOnCreatePost) // Just incase shit breaks???
			callOnAllScripts('onCreatePost');

		finishedCreating = true;

		noteTypeMap.clear();
		noteTypeMap = null;
		eventPushedMap.clear();
		eventPushedMap = null;

		Paths.clearUnusedMemory();
	}

	function updateKeybinds() {
		debugKeysChart = ClientPrefs.copyKey(ClientPrefs.keyBinds.get('debug_1'));
		debugKeysCharacter = ClientPrefs.copyKey(ClientPrefs.keyBinds.get('debug_2'));
		debugKeysBotplay = ClientPrefs.copyKey(ClientPrefs.keyBinds.get('botplay'));

		keysArray = [
			ClientPrefs.copyKey(ClientPrefs.keyBinds.get('note_left')),
			ClientPrefs.copyKey(ClientPrefs.keyBinds.get('note_down')),
			ClientPrefs.copyKey(ClientPrefs.keyBinds.get('note_up')),
			ClientPrefs.copyKey(ClientPrefs.keyBinds.get('note_right'))
		];

		buttonsArray = [
			ClientPrefs.copyKey(ClientPrefs.buttonBinds.get('note_left')),
			ClientPrefs.copyKey(ClientPrefs.buttonBinds.get('note_down')),
			ClientPrefs.copyKey(ClientPrefs.buttonBinds.get('note_up')),
			ClientPrefs.copyKey(ClientPrefs.buttonBinds.get('note_right'))
		];
	}

	function setStageData(stageData:StageFile)
	{
		defaultCamZoom = stageData.defaultZoom;
		camGame.zoom = defaultCamZoom;

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

	public function addTextToDebug(text:String, ?color:FlxColor = FlxColor.WHITE) {
		luaDebugGroup.forEachAlive(function(spr:DebugText) {
			spr.y += 20;
		});

		if(luaDebugGroup.members.length > 34) {
			var blah = luaDebugGroup.members[34];
			blah.destroy();
			luaDebugGroup.remove(blah);
		}
		luaDebugGroup.insert(0, new DebugText(text, luaDebugGroup));
	}

	public function reloadHealthBarColors() {
		// TODO: fuck this move it to hud.changedCharacter
		var dadArray = dad?.healthColorArray;
		var bfArray = boyfriend?.healthColorArray;
		var dadColor:FlxColor = (dadArray==null) ? 0xFFFF0000 : FlxColor.fromRGB(dadArray[0], dadArray[1], dadArray[2]);
		var bfColor:FlxColor = (bfArray==null) ? 0xFF00FF00 : FlxColor.fromRGB(bfArray[0], bfArray[1], bfArray[2]);
		
		if(callOnHScripts('reloadHealthBarColors', [hud, dadColor, bfColor]) == Globals.Function_Stop)
			return;

		hud.reloadHealthBarColors(dadColor, bfColor);
	}

	public function addCharacterToList(name:String, type:CharacterType) {
		switch(type) {
			case BF:
				if (boyfriendMap.exists(name))
					return;

				var char = new Character(0, 0, name, true);
				boyfriendMap.set(name, char);
				boyfriendGroup.add(char);

				char.setDefaultVar("used", false);
				char.alpha = 0.00001;

				startCharacter(char);

				char.cameraPosition[0] += stageData.camera_boyfriend[0];
				char.cameraPosition[1] += stageData.camera_boyfriend[1];
				
				if (playerField != null)
					playerField.characters.push(char);

			case DAD:
				if (dadMap.exists(name))
					return;

				var char = new Character(0, 0, name);
				dadMap.set(name, char);
				dadGroup.add(char);

				char.setDefaultVar("used", false);
				char.alpha = 0.00001;

				startCharacter(char, true);

				char.cameraPosition[0] += stageData.camera_opponent[0];
				char.cameraPosition[1] += stageData.camera_opponent[1];

				if (dadField!=null)
					dadField.characters.push(char);
				
			case GF:
				if (gfMap.exists(name)) 
					return;

				var char = new Character(0, 0, name);
				gfMap.set(name, char);
				gfGroup.add(char);
				
				char.setDefaultVar("used", false);
				char.alpha = 0.00001;

				startCharacter(char);

				char.cameraPosition[0] += stageData.camera_girlfriend[0];
				char.cameraPosition[1] += stageData.camera_girlfriend[1];
				char.scrollFactor.set(0.95, 0.95);
		}
	}

	function startCharacter(char:Character, ?gfCheck:Bool=false) {
		char.startScripts();
		char.setupCharacter();

		for (script in char.characterScripts) {
			hscriptArray.push(cast script);

			funkyScripts.push(script);
		}

		startCharacterPos(char, gfCheck);
	}

	public function getLuaObject(tag:String, ?checkForTextsToo:Bool){
		if (modchartObjects.exists(tag)) return modchartObjects.get(tag);
		if (modchartSprites.exists(tag)) return modchartSprites.get(tag);
		if (checkForTextsToo==true && modchartTexts.exists(tag)) return modchartTexts.get(tag);
		return null;
	}

	function startCharacterPos(char:Character, ?gfCheck:Bool = false, ?startBopBeat:Float) {
		if (startBopBeat != null) char.nextDanceBeat = startBopBeat;
		char.x += char.positionArray[0];
		char.y += char.positionArray[1];
	}

	var curVideo:VideoHandler = null;
	public function startVideo(name:String):VideoHandler
	{
		#if !VIDEOS_ALLOWED
		inCutscene = true;

		FlxG.log.warn('Video not supported!');
		startAndEnd();
		return null;
		#else

		var filepath:String = Paths.video(name);
		if (!Paths.exists(filepath))
		{
			FlxG.log.warn('Couldnt find video file: ' + name);
			startAndEnd();
			return null;
		}
		var video:VideoHandler = curVideo = new VideoHandler();
		#if (hxvlc)
		video.load(filepath);
		video.onEndReached.add(() ->
		{
			video.dispose();
			if (FlxG.game.contains(video))
				FlxG.game.removeChild(video);
			if (curVideo == video)
				curVideo = null;
			startAndEnd();
		});
		video.play();
		#elseif (hxCodec >= "3.0.0")
		video.play(filepath);
		video.onEndReached.add(()->{
			video.dispose();

			if (curVideo == video)
				curVideo = null;
			startAndEnd();
		}, true);
		#else
		video.playVideo(filepath);
		video.finishCallback = startAndEnd;
		#end

		return video;
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
		if (isStoryMode && !seenCutscene)
		{
			switch (songName)
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

	public function startCountdown():Void
	{
		if(startedCountdown) {
			callOnScripts('onStartCountdown');
			callScript(hudSkinScript, "onStartCountdown");
			return;
		}

		inCutscene = false;

		if (hudSkinScript != null) {
			if (callScript(hudSkinScript, "onStartCountdown") == Globals.Function_Stop)
				return;
		}

		if (callOnScripts('onStartCountdown') == Globals.Function_Stop) {
			return;
		}

		if (skipCountdown || startOnTime > 0)
			skipArrowStartTween = true;

		generateStrums();

		#if ALLOW_DEPRECATION
		callOnScripts('preModifierRegister'); // deprecated
		#end

		if (callOnScripts('onModifierRegister') != Globals.Function_Stop) {
			modManager.registerDefaultModifiers();

			if (centerNotefield) {
				var off:Float = Math.min(FlxG.width, 1280) / 4;
				var opp:Int = playOpponent ? 0 : 1;
				
				var halfKeys:Int = Math.floor(keyCount / 2);
				if (keyCount % 2 != 0) // middle receptor dissappears, if there is one
					modManager.setValue('alpha${halfKeys + 1}', 1.0, opp);
				
				for (i in 0...halfKeys)
					modManager.setValue('transform${i}X', -off, opp);
				for (i in keyCount-halfKeys...keyCount)
					modManager.setValue('transform${i}X', off, opp);
	
				modManager.setValue("alpha", 0.6, opp);
				modManager.setValue("opponentSwap", 0.5);
			}

			signals.onModifierRegister.dispatch();
		}
		#if ALLOW_DEPRECATION
		callOnScripts('postModifierRegister'); // deprecated
		#end
		callOnScripts('onModifierRegisterPost');
		signals.onModifierRegisterPost.dispatch();

		startedCountdown = true;
		setOnScripts('startedCountdown', true);
		callOnScripts('onCountdownStarted');
		if (hudSkinScript != null)
			hudSkinScript.call("onCountdownStarted");

		callOnScripts("generateModchart"); // this is where scripts should generate modcharts from here on out lol

		if (PlayState.startOnTime >= 500) {
			trace('starting on time: $startOnTime');
			startSong(PlayState.startOnTime, -500);
			PlayState.startOnTime = 0;
			return;
		}
		
		if (skipCountdown)
			return;

		// Do the countdown.
		var countdown = new funkin.objects.Countdown(this);
		resetCountdown(countdown);
		countdown.start(Conductor.crochet * 0.001); // time is optional but here we are
		curCountdown = countdown;
	}

	public function resetCountdown(countdown:funkin.objects.Countdown):Void {
		if (countdown == null) return;
		// I don't wanna break scripts so if you have a better way, do it
		if (countdown.introAlts != introAlts) countdown.introAlts = introAlts;
		if (countdown.introSnds != introSnds) countdown.introSnds = introSnds;
		if (countdown.introSoundsSuffix != introSoundsSuffix) countdown.introSoundsSuffix = introSoundsSuffix;
		countdown.onTick = (pos: Int) -> {
			countdownSpr = countdown.sprite;
			countdownSnd = countdown.sound;
			countdownTwn = countdown.tween;
		}
		//
	}

	function checkCharacterDance(character:Character, ?beat:Float, ignoreBeat:Bool = false){
		if (character.danceEveryNumBeats == 0) return;
		beat ??= this.curDecBeat;
		
		var shouldBop = beat >= character.nextDanceBeat;
		if (shouldBop || ignoreBeat){
			if (shouldBop)
				character.nextDanceBeat += character.danceEveryNumBeats;

			if ((character.animation.curAnim == null || !character.animation.curAnim.name.startsWith("sing")) && !character.stunned) 
				character.dance();
		}
	}

	function danceCharacters(?curBeat:Float)
	{
		curBeat ??= this.curDecBeat;

		if (gf != null)
			checkCharacterDance(gf, curBeat);	

		for (field in playfields)
		{
			for (char in field.characters)
			{
				if (char != gf)
					checkCharacterDance(char, curBeat);
			}
		}
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
		var time = time + 350;

		var i:Int = allNotes.length - 1;
		while (i >= 0) {
			var daNote:Note = allNotes[i];
			if(daNote.strumTime < time)
			{
				daNote.ignoreNote = true;
				modchartObjects.remove('note${daNote.ID}');
				for (field in playfields)
					field.removeNote(daNote);

				camZooming = true;
			}
			--i;
		}
	}

	public function setSongTime(time:Float)
	{
		if(time < 0) time = 0;

		if (curCountdown != null && !curCountdown.finished)
			curCountdown.destroy();

		Conductor.startSong(time);
	}

	function startSong(startOnTime:Float=0, offset:Float = 0):Void
	{
		startingSong = false;

		var realStartTime = startOnTime + offset;
		if (realStartTime > 0) {
			startedOnTime = startOnTime;
			clearNotesBefore(startOnTime);
		}else {
			realStartTime = 0;
		}

		Conductor.startSong(realStartTime);
		updateSongDiscordPresence();

		// Song duration in a float, useful for the time left feature
		songLength = inst.length;
		hud.songLength = songLength;
		hud.songStarted();

		setOnScripts('songLength', songLength);
		callOnScripts('onSongStart');
	}

	function shouldPush(event:PsychEvent){
		switch(event.event){
			default:
				if (eventScripts.exists(event.event)) {
					var script = eventScripts.get(event.event);
					var returnVal:Dynamic = script.call('shouldPush', [event]);
					
					//trace(event.event, "shouldPush", returnVal);
					
					if (returnVal == true)
						return true;
					if (returnVal == false)
						return false;
					if (returnVal == Globals.Function_Stop)
						return false;					
				}
		}

		return true;
	}

	static function eventNoteSort(a:PsychEvent, b:PsychEvent)
		return Std.int(a.strumTime - b.strumTime);

	function getSongEventNotes():Array<PsychEvent>
	{
		var allEvents:Array<PsychEvent> = [];

		var eventsJSON = Song.loadFromJson('events', songId, false);
		if (eventsJSON != null) Song.getEventNotes(eventsJSON.events, allEvents);

		Song.getEventNotes(SONG.events, allEvents);

		return allEvents;
	}

	private function createFirstScriptFromFolders(name:String, folders:Array<String>, ignoreCreateCall:Bool = false):FunkinScript {
		for (folder in folders)  {
			var pathKey:String = '$folder/$name';

			var hscriptPath = Paths.getHScriptPath(pathKey);
			if (hscriptPath != null) {
				return createHScript(hscriptPath, name, true);
			}
		}

		return null;
	}

	@:noCompletion
	private function set_playbackRate(pitch:Float):Float {		
		FlxG.timeScale = pitch;
		Conductor.changePitch(pitch);
		return playbackRate = pitch;
	}

	private function generateSong():Void
	{
		Conductor.changeBPM(PlayState.SONG.bpm);
		Conductor.tracks = this.tracks;
		Conductor.pitch = this.playbackRate;

		////
		songSpeedType = ClientPrefs.getGameplaySetting('scrolltype', songSpeedType);

		switch(songSpeedType)
		{
			case "multiplicative":
				songSpeed = SONG.speed * ClientPrefs.getGameplaySetting('scrollspeed', 1);
			case "constant":
				songSpeed = ClientPrefs.getGameplaySetting('scrollspeed', SONG.speed);
		}

		////
		#if tgt if(ClientPrefs.ruin){
			AL.effecti(sndEffect, AL.EFFECT_TYPE, AL.EFFECT_REVERB);
			AL.effectf(sndEffect, AL.REVERB_DECAY_TIME, 5);
			AL.effectf(sndEffect, AL.REVERB_GAIN, 0.75);
			AL.effectf(sndEffect, AL.REVERB_DIFFUSION, 0.5);
		}else #end {
			AL.effecti(sndEffect, AL.EFFECT_TYPE, AL.EFFECT_NULL);
			AL.filteri(sndFilter, AL.FILTER_TYPE, AL.FILTER_NULL);
		}

		////
		for (trackName in songTrackNames) {
			var sndAsset = {
				if (song != null)
					Paths.returnSound(song.getSongFile(trackName) + ".ogg");
				else
					Paths.track(songId, trackName);
			}
			var newTrack = new FlxSound().loadEmbedded(sndAsset);
			//newTrack.volume = 0.0;
			newTrack.pitch = playbackRate;
			newTrack.filter = sndFilter;
			newTrack.effect = sndEffect;
			newTrack.context = MUSIC;
			newTrack.exists = true; // So it doesn't get recycled
			FlxG.sound.list.add(newTrack);
			
			trackMap.set(trackName, newTrack);
			tracks.push(newTrack);
		}

		inline function getTrackInstances(nameArray:Null<Array<String>>)
			return nameArray==null ? [] : [for (name in nameArray) trackMap.get(name)];

		instTracks = getTrackInstances(SONG.tracks.inst);
		playerTracks = getTrackInstances(SONG.tracks.player);
		opponentTracks = getTrackInstances(SONG.tracks.opponent);

		hitsound = new FlxSound().loadEmbedded(Paths.sound("hitsound"));
		hitsound.exists = true;
		FlxG.sound.list.add(hitsound);

		playerField.tracks = playerTracks;
		dadField.tracks = opponentTracks;

		inst = instTracks[0];
		vocals = playerTracks[0];

		songLength = inst.length;
		inst.onComplete = function() {
			trace("song ended!?");
			finishSong(false);
		};
		
		//// NEW SHIT
		var noteData:Array<SwagSection> = PlayState.SONG.notes;

		// get note types to load
		for (section in noteData) {
			for (songNotes in section.sectionNotes) {
				var type:String = songNotes[3];
				if (noteTypeMap.exists(type))
					continue;

				noteTypeMap.set(type, true);
			}
		}

		//// get event names to load
		var daEvents:Array<PsychEvent> = getSongEventNotes();
		for (eventNote in daEvents) {
			var name:String = eventNote.event;
			if (eventPushedMap.exists(name))
				continue;

			eventPushedMap.set(name, true);
		}

		// create note type scripts
		final notetypeFolders = ["notetypes"];
		for (notetype in noteTypeMap.keys()) {
			var script = createFirstScriptFromFolders(notetype, notetypeFolders, true);
			if (script != null) {
				notetypeScripts.set(notetype, cast script);			
				firstNotePush(notetype);
			}
		}

		// create event scripts
		final eventFolders = ["events"];
		for (eventName in eventPushedMap.keys()) {
			var script:FunkinScript = createFirstScriptFromFolders(eventName, eventFolders, true);
			if (script != null) {
				eventScripts.set(eventName, cast script);
				firstEventPush(eventName);
			}
		}

		// apply event time offsets
		for (eventNote in daEvents)
			eventNote.strumTime -= eventNoteEarlyTrigger(eventNote);
		
		if(daEvents.length > 1)
			daEvents.sort(sortByTime);

		// push events
		for (eventNote in daEvents) {
			var sp = shouldPush(eventNote);
			
			if (sp) {
				eventNotes.push(eventNote);

				for(shit in getEventNotePreload(eventNote))
					shitToLoad.push(shit);
				
				eventPushed(eventNote);
			}/*else{
				trace("not pushing", eventNote.event, eventNote);
			}*/
		}

		speedChanges.sort(svSort);
		#if EASED_SVs
		resetSVDeltas();
		#end
		if (eventNotes.length > 1)
			eventNotes.sort(sortByTime);

		////
		var prevTime = Sys.time();
		generateNotes(noteData); // generates the chart
		print('generateNotes() took ${Sys.time() - prevTime} seconds');

		allNotes.sort(sortByNotes);

		for(fuck in allNotes)
			unspawnNotes.push(fuck);
		
		for (field in playfields.members)
			field.clearStackedNotes();

		checkEventNote();
		generatedMusic = true;
	}

	public function generateNotes(noteData:Array<SwagSection>, callScripts:Bool = true, addToFields:Bool = true, ?keyCount:Int, ?playfields:Array<PlayField>, ?notes:Array<Note>){

		if (playfields == null)
			playfields = this.playfields.members;

		if (notes==null)
			notes = this.allNotes;

		if(keyCount == null)
			keyCount = PlayState.keyCount;
		
		for (section in noteData) {
			for (songNotes in section.sectionNotes) {
				var daStrumTime:Float = songNotes[0];
				var daNoteData:Int = Std.int(songNotes[1]);
				var gottaHitNote:Bool = section.mustHitSection ? (daNoteData < keyCount) : (daNoteData >= keyCount);

				var daColumn:Int = daNoteData % keyCount;
				var susLength = Math.round(songNotes[2] / Conductor.stepCrochet) - 1;
				var prevNote:Note = (notes.length > 0) ? notes[notes.length - 1] : null;
				var daType:String = songNotes[3];

				var swagNote:Note = new Note(daStrumTime, daColumn, prevNote, gottaHitNote, songNotes[2] > 0 ? HEAD : TAP, false, hudSkin);
				#if ALLOW_DEPRECATION
				swagNote.realColumn = daNoteData;
				#end
				swagNote.sustainLength = songNotes[2] <= Conductor.stepCrotchet ? songNotes[2] : (susLength + 1) * Conductor.stepCrotchet; // +1 because hold end
				swagNote.ID = notes.length;

				modchartObjects.set('note${swagNote.ID}', swagNote);

				////
				if (section.altAnim) {
					swagNote.characterHitAnimSuffix = '-alt';
					swagNote.characterMissAnimSuffix = '-altmiss';
				}
				swagNote.gfNote = section.gfSection && daNoteData < keyCount;
				swagNote.noteType = daType;

				////
				var playfield:PlayField = swagNote.field;

				if (playfield == null && playfields.length > 0) {
					if (swagNote.fieldIndex == -1)
						swagNote.fieldIndex = swagNote.mustPress ? 0 : 1;

					if (playfields[swagNote.fieldIndex] != null) {
						playfield = playfields[swagNote.fieldIndex];
						swagNote.field = playfield;
					}
				}

				if (callScripts)
					callOnScripts("onGeneratedNote", [swagNote, section]);
				
				playfield = swagNote.field;
				swagNote.fieldIndex = playfield.modNumber;
				
				notes.push(swagNote); // just for the sake of convenience

				if (addToFields && playfield != null)
					playfield.queue(swagNote); // queues the note to be spawned

				if (callScripts)
					callOnScripts("onGeneratedNotePost", [swagNote, section]);
				
				prevNote = swagNote;
				
				inline function makeSustain(susNote:Int, susPart:SustainPart) {
					var sustainNote:Note = new Note(daStrumTime + Conductor.stepCrochet * (susNote + 1), daColumn, prevNote, gottaHitNote, susPart, false, hudSkin);
					#if ALLOW_DEPRECATION
					sustainNote.realColumn = daNoteData;
					#end
					sustainNote.ID = notes.length;
					modchartObjects.set('note${sustainNote.ID}', sustainNote);

					sustainNote.characterHitAnimSuffix = swagNote.characterHitAnimSuffix;
					sustainNote.characterMissAnimSuffix = swagNote.characterMissAnimSuffix;
					sustainNote.gfNote = swagNote.gfNote;
					sustainNote.noteType = daType;
					
					if (callScripts) 
						callOnScripts("onGeneratedHold", [sustainNote, section]);

					swagNote.tail.push(sustainNote);
					swagNote.unhitTail.push(sustainNote);
					sustainNote.parent = swagNote;
					sustainNote.fieldIndex = swagNote.fieldIndex;
					sustainNote.field = swagNote.field;

					if (addToFields && playfield != null)
						playfield.queue(sustainNote);

					notes.push(sustainNote);

					if (callScripts) 
						callOnScripts("onGeneratedHoldPost", [swagNote, section]);

					prevNote = sustainNote;
				}
				
				if (susLength > 0){
					for (susNote in 0...susLength)
						makeSustain(susNote, PART);
					makeSustain(susLength, END);
				}
			}
		}
		#if EASED_SVs
		resetSVDeltas();
		#end
		return notes;
	}

	// everything returned here gets preloaded by the preloader up-top ^
	function getEventNotePreload(event:PsychEvent):Array<AssetPreload>{
		var preload:Array<AssetPreload> = [];

		switch(event.event){
			case "Change Character":
				return CharacterData.returnCharacterPreload(event.value2);
		}

		return preload;
	}

	public function getNoteInitialTime(time:Float)
	{
		var event:SpeedEvent = getSV(time);
		return getTimeFromSV(time, event);
	}

	#if EASED_SVs
	var lastSVTime:Float = 0;
	var lastSVElapsed:Float = 0;
	var lastSVPos:Float = 0;
	
	inline function resetSVDeltas(){
		if(speedChanges.length > 0){
			lastSVTime = speedChanges[0].startTime;
			lastSVElapsed = 0;
			lastSVPos = speedChanges[0].position;
		}else{
			lastSVTime = -5000;
			lastSVElapsed = 0;
			lastSVPos = -5000 * 0.45;
		}
	}
	#end

	public function getTimeFromSV(time:Float, event:SpeedEvent):Float {
		#if EASED_SVs
		var func:EaseFunction = event.easeFunc == null ? FlxEase.linear : event.easeFunc;
		if (event.endTime != null) {
			var timeElapsed:Float = FlxMath.remapToRange(time, event.startTime, event.endTime, 0, 1);
			if(timeElapsed > 1)timeElapsed = 1;
			if(timeElapsed < 0)timeElapsed = 0;
			var currentSpeed = FlxMath.lerp(event.startSpeed, event.speed, func(lastSVElapsed));

			var toAdd:Float = time - lastSVTime;
			var finalPosition:Float = lastSVPos + toAdd * currentSpeed;
			
			lastSVPos = finalPosition;
			lastSVTime = time;
			lastSVElapsed = timeElapsed;
			return finalPosition;
		}
		#end

		return event.position + ((time - event.startTime) * 0.45 * event.speed);
	}

	public function getSV(time:Float){
		var svIndex:Int = 0;

		var event:SpeedEvent = speedChanges[svIndex];
		if (svIndex < speedChanges.length - 1) {
			while (speedChanges[svIndex + 1] != null && speedChanges[svIndex + 1].startTime <= time) {
				event = speedChanges[svIndex + 1];
				svIndex++;
			}
		}

		return event;
	}

	function eventNoteEarlyTrigger(event:PsychEvent):Float {
		var ret:Dynamic = callOnAllScripts('eventEarlyTrigger', [event.event, event.value1, event.value2]);
		if (ret != null && (ret is Int || ret is Float))
			return ret;
		
		if (eventScripts.exists(event.event)){
			var ret:Dynamic = callScript(eventScripts.get(event.event), "getOffset", [event]);
			if (ret != null && (ret is Int || ret is Float))
				return ret;
		}

		switch(event.event) {
			case 'Kill Henchmen': //Better timing so that the kill sound matches the beat intended
				return 280; //Plays 280ms before the actual position
		}
		return 0;
	}
	
	// called for every event note
	function eventPushed(event:PsychEvent) 
	{
		if (event.value1 == null) event.value1 = '';
		if (event.value2 == null) event.value2 = '';

		switch(event.event)
		{
			case 'Change Scroll Speed': // Negative duration means using the event time as the tween finish time
				var duration = Std.parseFloat(event.value2);
				if (!Math.isNaN(duration) && duration < 0.0){
					event.strumTime -= duration * 1000;
					event.value2 = Std.string(-duration);
				}

			case 'Mult SV' | 'Constant SV':
				var speed:Float = 1;
				if(event.event == 'Constant SV'){
					var b = Std.parseFloat(event.value1);
					speed = Math.isNaN(b) ? 1 : (b / songSpeed);
				}else{
					speed = Std.parseFloat(event.value1);
					if (Math.isNaN(speed)) speed = 1;
				}
				#if EASED_SVs
				var endTime:Null<Float> = null;
				var easeFunc:Null<EaseFunction> = null;

				var tweenOptions = event.value2.split("/");
				if(tweenOptions.length >= 1){
					easeFunc = FlxEase.linear;
					var parsed:Float = Std.parseFloat(tweenOptions[0]);
					if(!Math.isNaN(parsed))
						endTime = event.strumTime + (parsed * 1000);

					if(tweenOptions.length > 1){
						var f:EaseFunction = ScriptingUtil.getFlxEaseByString(tweenOptions[1]);
						if(f != null)
							easeFunc = f;
					}
				}

				var lastChange:SpeedEvent = speedChanges[speedChanges.length - 1];
				speedChanges.push({
					position: getTimeFromSV(event.strumTime, lastChange),
					startTime: event.strumTime,
					endTime: endTime,
					easeFunc: easeFunc,
					startSpeed: lastChange.startSpeed,
					speed: speed
				});
				#else
				var lastChange:SpeedEvent = speedChanges[speedChanges.length - 1];
				speedChanges.push({
					position: getTimeFromSV(event.strumTime, lastChange),
					startTime: event.strumTime,
					speed: speed
				});
				#end
				
			case 'Change Character':
				var charType = getCharacterTypeFromString(event.value1);
				if (charType != -1) addCharacterToList(event.value2, charType);

			default:
				if (eventScripts.exists(event.event)) {
					eventScripts.get(event.event).call("onPush", [event]);
				}
		}

		callOnHScripts("eventPushed", [event]);
	}

	// called only once for each different event
	function firstEventPush(eventName:String) {
		if (eventScripts.exists(eventName))
			eventScripts.get(eventName).call("onLoad");

		callOnHScripts("firstEventPush", [eventName]);
	}

	function firstNotePush(type:String) {
		if (notetypeScripts.exists(type))
			callScript(notetypeScripts.get(type), "onLoad", []);
	}

	inline function addKeyboardEvents() {
		FlxG.stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyDownEvent);
		FlxG.stage.addEventListener(KeyboardEvent.KEY_UP, onKeyUpEvent);		
	}
	
	inline function removeKeyboardEvents() {
		FlxG.stage.removeEventListener(KeyboardEvent.KEY_DOWN, onKeyDownEvent);
		FlxG.stage.removeEventListener(KeyboardEvent.KEY_UP, onKeyUpEvent);
	}

	public function optionsChanged(options:Array<String>){
		if (options.length < 1)
			return;

		this.songSyncMode = SongSyncMode.fromString(ClientPrefs.songSyncMode);
		
		trace("changed " + options);
				
		if (options.contains("gradeSet")) {
			ratingStuff = Highscore.grades.get(ClientPrefs.gradeSet);
			stats.useFlags = ClientPrefs.gradeSet == 'Etterna';
			// stats.accuracySystem = ClientPrefs.accuracyCalc;
			stats.gradeSet = ratingStuff;
			stats.updateVariables();
		}

		if (!ClientPrefs.coloredCombos)
			comboColor = 0xFFFFFFFF;

		if (!ClientPrefs.simpleJudge) {
			for (prevCombo in lastCombos)
				prevCombo.kill();
		}

		hud.alpha = ClientPrefs.hudOpacity;
		hud.changedOptions(options);
		
		callOnScripts('optionsChanged', [options]);
		if (hudSkinScript != null) callScript(hudSkinScript, "optionsChanged", [options]);
		
		for(field in playfields){
/* 			field.noteField.optimizeHolds = ClientPrefs.optimizeHolds; */
			field.noteField.drawDistMod = ClientPrefs.drawDistanceModifier;
			field.noteField.holdSubdivisions = Std.int(ClientPrefs.holdSubdivs) + 1;
		}

		if (ClientPrefs.controllerMode) {
			removeKeyboardEvents();
		}else {
			addKeyboardEvents();
		}

		var reBind:Bool = false;
		for (opt in options) {
			if (opt.startsWith("bind")) {
				reBind = true;
				break;
			}
		}

		if (reBind) {
			updateKeybinds();

			// unpress everything
			for (field in playfields.members) {
				if (!field.inControl || field.autoPlayed || !field.isPlayer)
					continue;

				for (idx in 0...field.keysPressed.length)
					field.keysPressed[idx] = false;

				for(obj in field.strumNotes) {
					obj.playAnim("static");
					obj.resetAnim = 0;
				}
			}
		}
	}

	override function draw(){
		if((subState is GameOverSubstate))
			camStageUnderlay.bgColor = 0;
		else
			camStageUnderlay.bgColor = Math.floor(0xFF * ClientPrefs.stageOpacity) * 0x1000000;

		var ret:Dynamic = callOnScripts('onDraw');
		if (ret != Globals.Function_Stop) 
			super.draw();

		callOnScripts('onDrawPost');
	}

	function sortByZIndex(Obj1:{zIndex:Float}, Obj2:{zIndex:Float}):Int
	{
		return FlxSort.byValues(FlxSort.ASCENDING, Obj1.zIndex, Obj2.zIndex);
	}

	function sortByNotes(Obj1:Note, Obj2:Note):Int
	{
		return FlxSort.byValues(FlxSort.ASCENDING, Obj1.strumTime, Obj2.strumTime);
	}

	function sortByTime(Obj1:{strumTime:Float}, Obj2:{strumTime:Float}):Int
	{
		return FlxSort.byValues(FlxSort.ASCENDING, Obj1.strumTime, Obj2.strumTime);
	}

	function svSort(Obj1:SpeedEvent, Obj2:SpeedEvent):Int
	{
		return FlxSort.byValues(FlxSort.ASCENDING, Obj1.startTime, Obj2.startTime);
	}

	private function generateStrums():Void
	{
		#if ALLOW_DEPRECATION
		callOnScripts('preReceptorGeneration'); // backwards compat, deprecated
		#end
		callOnScripts('onReceptorGeneration');

		for(field in playfields.members)
			field.generateStrums();

		#if ALLOW_DEPRECATION
		callOnScripts('postReceptorGeneration'); // deprecated
		#end
		callOnScripts('onReceptorGenerationPost');

		for(field in playfields.members)
			field.fadeIn(skipArrowStartTween);
	}

	override function openSubState(SubState:FlxSubState)
	{
		super.openSubState(SubState);
	}

	#if DISCORD_ALLOWED
	function updateSongDiscordPresence(?detailsText:String)
	{
		if (!updateDiscordRPC)
			return;

		final timeLeft:Float = (songLength - Conductor.songPosition - ClientPrefs.noteOffset);
		final detailsText:String = (detailsText!=null) ? detailsText : this.detailsText;

		if (isDead)
			DiscordClient.changePresence("Game Over - " + detailsText, stateText, songId);
		else if (paused)
			DiscordClient.changePresence(detailsPausedText, stateText, songId);
		else if (timeLeft > 0.0)
			DiscordClient.changePresence(detailsText, stateText, songId, true, timeLeft);
		else
			DiscordClient.changePresence(detailsText, stateText, songId);
	}
	#else
	// Saves me from having to write #if DISCORD_ALLOWED and blahblah
	inline function updateSongDiscordPresence(?detailsText:String) {}
	#end

	override function closeSubState()
	{
		if (paused)
			resume();

		super.closeSubState();
	}

	override public function onFocus():Void
	{
		if (!isDead && !paused)
			updateSongDiscordPresence();

		super.onFocus();
	}

	override public function onFocusLost():Void
	{
		if (ClientPrefs.autoPause && !paused && startedCountdown && canPause) {
			openPauseMenu();
		}

		super.onFocusLost();
	}

	////
	public function newPlayfield()
	{
		var field = new PlayField(modManager);
		field.modNumber = playfields.members.length;
		field.playerId = field.modNumber;
		field.cameras = playfields.cameras;
		initPlayfield(field);
		playfields.add(field);
		return field;
	}

	// good to call this whenever you make a playfield
	public function initPlayfield(field:PlayField){
		notefields.add(field.noteField);

		field.judgeManager = judgeManager;

		field.holdPressCallback = pressHold;
		field.holdStepCallback = stepHold;
		field.holdReleaseCallback = releaseHold;

		field.noteSpawned.add(field_noteSpawned);
		field.noteRemoved.add(field_noteRemoved);

		field.noteMissed.add(field_noteMissed);
		field.holdDropped.add(field_holdDropped);
		field.holdFinished.add(field_holdFinished);
	}

	function stepHold(note:Note, field:PlayField)
	{
		callOnHScripts("onHoldStep", [note, field]);
		
		if (note.noteScript != null)
			callScript(note.noteScript, "onHoldStep", [note, field]);

		if (note.genScript != null)
			callScript(note.genScript, "onHoldStep", [note, field]);

		if(field.isPlayer){
			if (holdsGiveHP && note.hitResult.judgment != UNJUDGED){
				var judgeData:JudgmentData = judgeManager.judgmentData.get(note.hitResult.judgment);
				if(judgeData.health > 0)
					health += judgeData.health * 0.02 * healthGain;
			}
		}
	}

	function pressHold(note:Note, field:PlayField)
	{
		callOnHScripts("onHoldPress", [note, field]);
		
		if (note.noteScript != null)
			callScript(note.noteScript, "onHoldPress", [note, field]);

		if (note.genScript != null)
			callScript(note.genScript, "onHoldPress", [note, field]);

		if (cpuControlled && note.isRoll && ClientPrefs.hitsoundBehav == 'Key Press') 
			playShithound();
		
	}
	
	function releaseHold(note:Note, field:PlayField):Void
	{
		callOnHScripts("onHoldRelease", [note, field]);
		
		if (note.noteScript != null)
			callScript(note.noteScript, "onHoldRelease", [note, field]);

		if (note.genScript != null)
			callScript(note.genScript, "onHoldRelease", [note, field]);	
	}

	function field_noteSpawned(dunceNote:Note, field:PlayField) {
		callOnHScripts('onSpawnNote', [dunceNote]);

		notes.add(dunceNote);
		unspawnNotes.remove(dunceNote);

		callOnHScripts('onSpawnNotePost', [dunceNote]);
		if (dunceNote.noteScript != null)
			callScript(dunceNote.noteScript, "postSpawnNote", [dunceNote]);
	}

	function field_noteRemoved(note:Note, field:PlayField) {
		modchartObjects.remove('note${note.ID}');
		allNotes.remove(note);
		unspawnNotes.remove(note);
		notes.remove(note);
	}

	function field_noteMissed(daNote:Note, field:PlayField) {
		if (!field.isPlayer)return;
		if (!field.autoPlayed && !daNote.ignoreNote && !endingSong && (daNote.tooLate || !daNote.wasGoodHit))
			noteMiss(daNote, field);
	}

	function field_holdDropped(daNote:Note, field:PlayField) {
		if (!field.isPlayer)return;
		if (stats.accuracySystem == 'PBot') {
			stats.totalPlayed += (PBot.holdScorePerSecond * (daNote.sustainLength * 0.001)) * 0.01;
			stats.totalNotesHit += PBot.holdScorePerSecond * 0.01 * (daNote.holdingTime * 0.001);
			RecalculateRating();
		}
	}
	
	function field_holdFinished(daNote:Note, field:PlayField) {
		if (!field.isPlayer)return;
		if (stats.accuracySystem == 'PBot') {
			stats.totalPlayed += (PBot.holdScorePerSecond * (daNote.sustainLength * 0.001)) * 0.01;
			stats.totalNotesHit += PBot.holdScorePerSecond * 0.01 * (daNote.sustainLength * 0.001);
			RecalculateRating();
		}
	}

	////
	@:noCompletion
	@:deprecated('resyncVocals is deprecated, use resyncTracks instead')
	function resyncVocals():Void
		return resyncTracks();

	override function resyncTracks():Void
	{
		if (finishTimer != null || transitioning || isDead)
			return;

		if (showDebugTraces)
			trace("resync vocals!!");

		super.resyncTracks();
		
		updateSongDiscordPresence();
	}

	public var paused:Bool = false;
	public var canReset:Bool = true;
	var startedCountdown:Bool = false;
	var canPause:Bool = true;
	var prevNoteCount:Int = 0;

	private var svIndex:Int =0;
	private inline function updateVisualPosition() {
		var event:SpeedEvent = null;

		for (i in svIndex+1...speedChanges.length) {
			var nextEvent = speedChanges[i];
			if (nextEvent.startTime > Conductor.songPosition)
				break;

			svIndex = i;
			event = nextEvent;
		}
		event ??= speedChanges[svIndex];
		
		Conductor.visualPosition = getTimeFromSV(Conductor.songPosition, event);
		FlxG.watch.addQuick("visualPos", Conductor.visualPosition);
	}

	override function updateSteps() {
		super.updateSteps();
		setOnScripts('curDecStep', curDecStep);
		setOnScripts('curDecBeat', curDecBeat);
	}

	override public function update(elapsed:Float)
	{
		if (paused){
			callOnScripts('onUpdate', [elapsed]);
			if (hudSkinScript != null) hudSkinScript.call("onUpdate", [elapsed]);

			super.update(elapsed);

			callOnScripts('onUpdatePost', [elapsed]);
			if (hudSkinScript != null) hudSkinScript.call("onUpdatePost", [elapsed]);

			return;
		}

		////
		for (idx in 0...playfields.members.length)
			playfields.members[idx].noteField.songSpeed = songSpeed;
		
		/*
		for (script in notetypeScripts)
			script.call("onUpdate", [elapsed]); 

		for (script in eventScripts)
			script.call("onUpdate", [elapsed]);

		callOnScripts('onUpdate', [elapsed], null, null, null, null, false);
		*/

		callOnScripts('onUpdate', [elapsed]);
		if (hudSkinScript != null)
			hudSkinScript.call("onUpdate", [elapsed]);

		if (!inCutscene) {
			var xOff:Float = 0;
			var yOff:Float = 0;

			if (ClientPrefs.directionalCam && focusedChar != null){
				xOff = focusedChar.camOffX;
				yOff = focusedChar.camOffY;
			}

			var currentCameraPoint = cameraPoints[cameraPoints.length-1];
			if (currentCameraPoint != null)
				camFollow.copyFrom(currentCameraPoint);

			var lerpVal:Float = Math.exp(-elapsed * 2.4 * cameraSpeed);
			camFollowPos.setPosition(
				FlxMath.lerp(camFollow.x + xOff, camFollowPos.x, lerpVal),
				FlxMath.lerp(camFollow.y + yOff, camFollowPos.y, lerpVal)
			);

			if (!startingSong && !endingSong){
				if (health > healthDrain)
					health -= healthDrain * elapsed;
			}
		}

		for (script in notetypeScripts)
			script.call("update", [elapsed]);
		for (script in eventScripts)
			script.call("update", [elapsed]);


		callOnHScripts('update', [elapsed]);

		if (camZooming)
		{
			var lerpVal = Math.exp(-elapsed * 3.125 * camZoomingDecay);

			camGame.zoom = FlxMath.lerp(
				defaultCamZoom #if NMV_MOD_COMPATIBILITY + defaultCamZoomAdd #end,
				camGame.zoom,
				lerpVal
			);
			camHUD.zoom = FlxMath.lerp(
				defaultHudZoom,
				camHUD.zoom,
				lerpVal
			);

		}
		camOverlay.zoom = camHUD.zoom;
		camOverlay.angle = camHUD.angle;

		////
		if (noteHits.length > 0){
			while (noteHits.length > 0 && (noteHits[0] + 2000) < Conductor.songPosition)
				noteHits.shift();
		}

		stats.nps = nps = Math.floor(noteHits.length / 2);
		FlxG.watch.addQuick("notes per second", nps);
		if (stats.npsPeak < nps)
			stats.npsPeak = nps;

		////
		if (!endingSong){
			//// time travel
			if (!startingSong #if !debug && chartingMode #end){
				if (FlxG.keys.justPressed.ONE) {
					KillNotes();
					inst.onComplete();
				}else if(FlxG.keys.justPressed.TWO) { //Go 10 seconds into the future :O
					setSongTime(Conductor.songPosition + 10000);
					clearNotesBefore(Conductor.songPosition);
				}
			}

			if (FlxG.keys.anyJustPressed(debugKeysBotplay))
				cpuControlled = !cpuControlled;

			//// editors
			if (FlxG.keys.anyJustPressed(debugKeysChart)) {
				openChartEditor();

			}else if (FlxG.keys.anyJustPressed(debugKeysCharacter)) {
				FlxTransitionableState.skipNextTransOut = true;
				persistentUpdate = false;
				pause();
				MusicBeatState.switchState(new CharacterEditorState(SONG.player2));

			}else if (canReset && !inCutscene && startedCountdown && controls.RESET) {
				// RESET = Quick Game Over Screen
				doGameOver();

			}else if (doDeathCheck()) {
				// die lol

			}else if (controls.PAUSE && startedCountdown && canPause) {
				openPauseMenu();
			}
		}

		if (startedCountdown && !paused) {

			if (startingSong) {
				Conductor.songPosition += elapsed * 1000;
				if (Conductor.songPosition >= 0)
					startSong(0);
			}
			else if (Conductor.songPosition >= 0) 
			{
				updateSongPosition(elapsed);
			}
		}

		////
		super.update(elapsed);
		updateVisualPosition();
		danceCharacters(); // Update characters dancing
		checkEventNote();
		modManager.update(elapsed, curDecBeat, curDecStep);

		if (generatedMusic && !isDead) {
			if (ClientPrefs.controllerMode) {
				keyShit();
			}

			for (field in playfields) {
				var holdingField = field.keysPressed.contains(true);
				for (char in field.characters) {
					if (char != gf && char.canResetDance(holdingField)) {
						char.resetDance();
					}
				}
			}

			// TODO: maybe give gf her own playfield
			if (gf != null && gf.canResetDance()) {
				gf.resetDance();
			}
		}
		
		setOnScripts('cameraX', camFollowPos.x);
		setOnScripts('cameraY', camFollowPos.y);
		
		callOnScripts('onUpdatePost', [elapsed]);
		if (hudSkinScript != null)
			hudSkinScript.call("onUpdatePost", [elapsed]);
	}

	function openChartEditor()
	{
		FlxTransitionableState.skipNextTransOut = true;
		persistentUpdate = false;
		pause();

		if (FlxG.keys.pressed.SHIFT) ChartingState.curSec = curSection;
		MusicBeatState.switchState(new ChartingState());
	}

	public var isDead:Bool = false;
	function doDeathCheck(?skipHealthCheck:Bool = false) {
		if (isDead || practiceMode)
			return false;

		if (skipHealthCheck || health <= 0)
			return doGameOver();
		
		return false;
	}

	function doGameOver()
	{
		switch(callOnScripts('onGameOver')) {
			case Globals.Function_Stop: return false;
			case Globals.Function_Halt: return true;
		} 

		isDead = true;
		deathCounter++;
		boyfriend.stunned = true;

		pause();

		////
		persistentUpdate = false;
		persistentDraw = false;

		if (instaRespawn){
			FlxG.camera.bgColor = 0xFF000000;
			MusicBeatState.resetState(true);
		}else{			
			openSubState(new GameOverSubstate(playOpponent ? dad : boyfriend));
			updateSongDiscordPresence(); // pause() already calls this so uhhhmnmg 
		}

		return true;
	}

	public function checkEventNote() {
		while(eventNotes.length > 0) {
			var daEvent = eventNotes[0];

			if(Conductor.songPosition < daEvent.strumTime)
				break;

			triggerEventNote(daEvent.event, daEvent.value1, daEvent.value2, daEvent.strumTime);
			eventNotes.shift();
		}
	}

	public function getControl(key:String) { // psych lua uses this
		var pressed:Bool = Reflect.getProperty(controls, key);
		//trace('Control result: ' + pressed);
		return pressed;
	}

	public function changeCharacter(name:String, charType:CharacterType)
	{
		var oldChar:Character;
		var charMap:Map<String, Character>;
		var varName:String;

		switch(charType) {
			case BF:
				oldChar = boyfriend;
				charMap = boyfriendMap;
				varName = 'boyfriendName';

			case DAD:
				oldChar = dad;
				charMap = dadMap;
				varName = 'dadName';

			case GF:
				oldChar = gf;
				charMap = gfMap;
				varName = "gfName";

			default: return;
		}

		if (oldChar != null && oldChar.characterId == name)
			return;

		if (showDebugTraces)
			trace('turning $charType into ' + name);
		
		if (!charMap.exists(name))
			addCharacterToList(name, charType);
		
		var newChar:Character = charMap.get(name);
		
		switch(charType) {
			case BF: boyfriend = newChar;
			case DAD: dad = newChar;
			case GF: gf = newChar;
		}

		setOnScripts(varName, name);

		if (oldChar != null) {
			newChar.alpha = oldChar.alpha;
			oldChar.alpha = 0.00001;
			oldChar.changedOut(newChar);
		}
		else 
			newChar.alpha = 1.0;

		newChar.changedIn(oldChar);

		if (focusedChar == oldChar) focusedChar = newChar;

		hud.changedCharacter(charType, newChar);
		reloadHealthBarColors();
	}

	public function getCharacterFromString(str:String):Null<Character> {
		return switch (str.toLowerCase().trim()) {
			case 'bf'	| 'boyfriend'	| '0': boyfriend;
			case 'dad'	| 'opponent'	| '1': dad;	
			case 'gf'	| 'girlfriend'	| '2': gf;
			default: null;
		}
	}

	public static function getCharacterTypeFromString(str:String):CharacterType
		return CharacterType.fromString(str);

	public function triggerEventNote(eventName:String = "", value1:String = "", value2:String = "", ?time:Float) {
		if (time==null)
			time = Conductor.songPosition;

		if(showDebugTraces)
			trace('Event: ' + eventName + ', Value 1: ' + value1 + ', Value 2: ' + value2 + ', at Time: ' + time);

		switch(eventName) {
			case 'Change Focus':
				switch(value1.toLowerCase().trim()){
					case 'dad' | 'opponent':
						if (callOnScripts('onMoveCamera', ["dad"]) != Globals.Function_Stop){
							#if NMV_MOD_COMPATIBILITY
							whosTurn = 'dad';
							#end
							moveCamera(dad);
						}
					case 'gf' | 'girlfriend':
						if (callOnScripts('onMoveCamera', ["gf"]) != Globals.Function_Stop){
							#if NMV_MOD_COMPATIBILITY
							whosTurn = 'gf';
							#end
							moveCamera(gf);
						}
					default:
						if (callOnScripts('onMoveCamera', ["bf"]) != Globals.Function_Stop){
							#if NMV_MOD_COMPATIBILITY
							whosTurn = 'bf';
							#end
							moveCamera(boyfriend);
						}
				}

			case 'Game Flash':
				var dur:Float = Std.parseFloat(value2);
				if(Math.isNaN(dur)) dur = 0.5;

				var col:Null<FlxColor> = FlxColor.fromString(value1);
				if (col == null) col = 0xFFFFFFFF;

				camGame.flash(col, dur, null, true);

			case 'Hey!':
				var value:Int = switch (value1.toLowerCase().trim()) {
					case 'bf' | 'boyfriend' | '0': 0;
					case 'gf' | 'girlfriend' | '1': 1;
					default: 2;
				}

				var time:Float = Std.parseFloat(value2);
				if(Math.isNaN(time) || time <= 0) time = 0.6;

				if (value != 0 && gf != null) {
					gf.playAnim('cheer', true);
					gf.specialAnim = true;
					gf.heyTimer = time;
				}
				if (value != 1 && boyfriend != null) {
					boyfriend.playAnim('hey', true);
					boyfriend.specialAnim = true;
					boyfriend.heyTimer = time;
				}

			case 'Set GF Speed':
				var value:Null<Int> = Std.parseInt(value1);
				if (value == null || value < 1) value = 1;
				gfSpeed = value;

			case 'Add Camera Zoom':
				if (ClientPrefs.camZoomP > 0) {
					var camZoom:Float = Std.parseFloat(value1);
					var hudZoom:Float = Std.parseFloat(value2);
					if(Math.isNaN(camZoom)) camZoom = 0.015;
					if(Math.isNaN(hudZoom)) hudZoom = 0.03;

					cameraBump(camZoom, hudZoom);
				}
				
			case 'Play Animation':
				var char:Character = getCharacterFromString(value2);
				if (char != null) {
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
				var char:Character = getCharacterFromString(value1);
				if (char != null) {
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
				var charType:CharacterType = getCharacterTypeFromString(value1);
				if (charType != -1) changeCharacter(value2, charType);

			case 'Change Scroll Speed':
				if (songSpeedType == "constant")
					return;

				var val1:Float = Std.parseFloat(value1);
				var val2:Float = Std.parseFloat(value2);
				if(Math.isNaN(val1)) val1 = 1.0;
				if(Math.isNaN(val2)) val2 = 0.0;

				var newValue:Float = SONG.speed * ClientPrefs.getGameplaySetting('scrollspeed', 1.0) * val1;
				if (songSpeedTween != null)
					songSpeedTween.cancel();

				// value should never be negative as that should be handled and changed prior to this
				if (val2 == 0.0)
					songSpeed = newValue;
				else{
					songSpeedTween = FlxTween.num(
						this.songSpeed, newValue, val2, 
						{
							ease: FlxEase.linear, 
							onComplete: (twn:FlxTween) -> songSpeedTween = null	
						},
						this.set_songSpeed
					);
				}

			case 'Set Property':
				var value2:Dynamic = switch(value2){
					case "true": true;
					case "false": false;
					default: value2;
				}

				try{
					ScriptingUtil.setProperty(value1, value2);					
				}catch (e:haxe.Exception){
					trace('Set Property event error: $value1 | $value2');
				}
		}
		callOnScripts('onEvent', [eventName, value1, value2, time]);
		if(eventScripts.exists(eventName))
			callScript(eventScripts.get(eventName), "onTrigger", [value1, value2, time]);
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
			var cam = char.getCamera();
			sectionCamera.set(cam[0], cam[1]);
		}
	}

	static public function getCharacterCamera(char:Character) 
		return char.getCamera();

	public function skipToTime(newTime:Float) {
		if (newTime < Conductor.songPosition) {
			PlayState.startOnTime = newTime;
			PlayState.instance.restartSong(true);
		}
		else {
			if (newTime != Conductor.songPosition) {
				PlayState.instance.clearNotesBefore(newTime);
				PlayState.instance.setSongTime(newTime - 500);
			}
		}
	}

	public function finishSong(?ignoreNoteOffset:Bool = false):Void
	{
		var finishCallback:Void->Void = endSong; // In case you want to change it in a specific song.

		hud.updateTime = false;

		for (track in tracks) {
			track.volume = 0;
			track.stop();
		}

		////
		if(ClientPrefs.noteOffset <= 0 || ignoreNoteOffset) {
			finishCallback();
		}else {
			finishTimer = new FlxTimer().start(ClientPrefs.noteOffset / 1000, (_) -> finishCallback());
		}
	}

	public function restartSong(noTrans:Bool = false)
	{
		persistentUpdate = false;
		pause();

		if(noTrans)
			FlxTransitionableState.skipNextTransOut = true;

		MusicBeatState.resetState();
	}

	public static function gotoMenus()
	{
		FlxTransitionableState.skipNextTransIn = false;

		// MusicBeatState.switchState(new MainMenuState());
		if (isStoryMode){
			MusicBeatState.playMenuMusic(1, true);
			MusicBeatState.switchState(new StoryMenuState());
		}else{
			FreeplayState.comingFromPlayState = true;
			MusicBeatState.switchState(new FreeplayState());
		}
		
		deathCounter = 0;
		seenCutscene = false;
		chartingMode = false;

		if (prevCamFollow != null) prevCamFollow.put();
		if (prevCamFollowPos != null) prevCamFollowPos.destroy();

		if (instance != null) {
			instance.camFollow.put();
			instance.camFollowPos.destroy();
		}
	}


	public var transitioning = false;
	public function endSong():Void
	{
	// Should kill you if you tried to cheat
		if (!startingSong) {
			for (field in playfields.members) {
				if(field.isPlayer) {
					for(daNote in field.spawnedNotes) {
						if (daNote.strumTime < songLength - Conductor.safeZoneOffset) {
							health -= 0.05 * healthLoss;
						}
					}
				}
			}

			if (doDeathCheck())
				return;
		}

		hud.songEnding();
		hud.updateTime = false;
		canPause = false;
		endingSong = true;
		camZooming = false;
		inCutscene = false;

		deathCounter = 0;
		seenCutscene = false;
		
		var ret:Dynamic = callOnScripts('onEndSong');

		if (transitioning || ret == Globals.Function_Stop)
			return;

		transitioning = true;

		if (chartingMode) {
			openChartEditor();
			return;
		}

		// Save song score and rating.

		if (saveScore && SONG.validScore && ratingFC != stats.fail)
			Highscore.saveScoreRecord(songId, difficultyName, stats.getScoreRecord());

		var gotoNextThing:Void -> Void = gotoMenus;
		var nextSong:BaseSong = songPlaylist[songPlaylistIdx + 1];

		if (isStoryMode) {
			// TODO: add a modcharted variable which songs w/ modcharts should set to true, then make it so if modcharts are disabled the score wont get added
			// same check should be in the saveScore check above too
			if (ratingFC != 'Fail')
				campaignScore += stats.score;
			campaignMisses += songMisses;
		}

		if (nextSong != null) {
			prevCamFollow = camFollow;
			prevCamFollowPos = camFollowPos;

			gotoNextThing = function gotoNextSong() {
				FlxTransitionableState.skipNextTransIn = true;
				FlxTransitionableState.skipNextTransOut = true;

				PlayState.songPlaylistIdx++;
				trace('LOADING NEXT SONG: $nextSong, (${PlayState.songPlaylistIdx + 1} / ${PlayState.songPlaylist.length})');
				PlayState.loadSong(nextSong, PlayState.difficultyName);
				MusicBeatState.switchState(new PlayState());
			}
		}else {
			trace('PLAYLIST END (${PlayState.songPlaylistIdx + 1} / ${PlayState.songPlaylist.length})');
			onPlaylistEnd();
		}

		if (gotoNextThing != null) {
			#if VIDEOS_ALLOWED
			var videoPath:String = postSongVideo;
			if (videoPath.length > 0 && Paths.exists(videoPath = Paths.video(postSongVideo))) 
				MusicBeatState.switchState(new VideoPlayerState(videoPath, gotoNextThing));	
			else
			#end
				gotoNextThing();
		}
		
		callOnScripts('onSongEnd');
	}

	function onPlaylistEnd() {
		if (isStoryMode && saveScore && WeekData.curWeek != null) {
			// Week ended, save week score
			if (!practiceMode && !cpuControlled && !playOpponent) {
				Highscore.saveWeekScore(WeekData.curWeek.name, campaignScore);						
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

	private function displayJudgment(image:String){
		var r:Bool = false;
		if(hudSkinScript!=null && callScript(hudSkinScript, "onDisplayJudgment", [image]) == Globals.Function_Stop)
			r = true;
		if(callOnScripts("onDisplayJudgment", [image]) == Globals.Function_Stop)
			return;

		if(r)return;

		var spr:RatingSprite;
		
		lastJudge = ratingGroup.lastJudge;
		if (ClientPrefs.simpleJudge && lastJudge != null)
			lastJudge.kill();

		if (worldCombos)
			spr = ratingGroup.displayJudgment(image, -40, -60);
		else
			spr = ratingGroup.displayJudgment(image, ClientPrefs.comboOffset[0], -ClientPrefs.comboOffset[1]);

		if (ClientPrefs.simpleJudge) {
			spr.moves = false;

			spr.scale.copyFrom(ratingGroup.judgeTemplate.scale);
			spr.tween = FlxTween.tween(spr.scale, {x: spr.scale.x, y: spr.scale.y}, 0.1, {
				ease: FlxEase.quadOut,
				onComplete: function(tween:FlxTween) {
					if (!spr.alive)
						return;

					var stepDur = (Conductor.stepCrochet * 0.001);
					spr.tween = FlxTween.tween(spr.scale, {x: 0, y: 0}, stepDur, {
						startDelay: stepDur * 8,
						ease: FlxEase.quadIn,
						onComplete: (tween:FlxTween) -> spr.kill()
					});
				}
			});

			spr.alpha = 1.0;
			spr.scale.scale(1.1, 1.1);

		} 
		else {
			spr.moves = true;
			spr.acceleration.y = 550;
			spr.velocity.set(FlxG.random.int(-10, 10), -FlxG.random.int(140, 175));

			spr.scale.copyFrom(ratingGroup.judgeTemplate.scale);
			spr.tween = FlxTween.tween(spr.scale, {x: spr.scale.x, y: spr.scale.y}, 0.1, {
				ease: FlxEase.backOut, 
				onComplete: function(twn) {
					spr.tween = FlxTween.tween(spr, {alpha: 0.0}, 0.2, {
						startDelay: Conductor.crochet * 0.001,
						onComplete: (_) -> spr.kill()
					});
				}
			});

			spr.alpha = 1.0;
			spr.scale.scale(0.96, 0.96);
		}

		spr.color = 0xFFFFFFFF;
		spr.visible = showRating;
		spr.alpha = ClientPrefs.judgeOpacity;	

		if(hudSkinScript!=null)
			callScript(hudSkinScript, "onDisplayJudgmentPost", [spr, image]);
		callOnScripts("onDisplayJudgmentPost", [spr, image]);
	}
	
	var comboColor = 0xFFFFFFFF;
	private function displayCombo(?combo:Int){
		var r:Bool = false;
		if (hudSkinScript!=null && callScript(hudSkinScript, "onDisplayCombo", [combo]) == Globals.Function_Stop)
			r = true;

		if (callOnScripts("onDisplayCombo", [combo]) == Globals.Function_Stop || r)
			return;

		if (combo == null) 
			combo = stats.combo;

		if (ClientPrefs.simpleJudge) {
			for (numSpr in lastCombos)
				numSpr.kill();
			
			if (combo == 0)
				return;
		}else{
			if (combo > 0 && combo < 10)
				return;
		}
		
		if (worldCombos)
			lastCombos = ratingGroup.displayCombo(combo, -150, 80)
		else
			lastCombos = ratingGroup.displayCombo(combo, ClientPrefs.comboOffset[2], -ClientPrefs.comboOffset[3]);
		
		var comboColor = (combo < 0) ? hud.judgeColours.get("miss") : comboColor;
		
		for (numSpr in lastCombos)
		{
			numSpr.color = comboColor;
			numSpr.visible = showComboNum;

			numSpr.alpha = ClientPrefs.judgeOpacity;

			if (ClientPrefs.simpleJudge)
			{
				numSpr.moves = false;

				numSpr.scale.copyFrom(ratingGroup.comboTemplate.scale);
				numSpr.tween = FlxTween.tween(numSpr.scale, {x: numSpr.scale.x, y: numSpr.scale.y}, 0.2, {ease: FlxEase.circOut});

				numSpr.scale.x *= 1.25;
				numSpr.updateHitbox();
				numSpr.scale.y *= 0.75;
			}
			else
			{
				numSpr.moves = true;
				numSpr.acceleration.y = FlxG.random.int(200, 300);
				numSpr.velocity.set(FlxG.random.float(-5, 5), -FlxG.random.int(140, 160));

				numSpr.scale.copyFrom(ratingGroup.comboTemplate.scale);
				numSpr.updateHitbox();

				numSpr.tween = FlxTween.tween(numSpr, {alpha: 0.0}, 0.2, {
					startDelay: Conductor.crochet * 0.002,
					onComplete: (_) -> numSpr.kill()
				});
			}
		}

		if(hudSkinScript!=null)callScript(hudSkinScript, "onDisplayComboPost", [combo]);
		callOnScripts("onDisplayComboPost", [combo]);
	}

	private function applyJudgmentData(judgeData:JudgmentData, diff:Float, ?bot:Bool = false, ?show:Bool = true){
		if(judgeData==null){
			trace("You didnt give a valid JudgmentData to applyJudgmentData!");
			return;
		}
		if(callOnScripts("onApplyJudgmentData", [judgeData, diff, bot, show]) == Globals.Function_Stop)
			return;

		stats.score += Math.floor(judgeData.score * playbackRate);
		health += (judgeData.health * 0.02) * (judgeData.health < 0 ? healthLoss : healthGain);
		songHits++;

		stats.calculateAccuracy(judgeData, diff); // deals with accuracy calculations

		switch(judgeData.comboBehaviour){
			default:
				stats.cbCombo = 0;
				stats.combo++;
			case BREAK:
				breakCombo();
			case IGNORE:
		}

		if (!stats.judgements.exists(judgeData.internalName))
			stats.judgements.set(judgeData.internalName, 0);

		stats.judgements.set(judgeData.internalName, stats.judgements.get(judgeData.internalName) + 1);
		
		RecalculateRating();

		if (ClientPrefs.coloredCombos)
		{
			if (stats.judgements.get("bad") > 0 || stats.judgements.get("shit") > 0 || stats.comboBreaks > 0)
				comboColor = 0xFFFFFFFF;
			else if (stats.judgements.get("good") > 0)
				comboColor = hud.judgeColours.get("good");
			else if (stats.judgements.get("sick") > 0)
				comboColor = hud.judgeColours.get("sick");
			else if (stats.judgements.get("epic") > 0)
				comboColor = hud.judgeColours.get("epic");
		}

		if(hudSkinScript!=null)callScript(hudSkinScript, "onApplyJudgmentDataPost", [judgeData, diff, bot, show]);
		callOnScripts("onApplyJudgmentDataPost", [judgeData, diff, bot, show]);

		if(show){
			if(judgeData.hideJudge!=true)
				displayJudgment(judgeData.internalName);
			if(judgeData.comboBehaviour != IGNORE)
				displayCombo(judgeData.comboBehaviour == BREAK ? (stats.cbCombo > 1 ? -stats.cbCombo : 0) : stats.combo);
		}
	}

	private function applyNoteJudgment(note:Note, bot:Bool = false):Null<JudgmentData>
	{
		if(note.hitResult.judgment == UNJUDGED)return null;
		var judgeData:JudgmentData = judgeManager.judgmentData.get(note.hitResult.judgment);
		if(judgeData==null)return null;

		if (callOnHScripts("onApplyNoteJudgment", [note, judgeData, bot]) == Globals.Function_Stop)
			return null;

		var mutatedJudgeData:JudgmentData = Reflect.copy(judgeData);
		if (note.noteScript != null){
			var ret:Dynamic = callScript(note.noteScript, "mutateJudgeData", [note, mutatedJudgeData]);
			if (ret != null && ret != Globals.Function_Continue)
				mutatedJudgeData = cast ret;
		}
		var ret:Dynamic = callOnHScripts("mutateJudgeData", [note, mutatedJudgeData]);
		if (ret != null && ret != Globals.Function_Continue)
			mutatedJudgeData = cast ret; // so you can return your own custom judgements or w/e

		applyJudgmentData(mutatedJudgeData, note.hitResult.hitDiff, bot, true);

		callOnHScripts("onApplyNoteJudgmentPost", [note, mutatedJudgeData, bot]);
		
		return mutatedJudgeData;
	}

	private function applyJudgment(judge:Judgment, ?diff:Float = 0, ?show:Bool = true)
		applyJudgmentData(judgeManager.judgmentData.get(judge), diff);

	private function judge(note:Note, field:PlayField=null) {
		if (field == null)
			field = getFieldFromNote(note);

		var judgeData:JudgmentData = applyNoteJudgment(note, field.autoPlayed);
		if(judgeData==null)return;

		note.ratingMod = judgeData.accuracy * 0.01;
		note.rating = judgeData.internalName;
		if (note.noteSplashBehaviour == FORCED || judgeData.noteSplash && !note.noteSplashDisabled)
			spawnNoteSplashOnNote(note, field);

		var hitDiff = note.hitResult.hitDiff + ClientPrefs.ratingOffset;
		stats.judged.push({
			strumTime: note.strumTime, 
			judgment: note.hitResult.judgment, 
			hitDiff: hitDiff
		});

		if (ClientPrefs.showMS && (field==null || !field.autoPlayed))
		{
			FlxTween.cancelTweensOf(timingTxt);
			FlxTween.cancelTweensOf(timingTxt.scale);
			
			timingTxt.text = '${FlxMath.roundDecimal(hitDiff, 2)}ms';
			timingTxt.screenCenter();
			timingTxt.x += ClientPrefs.comboOffset[4];
			timingTxt.y -= ClientPrefs.comboOffset[5];

			timingTxt.color = hud.judgeColours.get(judgeData.internalName);

			timingTxt.visible = true;
			timingTxt.alpha = ClientPrefs.judgeOpacity;
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

	public var strumsBlocked:Array<Bool> = [];
	var pressed:Array<FlxKey> = [];

	private function onKeyDownEvent(event:KeyboardEvent)
		onKeyPress(event.keyCode);
	
	private function onKeyUpEvent(event:KeyboardEvent)
		onKeyRelease(event.keyCode);

	private function onKeyPress(key:FlxKey):Void
	{
		if (paused || !startedCountdown || inCutscene)
			return;
		
		if (pressed.contains(key)) return;
		pressed.push(key);
		
		if (callOnScripts("onKeyDown", [key]) == Globals.Function_Stop) // wish this wasnt changed it broke old code of mine lol
			return;
		
		var column:Int = getColumnFromKey(key);
		if (column != -1) strumKeyDown(column);
	}

	private function onKeyRelease(key:FlxKey):Void
	{
		pressed.remove(key);
		
		if (callOnScripts("onKeyUp", [key]) == Globals.Function_Stop)
			return;
		
		var column:Int = getColumnFromKey(key);
		if (column != -1) strumKeyUp(column);
	}

	private function strumKeyDown(column:Int, player:Int = -1) {
		if (strumsBlocked[column]) return;
		
		if (callOnScripts("onKeyPress", [column]) == Globals.Function_Stop)
			return;

		if(ClientPrefs.hitsoundBehav == 'Key Press' && !cpuControlled)
			playShithound();
		
		var hitNotes:Array<Note> = []; // what could scripts possibly do with this information
		var controlledFields:Array<PlayField> = [];
		
		for (field in playfields.members) {
			if ((player != -1 && field.playerId != player) || !field.isPlayer || !field.inControl || field.autoPlayed) 
				continue;

			controlledFields.push(field);
			field.keysPressed[column] = true;

			if (endingSong) 
				continue;

			var note:Note = {
				var ret:Dynamic = callOnHScripts("onFieldInput", [field, column, hitNotes]);
				if (ret == Globals.Function_Stop) null;
				else if (ret is Note) ret;
				else field.input(column);
			}

			if (note == null) {
				var spr:StrumNote = field.strumNotes[column];
				if (spr != null) {
					spr.playAnim('pressed');
					spr.resetAnim = 0;
				}
			}else {
				hitNotes.push(note);
			}
		}
		
		if (hitNotes.length == 0) {
			for (field in controlledFields) {				
				callOnScripts('onGhostTap', [column, field]);

				if (!ClientPrefs.ghostTapping)
					noteMissPress(column, field);
			}
		}

		//trace('strum down: $column');
	}

	private function strumKeyUp(column:Int, player:Int = -1) {
		// doesnt matter if THIS is done while paused
		// only worry would be if we implemented Lifts
		// but afaik we arent doing that
		// (though could be interesting to add)

		for (field in playfields.members) {
			if ((player != -1 && field.playerId != player) || !field.isPlayer || !field.inControl || field.autoPlayed) 
				continue;

			field.keysPressed[column] = false;
			
			if (!field.isHolding[column]) {
				var spr:StrumNote = field.strumNotes[column];
				if (spr != null){
					spr.playAnim('static');
					spr.resetAnim = 0;
				}
			}
		}

		callOnScripts('onKeyRelease', [column]);
	}

	private function getColumnFromKey(key:FlxKey):Int {
		if (key != -1) {
			for (i in 0...keysArray.length) {
				for (j in 0...keysArray[i].length) {
					if(key == keysArray[i][j])
						return i;
				}
			}
		}
		return -1;
	}

	private function keyShit():Void {
		// RICO WE ALREADY HAVE EVENT CONTROLS // THAT'S HOW IT WORKED BEFORE
/* 		for (column => actionBinds in keysArray) {
			if (FlxG.keys.anyJustPressed(actionBinds)) strumKeyDown(column);
			if (FlxG.keys.anyJustReleased(actionBinds)) strumKeyUp(column);
		} */

		////
		var gamepad = FlxG.gamepads.firstActive;
		if (gamepad == null) return;

		for (column => actionBinds in buttonsArray) {
			if (gamepad.anyJustPressed(actionBinds)) strumKeyDown(column);
			if (gamepad.anyJustReleased(actionBinds)) strumKeyUp(column);
		}
	}

	function breakCombo() {
		while (lastCombos.length > 0)
			lastCombos.shift().kill();

		if (stats.combo > 10 && gf != null && gf.animOffsets.exists('sad')){
			gf.playAnim('sad');
			gf.specialAnim = true;
		}

		stats.comboBreaks++;
		stats.cbCombo++;
		stats.combo = 0;

		RecalculateRating();
	}

	// You didn't hit the key and let it go offscreen, also used by Hurt Notes
	function noteMiss(daNote:Note, field:PlayField, ?mine:Bool=false):Void 
	{
		// Dupe note remove
		if (field.isPlayer) {		
			for (note in field.spawnedNotes) {
				if (note.alive
					&& !note.isSustainNote 
					&& daNote.column == note.column 
					&& daNote != note 
					&& Math.abs(daNote.strumTime - note.strumTime) < 1
					&& !daNote.tail.contains(note)
				) 
					field.removeNote(note);
			}
		}

		if (daNote.sustainLength > 0 && daNote.hitResult.judgment != UNJUDGED){
			daNote.hitResult.judgment = DROPPED_HOLD;
		}else
			daNote.hitResult.judgment = MISS;

		if(callOnHScripts("preNoteMiss", [daNote, field]) == Globals.Function_Stop)
			return;
		if (daNote.noteScript != null && callScript(daNote.noteScript, "preNoteMiss", [daNote, field]) == Globals.Function_Stop)
			return;

		////
		if(!daNote.isSustainNote && daNote.unhitTail.length > 0){
			for(tail in daNote.unhitTail){
				tail.tooLate = true;
				tail.blockHit = true;
				tail.ignoreNote = true;
				//health -= daNote.missHealth * healthLoss; // this is kinda dumb tbh no other VSRG does this just FNF
			}
		}

		if (noDropPenalty && daNote.hitResult.judgment == DROPPED_HOLD){ // PBot doesnt fucking penalize dropping holds for some reason
			// Unsure if we wanna keep that behaviour i dont but im keeping for parity LOL
			daNote.ratingDisabled = true;
			daNote.noMissAnimation = true;
		}
		
		if (!daNote.ratingDisabled) {
			stats.judged.push({
				strumTime: daNote.strumTime, 
				judgment: daNote.hitResult.judgment, 
				hitDiff: daNote.hitResult.hitDiff
			});
			
			if (!mine) {
				songMisses++;
				applyJudgment(daNote.hitResult.judgment, Conductor.safeZoneOffset);
			}else {
				applyJudgment(MISS_MINE, Conductor.safeZoneOffset);
				health -= daNote.missHealth * healthLoss;
			}
	
			if (instakillOnMiss)
				doDeathCheck(true);
		}

		for(track in field.tracks)
			track.volume = 0;

		if (!daNote.isSustainNote && ClientPrefs.missVolume > 0)
			FlxG.sound.play(Paths.soundRandom('missnote', 1, 3), ClientPrefs.missVolume * FlxG.random.float(0.9, 1));

		if (!daNote.noMissAnimation) {
			for (char in getNoteCharacters(daNote, field)) {
				char.missNote(daNote, field);
			}
		}
		
		////
		callOnHScripts("noteMiss", [daNote, field]);
		if (daNote.noteScript != null)
			callScript(daNote.noteScript, "noteMiss", [daNote, field]);
		if (daNote.genScript != null)
			callScript(daNote.genScript, "noteMiss", [daNote, field]); 
	}

	function noteMissPress(direction:Int = 1, field:PlayField):Void //You pressed a key when there was no notes to press for this key
	{
		if (!inst.playing) {
			if (field != null) {
				for (char in field.characters) 
					char.missPress(direction, field);
			}

			callOnScripts('noteMissPress', [direction]);
			return;
		}

		health -= 0.05 * healthLoss;
		
		if (instakillOnMiss)
			doDeathCheck(true);
		
		if(!practiceMode) stats.score -= 10;
		if(!endingSong) songMisses++;

		breakCombo();
		
		// i dont think this should reduce acc lol
		//totalPlayed++;
		//RecalculateRating();

		if (ClientPrefs.missVolume > 0)
			FlxG.sound.play(Paths.soundRandom('missnote', 1, 3), ClientPrefs.missVolume  * FlxG.random.float(0.9, 1));

		if (field != null) {
			for (track in field.tracks)
				track.volume = 0;

			for (char in field.characters) 
				char.missPress(direction, field);	
		}

		callOnScripts('noteMissPress', [direction]);
	}

	function opponentNoteHit(note:Note, field:PlayField):Void
	{
		if (note.noteScript != null && callScript(note.noteScript, "preOpponentNoteHit", [note, field]) == Globals.Function_Stop)
			return;
		if (callOnHScripts("preOpponentNoteHit", [note, field]) == Globals.Function_Stop)
			return;
		commonNoteHit(note, field);

		// Script shit
		callOnHScripts("opponentNoteHit", [note, field]);
		if (note.noteScript != null)
			callScript(note.noteScript, "opponentNoteHit", [note, field]);	

		if (note.genScript != null)
			callScript(note.genScript, "noteHit", [note, field]);

		if (!note.isSustainNote)
		{
			if (opponentHPDrain > 0 && health > opponentHPDrain)
				health -= opponentHPDrain;

			if(note.sustainLength == 0)
				field.removeNote(note);
		}
		else if (note.isSustainNote)
			if (note.parent.unhitTail.contains(note))
				note.parent.unhitTail.remove(note);
		
	}

	inline function getNoteCharacters(note:Note, field:PlayField):Array<Character> {
		var chars:Array<Character> = note.characters.copy();

		if (note.gfNote)
			if (gf != null) chars.push(gf);
		
		if (chars.length == 0) {
			for (c in field.characters)
				chars.push(c);
		}

		return chars;
	}

	function commonNoteHit(note:Note, field:PlayField){ // things done by all note hit functions
		camZooming = true;

		note.wasGoodHit = true;

		for (track in field.tracks)
			track.volume = 1;

		// Sing animations
		for (char in getNoteCharacters(note, field)) 
			char.playNote(note, field);
		
		// Strum animations
		if (field.autoPlayed) {
			var time:Float = 0.15;
			if (note.isSustainNote && !note.isSustainEnd)
				time += 0.15;

			StrumPlayAnim(field, note.column % field.keyCount, time, note);
		} else {
			var spr = field.strumNotes[note.column];
			if (spr != null && (field.keysPressed[note.column] || note.isRoll))
				spr.playAnim('confirm', true, note.isSustainNote ? note.parent : note);
		}
	}

	inline function playShithound(){
		hitsound.volume = ClientPrefs.hitsoundVolume;
		if(ClientPrefs.hitsoundVolume > 0){
			hitsound.time = 0;
			hitsound.play();
		}
	}
	function goodNoteHit(note:Note, field:PlayField):Void
	{	
		if (note.wasGoodHit || (field.autoPlayed && (note.ignoreNote || note.breaksCombo)))
			return;

		if (note.noteScript != null && callScript(note.noteScript, "preGoodNoteHit", [note, field]) == Globals.Function_Stop)
			return;
		if (callOnHScripts("preGoodNoteHit", [note, field]) == Globals.Function_Stop)
			return;

		if (!note.isSustainNote) {
			noteHits.push(Conductor.songPosition); // used for NPS
			stats.noteDiffs.push(note.hitResult.hitDiff + ClientPrefs.ratingOffset); // used for stat saving (i.e viewing song stats after you beaten it)
		}

		if (!note.hitsoundDisabled && (ClientPrefs.hitsoundBehav == 'Note Hit' || cpuControlled)){
			playShithound();
		}

		if (note.ratingDisabled) {
			// NOTHING!!!! Note will just dissappear

		}else if (note.hitResult.judgment != MISS_MINE) 
			judge(note, field);

		else {
			// tbh I hate hitCausesMiss lol its retarded
			// added a shitty judge to deal w/ it tho!! 
			noteMiss(note, field, true);

			if (!note.noMissAnimation)
			{
				switch (note.noteType)
				{
					case 'Hurt Note':
						for (char in getNoteCharacters(note, field)) {
							if (char.animation.exists('hurt')){
								char.playAnim('hurt', true);
								char.specialAnim = true;
							}
						}

				}
			}

			note.wasGoodHit = true;
			if (!note.isSustainNote && note.sustainLength==0)
				field.removeNote(note);
			else if(note.isSustainNote){
				if (note.parent != null)
					if (note.parent.unhitTail.contains(note))
						note.parent.unhitTail.remove(note);
			}

			return;
		} 

		
		//
		if (cpuControlled) saveScore = false; // if botplay hits a note, then you lose scoring

		commonNoteHit(note, field);
		// Script shit
		callOnHScripts("goodNoteHit", [note, field]);
		if (note.noteScript != null)
			callScript(note.noteScript, "goodNoteHit", [note, field]);

		if (note.genScript != null)
			callScript(note.genScript, "noteHit", [note, field]); // might be useful for some things i.e judge explosions
		
		if (note.isSustainNote) {
			if (note.parent != null)
				if (note.parent.unhitTail.contains(note))
					note.parent.unhitTail.remove(note);
		}
		else if (note.sustainLength == 0)
			field.removeNote(note);
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
		if (ClientPrefs.noteSplashes && note != null) {
			if(field==null)
				field = getFieldFromNote(note);

			var strum:StrumNote = field.strumNotes[note.column];
			if(strum != null) {
				field.spawnSplash(note, splashSkin);
			}
		}
	}

	#if HSCRIPT_ALLOWED
	public function createHScript(path:String, ?scriptName:String, ?ignoreCreateCall:Bool = false):FunkinHScript
	{
		var split = path.split("/");
		var modName:String = split[0] == "content" ? split[1] : 'assets';
		var script = FunkinHScript.fromFile(path, scriptName, [
			"modName" => modName
		], ignoreCreateCall != true);
		hscriptArray.push(script);
		funkyScripts.push(script);
		return script;
	}

	public function removeHScript(script:FunkinHScript):Void {
		funkyScripts.remove(script);
		hscriptArray.remove(script);
	}

	public function getHudSkinScript(name:String):Null<FunkinHScript> {
		if (hudSkinScripts.exists(name))
			return hudSkinScripts.get(name);

		var path = Paths.getHScriptPath('hudskins/$name');
		var script:FunkinHScript = (path==null) ? null : createHScript(path, name);
		
		hudSkinScripts.set(name, script);
		return script;
	}
	#end

	override function stepHit()
	{
		super.stepHit();
		
		hud.stepHit(curStep);
		setOnScripts('curStep', curStep);
		callOnScripts('onStepHit');
	}

	public function cameraBump(camZoom:Float = 0.015, hudZoom:Float = 0.03)
	{
		var zoomMult = camZoomingMult * ClientPrefs.camZoomP;
		if (camGame.zoom < (defaultCamZoom * 1.35))
			camGame.zoom += camZoom * zoomMult;
		camHUD.zoom += hudZoom * zoomMult;
	}

	// -1 = zoom every section
	// 0 = dont zoom
	public var zoomEveryBeat:Int = -1;
	public var beatToZoom:Int = 0;
		
	override function beatHit()
	{
		super.beatHit();
		
		hud.beatHit(curBeat);

		if (camZooming && zoomEveryBeat > 0 && curBeat % zoomEveryBeat == beatToZoom)
		{
			cameraBump();
		}


		setOnScripts('curBeat', curBeat);
		callOnScripts('onBeatHit');
	}

	var lastSection:Int = -1;
	override function sectionHit(){
		var sectionNumber = curSection;
		var curSection = SONG.notes[sectionNumber];

		if (curSection == null)
			return;

		if (camZooming && zoomEveryBeat < 0) 
		{
			cameraBump();
		}

		if (curSection.changeBPM)
		{
			Conductor.changeBPM(curSection.bpm);
			
			setOnScripts('curBpm', Conductor.bpm);
			setOnScripts('crochet', Conductor.crochet);
			setOnScripts('stepCrochet', Conductor.stepCrochet);
		}
		
		setOnHScripts("curSection", curSection);
		setOnScripts('sectionNumber', sectionNumber);

		setOnScripts('mustHitSection', curSection.mustHitSection == true);
		setOnScripts('altAnim', curSection.altAnim == true);
		setOnScripts('gfSection', curSection.gfSection  == true);

		if (lastSection != sectionNumber)
		{
			callOnScripts("onSectionHit");
			lastSection = sectionNumber;
		}

		if (generatedMusic && !endingSong)
		{
			moveCameraSection(curSection);
		}
	}

	inline public function callOnAllScripts(event:String, ?args:Array<Dynamic>, ignoreStops:Bool = false, ?exclusions:Array<String>, ?scriptArray:Array<Dynamic>,
			?vars:Map<String, Dynamic>):Dynamic
			return callOnScripts(event, args, ignoreStops, exclusions, scriptArray, vars, false);

	inline public function isSpecialScript(script:FunkinScript)
		return notetypeScripts.exists(script.scriptName) || eventScripts.exists(script.scriptName) || hudSkinScripts.exists(script.scriptName);

	public function callOnScripts(event:String, ?args:Array<Dynamic>, ignoreStops:Bool = false, ?exclusions:Array<String>, ?scriptArray:Array<Dynamic>,
			?vars:Map<String, Dynamic>, ?ignoreSpecialShit:Bool = true):Dynamic
	{
		#if (HSCRIPT_ALLOWED)
		while (scriptsToClose.length > 0){
			var script = scriptsToClose.pop();

			if (script.scriptType == HSCRIPT)
				hscriptArray.remove(cast script);

			trace('Closed ${script.scriptName}');
			funkyScripts.remove(script);
			script.stop();
		}

		if (args == null) args = [];
		if (scriptArray == null) scriptArray = funkyScripts;
		if (exclusions == null) exclusions = [];
		
		var returnVal:Dynamic = Globals.Function_Continue;
		for (idx in 0...scriptArray.length)
		{
			var script:FunkinScript = scriptArray[idx];
			if (script==null || exclusions.contains(script.scriptName) || (ignoreSpecialShit && isSpecialScript(script)))			
				continue;
			var ret:Dynamic = script.call(event, args, vars);
			if (ret == Globals.Function_Halt){
				ret = returnVal;
				if (!ignoreStops)
					return returnVal;
			};
			if (ret != Globals.Function_Continue && ret!=null)
				returnVal = ret;
		}
		
		return (returnVal == null) ? Globals.Function_Continue : returnVal;
		#else
		return Globals.Function_Continue;
		#end
	}

	public function setOnScripts(variable:String, value:Dynamic, ?scriptArray:Array<Dynamic>)
	{
		if (scriptArray == null)
			scriptArray = funkyScripts;

		for (idx in 0...scriptArray.length){
			var script = scriptArray[idx];
			script.set(variable, value);
		}
	}

	public function callScript(script:Dynamic, event:String, ?args:Array<Dynamic>):Dynamic
	{
		#if (HSCRIPT_ALLOWED) // no point in calling this code if you.. for whatever reason, disabled scripting.
		if((script is FunkinScript)){
			return callOnScripts(event, args, true, [], [script], [], false);
		}
		else if((script is Array)){
			return callOnScripts(event, args, true, [], script, [], false);
		}
		else if((script is String)){
			var scripts:Array<FunkinScript> = [];

			for (idx in 0...funkyScripts.length)
			{
				var scr = funkyScripts[idx];
				if(scr.scriptName == script)
					scripts.push(scr);
			}

			return callOnScripts(event, args, true, [], scripts, [], false);
		}
		#end
		return Globals.Function_Continue;
	}

	#if HSCRIPT_ALLOWED
	public function callOnHScripts(event:String, ?args:Array<Dynamic>, ?vars:Map<String, Dynamic>, ignoreStops = false, ?exclusions:Array<String>):Dynamic
		return callOnScripts(event, args, ignoreStops, exclusions, hscriptArray, vars);
	
	public function setOnHScripts(variable:String, arg:Dynamic)
		return setOnScripts(variable, arg, hscriptArray);

	public function setDefaultHScripts(variable:String, arg:Dynamic){
		FunkinHScript.defaultVars.set(variable, arg);
		return setOnScripts(variable, arg, hscriptArray);
	}
	#else
	inline public function callOnHScripts(event:String, ?args:Array<Dynamic>, ?vars:Map<String, Dynamic>, ignoreStops = false, ?exclusions:Array<String>):Dynamic
		return Globals.Function_Continue;
	#end

	function StrumPlayAnim(field:PlayField, id:Int, time:Float, ?note:Note) {
		var spr:StrumNote = field.strumNotes[id];

		if (spr != null) {
			spr.playAnim('confirm', true, note);
			spr.resetAnim = time;
		}
	}

	public function RecalculateRating() {
		setOnScripts('score', stats.score);
		setOnScripts('misses', songMisses);
		setOnScripts('comboBreaks', stats.comboBreaks);
		setOnScripts('hits', songHits);

		callOnScripts('onRecalculateRating');

		stats.updateVariables();
		
		hud.recalculateRating();
		#if ALLOW_DEPRECATION
		callOnScripts('postRecalculateRating'); // deprecated
		#end

		callOnScripts('onRecalculateRatingPost');

		setOnScripts('rating', ratingPercent);
		setOnScripts('ratingName', ratingName);
		setOnScripts('ratingFC', ratingFC);
	}

	////
	public function openPauseMenu()
	{
		if (callOnScripts('onPause') == Globals.Function_Stop) 
			return;
		
		// 0 chance for Gitaroo Man easter egg
		pause();
		persistentUpdate = false;
		persistentDraw = true;
		openSubState(new PauseSubState());
	}

	public function pause(){
		paused = true;

		Conductor.pauseSong();

		if (curCountdown != null && !curCountdown.finished)
			curCountdown.timer.active = false;
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

		updateSongDiscordPresence();

		signals.onPause.dispatch();
	}

	public function resume(){
		if (!paused)
			return;

		paused = false;
		active = true;

		if (!startingSong)
		{
			Conductor.resumeSong();
		}

		if (curCountdown != null && !curCountdown.finished)
			curCountdown.timer.active = true;
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

		updateSongDiscordPresence();
		
		signals.onResume.dispatch();
		callOnScripts('onResume');
	} 

	override public function startOutro(onOutroComplete)
	{
		callOnScripts("switchingState");

		return super.startOutro(onOutroComplete);
	}

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
		});
		*/

		signals.onDestroy.dispatch();

		////
		removeKeyboardEvents();
		
		FlxG.timeScale = 1.0;
		ClientPrefs.gameplaySettings.set('botplay', cpuControlled);

		if (funkyScripts != null) while (funkyScripts.length > 0){
			var script = funkyScripts.pop();
			script.call("onDestroy");
			script.stop();
		}
		
		if (hscriptArray != null)
			hscriptArray.resize(0);

		sectionCamera.put();
		customCamera.put();
		
		if (cameraPoints != null) while (cameraPoints.length > 0)
			cameraPoints.pop().put();

		stats.changedEvent.removeAll();

		Note.quantShitCache.clear();
		FunkinHScript.defaultVars.clear();

		notetypeScripts.clear();
		hudSkinScripts.clear();		
		eventScripts.clear();

		Conductor.cleanup();
		instance = null;

		super.destroy();
	}	
}

class PlayStateSignals /*extends MusicBeatSignals*/
{
	public var onCreatePost = new FlxTypedSignal<Void -> Void>();
	
	public var onUpdate = new FlxTypedSignal<Float -> Void>();
	public var onUpdatePost = new FlxTypedSignal<Float -> Void>();

	public var onCountdownStarted = new FlxTypedSignal<Void -> Void>();

	public var onModifierRegister = new FlxTypedSignal<Void -> Void>();	
	public var onModifierRegisterPost = new FlxTypedSignal<Void -> Void>();

	public var onSongStart = new FlxTypedSignal<Void -> Void>();
	public var onSongEnd = new FlxTypedSignal<Void -> Void>();

	public var onBeatHit = new FlxTypedSignal<Int -> Void>();
	public var onStepHit = new FlxTypedSignal<Int -> Void>();

	public var goodNoteHit = new FlxTypedSignal<(Note, NoteField) -> Void>();
	public var opponentNoteHit = new FlxTypedSignal<(Note, NoteField) -> Void>();
	
	public var noteMiss = new FlxTypedSignal<(Note, NoteField) -> Void>();
	public var noteMissPress = new FlxTypedSignal<(Note, NoteField) -> Void>();

	public var onPause = new FlxTypedSignal<Void -> Void>();
	public var onResume = new FlxTypedSignal<Void -> Void>();

	public var onDestroy = new FlxTypedSignal<Void -> Void>();

	@:allow(funkin.states.PlayState)
	function new() {}
}
