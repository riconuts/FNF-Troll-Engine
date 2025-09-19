package funkin.states.editors;

import funkin.data.CharacterData;
import funkin.objects.AttachedFlxText;
import funkin.objects.hud.HealthIcon;
import funkin.scripts.FunkinHScript;
import funkin.scripts.FunkinScript;

import funkin.Conductor.BPMChangeEvent;
import funkin.data.ChartData.defaultNoteTypeList as noteTypeList;
import funkin.data.ChartData;
import funkin.data.BaseSong;
import funkin.data.Song;

import funkin.objects.notes.*;

import flixel.*;
import flixel.group.FlxGroup;
import flixel.group.FlxSpriteGroup;
import flixel.input.keyboard.FlxKey;
import flixel.util.FlxGradient;
import flixel.addons.display.FlxGridOverlay;
import flixel.addons.ui.*;
import flixel.addons.transition.FlxTransitionableState;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.tweens.*;
import flixel.ui.FlxButton;
import flixel.ui.FlxSpriteButton;

import haxe.Json;
import haxe.io.Path;
import haxe.io.Bytes;
import haxe.format.JsonParser;
import openfl.utils.ByteArray;
import openfl.utils.Assets as OpenFlAssets;
import openfl.media.Sound;
import lime.media.AudioBuffer;
import lime.ui.FileDialog;
import openfl.geom.Rectangle;
import flixel.util.FlxSort;

#if DISCORD_ALLOWED
import funkin.api.Discord.DiscordClient;
#end

#if sys
import sys.io.File;
import sys.FileSystem;
import openfl.media.Sound;
#end

using StringTools;
using Lambda;

typedef ChartingStateOptions = {
	var ?autosave:String;
	var ignoreWarnings:Bool;
	var hideHelp:Bool;
	var vortex:Bool;
	var mouseScrollingQuant:Bool;
	var noAutoScroll:Bool;
	var playSoundBf:Bool;
	var playSoundDad:Bool;
	var playSoundEvents:Bool;
	var panHitSounds:Bool;
	var metronome:Bool;
}

typedef ChartingStateSession = {
	var curSec:Int;
	var songPosition:Float;
	var selectedTrack:String;
	var trackVolumes:Map<String, Float>;
}

@:access(flixel.sound.FlxSound._sound)
@:access(openfl.media.Sound.__buffer)
@:allow(funkin.states.editors.ChartingState)
class ChartingState extends MusicBeatState
{
	public static function makeSession():ChartingStateSession return {
		selectedTrack: "None",
		trackVolumes: ["Inst" => 0.6],
		songPosition: 0.0,
		curSec: 0,
	}

	var _session(get, set):ChartingStateSession;
	function set__session(s:ChartingStateSession) {Reflect.setField(_song, "_chartEditor", s); return s;}
	function get__session() return Reflect.field(_song, "_chartEditor");

	public static function getDefaultOptions():ChartingStateOptions return {
		autosave: null,
		ignoreWarnings: false,
		hideHelp: false,
		vortex: false,
		mouseScrollingQuant: false,
		noAutoScroll: false,
		playSoundBf: false,
		playSoundDad: false,
		playSoundEvents: false,
		panHitSounds: false,
		metronome: false,
	}

	public static function getSavedOptions():ChartingStateOptions {
		var defaultOptions:ChartingStateOptions = getDefaultOptions();
		var currentOptions:Dynamic = FlxG.save.data.chartingStateOptions;

		if (currentOptions == null) {
			FlxG.save.data.chartingStateOptions = defaultOptions;
			return defaultOptions;
		}

		for (fn in Reflect.fields(defaultOptions)) {
			if (!Reflect.hasField(currentOptions, fn)) {
				Reflect.setField(currentOptions, fn, Reflect.field(defaultOptions, fn));
			}
		}
		return currentOptions;
	}

	public var options:ChartingStateOptions = getSavedOptions();

	var helpTextGrp:FlxTypedGroup<FlxText>;

	var oppHitsound:FlxSound;
	var plrHitsound:FlxSound;
	var hitsound:FlxSound;

	public static var instance:ChartingState;
	
	public var offset:Float = 0;
	public var notetypeScripts:Map<String, FunkinHScript> = [];

	var hudList:Array<String> = [
		'Default'
	];

	private var noteTypeIntMap:Map<Int, String> = new Map<Int, String>();
	private var noteTypeMap:Map<String, Null<Int>> = new Map<String, Null<Int>>();
	var eventStuff:Array<Dynamic> =
	[
		// Name, Description
		['', ''], // This is used to input custom events.
		['Hey!', "Plays the \"Hey!\" animation from Bopeebo,\nValue 1: BF = Only Boyfriend, GF = Only Girlfriend,\nSomething else = Both.\nValue 2: Custom animation duration,\nleave it blank for 0.6s"],
		['Set GF Speed', "Sets GF head bopping speed,\nValue 1: 1 = Normal speed,\n2 = 1/2 speed, 4 = 1/4 speed etc.\nUsed on Fresh during the beatbox parts.\n\nWarning: Value must be integer!"],
		['Add Camera Zoom', "Used on MILF on that one \"hard\" part\nValue 1: Camera zoom add (Default: 0.015)\nValue 2: UI zoom add (Default: 0.03)\nLeave the values blank if you want to use Default."],
		['Play Animation', "Plays an animation on a Character,\nonce the animation is completed,\nthe animation changes to Idle\n\nValue 1: Animation to play.\nValue 2: Character (Dad, BF, GF)"],
		['Camera Follow Pos', "Value 1: X\nValue 2: Y\n\nThe camera won't change the follow point\nafter using this, for getting it back\nto normal, leave both values blank."],
		["Change Focus", "Sets who the camera is focusing on.\nNote that the must hit changing on a section will reset\nthe focus.\nValue 1: Who to focus on (dad, bf)"],
		
		['Stage Event', 'Event whose behaviour defined by the stage.'],
		['Song Event', 'Event whose behaviour defined by the song.'],
		['Set Property', "Value 1: Variable name\nValue 2: New value"],
		
		['Alt Idle Animation', "Sets a specified suffix after the idle animation name.\nYou can use this to trigger 'idle-alt' if you set\nValue 2 to -alt\n\nValue 1: Character to set (Dad, BF or GF)\nValue 2: New suffix (Leave it blank to disable)"],
		['Screen Shake', "Value 1: Camera shake\nValue 2: HUD shake\n\nEvery value works as the following example: \"1, 0.05\".\nThe first number (1) is the duration.\nThe second number (0.05) is the intensity."],
		['Change Character', "Value 1: Character to change (dad, bf, gf)\nValue 2: New character's name"],
		
		['Game Flash', "Value 1: Hexadecimal Color (0xFFFFFFFF is default)\nValue 2: Duration in seconds (0.5 is default)"],

		['Change Scroll Speed', "Value 1: Scroll Speed Multiplier (1 is default)\nValue 2: Time it takes to change fully in seconds."],
		[
			"Constant SV", 
			"Speed changes which don't affect note positions.\n(For example, a speed of 0 stops notes\ninstead of making them go onto the receptors.)\nValue 1: New Speed. Defaults to 1"
			#if EASED_SVs
			+ "\nValue 2: Tween settings\n(Duration and EaseFunc seperated by a / (ex. 1/quadOut))"
			#end
		],
		[
			"Mult SV", 
			"Speed changes which don't affect note positions.\n(For example, a speed of 0 stops notes\ninstead of making them go onto the receptors.)\nValue 1: Speed Multiplier. Defaults to 1"
			#if EASED_SVs
			+ "\nValue 2: Tween settings\n(Duration and EaseFunc seperated by a /(ex. 1/quadOut))"
			#end
		]
	];

	var UI_box:FlxUITabMenu;

	var bpmTxt:FlxText;

	var camPos:FlxObject;
	var strumLine:FlxSprite;
	var quant:AttachedSprite;
	var strumLineNotes:FlxTypedGroup<StrumNote>;
	var curSong:String = 'Test';
	var curSec:Int = 0;
	var amountSteps:Int = 0;

	var highlight:FlxSprite;

	public static var GRID_SIZE:Int = 40;
	public static var GRID_HALF:Float = GRID_SIZE * 0.5;

	var dummyArrow:FlxSprite;

	var prevRenderedSustains:FlxTypedGroup<FlxSprite>;
	var prevRenderedNotes:FlxTypedGroup<Note>;

	var curRenderedSustains:FlxTypedGroup<FlxSprite>;
	var curRenderedNotes:FlxTypedGroup<Note>;
	var curRenderedNoteType:FlxTypedGroup<FlxText>;

	var nextRenderedSustains:FlxTypedGroup<FlxSprite>;
	var nextRenderedNotes:FlxTypedGroup<Note>;

	var prevGridBG:FlxSprite;
	var gridBG:FlxSprite;
	var nextGridBG:FlxSprite;

	var subEventIdx:Int = 0;
	var _song:SwagSong;
	/* WILL BE THE CURRENT / LAST PLACED NOTE */
	var curSelectedNote:NoteData = null;
	var curSelectedEvent:PsychEventNote = null;

	/** HELD NOTE FROM CLICKING **/
	private var heldNotesClick:Array<NoteData> = []; 
	/** HELD NOTES FROM VORTEX **/
	private var heldNotesVortex:Array<NoteData> = []; 

	var playedSound:Array<Bool> = []; //Prevents ouchy GF sex sounds

	var inst:FlxSound = null;
	var tracks:Array<FlxSound> = [];
	var soundTracksMap:Map<String, FlxSound> = [];
	
	var songId:String;
	var songLength:Float = 0.0;

	var progressBG:FlxSprite;
	var progressBar:CustomFlxUISlider;

	var iconBG:FlxSprite;
	var leftIcon:HealthIcon;
	var rightIcon:HealthIcon;

	var value1InputText:FlxUIInputText;
	var value2InputText:FlxUIInputText;

	var zoomTxt:FlxText;

	var zoomList:Array<Float> = [
		0.25,
		0.5,
		1,
		2,
		3,
		4,
		6,
		8,
		12,
		16,
		24
	];
	/**Selected zoom index**/
	var curZoom:Int = 2;

	private var blockPressWhileTypingOn:Array<FlxUIInputText> = [];
	private var blockPressWhileTypingOnStepper:Array<CustomFlxUINumericStepper> = [];
	private var blockPressWhileScrolling:Array<FlxUIDropDownMenu> = [];
	private var blockScrollWhileHovering:Array<FlxUISlider> = [];

	var waveformSprite:FlxSprite;
	var gridLayer:FlxTypedGroup<FlxBasic>;
	var beatSeparators:FlxTypedGroup<FlxSprite>;
	var fieldSeparators:FlxTypedGroup<FlxSprite>;

	public static var quantization:Int = 16;
	public var quantizationMult:Float = (quantization / 16);
	public static var curQuant = 3;

	var quantTxt:FlxText;

	public var quantNames:Array<String> = [
		"4th",
		"8th",
		"12th",
		"16th",
		"20th",
		"24th",
		"32nd",
		"48th",
		"64th",
		"96th",
		"192nd"
	];
	public var quantizations:Array<Int> = [
		4,
		8,
		12,
		16,
		20,
		24,
		32,
		48,
		64,
		96,
		192
	];
	
	public var hitsoundVolume(default, set):Float = 1.0;
	@:noCompletion function set_hitsoundVolume(val:Float){
		plrHitsound.volume = val;
		oppHitsound.volume = val;
		hitsound.volume = val;
		return hitsoundVolume = val;
	}


	public var playbackSpeed(default, set):Float = 1.0;
	@:noCompletion function set_playbackSpeed(val:Float){
		Conductor.changePitch(val);
		return playbackSpeed = val;
	}

	// move notes to their corresponding sections
	function fixOOBNotes() {
		var allSections:Array<SwagSection> = _song.notes;
		var allNotes:Array<NoteData> = [];
		var sectionStarts:Array<Float> = [];
		
		var bimp = Conductor.bpm;
		var beat:Float = 0;
		for (i => section in allSections) {			
			if (section.changeBPM)
				Conductor.changeBPM(section.bpm);

			while (section.sectionNotes.length > 0) {
				var note = section.sectionNotes.pop();
				note.strumTime = fuckFloatingPoints(note.strumTime);
				if (!section.mustHitSection)
					note.column = (note.column + _song.keyCount) % (_song.keyCount * 2);
				allNotes.push(note);
			}
			
			sectionStarts[i] = fuckFloatingPoints(Conductor.stepToMs(beat * 4));
			beat += getSectionBeats(i);
		}
		Conductor.changeBPM(bimp);
		
		allNotes.sort((a, b) -> return Std.int(b.strumTime - a.strumTime)); // descending order

		var curSection = 0;
		while (allNotes.length > 0) {
			var note:NoteData = allNotes.pop();

			for (i in curSection...sectionStarts.length) {
				if (note.strumTime >= sectionStarts[i])
					curSection = i;
				else
					break;
			}

			var section = allSections[curSection];
			if (!section.mustHitSection)
				note.column = (note.column + _song.keyCount) % (_song.keyCount * 2);

			section.sectionNotes.push(note); 
		}

		updateGrid();
	}

	function adjustCamPos() {
		camPos.x = GRID_SIZE * (1 + _song.keyCount);

		var boxWidth = 300;
		var chart_grid_end = FlxG.width / 2 + GRID_SIZE * _song.keyCount;

		var ui_width_grid_snapped = Math.ceil(boxWidth / GRID_SIZE) * GRID_SIZE;
		var chart_grid_offset = ui_width_grid_snapped - boxWidth;

		var ui_start = chart_grid_end + chart_grid_offset;
		var ui_end = chart_grid_end + ui_width_grid_snapped + boxWidth;

		var ui_space_leftover = (FlxG.width - chart_grid_end) - ui_width_grid_snapped;
		
		if (ui_space_leftover < 0){
			ui_start += ui_space_leftover;
			camPos.x -= ui_space_leftover;
		}else if (ui_space_leftover <= GRID_SIZE * 2){
			ui_start += ui_space_leftover / 2;
		}else if (ui_space_leftover > GRID_SIZE * 2){
			ui_start += ui_space_leftover - GRID_SIZE;
		}

		UI_box.setPosition(ui_start, 25);
	}

	private function onLoadMetadata() {
		_song.metadata ??= {};
		_song.metadata.songName ??= _song.song ?? songId ?? "Untitled";
		_song.metadata.artist ??= "";
		_song.metadata.charter ??= "";
		_song.metadata.modcharter ??= "";

		updateDiscordRPC();
	}

	private function updateDiscordRPC() {
		#if DISCORD_ALLOWED
		// Updating Discord Rich Presence
		DiscordClient.changePresence("Chart Editor", _song.metadata.songName);
		#end
	}

	public function new(data:SwagSong = null) {
		super();

		data ??= PlayState.SONG;
		this._song = data ?? {
			song: 'Test',
			bpm: 150.0,
			speed: 1,
			offset: 0,

			stage: 'stage',
			player1: 'bf',
			player2: 'dad',
			gfVersion: 'gf',

			arrowSkin: 'NOTE_assets',
			splashSkin: 'noteSplashes',
			hudSkin: 'default',

			tracks: {
				inst: ["Inst"],
				player: ["Voices"],
				opponent: ["Voices"]
			},

			validScore: false,

			keyCount: 4,
			notes: [],
			events: [],
		};
		this.songId = _song.song;
	}

	inline function formatTime(ms:Float) {
		var mins = '' + Math.floor(ms / 60000);
		var secs = '' + Math.floor((ms % 60000) / 1000);
		return '$mins:${secs.length < 2 ? '0' + secs : secs}';
	}

	override function create()
	{
		instance = this;
		updateSongPos = false;
		
		FlxTransitionableState.skipNextTransOut = true;
		MusicBeatState.stopMenuMusic();

		PlayState.SONG = _song;

		loadEventStuff();
		
		onLoadMetadata();

		if (_song.notes.length == 0)
			pushSection();

		_session ??= makeSession();

		Conductor.cleanup();
		Conductor.changeBPM(_song.bpm);
		Conductor.mapBPMChanges(_song);
		Conductor.tracks = this.tracks;
		loadTracks();
/* 		fixEvents(); */

		plrHitsound = new FlxSound().loadEmbedded(Paths.sound("monoHitsound"));
		plrHitsound.pan = -0.75;
		plrHitsound.exists = true;
		FlxG.sound.list.add(plrHitsound);

		oppHitsound = new FlxSound().loadEmbedded(Paths.sound("monoHitsound"));
		oppHitsound.pan = 0.75;
		oppHitsound.exists = true;
		FlxG.sound.list.add(oppHitsound);

		hitsound = new FlxSound().loadEmbedded(Paths.sound("hitsound"));
		hitsound.exists = true;
		FlxG.sound.list.add(hitsound);
		// Paths.clearMemory();

		var bg:FlxSprite = new FlxSprite(0, 0, Paths.image('menuDesat'));
		bg.color = FlxColor.fromHSB(Std.random(64) * 5.625, 0.15, 0.15);
		bg.scrollFactor.set();
		bg.screenCenter();
		add(bg);

		gridLayer = new FlxTypedGroup<FlxBasic>();
		add(gridLayer);

		beatSeparators = new FlxTypedGroup<FlxSprite>();
		fieldSeparators = new FlxTypedGroup<FlxSprite>();

		waveformSprite = new FlxSprite(GRID_SIZE, 0).makeGraphic(FlxG.width, FlxG.height, 0x00FFFFFF);
		add(waveformSprite);

		prevRenderedSustains = new FlxTypedGroup<FlxSprite>();
		prevRenderedNotes = new FlxTypedGroup<Note>();

		curRenderedSustains = new FlxTypedGroup<FlxSprite>();
		curRenderedNotes = new FlxTypedGroup<Note>();
		curRenderedNoteType = new FlxTypedGroup<FlxText>();

		nextRenderedSustains = new FlxTypedGroup<FlxSprite>();
		nextRenderedNotes = new FlxTypedGroup<Note>();

		bpmTxt = new FlxText(12, 50, 0, "", 20);
		bpmTxt.setFormat(null, 18, 0xFFFFFFFF, LEFT, FlxTextBorderStyle.OUTLINE, 0xFF000000);
		bpmTxt.borderSize = 2;
		bpmTxt.scrollFactor.set();
		add(bpmTxt);

		strumLine = CoolUtil.blankSprite(Std.int(GRID_SIZE * (1 + _song.keyCount * 2)), 4);
		add(strumLine);

		camPos = new FlxObject();
		add(camPos);

		FlxG.camera.follow(camPos);

		quant = new AttachedSprite('chart_quant','chart_quant');
		quant.animation.addByPrefix('q','chart_quant',0,false);
		quant.animation.play('q', true, false, 0);
		quant.sprTracker = strumLine;
		quant.xAdd = -32;
		quant.yAdd = 8;
		add(quant);

		strumLineNotes = new FlxTypedGroup<StrumNote>();
		for (i in 0..._song.keyCount * 2){
			var note:StrumNote = new StrumNote(GRID_SIZE * (i+1), strumLine.y, i % _song.keyCount);
			note.setGraphicSize(GRID_SIZE, GRID_SIZE);
			note.updateHitbox();
			note.playAnim('static', true);
			strumLineNotes.add(note);
			note.scrollFactor.set(1, 1);
		}
		add(strumLineNotes);

		dummyArrow = CoolUtil.blankSprite(GRID_SIZE, GRID_SIZE);
		add(dummyArrow);

		////
		iconBG = FlxGradient.createGradientFlxSprite(1, 45 + 5 * 2, [0xFF535353, 0x00535353]);
		iconBG.scale.x = FlxG.width;
		iconBG.updateHitbox();
		iconBG.scrollFactor.set(0, 0);
		add(iconBG);

		var eventIcon:FlxSprite = new FlxSprite(GRID_SIZE * 0.5 - 30 * 0.5, (55 - 30) * 0.5, Paths.image('eventArrow'));
		eventIcon.scrollFactor.set(1, 0);
		eventIcon.setGraphicSize(30, 30);
		eventIcon.updateHitbox();
		add(eventIcon);
		
		leftIcon = new HealthIcon('bf');
		leftIcon.scrollFactor.set(1, 0);
		leftIcon.setGraphicSize(0, 45);
		leftIcon.updateHitbox();
		add(leftIcon);
		
		rightIcon = new HealthIcon('dad');
		rightIcon.scrollFactor.set(1, 0);
		rightIcon.setGraphicSize(0, 45);
		rightIcon.updateHitbox();
		add(rightIcon);

		////
		var text =
		"W/S or Mouse Wheel - Change strum time
		\nA/D - Go to the previous/next section
		\nUp/Down - Change strum Time with snapping
		\nLeft/Right - Change Snap
		\nHold Shift to move 4x faster
		\nHold Control and click on an arrow to select it
		\nZ/X - Zoom in/out
		\n
		\nEnter - Play your chart
		\nQ/E - Decrease/Increase Note Sustain Length
		\nSpace - Stop/Resume song
		\n
		\nF1 - Hide/Show help
		";
		
		helpTextGrp = new FlxTypedGroup<FlxText>();
		helpTextGrp.exists = !options.hideHelp;
		add(helpTextGrp);

		var tipTextY = FlxG.height/2 + GRID_SIZE;
		var tipTextArray:Array<String> = text.split('\n');
		for (i in 0...tipTextArray.length) {
			var tipText:FlxText = new FlxText(12, tipTextY + i * 12, 0, tipTextArray[i], 14);
			tipText.setFormat(null, 14, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE_FAST, FlxColor.BLACK);
			tipText.antialiasing = false;
			tipText.borderSize = 1.25;
			tipText.scrollFactor.set();
			tipText.antialiasing = ClientPrefs.globalAntialiasing;
			helpTextGrp.add(tipText);
		}

		var tabs = [
			{name: "Editor", label: 'Editor'},
			{name: "Note", label: 'Note'},
			{name: "Event", label: 'Event'},
			{name: "Section", label: 'Section'},
			{name: "Song", label: 'Song'},
			{name: "Metadata", label: 'Metadata'},
		];

		UI_box = new CustomFlxUITabMenu(null, tabs, true);
		UI_box.resize(300, 400);
		UI_box.scrollFactor.set();
		add(UI_box);

		adjustCamPos();

		addMetadataUI();
		addSongUI();
		addSectionUI();
		addNoteUI();
		addEventsUI();
		addChartingUI();
		addTracksUI();

		add(prevRenderedSustains);
		add(prevRenderedNotes);
		add(curRenderedSustains);
		add(curRenderedNotes);
		add(curRenderedNoteType);
		add(nextRenderedSustains);
		add(nextRenderedNotes);

		zoomTxt = new FlxText(10, 180, 0, "Zoom: 1 / 1", 16);
		zoomTxt.setFormat(null, 18, 0xFFFFFFFF, LEFT, FlxTextBorderStyle.OUTLINE, 0xFF000000);
		zoomTxt.borderSize = 2;
		zoomTxt.scrollFactor.set();
		add(zoomTxt);

		quantTxt = new FlxText(10, 200, 0, "Beat Snap: " + quantNames[curQuant] , 16);
		quantTxt.setFormat(null, 18, 0xFFFFFFFF, LEFT, FlxTextBorderStyle.OUTLINE, 0xFF000000);
		quantTxt.borderSize = 2;
		quantTxt.scrollFactor.set();
		add(quantTxt);

		////
		progressBG = FlxGradient.createGradientFlxSprite(1, GRID_SIZE, [0xFF535353, 0xFF414040]);
		progressBG.scale.x = FlxG.width;
		progressBG.updateHitbox();
		progressBG.scrollFactor.set(0, 0);
		progressBG.y = FlxG.height - progressBG.height;
		add(progressBG);

		var w = Math.floor(progressBG.width / 3);
		progressBar = new CustomFlxUISlider(
			Conductor, 
			'songPosition', 
			progressBG.x + (progressBG.width - w) / 2,
			progressBG.y,
			0.0, 
			songLength, 
			w, 
			null, 
			5, 
			FlxColor.WHITE, 
			FlxColor.BLACK	
		);
		progressBar.setVariable = false;
		progressBar.scrollStep = 0.0;
		progressBar.callback = function(perc) {
			if (!progressBar.dragging) return;
			var playing;
			if (playing = Conductor.playing) Conductor.pauseSong();
			Conductor.songPosition = Math.ffloor(perc * songLength);
			if (playing) Conductor.resumeSong();
		}

		progressBar.nameLabel.exists = false;
		progressBar.valueLabel.exists = false;

		progressBar.minLabel.text = "0:00";
		progressBar.minLabel.x -= 30;
		progressBar.minLabel.y = progressBar.body.y;

		progressBar.maxLabel.text = formatTime(songLength);
		progressBar.maxLabel.x += 30;
		progressBar.maxLabel.y = progressBar.body.y;

		progressBar.y += (progressBG.height - progressBar.height) / 2;
		add(progressBar);
		progressBar.scrollFactor.set();

		////
		curSec = _session.curSec;
		Conductor.songPosition = _session.songPosition;
		
		if (curSec >= _song.notes.length)
			curSec = _song.notes.length - 1;
		changeSection(curSec, false);

		//
		for (id => volume in _session.trackVolumes) {
			var snd = soundTracksMap.get(id);
			if (snd != null) snd.volume = volume;
		}

		//
		var lastSelectedTrack = _session.selectedTrack;
		if (soundTracksMap.exists(lastSelectedTrack))
			selectTrack(lastSelectedTrack);
		else
			waveformTrackDropDown.selectedId = "None";

		////
		/*
		var lol = new TimelineDisplay(UI_box.x + UI_box.width - 250, FlxG.height - 5 - 16 * 10, 10);
		this.add(lol);
		*/

		////
		super.create();
		FlxG.mouse.visible = true;
	}

	function loadEventStuff() {
		#if (sys && (hscript))
		var eventsLoaded:Map<String, Bool> = new Map();
		for (directory in Paths.getFolders('events'))
		{
			if (!FileSystem.exists(directory))
				continue;

			for (file in FileSystem.readDirectory(directory))
			{
				if (!file.endsWith('.txt'))
					continue;

				var eventToCheck:String = file.substr(0, file.length - 4);
				if (eventsLoaded.exists(eventToCheck))
					continue;

				eventsLoaded.set(eventToCheck, true);
				eventStuff.push([eventToCheck, File.getContent(haxe.io.Path.join([directory, file]))]);
			}
		}
		#end
	}

	override function startOutro(fuck){
		this.persistentUpdate = false;
		super.startOutro(fuck);
	}

	function fixEvents(){
		var rawEventsData:Array<PsychEventNote> = _song.events;
		rawEventsData.sort((a, b) -> return Std.int(a.strumTime - b.strumTime));
		var eventsData:Array<PsychEventNote> = [];
		for (event in rawEventsData)
		{
			var last = eventsData[eventsData.length - 1];
			if (last == null)
			{
				eventsData.push(event);
			}
			else
			{
				if (Math.abs(last.strumTime - event.strumTime) <= Conductor.jackLimit)
				{
					var fuck = eventsData[eventsData.length - 1];
					for (shit in event.subEventsData)
						fuck.subEventsData.push(shit);
				}
				else
				{
					eventsData.push(event);
				}
			}
		}

		_song.events = eventsData;	
	}

	function showPopup(text:String, ?onAccept:Void->Void) {
		if (onAccept != null)
			openSubState(new Prompt(text, 0, onAccept));
		else
			openSubState(new Prompt(text, 0, onAccept, null, false, "OK", "OK"));
	}

	function showWarning(text:String, ?onAccept:Void->Void) {
		if (options.ignoreWarnings) {
			if (onAccept != null) onAccept();
		}else {
			showPopup(text, onAccept);
		}
	}

	function addSongUI():Void
	{
		var UI_songTitle = new FlxUIInputText(10, 10, 70, _song.song, 8);
		UI_songTitle.name = 'song_title';
		blockPressWhileTypingOn.push(UI_songTitle);

		var saveButton:FlxButton = new FlxButton(110, 8, "Save Chart", saveLevel);

		var reloadSongJson:FlxButton = new FlxButton(saveButton.x + 90, saveButton.y, "Reload JSON", function()
		{
			showWarning('This action will clear current progress.\n\nProceed?', loadJson.bind(_song.song));
		});

		var loadAutosaveBtn:FlxButton = new FlxButton(reloadSongJson.x, reloadSongJson.y + 30, 'Load Autosave', function()
		{
			var autosaved:Dynamic = options.autosave;
			if (autosaved == null) {
				showPopup("There is no autosaved data");
			}else if (!Std.isOfType(autosaved, String)) {
				showPopup("Invalid autosaved data");
			}else{
				var _song:Dynamic = Json.parse(autosaved);
				
				// Ugh
				var _session:ChartingStateSession = Reflect.field(_song, "_chartEditor");
				if (_session.trackVolumes != null && !Std.isOfType(_session.trackVolumes, haxe.ds.StringMap) && Reflect.isObject(_session.trackVolumes))
					_session.trackVolumes = cast CoolUtil.structureToMap(_session.trackVolumes);

				MusicBeatState.switchState(new ChartingState(_song));
			}
		});

		////
		function onOpenEvents(resource) {
			var data:Dynamic = Json.parse((resource:Bytes).toString());

			var song:SwagSong = Reflect.field(data, "song"); 
			if (song == null)
				return;
		
			var events = ChartData.onLoadEvents(data.song).events;
			if (events == null)
				return;

			_song.events = events;
			updateGrid();
		}

		var loadEventJson:FlxButton = new FlxButton(loadAutosaveBtn.x, loadAutosaveBtn.y + 30, 'Open Events', function() {
			final openEvents:Void->Void = CoolUtil.showOpenDialog.bind('Open Events', getSongPath('events.json'), ['*.json'], onOpenEvents);
			showWarning('This action will clear the current events.\n\nProceed?', openEvents);
		});

		var saveEventJson:FlxButton = new FlxButton(110, saveButton.y + 30, 'Save Events', function() {
			if (_song.events != null && _song.events.length > 1)
				_song.events.sort(sortEventsByTime);

			var json = {"song": {"events": _song.events}}
			var data:String = Json.stringify(json, "\t");
			CoolUtil.showSaveDialog(data, 'Save Events', getSongPath('events.json'), ["JSON file", '*.json']);
		});

		////
		var editTracksButton:FlxButton = new FlxButton(loadAutosaveBtn.x, loadEventJson.y + 40, 'Edit Tracks', function() {
			UI_box.selected_tab_id = "Tracks";
		});

		////
		var fix_oob_notes:FlxButton = new FlxButton(loadAutosaveBtn.x, 300 - 40, 'Fix Notes', showWarning.bind('This action will fix notes that are outside of their corresponding section.\n\nProceed?', fixOOBNotes));
		fix_oob_notes.color = FlxColor.PINK;
		fix_oob_notes.label.color = FlxColor.WHITE;

		var clear_events:FlxButton = new FlxButton(loadAutosaveBtn.x, 300, 'Clear events', showWarning.bind('Clear notes?\n\nThis action cannot be undone.', clearEvents));
		clear_events.color = FlxColor.RED;
		clear_events.label.color = FlxColor.WHITE;

		var clear_notes:FlxButton = new FlxButton(clear_events.x, clear_events.y + 30, 'Clear notes', showWarning.bind('Clear events?\n\nThis action cannot be undone.', clearNotes));
		clear_notes.color = FlxColor.RED;
		clear_notes.label.color = FlxColor.WHITE;

		var stepperSpeed = new CustomFlxUINumericStepper(10, UI_songTitle.y + 35, 0.1, 1, 0.1, 10, 1);
		stepperSpeed.value = _song.speed;
		stepperSpeed.name = 'song_speed';
		blockPressWhileTypingOnStepper.push(stepperSpeed);

		var stepperBPM = new CustomFlxUINumericStepper(10, stepperSpeed.y + 35, 1, 1, 1, 9000, 3);
		stepperBPM.value = Conductor.bpm;
		stepperBPM.name = 'song_bpm';
		blockPressWhileTypingOnStepper.push(stepperBPM);

		var stepperKeyCount = new CustomFlxUINumericStepper(10, stepperBPM.y + 35, 1, 4, 1, 10, 0);
		stepperKeyCount.value = _song.keyCount;
		stepperKeyCount.name = 'song_keyCount';
		blockPressWhileTypingOnStepper.push(stepperKeyCount);

		////
		var skins:Array<String> = ['default'];
		#if MODS_ALLOWED
		var skinsLoaded:Map<String, Bool> = new Map();
		var directories:Array<String> = Paths.getFolders('hudskins');
		for (i in 0...directories.length) {
			var directory:String = directories[i];
			if(FileSystem.exists(directory)) {
				for (file in FileSystem.readDirectory(directory)) {
					var path = haxe.io.Path.join([directory, file]);
					if (!FileSystem.isDirectory(path) && Paths.isHScript(path)) {
						var skinToCheck:String = file.substr(0, file.length - 8);
						if(!skinsLoaded.exists(skinToCheck)) {
							skins.push(skinToCheck);
							skinsLoaded.set(skinToCheck, true);
						}
					}
				}
			}
		}
		#end

		////
		var characters:Array<Null<String>> = CharacterData.getAllCharacters();
		characters.sort(CoolUtil.alphabeticalSort);
		characters.insert(0, "null");
		var ddCharacters = FlxUIDropDownMenu.makeStrIdLabelArray(characters, true);
		ddCharacters[0].label = "<null>";
		characters[0] = null;

		var daY = stepperKeyCount.y;

		var player1DropDown = new CustomFlxUIDropDownMenu(10, daY + 45, ddCharacters, function(character:String)
		{
			_song.player1 = characters[Std.parseInt(character)];
			updateHeads();
		});
		player1DropDown.selectedLabel = _song.player1;
		blockPressWhileScrolling.push(player1DropDown);

		var gfVersionDropDown = new CustomFlxUIDropDownMenu(player1DropDown.x, player1DropDown.y + 40, ddCharacters, function(character:String)
		{
			_song.gfVersion = characters[Std.parseInt(character)];
			updateHeads();
		});
		gfVersionDropDown.selectedLabel = _song.gfVersion;
		blockPressWhileScrolling.push(gfVersionDropDown);

		var player2DropDown = new CustomFlxUIDropDownMenu(player1DropDown.x, gfVersionDropDown.y + 40, ddCharacters, function(character:String)
		{
			_song.player2 = characters[Std.parseInt(character)];
			updateHeads();
		});
		player2DropDown.selectedLabel = _song.player2;
		blockPressWhileScrolling.push(player2DropDown);


		////
		var stages = Stage.getAllStages();
		stages.sort(CoolUtil.alphabeticalSort);
		stages.remove("empty");
		stages.insert(0, "empty");
		
		var stageDropDown = new CustomFlxUIDropDownMenu(
			player1DropDown.x + 140, 
			player1DropDown.y, 
			FlxUIDropDownMenu.makeStrIdLabelArray(stages, true), 
			function(character:String)
			{
				_song.stage = stages[Std.parseInt(character)];
				trace('stage changed. index:$character, result:${_song.stage}');
			}
		);
		stageDropDown.selectedLabel = _song.stage;
		blockPressWhileScrolling.push(stageDropDown);

		var skinDropdown = new CustomFlxUIDropDownMenu(
			stageDropDown.x, stageDropDown.y + 40, 
			FlxUIDropDownMenu.makeStrIdLabelArray(skins, true), 
			function(skin:String){
				_song.hudSkin = skins[Std.parseInt(skin)];
			}
		);
		skinDropdown.selectedLabel = _song.hudSkin;
		blockPressWhileScrolling.push(skinDropdown);

		var arrowSkin = _song.arrowSkin;
		if (arrowSkin == null) arrowSkin = '';
		
		var splashSkin = _song.splashSkin;
		if (splashSkin == null) splashSkin = '';

		var noteSkinInputText = new FlxUIInputText(player2DropDown.x, player2DropDown.y + 50, 150, arrowSkin, 8);
		blockPressWhileTypingOn.push(noteSkinInputText);

		var noteSplashesInputText = new FlxUIInputText(noteSkinInputText.x, noteSkinInputText.y + 35, 150, splashSkin, 8);
		noteSplashesInputText.name = 'song_noteSplashes';
		blockPressWhileTypingOn.push(noteSplashesInputText);

		var reloadNotesButton:FlxButton = new FlxButton(noteSplashesInputText.x + 5, noteSplashesInputText.y + 20, 'Change Notes', function() {
			_song.arrowSkin = noteSkinInputText.text;
			updateGrid();
		});
		
		var tab_group_song = new FlxUI(null, UI_box);
		tab_group_song.name = "Song";
		tab_group_song.add(UI_songTitle);

		tab_group_song.add(fix_oob_notes);
		tab_group_song.add(clear_events);
		tab_group_song.add(clear_notes);
		tab_group_song.add(saveButton);
		tab_group_song.add(saveEventJson);
		tab_group_song.add(editTracksButton);

		tab_group_song.add(reloadSongJson);
		tab_group_song.add(loadAutosaveBtn);
		tab_group_song.add(loadEventJson);
		tab_group_song.add(stepperSpeed);
		tab_group_song.add(stepperBPM);
		tab_group_song.add(stepperKeyCount);
		tab_group_song.add(reloadNotesButton);
		tab_group_song.add(noteSkinInputText);
		tab_group_song.add(noteSplashesInputText);

		tab_group_song.add(new FlxText(stepperSpeed.x, stepperSpeed.y - 15, 0, 'Song Speed:'));
		tab_group_song.add(new FlxText(stepperBPM.x, stepperBPM.y - 15, 0, 'Song BPM:'));
		tab_group_song.add(new FlxText(stepperKeyCount.x, stepperKeyCount.y - 15, 0, 'Key Count:'));

		tab_group_song.add(new FlxText(skinDropdown.x, skinDropdown.y - 15, 0, 'HUD Skin:'));
		tab_group_song.add(new FlxText(player2DropDown.x, player2DropDown.y - 15, 0, 'Opponent:'));
		tab_group_song.add(new FlxText(gfVersionDropDown.x, gfVersionDropDown.y - 15, 0, 'Girlfriend:'));
		tab_group_song.add(new FlxText(player1DropDown.x, player1DropDown.y - 15, 0, 'Boyfriend:'));
		tab_group_song.add(new FlxText(stageDropDown.x, stageDropDown.y - 15, 0, 'Stage:'));
		
		tab_group_song.add(new FlxText(noteSkinInputText.x, noteSkinInputText.y - 15, 0, 'Note Texture:'));
		tab_group_song.add(new FlxText(noteSplashesInputText.x, noteSplashesInputText.y - 15, 0, 'Note Splashes Texture:'));
		
		tab_group_song.add(skinDropdown);
		tab_group_song.add(player2DropDown);
		tab_group_song.add(gfVersionDropDown);
		tab_group_song.add(player1DropDown);
		tab_group_song.add(stageDropDown);

		UI_box.addGroup(tab_group_song);
	}

	var stepperBeats:CustomFlxUINumericStepper;
	var check_mustHitSection:FlxUICheckBox;
	var check_gfSection:FlxUICheckBox;
	var check_changeBPM:FlxUICheckBox;
	var stepperSectionBPM:CustomFlxUINumericStepper;
	var check_altAnim:FlxUICheckBox;

	var sectionToCopy:Int = 0;

	function addSectionUI():Void
	{
		var tab_group_section = new FlxUI(null, UI_box);
		tab_group_section.name = 'Section';

		////
		check_mustHitSection = new FlxUICheckBox(10, 15, null, null, "Must hit section", 100);
		check_mustHitSection.name = 'check_mustHit';
		check_mustHitSection.checked = _song.notes[curSec].mustHitSection;

		check_gfSection = new FlxUICheckBox(10, check_mustHitSection.y + 30, null, null, "GF section", 100);
		check_gfSection.name = 'check_gf';
		check_gfSection.checked = _song.notes[curSec].gfSection;

		check_altAnim = new FlxUICheckBox(10, check_gfSection.y + 30, null, null, "Alt Animation", 100);
		check_altAnim.checked = _song.notes[curSec].altAnim;
		check_altAnim.name = 'check_altAnim';

		stepperBeats = new CustomFlxUINumericStepper(150, 25, 1, 1, 1, 9000, 3);
		stepperBeats.value = getSectionBeats(curSec);
		stepperBeats.name = 'section_beats';
		blockPressWhileTypingOnStepper.push(stepperBeats);

		check_changeBPM = new FlxUICheckBox(150, stepperBeats.y + 30, null, null, 'Change BPM', 100);
		check_changeBPM.checked = _song.notes[curSec].changeBPM;
		check_changeBPM.name = 'check_changeBPM';

		stepperSectionBPM = new CustomFlxUINumericStepper(150, check_changeBPM.y + 20, 1, Conductor.bpm, 0, 999, 1);
		if(check_changeBPM.checked) {
			stepperSectionBPM.value = _song.notes[curSec].bpm;
		} else {
			stepperSectionBPM.value = Conductor.bpm;
		}
		stepperSectionBPM.name = 'section_bpm';
		blockPressWhileTypingOnStepper.push(stepperSectionBPM);

		////
		var check_eventsSec:FlxUICheckBox = null;
		var check_notesSec:FlxUICheckBox = null;

		var copyButton:FlxButton = new FlxButton(10, 140, "Copy Section", function()
		{
			sectionToCopy = curSec;
		});

		var pasteButton:FlxButton = new FlxButton(copyButton.x + 100, copyButton.y, "Paste Section", function()
		{
			/*
			if (sectionToCopy == null)
				return;
			*/

			var addToTime:Float = Conductor.stepCrochet * (getSectionBeats(curSec) * 4 * (curSec - sectionToCopy));
			//trace('Time to add: ' + addToTime);

			////
			if(check_notesSec.checked) {
				for (note in _song.notes[sectionToCopy].sectionNotes) {
					var copiedNote = note.clone();
					note.strumTime += addToTime;
					_song.notes[curSec].sectionNotes.push(copiedNote);
				}
			}

			////
			if (check_eventsSec.checked) {
				var sectionStart:Float = fuckFloatingPoints(getSectionStartTime(sectionToCopy));
				var sectionEnd:Float = fuckFloatingPoints(getSectionStartTime(sectionToCopy + 1));
				for (event in _song.events) {
					var strumTime:Float = fuckFloatingPoints(event.strumTime);
					if (sectionStart <= strumTime && strumTime < sectionEnd) {
						var copiedEvent:PsychEventNote = event.clone();
						copiedEvent.strumTime = strumTime + addToTime;
						_song.events.push(copiedEvent);
					}
				}
			}

/* 			if(check_eventsSec.checked)
			{
				fixEvents();
			} */
			updateGrid();
		});

		var clearSectionButton:FlxButton = new FlxButton(pasteButton.x + 100, pasteButton.y, "Clear current", function()
		{
			if (check_notesSec.checked) {
				_song.notes[curSec].sectionNotes.resize(0);
				updateNoteUI();
			}

			if (check_eventsSec.checked) {
				var startThing:Float = sectionStartTime();
				var endThing:Float = sectionStartTime(1);
				var filteredEvents = _song.events.filter(function(event:PsychEventNote) {
					return startThing <= event.strumTime && event.strumTime < endThing;
				});
				
				for (event in filteredEvents) {
					if (event == curSelectedEvent) {
						curSelectedEvent = null;
						changeEventSelected();
					}
					_song.events.remove(event);
				}
			}
			updateGrid();
		});
		clearSectionButton.color = FlxColor.RED;
		clearSectionButton.label.color = FlxColor.WHITE;
		
		check_notesSec = new FlxUICheckBox(10, clearSectionButton.y + 25, null, null, "Notes", 35);
		check_notesSec.checked = true;
		check_eventsSec = new FlxUICheckBox(check_notesSec.x + 105, check_notesSec.y, null, null, "Events", 50);
		check_eventsSec.checked = true;

		////
		var stepperCopy:CustomFlxUINumericStepper = null;
		var copyLastButton:FlxButton = new FlxButton(10, 220, "Copy last section", function()
		{
			var value:Int = Std.int(stepperCopy.value);
			if(value == 0) return;

			var secToCopy:Int = curSec - value;
			if (secToCopy < 0) return;

			var startThing:Float = getSectionStartTime(secToCopy);
			var sectionsTimeDiff:Float = getSectionStartTime(curSec) - startThing;

			if(check_notesSec.checked){
				var notesToCopy = _song.notes[secToCopy].sectionNotes;
				var sectionNotes = _song.notes[curSec].sectionNotes;
				for (i in 0...notesToCopy.length)
				{
					var copiedNote:NoteData = notesToCopy[i].clone();
					copiedNote.strumTime += sectionsTimeDiff;
					sectionNotes.push(copiedNote);
				}
			}

			if(check_eventsSec.checked){
				var endThing:Float = getSectionStartTime(secToCopy + 1);
				for (event in _song.events)
				{					
					var eventStrumTime:Float = fuckFloatingPoints(event.strumTime);
					if (startThing <= eventStrumTime && eventStrumTime < endThing)
					{
						var copiedEvent = event.clone();
						copiedEvent.strumTime = eventStrumTime + sectionsTimeDiff;
						_song.events.push(copiedEvent);
					}
				}
/* 				fixEvents(); */
			}
			updateGrid();
		});
		copyLastButton.setGraphicSize(80, 30);
		copyLastButton.updateHitbox();
		
		stepperCopy = new CustomFlxUINumericStepper(copyLastButton.x + 100, copyLastButton.y, 1, 1, -999, 999, 0);
		blockPressWhileTypingOnStepper.push(stepperCopy);

		var swapSection:FlxButton = new FlxButton(10, copyLastButton.y + 80, "Swap sides", function()
		{
			for (note in _song.notes[curSec].sectionNotes)
			{
				note.column = (note.column + _song.keyCount) % (_song.keyCount * 2);
			}

			updateGrid();
		});

		var duetButton:FlxButton = new FlxButton(swapSection.x + 100, swapSection.y, "Duet Notes", function()
		{
			var copiedNotes:Array<NoteData> = [for (note in _song.notes[curSec].sectionNotes) note.clone()];

			for (note in copiedNotes) {
				if (Math.floor(note.column / _song.keyCount) % 2 == 1)
					note.column -= _song.keyCount;
				else
					note.column += _song.keyCount;

				_song.notes[curSec].sectionNotes.push(note);
			}
			
			copiedNotes.resize(0);
			copiedNotes = null;

			updateGrid();
		});

		var mirrorButton:FlxButton = new FlxButton(duetButton.x + 100, duetButton.y, "Mirror Notes", function()
		{
			for (note in _song.notes[curSec].sectionNotes)
			{
				var boob:Int = note.column % _song.keyCount;
				boob = _song.keyCount - 1 - boob;
				if (note.column >= _song.keyCount) boob += _song.keyCount;

				note.column = boob;
			}

			updateGrid();
		});

		tab_group_section.add(new FlxText(stepperBeats.x, stepperBeats.y - 15, 0, 'Beats per Section:'));
		tab_group_section.add(stepperBeats);
		tab_group_section.add(stepperSectionBPM);
		tab_group_section.add(check_mustHitSection);
		tab_group_section.add(check_gfSection);
		tab_group_section.add(check_altAnim);
		tab_group_section.add(check_changeBPM);
		tab_group_section.add(copyButton);
		tab_group_section.add(pasteButton);
		tab_group_section.add(clearSectionButton);
		tab_group_section.add(check_notesSec);
		tab_group_section.add(check_eventsSec);
		tab_group_section.add(swapSection);
		tab_group_section.add(stepperCopy);
		tab_group_section.add(copyLastButton);
		tab_group_section.add(duetButton);
		tab_group_section.add(mirrorButton);

		UI_box.addGroup(tab_group_section);
	}

	var labelSusLength:FlxText;
	var labelStrumTime:FlxText;
	var stepperSusLength:CustomFlxUINumericStepper;
	var stepperStrumTime:CustomFlxUINumericStepper;
	var noteTypeDropDown:FlxUIDropDownMenu;
	var currentNoteType:String = '';

	function addNoteUI():Void
	{
		var tab_group_note = new FlxUI(null, UI_box);
		tab_group_note.name = 'Note';

		final DECIMALS:Int = 4;

		stepperSusLength = new CustomFlxUINumericStepper(10, 25, 1, 0, 0, Math.POSITIVE_INFINITY, DECIMALS, 1, new FlxUIInputText(0, 0, 120));
		stepperSusLength.name = 'note_susLength';
		blockPressWhileTypingOnStepper.push(stepperSusLength);

		stepperStrumTime = new CustomFlxUINumericStepper(10, 65, 1, 0, 0, Math.POSITIVE_INFINITY, DECIMALS, 1, new FlxUIInputText(0, 0, 120));
		stepperStrumTime.name = 'note_strumTime';
		blockPressWhileTypingOnStepper.push(stepperStrumTime);

		var key:Int = 0;
		var displayNameList:Array<String> = [];
		while (key < noteTypeList.length) {
			displayNameList.push(noteTypeList[key]);
			noteTypeMap.set(noteTypeList[key], key);
			noteTypeIntMap.set(key, noteTypeList[key]);
			key++;
		}

		#if (sys && (hscript))
		var directories:Array<String> = Paths.getFolders('notetypes');
		var allowedFormats = [
			#if hscript
			'.hscript',
			#end
		];
		for (directory in directories)
		{
			if (!FileSystem.exists(directory))
				continue;

			for (file in FileSystem.readDirectory(directory))
			{
				var path = haxe.io.Path.join([directory, file]);
				if (FileSystem.isDirectory(path))
					continue;

				var fileFormat:Null<String> = null;
				for (format in allowedFormats){ // check file format
					if (path.endsWith(format)){ // if its a supported format
						fileFormat = format;
						break;
					}
				}
				if (fileFormat == null) // if its not supported
					continue;

				var fileToCheck:String = file.substr(0, file.length - fileFormat.length); // get file name
				if (noteTypeMap.exists(fileToCheck)) // if it already is on the list
					continue;

				displayNameList.push(fileToCheck);
				noteTypeMap.set(fileToCheck, key);
				noteTypeIntMap.set(key, fileToCheck);
				key++;	
			}
		}
		#end

		for (i in 1...displayNameList.length) {
			displayNameList[i] = i + '. ' + displayNameList[i];
		}

		noteTypeDropDown = new CustomFlxUIDropDownMenu(10, 105, FlxUIDropDownMenu.makeStrIdLabelArray(displayNameList, true), function(character:String)
		{
			var typeIdx = Std.parseInt(character);
			currentNoteType = noteTypeIntMap.get(typeIdx);
			if (curSelectedNote != null) {
				curSelectedNote.noteType = currentNoteType;
				updateGrid();
			}
		});
		blockPressWhileScrolling.push(noteTypeDropDown);

		tab_group_note.add(labelSusLength = new FlxText(10, 10, 0, 'Sustain length:'));
		tab_group_note.add(stepperSusLength);
		tab_group_note.add(labelStrumTime = new FlxText(10, 50, 0, 'Strum time:'));
		tab_group_note.add(stepperStrumTime);
		tab_group_note.add(new FlxText(10, 90, 0, 'Note type:'));
		tab_group_note.add(noteTypeDropDown);

		UI_box.addGroup(tab_group_note);
	}

	var eventDropDown:FlxUIDropDownMenu;
	var eventNameInput:FlxUIInputText;
	var descText:FlxText;
	var selectedEventText:FlxText;

	function setSelectedEventType(typeName:String)
	{
		if (curSelectedEvent != null)
		{
			curSelectedEvent.subEventsData[subEventIdx][0] = typeName;

			updateGrid();
		}
	}

	function addEventsUI():Void
	{
		var tab_group_event = new FlxUI(null, UI_box);
		tab_group_event.name = 'Event';

		descText = new FlxText(20, 200, 0, eventStuff[0][0]);

		var leEvents:Array<String> = [];
		for (i in 0...eventStuff.length)
			leEvents.push(eventStuff[i][0]);

		var text:FlxText = new FlxText(20, 30, 0, "Event:");
		tab_group_event.add(text);

		eventDropDown = new CustomFlxUIDropDownMenu(
			20, 50, 
			FlxUIDropDownMenu.makeStrIdLabelArray(leEvents, true), 
			function(pressed:String) {
				var idx:Int = Std.parseInt(pressed);
				
				if (idx > 0){
					var data = eventStuff[idx];
					if (data != null){
						setSelectedEventType(data[0]);
						eventNameInput.text = data[0];
						descText.text = data[1];
					}
				}else{
					eventNameInput.text = "";
					eventNameInput.exists = true;
					eventNameInput.hasFocus = true;
				}
			}
		);
		//eventDropDown.getBtnByIndex(0).getLabel().text = "Custom";
		blockPressWhileScrolling.push(eventDropDown);

		eventNameInput = new FlxUIInputText(
			eventDropDown.x + 1, eventDropDown.y + 1, 
			100, 
			eventDropDown.selectedLabel,
			8
		);
		eventNameInput.resize(100, eventDropDown.header.background.height - 2);
		eventNameInput.exists = false;
		eventNameInput.callback = function(inputStr:String, actionName:String){
			if (actionName == "enter"){
				setSelectedEventType(inputStr);
				
				eventDropDown.header.text.text = inputStr;
				descText.text = "";

				eventNameInput.exists = false;
			}
		}
		eventNameInput.focusLost = () ->
		{
			eventNameInput.callback(eventNameInput.text, "enter");}
		blockPressWhileTypingOn.push(eventNameInput);

		value1InputText = new FlxUIInputText(20, 110, 100, "");
		value1InputText.name = 'event_value1';
		blockPressWhileTypingOn.push(value1InputText);

		value2InputText = new FlxUIInputText(20, 150, 100, "");
		value2InputText.name = 'event_value2';
		blockPressWhileTypingOn.push(value2InputText);

		// New event buttons
		var removeButton:FlxButton = new FlxButton(eventDropDown.x + eventDropDown.width + 10, eventDropDown.y, '-', function()
		{
			if(curSelectedEvent != null) //Is event note
			{
				if(curSelectedEvent.subEventsData.length < 2)
				{
					_song.events.remove(curSelectedEvent);
					curSelectedEvent = null;
				}
				else
				{
					curSelectedEvent.subEventsData.remove(curSelectedEvent.subEventsData[subEventIdx]);
				}

				var eventsGroup:Array<PsychSubEventData>;
				--subEventIdx;
				if (subEventIdx < 0) 
					subEventIdx = 0;
				else if(curSelectedEvent != null && subEventIdx >= (eventsGroup = curSelectedEvent.subEventsData).length) 
					subEventIdx = eventsGroup.length - 1;

				changeEventSelected();
				updateGrid();
			}
		});
		removeButton.setGraphicSize(Std.int(removeButton.height), Std.int(removeButton.height));
		removeButton.updateHitbox();
		removeButton.color = FlxColor.RED;
		removeButton.label.color = FlxColor.WHITE;
		removeButton.label.size = 12;
		setAllLabelsOffset(removeButton, -30, 0);
		tab_group_event.add(removeButton);

		var addButton:FlxButton = new FlxButton(removeButton.x + removeButton.width + 10, removeButton.y, '+', function()
		{
			if(curSelectedEvent != null) //Is event note
			{
				curSelectedEvent.subEventsData.push(['', '', '']);

				changeEventSelected(1);
				updateGrid();
			}
		});
		addButton.setGraphicSize(Std.int(removeButton.width), Std.int(removeButton.height));
		addButton.updateHitbox();
		addButton.color = FlxColor.GREEN;
		addButton.label.color = FlxColor.WHITE;
		addButton.label.size = 12;
		setAllLabelsOffset(addButton, -30, 0);
		tab_group_event.add(addButton);

		var moveLeftButton:FlxButton = new FlxButton(addButton.x + addButton.width + 20, addButton.y, '<', function()
		{
			if (curSelectedEvent == null) // Isn't event note
				return;

			if (FlxG.keys.pressed.SHIFT){
				var noteEvents = curSelectedEvent.subEventsData;
				var selectedEvent:Array<String> = noteEvents[subEventIdx];
				var switchIdx:Int = (subEventIdx < 1) ? noteEvents.length-1 : subEventIdx-1;

				noteEvents[subEventIdx] = noteEvents[switchIdx];
				noteEvents[switchIdx] = selectedEvent;

				updateGrid();				
			}
			
			changeEventSelected(-1);			
		});
		moveLeftButton.setGraphicSize(Std.int(addButton.width), Std.int(addButton.height));
		moveLeftButton.updateHitbox();
		moveLeftButton.label.size = 12;
		setAllLabelsOffset(moveLeftButton, -30, 0);
		tab_group_event.add(moveLeftButton);

		var moveRightButton:FlxButton = new FlxButton(moveLeftButton.x + moveLeftButton.width + 10, moveLeftButton.y, '>', function()
		{
			if (curSelectedEvent == null) // Isn't event note
				return;

			if (FlxG.keys.pressed.SHIFT)
			{
				var noteEvents = curSelectedEvent.subEventsData;
				var selectedEvent:Array<String> = noteEvents[subEventIdx];
				var switchIdx:Int = (subEventIdx == noteEvents.length-1) ? 0 : subEventIdx+1;

				noteEvents[subEventIdx] = noteEvents[switchIdx];
				noteEvents[switchIdx] = selectedEvent;

				updateGrid();
			}
			
			changeEventSelected(1);
		});
		moveRightButton.setGraphicSize(Std.int(moveLeftButton.width), Std.int(moveLeftButton.height));
		moveRightButton.updateHitbox();
		moveRightButton.label.size = 12;
		setAllLabelsOffset(moveRightButton, -30, 0);
		tab_group_event.add(moveRightButton);

		selectedEventText = new FlxText(addButton.x - 100, addButton.y + addButton.height + 6, (moveRightButton.x - addButton.x) + 186, 'Selected Event: None');
		selectedEventText.alignment = CENTER;
		tab_group_event.add(selectedEventText);

		tab_group_event.add(descText);
		tab_group_event.add(new FlxText(20, 90, 0, "Value 1:"));		
		tab_group_event.add(value1InputText);
		tab_group_event.add(new FlxText(20, 130, 0, "Value 2:"));
		tab_group_event.add(value2InputText);
		tab_group_event.add(eventDropDown);
		tab_group_event.add(eventNameInput);

		UI_box.addGroup(tab_group_event);
	}

	function changeEventSelected(value:Int = 0, isAbs:Bool = false)
	{
		if (curSelectedEvent != null) {
			subEventIdx = isAbs ? value : subEventIdx + value;
			if(subEventIdx < 0) subEventIdx = Std.int(curSelectedEvent.subEventsData.length) - 1;
			else if(subEventIdx >= curSelectedEvent.subEventsData.length) subEventIdx = 0;
		}else {
			subEventIdx = 0;
		}
		updateEventsUI();
	}

	function setAllLabelsOffset(button:FlxButton, x:Float, y:Float)
	{
		for (point in button.labelOffsets)
		{
			point.set(x, y);
		}
	}

	var metronomeStepper:CustomFlxUINumericStepper;
	var metronomeOffsetStepper:CustomFlxUINumericStepper;

	var waveformTrackDropDown:FlxUIDropDownMenu;
	var waveformTrack:Null<FlxSound> = null;
	var trackVolumeSlider:FlxUISlider;

	function selectTrack(trackName:String){
		waveformTrack = soundTracksMap.get(trackName); 

		if (waveformTrack != null){
			waveformTrackDropDown.selectedId = trackName;

			trackVolumeSlider.value = waveformTrack.volume;
			trackVolumeSlider.visible = true;
		/*}else{
			trackVolumeSlider.visible = false;*/
		}
		
		updateWaveform();
		_session.selectedTrack = trackName;
	}

	function changeSelectedTrackVolume(val:Float)
	{
		if (waveformTrack != null)
			waveformTrack.volume = val;
		/*else
			trace("Erm. No track is selected!");*/
		
		trackVolumeSlider.value = val;
	}

	function getSongPath(file:String = "") {
		var path = Reflect.field(_song, "_path");
		path = path==null ? file : Path.addTrailingSlash(Path.directory(path)) + file;
		trace(path);
		return path;
	}

	function addMetadataUI() {
		var tab_group = new FlxUI(null, UI_box);
		tab_group.name = 'Metadata';

		var songNameInputText = new FlxUIInputText(10, 30, 180, _song.metadata.songName);
		songNameInputText.name = "metadata_songName";
		blockPressWhileTypingOn.push(songNameInputText);

		var artistInputText = new FlxUIInputText(10, songNameInputText.y + 30, 180, _song.metadata.artist);
		artistInputText.name = "metadata_artist";
		blockPressWhileTypingOn.push(artistInputText);

		var charterInputText = new FlxUIInputText(10, artistInputText.y + 30, 180, _song.metadata.charter);
		charterInputText.name = "metadata_charter";
		blockPressWhileTypingOn.push(charterInputText);

		var modcharterInputText = new FlxUIInputText(10, charterInputText.y + 30, 180, _song.metadata.modcharter);
		modcharterInputText.name = "metadata_modcharter";
		blockPressWhileTypingOn.push(modcharterInputText);

		var extraInfoInputText = new FlxUIInputText(10, modcharterInputText.y + 30, 180, (_song.metadata.extraInfo?.join(',') ?? ""));
		extraInfoInputText.name = "metadata_extraInfo";
		blockPressWhileTypingOn.push(extraInfoInputText);

		////
		// TODO: freeplay data shit idunno

		////
		final fileDialog = new FileDialog();
		fileDialog.onOpen.add(function(resource) {
			var str:String = (resource:Bytes).toString();
			if (str != null && str.length > 0) {
				var data:Dynamic = Json.parse(str);
				_song.metadata = data; // kinda dangerous
				onLoadMetadata();

				songNameInputText.text = data.songName;
				artistInputText.text = data.artist;
				charterInputText.text = data.charter;
				modcharterInputText.text = data.modcharter;	
				extraInfoInputText.text = (data.extraInfo?.join(',') ?? "");
			}
		});

		var loadButton = new FlxButton(10, extraInfoInputText.y + 30, "Load Metadata", function() {			
			fileDialog.open('json', getSongPath("metadata.json"), 'Load Metadata');
		});

		////
		var saveButton = new FlxButton(10, loadButton.y + 30, "Save Metadata", function()
		{
			_song.metadata.songName = songNameInputText.text;
			_song.metadata.artist = artistInputText.text;
			_song.metadata.charter = charterInputText.text;
			_song.metadata.modcharter = modcharterInputText.text;
			_song.metadata.extraInfo = extraInfoInputText.text.split(',');

			var data:String = Json.stringify(_song.metadata, "\t");
			fileDialog.save(data, 'json', getSongPath("metadata.json"), 'Save Metadata');
		});

		////
		tab_group.add(new FlxText(songNameInputText.x, songNameInputText.y - 15, 0, 'Song Name:'));
		tab_group.add(new FlxText(artistInputText.x, artistInputText.y - 15, 0, 'Artist:'));
		tab_group.add(new FlxText(charterInputText.x, charterInputText.y - 15, 0, 'Charter:'));
		tab_group.add(new FlxText(modcharterInputText.x, modcharterInputText.y - 15, 0, 'Modcharter:'));
		tab_group.add(new FlxText(extraInfoInputText.x, extraInfoInputText.y - 15, 0, 'Extra Info:'));
		
		tab_group.add(songNameInputText);
		tab_group.add(artistInputText);
		tab_group.add(charterInputText);
		tab_group.add(modcharterInputText);
		tab_group.add(extraInfoInputText);

		tab_group.add(loadButton);
		tab_group.add(saveButton);

		tab_group.add(new FlxText(10, saveButton.y + 30, UI_box.width - 20, 'NOTE: Metadata is saved and loaded as a separate file, it will not be included in the saved chart file!'));

		UI_box.addGroup(tab_group);
	}

	function addChartingUI() {
		var tab_group_chart = new FlxUI(null, UI_box);
		tab_group_chart.name = 'Editor';

		////////
		var trackNamesArray = ["None"];
		for (trackName in soundTracksMap.keys())
			trackNamesArray.push(trackName);

		//
		waveformTrackDropDown = new CustomFlxUIDropDownMenu(
			10, 100, 
			FlxUIDropDownMenu.makeStrIdLabelArray(trackNamesArray, false), 
			selectTrack
		);
		blockPressWhileScrolling.push(waveformTrackDropDown);

		//
		trackVolumeSlider = new CustomFlxUISlider(
			this, 
			'_curTrackVolume', 
			waveformTrackDropDown.x + 150 - 10, 
			waveformTrackDropDown.y - 15, 
			0.0, 
			1.0, 
			Math.floor(waveformTrackDropDown.width), 
			null, 
			5, 
			FlxColor.WHITE, 
			FlxColor.BLACK
		);
		trackVolumeSlider.nameLabel.text = 'Track Volume';
		trackVolumeSlider.setVariable = false;
		trackVolumeSlider.callback = changeSelectedTrackVolume;
		blockScrollWhileHovering.push(trackVolumeSlider);

		////////

		var startY = 165;

		var check_warnings = new FlxUICheckBox(10, startY, null, null, "Ignore Progress Warnings", 100);
		check_warnings.callback = function()
		{
			options.ignoreWarnings = check_warnings.checked;
		};
		check_warnings.checked = options.ignoreWarnings;


		var check_vortex = new FlxUICheckBox(10, startY + 30, null, null, "Vortex Editor", 100);
		check_vortex.callback = function()
		{
			options.vortex = check_vortex.checked;
		};
		check_vortex.checked = options.vortex == true;


		var mouseScrollingQuant = new FlxUICheckBox(10, startY + 60, null, null, "Mouse Scrolling Quantization", 100);
		mouseScrollingQuant.callback = function()
		{
			options.mouseScrollingQuant = mouseScrollingQuant.checked;
		};
		mouseScrollingQuant.checked = options.mouseScrollingQuant == true;

		////////
		var xPos = 10 + 150;

		var playSoundBf = new FlxUICheckBox(xPos, startY, null, null, 'Play Hit Sound (Boyfriend notes)', 100);
		playSoundBf.callback = () -> options.playSoundBf = playSoundBf.checked;
		playSoundBf.checked = options.playSoundBf == true;


		var playSoundDad = new FlxUICheckBox(xPos, startY + 30, null, null, 'Play Hit Sound (Opponent notes)', 100);
		playSoundDad.callback = () -> options.playSoundDad = playSoundDad.checked;
		playSoundDad.checked = options.playSoundDad == true;

		
		var playSoundEvents = new FlxUICheckBox(xPos, startY + 60, null, null, 'Play Hit Sound (Event notes)', 100);
		playSoundEvents.callback = () -> options.playSoundEvents = playSoundEvents.checked;
		playSoundEvents.checked = options.playSoundEvents == true;

		var panHitSounds = new FlxUICheckBox(xPos, startY + 90, null, null, 'Pan Hit Sounds', 100);
		panHitSounds.callback = () -> options.panHitSounds = panHitSounds.checked;
		panHitSounds.checked = options.panHitSounds == true;

		////////
		var metronome = new FlxUICheckBox(10, 15, null, null, "Metronome Enabled", 100);
		metronome.callback = () -> {options.metronome = metronome.checked;}
		metronome.checked = options.metronome == true;

		metronomeStepper = new CustomFlxUINumericStepper(15, 55, 5, _song.bpm, 1, 9000, 3);
		metronomeOffsetStepper = new CustomFlxUINumericStepper(metronomeStepper.x + 146, metronomeStepper.y, 25, 0, 0, 1000, 1);
		blockPressWhileTypingOnStepper.push(metronomeStepper);
		blockPressWhileTypingOnStepper.push(metronomeOffsetStepper);

		var disableAutoScrolling = new FlxUICheckBox(metronome.x + 150, metronome.y, null, null, "Disable Section Autoscroll", 120);
		disableAutoScrolling.callback = () -> {options.noAutoScroll = disableAutoScrolling.checked;}
		disableAutoScrolling.checked = options.noAutoScroll == true;

		var sliderHitVol = new CustomFlxUISlider(this, 'hitsoundVolume', 10, startY + 90, 0, 1, 125, null, 5, FlxColor.WHITE, FlxColor.BLACK);
		sliderHitVol.nameLabel.text = 'Hitsound Volume';
		sliderHitVol.value = hitsoundVolume;
		blockScrollWhileHovering.push(sliderHitVol);

		var sliderRate = new CustomFlxUISlider(this, 'playbackSpeed', 68, 325, 0.5, 3, 150, null, 5, FlxColor.WHITE, FlxColor.BLACK);
		sliderRate.nameLabel.text = 'Playback Rate';
		sliderRate.value = playbackSpeed;
		blockScrollWhileHovering.push(sliderRate);

		tab_group_chart.add(sliderHitVol);
		tab_group_chart.add(sliderRate);

		tab_group_chart.add(mouseScrollingQuant);
		tab_group_chart.add(check_vortex);
		tab_group_chart.add(check_warnings);

		tab_group_chart.add(playSoundEvents);
		tab_group_chart.add(playSoundDad);
		tab_group_chart.add(playSoundBf);

		tab_group_chart.add(panHitSounds);

		tab_group_chart.add(metronomeStepper);
		tab_group_chart.add(metronomeOffsetStepper);
		tab_group_chart.add(metronome);
		tab_group_chart.add(disableAutoScrolling);

		tab_group_chart.add(new FlxText(metronomeStepper.x, metronomeStepper.y - 15, 0, 'Metronome BPM:'));
		tab_group_chart.add(new FlxText(metronomeOffsetStepper.x, metronomeOffsetStepper.y - 15, 0, 'Metronome Offset (ms):'));

		tab_group_chart.add(new FlxText(waveformTrackDropDown.x, waveformTrackDropDown.y - 15, 0, "Track"));
		tab_group_chart.add(waveformTrackDropDown);
		tab_group_chart.add(trackVolumeSlider);

		UI_box.addGroup(tab_group_chart);
	}

	function addTracksUI() {
		var tab_group_tracks = new FlxUI(null, UI_box);
		tab_group_tracks.name = 'Tracks';

		var instInput = new FlxUIInputText(10, 30, 200, _song.tracks.inst.join(','));
		instInput.name = "tracks_inst";

		var playInput = new FlxUIInputText(10, 60, 200, _song.tracks.player.join(','));
		playInput.name = "tracks_player";
		
		var oppInput = new FlxUIInputText(10, 90, 200, _song.tracks.opponent.join(','));
		oppInput.name = "tracks_opponent";

		var reloadButton = new FlxButton(10, 120, "Reload Audio", function() {
			loadTracks();

			var trackNamesArray = ["None"];
			for (trackName in soundTracksMap.keys())
				trackNamesArray.push(trackName);

			waveformTrackDropDown.setData(FlxUIDropDownMenu.makeStrIdLabelArray(trackNamesArray, false));
			
			selectTrack(_session.selectedTrack);
		});

		tab_group_tracks.add(new FlxText(10, instInput.y - 15, 0, 'Instrumental Tracks'));
		tab_group_tracks.add(instInput);
		tab_group_tracks.add(new FlxText(10, playInput.y - 15, 0, 'Player Tracks'));
		tab_group_tracks.add(playInput);
		tab_group_tracks.add(new FlxText(10, oppInput.y - 15, 0, 'Opponent Tracks'));
		tab_group_tracks.add(oppInput);
		tab_group_tracks.add(reloadButton);
		tab_group_tracks.add(new FlxText(10, reloadButton.y + 45, 0, 'Separate multiple tracks with a comma\nEx: "Voices1,Voices2"'));
		
		UI_box.addGroup(tab_group_tracks);
	}

	var tracksCompleted:Bool = false;

	function loadTracks():Void
	{
		Conductor.songPosition = sectionStartTime();

		var songTrackNames:Array<String> = [];
		var jsonTracks = _song.tracks;

		soundTracksMap.clear();
		tracks.resize(0);

		for (groupName in Reflect.fields(jsonTracks)) {
			var trackGroup:Array<String> = Reflect.field(jsonTracks, groupName);
			for (trackName in trackGroup) {
				if (soundTracksMap.exists(trackName))
					continue;

				soundTracksMap.set(trackName, null);
				songTrackNames.push(trackName);
			}
		}

		songLength = 0.0;

		inline function createMusicTrack() {
			var newTrack = new FlxSound();
			newTrack.context = MUSIC;
			newTrack.exists = true;
			FlxG.sound.list.add(newTrack);
			return newTrack;
		}

		for (trackName in songTrackNames) {
			var file:Sound = {
				if (PlayState.song != null)
					PlayState.song.getTrackSound(trackName);
				else
					Paths.track(songId, trackName);
			}

			if (file == null || file.length <= 0) 
				continue;

			var newTrack = createMusicTrack();
			newTrack.loadEmbedded(file);
			newTrack.time = Conductor.songPosition;
			
			songLength = Math.max(songLength, newTrack.length);

			soundTracksMap.set(trackName, newTrack);
			tracks.push(newTrack);
		}
		
		inst = soundTracksMap.get(jsonTracks.inst[0]);
		if (inst == null)
			inst = createMusicTrack();
		inst.volume = 0.6;
	}

	override function getEvent(id:String, sender:Dynamic, data:Dynamic, ?params:Array<Dynamic>)
	{
		var name:Null<String> = sender.name;

		if (id == FlxUICheckBox.CLICK_EVENT)
		{
			var check:FlxUICheckBox = cast sender;
			switch (name)
			{
				case 'check_mustHit':
					new ChangeMustHitSectionAction(curSec, !FlxG.keys.pressed.CONTROL);

					updateGrid();
					updateHeads();
				case 'check_gf':
					_song.notes[curSec].gfSection = check.checked;

					updateGrid();
					updateHeads();
				case 'check_changeBPM':
					_song.notes[curSec].changeBPM = check.checked;
					
					Conductor.mapBPMChanges(_song);
					updateGrid();
					updateNoteSteps();

				case "check_altAnim":
					_song.notes[curSec].altAnim = check.checked;
			}
		}
		else if (id == FlxUINumericStepper.CHANGE_EVENT)
		{
			var nums:FlxUINumericStepper = cast sender;
			switch(name) {
				case 'section_beats':
					_song.notes[curSec].sectionBeats = nums.value;
					reloadGridLayer();
					updateNoteSteps();
				
				case 'song_keyCount':
					_song.keyCount = Math.ceil(Math.max(1, nums.value));
					reloadGridLayer();
					adjustCamPos();
				
				case 'song_speed':
					_song.speed = nums.value;
				
				case 'song_bpm':
					_song.bpm = nums.value;
					Conductor.mapBPMChanges(_song);
					updateGrid();
					updateNoteSteps();

				case 'note_strumTime':
					if (curSelectedNote != null) {
						curSelectedNote.strumTime = nums.value;
						updateGrid();
						updateNoteSteps();
					} else {
						sender.value = 0;
					}
				
				case 'note_susLength':
					if(curSelectedNote != null) {
						new ChangeSustainAction(curSelectedNote, nums.value, true);
					} else {
						sender.value = 0;
					}

				case 'section_bpm':
					_song.notes[curSec].bpm = nums.value;
					Conductor.mapBPMChanges(_song);
					updateGrid();
					updateNoteSteps();
			}
		}
		else if(id == FlxUIInputText.CHANGE_EVENT) {
			var sender:FlxUIInputText = cast sender;
			switch (name) {
				case 'song_title':
					_song.song = sender.text;

				case 'song_noteSplashes':
					_song.splashSkin = sender.text;

				case 'event_value1':
					if (curSelectedEvent != null) {
						curSelectedEvent.subEventsData[subEventIdx][1] = sender.text;
						updateGrid();
					}

				case 'event_value2':
					if (curSelectedEvent != null) {
						curSelectedEvent.subEventsData[subEventIdx][2] = sender.text;
						updateGrid();
					}

				case 'metadata_songName':
					_song.metadata.songName = sender.text;
					updateDiscordRPC();
				case 'metadata_artist':
					_song.metadata.artist = sender.text;
				case 'metadata_charter':
					_song.metadata.charter = sender.text;
				case 'metadata_modcharter':
					_song.metadata.modcharter = sender.text;
				case 'metadata_extraInfo':
					_song.metadata.extraInfo = sender.text.split(',');
				
				case 'tracks_inst':
					_song.tracks.inst = sender.text.split(',');
				case 'tracks_player':
					_song.tracks.player = sender.text.split(',');
				case 'tracks_opponent':
					_song.tracks.opponent = sender.text.split(',');
			}	
		}
		else if (id == FlxUISlider.CHANGE_EVENT)
		{
			var sender:CustomFlxUISlider = cast sender;

			
		}

		// FlxG.log.add(id + " WEED " + sender + " WEED " + data + " WEED " + params);
	}

	var updatedSection:Bool = false;

	function getSectionStartTime(sec:Int):Float
	{
		var daBPM:Float = _song.bpm;
		var daPos:Float = 0;

		for (i in 0...sec)
		{
			if(_song.notes[i] == null)
				continue;
			
			if (_song.notes[i].changeBPM)
				daBPM = _song.notes[i].bpm;
			
			daPos += getSectionBeats(i) * (1000 * 60 / daBPM);
		}
		return daPos;
	}

	inline function sectionStartTime(add:Int = 0):Float
		return getSectionStartTime(curSec + add);

	function updateQuantization(){
		quantization = quantizations[curQuant];
		quantizationMult = (quantization / 16);
		
		quantTxt.text = "Beat Snap: " + quantNames[curQuant];
		quant.animation.play('q', true, false, curQuant);
	}

	var lastConductorPos:Float = -1;
	var colorSine:Float = 0;
	//// sustain note dragging 
	var startDummyY:Null<Float> = null;
	var curDummyY:Null<Float> = null;

	// pause tracks and set them to the conductor song position
	inline function pauseTracks()
		Conductor.pauseSong();

	// set tracks to the conductor song position and play them
	inline function resumeTracks()
		Conductor.resumeSong();

	override function updateSongPosition(?_:FlxSound) {
		@:privateAccess
		var elapsedMS:Float = FlxG.game._elapsedMS * inst.pitch;

		if (inst.playing && lastMixPos != inst.time) {
			lastMixPos = inst.time;
			lastMixTimer = 0;
		}else {
			lastMixTimer += elapsedMS;
		}
				
		Conductor.songPosition = lastMixPos + lastMixTimer;
	}

	var inputBlocked = false;
	function checkIsTyping():Bool {
		for (inputText in blockPressWhileTypingOn) {
			if (inputText.hasFocus)
				return true;
		}

		for (stepper in blockPressWhileTypingOnStepper) {
			@:privateAccess
			var leText:Dynamic = stepper.text_field;
			var leText:FlxUIInputText = leText;
			if (leText.hasFocus)
				return true;
		}

		for (dropDownMenu in blockPressWhileScrolling) {
			if (dropDownMenu.dropPanel.visible)
				return true;
		}

		return false;
	}

	function checkCanMouseScroll():Bool {
		for (dropDownMenu in blockPressWhileScrolling) {
			if (dropDownMenu.header.button.status == FlxButton.HIGHLIGHT)
				return false;
		}

		for (slider in blockScrollWhileHovering) {
			@:privateAccess
			if (slider._justHovered)
				return false;
		}

		for (stepper in blockPressWhileTypingOnStepper) {
			if (stepper.hoveringText)
				return false;
		}

		return true;
	}

	override function update(elapsed:Float)
	{
		colorSine += elapsed;
		var sineColor:Float = 0.7 + 0.3 * FlxMath.fastSin(Math.PI * colorSine);
		var sineColor:Int = Math.round(sineColor * 255);
		var sineColor = FlxColor.fromRGB(sineColor, sineColor, sineColor, 255);

		FlxG.mouse.visible = true; //cause reasons. trust me

		var movedDummyY:Bool = false;
		var onIcons:Bool = FlxG.mouse.overlaps(iconBG);
		var onGrid:Bool = !onIcons && !FlxG.mouse.overlaps(progressBG)
						&&	FlxG.mouse.x >= gridBG.x
						&&	FlxG.mouse.x <	gridBG.x + gridBG.width
						&&	FlxG.mouse.y >= gridBG.y
						&&	FlxG.mouse.y <	gridBG.y + gridBG.height;

		if (onIcons && FlxG.mouse.justPressed) {
			if (FlxG.mouse.overlaps(rightIcon)) {
				new ChangeMustHitSectionAction(curSec, true);
			}
		}

		if (onGrid){
			dummyArrow.visible = true;
			dummyArrow.x = Math.floor(FlxG.mouse.x / GRID_SIZE) * GRID_SIZE;

			var gridMult = GRID_SIZE / quantizationMult;
			var rawGridY = FlxG.mouse.y / gridMult;
			var gridY = Math.floor(rawGridY);

			dummyArrow.y = (FlxG.keys.pressed.SHIFT) ? FlxG.mouse.y : (gridY * gridMult);

			if (FlxG.mouse.pressed){
				movedDummyY = (curDummyY != (curDummyY = (FlxG.keys.pressed.SHIFT) ? rawGridY : gridY/quantizationMult)); // wtf

				if (startDummyY == null) startDummyY = curDummyY;
			}

		}else{
			dummyArrow.visible = false;

			curDummyY = null;
		}

		if (FlxG.mouse.justPressed)
		{
			var clickedNote = false;
			for (note in curRenderedNotes)
			{
				if (FlxG.mouse.overlaps(note))
				{
					clickedNote = true;
					if (FlxG.keys.pressed.CONTROL) 
					{
						selectNote(note);
					}
					else if (FlxG.keys.pressed.ALT)
					{
						if (note.column > -1) {
							curSelectedNote = note.chartData;
							curSelectedNote.noteType = currentNoteType;
							updateNoteUI();
							updateGrid();
						}
					}
					else
					{
						deleteNote(note);
					}
					break;
				}
			}
			if (!clickedNote && onGrid) {
				var noteTime:Float = sectionStartTime() + getStrumTime(dummyArrow.y * (getSectionBeats(curSec) / 4), false);
				var column:Int = Math.floor(FlxG.mouse.x / GRID_SIZE) - 1;
				(column < 0) ? addEvent(noteTime) : addNote(noteTime, column, null, true);
			}
		}else if(FlxG.mouse.pressed){

			if (movedDummyY)
			{
				var doUpdate:Bool = false;

				for (note in heldNotesClick){
					if (note == null) continue;
				
					// how much time does a grid block occupy
					var gridTime:Float = Conductor.stepCrochet / zoomList[curZoom];
					// time at which the mouse is standing on the grid
					var clickTime:Float = sectionStartTime() + curDummyY * gridTime;
					
					var len:Float = Math.max(0, clickTime - note.strumTime);
					note.sustainLength = FlxG.keys.pressed.SHIFT ? len : CoolUtil.snap(len, gridTime);
					doUpdate = true;
				}

				if (doUpdate) {
					updateNoteUI();
					updateGrid();
				}
			}

		}else {
			heldNotesClick.resize(0);
			startDummyY = null;
			curDummyY = null;
		}

		if (checkIsTyping() != inputBlocked) {
			inputBlocked = !inputBlocked;
			FNFGame.specialKeysEnabled = !inputBlocked;
		}

		if (!inputBlocked) {
			updateKeys(elapsed);
		}else if (FlxG.keys.justPressed.ENTER) {
			for (typebox in blockPressWhileTypingOn) {
				if (typebox.hasFocus)
					typebox.hasFocus = false;
			}
		}

		if (checkCanMouseScroll() && FlxG.mouse.wheel != 0) {
			if (!options.mouseScrollingQuant)
				Conductor.songPosition -= (FlxG.mouse.wheel * Conductor.stepCrochet);
			else{
				var snap = Conductor.stepCrochet / quantizationMult;
				Conductor.songPosition = CoolUtil.snap(Conductor.songPosition, snap) - (snap * FlxG.mouse.wheel);
			}

			pauseTracks();
		}

		////
		if (Conductor.playing)
			updateSongPosition();

		if (!options.noAutoScroll) {
			if (Conductor.songPosition > songLength) {
				//trace('Went past song duration: (${Conductor.songPosition} / $songLength), going back to first section');
				changeSection(0, true);
			}
			else if (Conductor.songPosition < 0) {
				Conductor.songPosition += songLength;
				changeSection(_song.notes.length - 1);
			}
			else if (Conductor.songPosition >= currentSectionEnd) {
				while (Conductor.songPosition >= currentSectionEnd) {
					var nextSection:Int = curSec + 1;
					if (_song.notes[nextSection] == null)
						pushSection();
					curSec = nextSection;
					currentSectionEnd = sectionStartTime(1);
				}
				reloadGridLayer();
				updateSectionUI();
				stepperStrumTime.stepSize = Conductor.stepCrochet;
				stepperSusLength.stepSize = Conductor.stepCrochet;
			}
			else if (Conductor.songPosition < currentSectionStart) {
				while (Conductor.songPosition < currentSectionStart) {
					curSec = curSec - 1;
					currentSectionStart = sectionStartTime();
				}
				reloadGridLayer();
				updateSectionUI();
				stepperStrumTime.stepSize = Conductor.stepCrochet;
				stepperSusLength.stepSize = Conductor.stepCrochet;
			}
		}

		Conductor.updateSteps();
		strumLineUpdateY();

		if (strumLineNotes.visible = quant.visible = options.vortex) {
			var alpha = Conductor.playing ? 1 : 0.35;
			for (receptor in strumLineNotes){
				receptor.y = strumLine.y;
				receptor.alpha = alpha;
			}
		}

		bpmTxt.text =
		"Time: " + FlxMath.roundDecimal(Conductor.songPosition / 1000, 2) + " / " + FlxMath.roundDecimal(songLength / 1000, 2) +
		"\n\nSection: " + curSec +
		"\nBeat: " + math.CoolMath.floorDecimal(curDecBeat, 2) +
		"\nStep: " + curStep;

		progressBar.minLabel.text = formatTime(Conductor.songPosition);

		playedSound.resize(0);
		curRenderedNotes.forEachAlive(function(note:Note) {
			if (note.chartData == curSelectedNote || note.chartData == curSelectedEvent)
				note.color = sineColor;
			else
				note.color = 0xFFFFFFFF;
			
			if (note.strumTime <= Conductor.songPosition) {
				if (inst.playing && !note.wasGoodHit) {
					if (note.column > -1)
					{
						// This is a note.

						if (!note.ignoreNote)
						{					
							var strum:StrumNote = strumLineNotes.members[note.realColumn];
							if (strum != null) {
								strum.playAnim('confirm', true, note);
								strum.resetAnim = (note.sustainLength / 1000) + 0.15;
							}

							if (!note.hitsoundDisabled && (note.mustPress ? options.playSoundBf : options.playSoundDad) && playedSound[note.realColumn] != true) {
								(options.panHitSounds ? (note.mustPress ? plrHitsound : oppHitsound) : hitsound).play(true);
								playedSound[note.realColumn] = true;
							}
							
						}
					}else{
						// This is an event.

						if (options.playSoundEvents)
							hitsound.play(true);
					}
				}

				note.wasGoodHit = true;
				note.alpha = 0.4;
			}else {
				note.wasGoodHit = false;
				note.alpha = 1;
			}
		});

		if (options.metronome && lastConductorPos != Conductor.songPosition) {
			var metroInterval:Float = 60 / metronomeStepper.value;
			var metroStep:Int = Math.floor(((Conductor.songPosition + metronomeOffsetStepper.value) / metroInterval) / 1000);
			var lastMetroStep:Int = Math.floor(((lastConductorPos + metronomeOffsetStepper.value) / metroInterval) / 1000);
			if (metroStep != lastMetroStep) {
				FlxG.sound.play(Paths.sound('Metronome_Tick'));
				lastConductorPos = Conductor.songPosition;
			}
		}

		super.update(elapsed);
	}

	function updateKeys(elapsed:Float) {
		if (FlxG.keys.justPressed.M) {
			new ChangeMustHitSectionAction(curSec, !FlxG.keys.pressed.CONTROL);
		}	

		if (curSelectedNote != null) {
			if (FlxG.keys.justPressed.E)
				new ChangeSustainAction(curSelectedNote, Conductor.stepCrochet, false);
			if (FlxG.keys.justPressed.Q)
				new ChangeSustainAction(curSelectedNote, -Conductor.stepCrochet, false);
		}

		if (FlxG.keys.pressed.CONTROL) {
			if (FlxG.keys.justPressed.Z) {
				undo();
			}
			if (FlxG.keys.justPressed.Y) {
				redo();
			}
			if (FlxG.keys.justPressed.S) {
				saveLevel();
			}
		}

		if(FlxG.keys.justPressed.Z && curZoom > 0 && !FlxG.keys.pressed.CONTROL) {
			--curZoom;
			updateZoom();
		}
		if(FlxG.keys.justPressed.X && curZoom < zoomList.length-1) {
			curZoom++;
			updateZoom();
		}

		if (FlxG.keys.justPressed.TAB) {
			if (FlxG.keys.pressed.SHIFT) {
				if (--UI_box.selected_tab < 0)
					UI_box.selected_tab = UI_box.get_numTabs() - 1;
			} else {					
				if (++UI_box.selected_tab < 0)
					UI_box.selected_tab = 0;
			}
		}

		if (FlxG.keys.justPressed.SPACE)
			(Conductor.playing) ? pauseTracks() : resumeTracks();

		if (FlxG.keys.justPressed.R)
			changeSection(FlxG.keys.pressed.SHIFT ? 0 : curSec, true);

		if (FlxG.keys.pressed.W || FlxG.keys.pressed.S)
		{
			var mult:Float = 1;
			if (FlxG.keys.pressed.CONTROL) mult = 0.25;
			else if (FlxG.keys.pressed.SHIFT) mult = 4;

			var daTime:Float = 720 * elapsed * mult;

			if (FlxG.keys.pressed.S)
				Conductor.songPosition += daTime;
			else
				Conductor.songPosition -= daTime;

			pauseTracks();
		}

		//AWW YOU MADE IT SEXY <3333 THX SHADMAR

		if(FlxG.keys.justPressed.RIGHT){
			if (++curQuant > quantizations.length-1)
				curQuant = 0;

			updateQuantization();
		}else if(FlxG.keys.justPressed.LEFT){
			if (--curQuant < 0)
				curQuant = quantizations.length-1;

			updateQuantization();
		}
		
		if (FlxG.keys.pressed.CONTROL && FlxG.keys.justPressed.Q) {
			useQuantNotes = !useQuantNotes;
			updateGrid();
		}

		//ARROW VORTEX SHIT NO DEADASS
		if(options.vortex){
			var controlArray:Array<Bool> = [
				FlxG.keys.justPressed.ONE, FlxG.keys.justPressed.TWO, FlxG.keys.justPressed.THREE, FlxG.keys.justPressed.FOUR,
				FlxG.keys.justPressed.FIVE, FlxG.keys.justPressed.SIX, FlxG.keys.justPressed.SEVEN, FlxG.keys.justPressed.EIGHT
			];
			var holdArray:Array<Bool> = [
				FlxG.keys.pressed.ONE, FlxG.keys.pressed.TWO, FlxG.keys.pressed.THREE, FlxG.keys.pressed.FOUR,
				FlxG.keys.pressed.FIVE, FlxG.keys.pressed.SIX, FlxG.keys.pressed.SEVEN, FlxG.keys.pressed.EIGHT
			];

			if (heldNotesVortex.length > 0)
			{
				var doUpdate:Bool = false;

				for(i in 0...holdArray.length){
					if (holdArray[i]){
						var note = heldNotesVortex[i];
						if (note != null){
							note.sustainLength = CoolUtil.snap(Conductor.songPosition - note.strumTime, Conductor.stepCrochet);
							doUpdate = true;
						}
					}else {
						heldNotesVortex[i] = null;
					}
				}

				if (doUpdate) {
					updateNoteUI();
					updateGrid();
				}
			}

			for (i in 0...controlArray.length)
			{
				if (controlArray[i]) {
					var delnote = false;

					if (strumLineNotes.members[i].overlaps(curRenderedNotes)) {
						var c:Int =i%_song.keyCount;
						var p = FlxPoint.get(strumLineNotes.members[i].x + 1, strumLine.y + 1);
						for (note in curRenderedNotes) {
							if (note != null && note.exists && note.alive) {
								if (note.column == c && note.overlapsPoint(p)) {
									//trace('tryin to delete note...');
									deleteNote(note);
									delnote = true;
									break;
								}
							}
						}
						p.put();
					}

					if (!delnote)
						addNote(Conductor.songPosition, i, currentNoteType, false);
				}
			}
		}	

		if (FlxG.keys.justPressed.UP || FlxG.keys.justPressed.DOWN) {
			pauseTracks();

			var snap:Float = Conductor.stepCrochet / quantizationMult;
			var feces:Float = CoolUtil.snap(Conductor.songPosition, snap) + (FlxG.keys.justPressed.UP ? -snap : snap);

			FlxTween.tween(Conductor, {songPosition: feces}, 0.1, {ease: FlxEase.circOut});
		}
		
		var shiftThing:Int = 1;
		if (FlxG.keys.pressed.SHIFT)
			shiftThing = 4;

		for (i in curSec ... curSec + shiftThing + 1) {
			if (_song.notes[i] == null) {
				if (getSectionStartTime(i) < inst.length)
					insertSection(i);
			}
		}

		if (FlxG.keys.justPressed.A) {
			var nextSection:Int = curSec - shiftThing;
			if (nextSection < 0) nextSection += _song.notes.length;
			changeSection(nextSection);
		}
		if (FlxG.keys.justPressed.D) {
			var nextSection:Int = (curSec + shiftThing) % _song.notes.length;
			changeSection(nextSection);
		}

		if (FlxG.keys.justPressed.F1) {
			helpTextGrp.exists = !helpTextGrp.exists;
			options.hideHelp = !helpTextGrp.exists;
		}

		if (FlxG.keys.justPressed.ENTER) {
			autosaveSong();
			_song.events.sort(sortEventsByTime);
			PlayState.SONG = _song;
			PlayState.chartingMode = true;

			if (FlxG.keys.pressed.SHIFT)
				PlayState.startOnTime = Conductor.songPosition;

			FlxG.sound.pause();

			LoadingState.loadAndSwitchState(new PlayState());
		}
		else if (FlxG.keys.justPressed.ESCAPE) {
			openSubState(new Prompt('Go back to the menus?\n\nUnsaved progress will be lost', 0, function() {
				PlayState.chartingMode = false;
				MusicBeatState.switchState(new funkin.states.editors.MasterEditorMenu());
				MusicBeatState.playMenuMusic(true);
	
				FlxG.mouse.visible = false;
			}, null, options.ignoreWarnings));
		}
	}

	function updateZoom() {
		var daZoom:Float = zoomList[curZoom];
		var zoomThing:String = '1 / ' + daZoom;
		if(daZoom < 1) zoomThing = Math.round(1 / daZoom) + ' / 1';
		zoomTxt.text = 'Zoom: ' + zoomThing;
		reloadGridLayer();
	} 

	var currentSectionBeats:Float = 0;

	var currentSectionStart:Float = 0;
	var currentSectionEnd:Float = 0;

	/** Creates the currently visible sections grid background and their objects (notes, events, waveform) **/
	function reloadGridLayer() 
	{
		beatSeparators.killMembers();
		fieldSeparators.killMembers();
		gridLayer.remove(beatSeparators);
		gridLayer.remove(fieldSeparators);
		wipeGroup(gridLayer);
		
		////
		final gridColor1:FlxColor = 0xffe7e6e6;
		final gridColor2:FlxColor = 0xffd9d5d5;

		var gridWidth:Int = 1 + _song.keyCount * 2;
		var totalHeight:Float = 0.0;
		var gridY:Float = 1; // i say right foot creep oo
		
		currentSectionStart = sectionStartTime(0);
		currentSectionEnd = sectionStartTime(1); 

		// previous section grid
		var previousSectionBeats = curSec > 0 ? getSectionBeats(curSec - 1) : 0;
		if (previousSectionBeats > 0) {
			var gridHeight:Int = Math.floor(previousSectionBeats * 4 * zoomList[curZoom]); 
			
			prevGridBG = FlxGridOverlay.create(1, 1, gridWidth, gridHeight, gridColor1, gridColor2);
			prevGridBG.color = 0xFF999999; // prev section darkness
			prevGridBG.antialiasing = false;
			prevGridBG.scale.set(GRID_SIZE, GRID_SIZE);
			prevGridBG.updateHitbox();
			prevGridBG.y = -prevGridBG.height;
			gridLayer.add(prevGridBG);

			gridY = prevGridBG.y;
			totalHeight += prevGridBG.height;
		}

		// current section grid
		currentSectionBeats = getSectionBeats(curSec);
		{
			var gridHeight:Int = Math.floor(currentSectionBeats * 4 * zoomList[curZoom]); 
			
			gridBG = FlxGridOverlay.create(1, 1, gridWidth, gridHeight, gridColor1, gridColor2);
			gridBG.antialiasing = false;
			gridBG.scale.set(GRID_SIZE, GRID_SIZE);
			gridBG.updateHitbox();
			gridLayer.add(gridBG);

			if (gridY > 0) gridY = 0;

			totalHeight += gridBG.height;
		}
		
		// next section grid
		var nextSectionBeats = (currentSectionEnd > inst.length) ? 0 : (getSectionBeats(curSec + 1) ?? 0);
		if (nextSectionBeats > 0 && currentSectionEnd <= inst.length) {
			var gridHeight:Int = Math.floor(nextSectionBeats * 4 * zoomList[curZoom]); 
			nextGridBG = FlxGridOverlay.create(1, 1, gridWidth, gridHeight, gridColor1, gridColor2);
			nextGridBG.color = 0xFF999999; // next section darkness
			nextGridBG.antialiasing = false;
			nextGridBG.setPosition(gridBG.x, gridBG.y + gridBG.height);
			nextGridBG.scale.set(GRID_SIZE, GRID_SIZE);
			nextGridBG.updateHitbox();
			gridLayer.add(nextGridBG);

			totalHeight += nextGridBG.height;
		}

		// beat separators
		var totalBeats:Float = previousSectionBeats + currentSectionBeats + nextSectionBeats;
		for (i in 1...Math.floor(totalBeats)) {
			var beatsep1:FlxSprite = beatSeparators.recycle();
			if (beatsep1 == null) {
				beatsep1 = CoolUtil.blankSprite(gridBG.width, 4, 0xFFFF0000);
				beatsep1.alpha = 0.25;
				beatSeparators.add(beatsep1);
			}else {
				beatsep1.scale.x = gridBG.width;
				beatsep1.updateHitbox();
			}
			beatsep1.setPosition(gridBG.x, gridY + (i * GRID_SIZE * 4) * zoomList[curZoom]);
		}
		gridLayer.add(beatSeparators);
		
		// field separators
		var fields:Int = 2;
		for (i in 0...fields) {
			var gridBlackLine = fieldSeparators.recycle(); 
			if (gridBlackLine == null) {
				gridBlackLine = CoolUtil.blankSprite(2, totalHeight, FlxColor.BLACK);
			}else {
				gridBlackLine.scale.y = totalHeight;
				gridBlackLine.updateHitbox();
			}
			gridBlackLine.x = -1 + gridBG.x + GRID_SIZE + (GRID_SIZE * _song.keyCount * i);
			gridBlackLine.y = gridY;
			fieldSeparators.add(gridBlackLine);
		}
		gridLayer.add(fieldSeparators);

		updateWaveform();
		updateGrid();
	}

	function strumLineUpdateY()
	{
		strumLine.y = getYfromStrum((Conductor.songPosition - currentSectionStart) / zoomList[curZoom] % (Conductor.stepCrochet * 16)) / (currentSectionBeats / 4);
		camPos.y = strumLine.y;
	}

	var waveformPrinted:Bool = true;
	var wavData:Array<Array<Array<Float>>> = [[[0], [0]], [[0], [0]]];
	function updateWaveform() 
	{
		#if desktop
		var gSize:Int = Std.int(GRID_SIZE * _song.keyCount * 2);
		var hSize:Int = Std.int(gSize* 0.5);

		if (waveformPrinted) { 
			waveformSprite.makeGraphic(gSize, Std.int(gridBG.height), 0x00FFFFFF);
			waveformSprite.pixels.fillRect(new Rectangle(0, 0, gridBG.width, gridBG.height), 0x00FFFFFF);
			waveformPrinted = false;
		}
		if (waveformTrack == null)
			return;

		waveformSprite.x = GRID_SIZE + GRID_SIZE * _song.keyCount - hSize;

		wavData[0][0] = [];
		wavData[0][1] = [];
		wavData[1][0] = [];
		wavData[1][1] = [];

		var steps:Int = Math.round(currentSectionBeats * 4);
		var st:Float = currentSectionStart;
		var et:Float = st + (Conductor.stepCrochet * steps);

		var sound:FlxSound = waveformTrack;
		if (sound._sound != null && sound._sound.__buffer != null) {
			var bytes:Bytes = sound._sound.__buffer.data.toBytes();

			wavData = waveformData(
				sound._sound.__buffer,
				bytes,
				st,
				et,
				1,
				wavData,
				Std.int(gridBG.height)
			);
		}

		// Draws
		var lmin:Float = 0;
		var lmax:Float = 0;

		var rmin:Float = 0;
		var rmax:Float = 0;

		var size:Float = 1;

		var leftLength:Int = (
			wavData[0][0].length > wavData[0][1].length ? wavData[0][0].length : wavData[0][1].length
		);

		var rightLength:Int = (
			wavData[1][0].length > wavData[1][1].length ? wavData[1][0].length : wavData[1][1].length
		);

		var length:Int = leftLength > rightLength ? leftLength : rightLength;

		var index:Int;
		for (i in 0...length) {
			index = i;

			lmin = FlxMath.bound(((index < wavData[0][0].length && index >= 0) ? wavData[0][0][index] : 0) * (gSize / 1.12), -hSize, hSize)* 0.5;
			lmax = FlxMath.bound(((index < wavData[0][1].length && index >= 0) ? wavData[0][1][index] : 0) * (gSize / 1.12), -hSize, hSize)* 0.5;

			rmin = FlxMath.bound(((index < wavData[1][0].length && index >= 0) ? wavData[1][0][index] : 0) * (gSize / 1.12), -hSize, hSize)* 0.5;
			rmax = FlxMath.bound(((index < wavData[1][1].length && index >= 0) ? wavData[1][1][index] : 0) * (gSize / 1.12), -hSize, hSize)* 0.5;

			waveformSprite.pixels.fillRect(new Rectangle(hSize - (lmin + rmin), i * size, (lmin + rmin) + (lmax + rmax), size), FlxColor.BLUE);
		}

		waveformPrinted = true;
		#end
	}

	function waveformData(buffer:AudioBuffer, bytes:Bytes, time:Float, endTime:Float, multiply:Float = 1, ?array:Array<Array<Array<Float>>>, ?steps:Float):Array<Array<Array<Float>>>
	{
		#if (lime_cffi && !macro)
		if (buffer == null || buffer.data == null) return [[[0], [0]], [[0], [0]]];

		var khz:Float = (buffer.sampleRate / 1000);
		var channels:Int = buffer.channels;

		var index:Int = Std.int(time * khz);

		var samples:Float = ((endTime - time) * khz);

		if (steps == null) steps = 1280;

		var samplesPerRow:Float = samples / steps;
		var samplesPerRowI:Int = Std.int(samplesPerRow);

		var gotIndex:Int = 0;

		var lmin:Float = 0;
		var lmax:Float = 0;

		var rmin:Float = 0;
		var rmax:Float = 0;

		var rows:Float = 0;

		var simpleSample:Bool = true;//samples > 17200;
		var v1:Bool = false;

		if (array == null) array = [[[0], [0]], [[0], [0]]];

		while (index < (bytes.length - 1)) {
			if (index >= 0) {
				var byte:Int = bytes.getUInt16(index * channels * 2);

				if (byte > 65535* 0.5) byte -= 65535;

				var sample:Float = (byte / 65535);

				if (sample > 0) {
					if (sample > lmax) lmax = sample;
				} else if (sample < 0) {
					if (sample < lmin) lmin = sample;
				}

				if (channels >= 2) {
					byte = bytes.getUInt16((index * channels * 2) + 2);

					if (byte > 65535* 0.5) byte -= 65535;

					sample = (byte / 65535);

					if (sample > 0) {
						if (sample > rmax) rmax = sample;
					} else if (sample < 0) {
						if (sample < rmin) rmin = sample;
					}
				}
			}

			v1 = samplesPerRowI > 0 ? (index % samplesPerRowI == 0) : false;
			while (simpleSample ? v1 : rows >= samplesPerRow) {
				v1 = false;
				rows -= samplesPerRow;

				gotIndex++;

				var lRMin:Float = Math.abs(lmin) * multiply;
				var lRMax:Float = lmax * multiply;

				var rRMin:Float = Math.abs(rmin) * multiply;
				var rRMax:Float = rmax * multiply;

				if (gotIndex > array[0][0].length) array[0][0].push(lRMin);
					else array[0][0][gotIndex - 1] = array[0][0][gotIndex - 1] + lRMin;

				if (gotIndex > array[0][1].length) array[0][1].push(lRMax);
					else array[0][1][gotIndex - 1] = array[0][1][gotIndex - 1] + lRMax;

				if (channels >= 2) {
					if (gotIndex > array[1][0].length) array[1][0].push(rRMin);
						else array[1][0][gotIndex - 1] = array[1][0][gotIndex - 1] + rRMin;

					if (gotIndex > array[1][1].length) array[1][1].push(rRMax);
						else array[1][1][gotIndex - 1] = array[1][1][gotIndex - 1] + rRMax;
				}
				else {
					if (gotIndex > array[1][0].length) array[1][0].push(lRMin);
						else array[1][0][gotIndex - 1] = array[1][0][gotIndex - 1] + lRMin;

					if (gotIndex > array[1][1].length) array[1][1].push(lRMax);
						else array[1][1][gotIndex - 1] = array[1][1][gotIndex - 1] + lRMax;
				}

				lmin = 0;
				lmax = 0;

				rmin = 0;
				rmax = 0;
			}

			index++;
			rows++;
			if(gotIndex > steps) break;
		}

		return array;
		#else
		return [[[0], [0]], [[0], [0]]];
		#end
	}

	function changeSection(sec:Int = 0, ?updateMusic:Bool = true):Void
	{
		if (_song.notes[sec] != null) {
			curSec = sec;

			if (updateMusic) {
				pauseTracks();
				Conductor.songPosition = sectionStartTime();
				Conductor.updateSteps();
			}

			reloadGridLayer();
			updateSectionUI();
		}
		stepperStrumTime.stepSize = Conductor.stepCrochet;
		stepperSusLength.stepSize = Conductor.stepCrochet;
	}

	function updateSectionUI():Void
	{
		var sec = _song.notes[curSec];

		stepperBeats.value = getSectionBeats(curSec);
		check_mustHitSection.checked = sec.mustHitSection;
		check_gfSection.checked = sec.gfSection;
		check_altAnim.checked = sec.altAnim;
		check_changeBPM.checked = sec.changeBPM;
		stepperSectionBPM.value = sec.bpm;

		updateHeads();
	}

	function updateHeads():Void
	{
		var healthIconP1:String ="bf";
		var healthIconP2:String = "dad";

		if (_song.notes[curSec].mustHitSection)
		{
			leftIcon.changeIcon(healthIconP1);
			rightIcon.changeIcon(healthIconP2);
			if (_song.notes[curSec].gfSection) leftIcon.changeIcon('gf');
		}
		else
		{
			leftIcon.changeIcon(healthIconP2);
			rightIcon.changeIcon(healthIconP1);
			if (_song.notes[curSec].gfSection) leftIcon.changeIcon('gf');
		}

		leftIcon.setGraphicSize(0, 45);
		leftIcon.updateHitbox();
		rightIcon.setGraphicSize(0, 45);
		rightIcon.updateHitbox();

		leftIcon.setPosition(GRID_SIZE * (1 + _song.keyCount * 0.5) - leftIcon.width * 0.5, 5);
		rightIcon.setPosition(GRID_SIZE * (1 + _song.keyCount * 1.5) - rightIcon.width * 0.5, 5);
	}

	function updateNoteSteps():Void
	{
		if (curSelectedNote == null) {
			labelSusLength.text = '';
			labelStrumTime.text = '';
			return;
		}

		var strumStep:Float = Conductor.getStep(curSelectedNote.strumTime);
		var sustainSteps:Float = 0;

		if (curSelectedNote.sustainLength > 0) {
			var endStep:Float = Conductor.getStep(curSelectedNote.strumTime + curSelectedNote.sustainLength);
			sustainSteps = endStep - strumStep;
		}

		labelSusLength.text = 'Sustain Length: (${Math.round(sustainSteps)} Steps)';
		labelStrumTime.text = 'Strum Time: (Step ${strumStep})';
	}

	function updateNoteUI():Void
	{
		if (curSelectedNote != null) {
			updateNoteSteps();

			stepperStrumTime.value = curSelectedNote.strumTime;
			stepperSusLength.value = curSelectedNote.sustainLength;

			var typeIdx = noteTypeMap.get(curSelectedNote.noteType);
			noteTypeDropDown.selectedLabel = (typeIdx > 0) ? typeIdx + '. ' + curSelectedNote.noteType : '';		
		}
	}

	function updateEventsUI():Void
	{
		if (curSelectedEvent != null) {
			selectedEventText.text = 'Selected Event: ' + (subEventIdx + 1) + ' / ' + curSelectedEvent.subEventsData.length;

			var eventData:PsychSubEventData = curSelectedEvent.subEventsData[subEventIdx];

			eventDropDown.selectedLabel = eventNameInput.text = eventData.eventName;
			value1InputText.text = eventData.value1;
			value2InputText.text = eventData.value2;

			var selectedIdx:Int = 0;
			for (i in 0...eventStuff.length){
				if (eventStuff[i][0] == eventData.eventName){
					selectedIdx = i;
					break;
				}
			}

			eventDropDown.selectedId = Std.string(selectedIdx);
			eventDropDown.header.text.text = eventData.eventName;
			
			descText.text = eventStuff[selectedIdx][1];
		}else {
			selectedEventText.text = 'Selected Event: None';
		}
	}
	
	inline function fuckFloatingPoints(n:Float):Float // haha decimals
		return CoolUtil.snap(n, Conductor.jackLimit);

	inline function wipeGroup(group:FlxTypedGroup<Dynamic>)
	{
		for (obj in group) obj.destroy();
		group.clear();	
	}

	/** Creates the notes and event sprites from the currently visible sections **/
	function updateGrid():Void
	{
		wipeGroup(curRenderedNotes);
		wipeGroup(curRenderedSustains);
		wipeGroup(curRenderedNoteType);
		wipeGroup(nextRenderedNotes);
		wipeGroup(nextRenderedSustains);
		wipeGroup(prevRenderedNotes);
		wipeGroup(prevRenderedSustains);

		if (_song.notes[curSec].changeBPM && _song.notes[curSec].bpm > 0)
		{
			Conductor.changeBPM(_song.notes[curSec].bpm);
			//trace('BPM of this section:');
		}
		else
		{
			// get last bpm
			var daBPM:Float = _song.bpm;
			for (i in 0...curSec)
				if (_song.notes[i].changeBPM)
					daBPM = _song.notes[i].bpm;
			Conductor.changeBPM(daBPM);
		}

		// PREV SECTION
		if(curSec > 0) {
			var prevSection = curSec-1;
			for (i in _song.notes[prevSection].sectionNotes)
			{
				var note:Note = setupNoteData(i, prevSection);
				note.alpha = 0.6;
				nextRenderedNotes.add(note);
				if (note.sustainLength > 0)
				{
					nextRenderedSustains.add(setupSusNote(note));
				}
			}
		}

		// CURRENT SECTION
		for (i in _song.notes[curSec].sectionNotes)
		{
			var note:Note = setupNoteData(i, curSec);
			curRenderedNotes.add(note);
			if (note.sustainLength > 0)
			{
				curRenderedSustains.add(setupSusNote(note));
			}

			if (note.noteType.length > 0) {
				var typeInt:Null<Int> = noteTypeMap.get(note.noteType);
				var theType:String = (typeInt == null) ? '?' : '$typeInt';

				var daText:AttachedFlxText = new AttachedFlxText(0, 0, 100, theType, 24);
				daText.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, CENTER);
				daText.setBorderStyle(FlxTextBorderStyle.OUTLINE, FlxColor.BLACK, 1);
				daText.xAdd = -32;
				daText.yAdd = 6;
				curRenderedNoteType.add(daText);
				daText.sprTracker = note;
			}
		}
		// CURRENT EVENTS
		var startThing:Float = fuckFloatingPoints(sectionStartTime());
		var endThing:Float = fuckFloatingPoints(sectionStartTime(1));
		for (i in _song.events)
		{
			var t = fuckFloatingPoints(i.strumTime);
			if (startThing <= t && t < endThing)
			{
				var note:Note = setupEventData(i, curSec);
				curRenderedNotes.add(note);

				var text:String = 'Event: ' + note.eventName + ' (' + Math.floor(note.strumTime) + ' ms)' + '\nValue 1: ' + note.eventVal1 + '\nValue 2: ' + note.eventVal2;
				if(note.eventLength > 1) text = note.eventLength + ' Events:\n' + note.eventName;

				var daText:AttachedFlxText = new AttachedFlxText(0, 0, 400, text, 12);
				daText.setFormat(Paths.font("vcr.ttf"), 12, FlxColor.WHITE, RIGHT);
				daText.setBorderStyle(FlxTextBorderStyle.OUTLINE_FAST, FlxColor.BLACK, 1);
				daText.xAdd = -410;
				if (note.eventLength > 1) daText.yAdd = 8;
				curRenderedNoteType.add(daText);
				daText.sprTracker = note;

				////trace('test: ${i[0]}, startThing: $startThing, endThing: $endThing');
			}
		}

		// NEXT SECTION
		var nextSection = curSec+1;
		if (curSec < _song.notes.length-1) {
			for (i in _song.notes[nextSection].sectionNotes)
			{
				var note:Note = setupNoteData(i, nextSection);
				note.alpha = 0.6;
				nextRenderedNotes.add(note);
				if (note.sustainLength > 0)
				{
					nextRenderedSustains.add(setupSusNote(note));
				}
			}
		}

		// NEXT EVENTS
		var startThing:Float = endThing;
		var endThing:Float = fuckFloatingPoints(sectionStartTime(2));
		for (i in _song.events)
		{
			var t:Float = fuckFloatingPoints(i.strumTime);
			if(t >= startThing && t < endThing)
			{
				var note:Note = setupEventData(i, nextSection);
				note.alpha = 0.6;
				nextRenderedNotes.add(note);
			}
		}
	}

	function initNoteType(notetype:String){
		if(notetype == '') return;
		if(notetypeScripts.exists(notetype)) return;

		var file:Null<String> = Paths.getHScriptPath('notetypes/$notetype');
		if (file != null) {
			var script = FunkinHScript.fromFile(file);
			notetypeScripts.set(notetype, script);
		}
	}

	var useQuantNotes:Bool = ClientPrefs.noteSkin == 'Quants';

	function setupNoteData(i:NoteData, sectionNumber:Int):Note {
		var daField:Int = Math.floor(i.column / _song.keyCount);
		var note:Note = new Note(i.strumTime, i.column % _song.keyCount, null, daField, (i.sustainLength <= 0 ? TAP : HEAD), true);
		note.chartData = i;
		note.realColumn = i.column;
		note.sustainLength = i.sustainLength;
		note.canQuant = useQuantNotes;
		note.reloadNote();
		initNoteType(i.noteType);
		note.noteType = i.noteType;

		//note.wasGoodHit = note.beat <= Conductor.curDecBeat;

		note.setGraphicSize(GRID_SIZE, GRID_SIZE);
		note.updateHitbox();

		note.x = getNoteX(note.realColumn, sectionNumber);
		note.y = getNoteY(note.strumTime, sectionNumber);

		return note;	
	}

	inline function getNoteX(column:Int, sectionNumber:Int):Float {
		if (_song.notes[curSec].mustHitSection != _song.notes[sectionNumber].mustHitSection)
			(column < _song.keyCount) ? (column += _song.keyCount) : (column -= _song.keyCount);
		return (1 + column) * GRID_SIZE;
	}

	inline function getNoteY(strumTime:Float, sectionNumber:Int):Float
		return getYfromStrumNotes(strumTime - getSectionStartTime(curSec), getSectionBeats(sectionNumber));

	function setupEventData(i:PsychEventNote, sectionNumber:Int) {
		var note:Note = new Note(i.strumTime, -1, null, -1, 0, true);
		note.realColumn -1;
		note.chartData = i;
		note.usesDefaultColours = false;

		note.loadGraphic(Paths.image('eventArrow'));
		note.eventName = getEventName(i.subEventsData);
		note.eventLength = i.subEventsData.length;
		if (i.subEventsData.length < 2)
		{
			note.eventVal1 = i.subEventsData[0].value1;
			note.eventVal2 = i.subEventsData[0].value2;
		}

		//note.wasGoodHit = note.beat <= Conductor.curBeat;

		note.setGraphicSize(GRID_SIZE, GRID_SIZE);
		note.updateHitbox();
				
		note.x = 0; // getNoteX(note.realColumn, sectionNumber);
		note.y = getNoteY(note.strumTime, sectionNumber);
		return note;
	}

	function getEventName(names:Array<Array<String>>):String
	{
		var retStr:String = '';
		var addedOne:Bool = false;
		for (i in 0...names.length)
		{
			if(addedOne) retStr += ', ';
			retStr += names[i][0];
			addedOne = true;
		}
		return retStr;
	}

	var noteColors:Array<FlxColor> = [0xFFC24B99, 0xFF00FFFF, 0xFF12FA05, 0xFFF9393F];
	var susWidth:Float = 8;
	var showSusTail:Bool = true; // to visualise the head/cap/end of the tail
	// because they looked WAY too short
	
	function setupSusNote(note:Note):Null<FlxSprite> 
	{
		final stepLength = (Conductor.getBPMFromSeconds(note.strumTime).stepCrochet);
		final tailSteps:Float = note.sustainLength / stepLength;
		var height:Float = tailSteps * GRID_SIZE * zoomList[curZoom];
		if (!showSusTail) height -= GRID_HALF;
		
		if (height <= 0) return null;
		
		var spr:FlxSprite = new FlxSprite(
			note.x + (GRID_SIZE - susWidth) * 0.5, 
			note.y + GRID_HALF
		);
		var color:FlxColor = note.isQuant ? 0xFFFF0000 : noteColors[note.column % noteColors.length];
		color.setHSB(
			((color.hue + note.colorSwap.hue * 360) % 360 + 360) % 360,
			CoolUtil.boundTo(color.saturation * 0.01 * (1.0 + note.colorSwap.saturation), 0.0, 1.0) * 100.0,
			(color.brightness * 0.01 * (1.0 + note.colorSwap.brightness)) * 100.0,
			color.alphaFloat
		);
		spr.makeGraphic(1, 1, color);
		spr.scale.set(susWidth, height);
		spr.updateHitbox();
		
		return spr;
	}

	private function pushSection(sectionBeats:Float = 4):Void
	{
		var sec:SwagSection = {
			sectionBeats: sectionBeats,
			bpm: _song.bpm,
			changeBPM: false,
			mustHitSection: true,
			gfSection: false,
			sectionNotes: [],
			typeOfSection: 0,
			altAnim: false
		};

		_song.notes.push(sec);
	}
	
	private function insertSection(idx:Int, sectionBeats:Float = 4):Void
	{
		var sec:SwagSection = {
			sectionBeats: sectionBeats,
			bpm: _song.bpm,
			changeBPM: false,
			mustHitSection: true,
			gfSection: false,
			sectionNotes: [],
			typeOfSection: 0,
			altAnim: false
		};

		_song.notes.insert(idx, sec);
	}

	function selectNote(note:Note):Void
	{		
		if (note.column > -1) {
			curSelectedNote = note.chartData;
			currentNoteType = note.noteType;
			updateNoteUI();
		}else {
			curSelectedEvent = note.chartData;
			subEventIdx = Std.int(curSelectedEvent.subEventsData.length) - 1;
			changeEventSelected();
		}
	}

	function deleteNote(note:Note):Void
	{
		if (note.column > -1) {
			//Normal Notes
			var currentSection = _song.notes[curSec];
			for (i in currentSection.sectionNotes) {
				if (i != note.chartData) continue;
				new RemoveNoteAction(curSec, i);
				break;
			}
		}else {
			//Events
			for (i in _song.events) {
				if (i != note.chartData) continue;
				new RemoveEventAction(i);
				break;
			}
		}

		updateGrid();
	}

	private function addNote(strumTime:Float, column:Int, ?noteType:String, ?click:Bool):Void
	{
		noteType ??= currentNoteType;
		var heldNotes:Array<NoteData> = switch(click) {
			case true: heldNotesClick;
			case false: heldNotesVortex;
			default: null;
		}

		var noteData = _addNote(curSec, strumTime, column, noteType);
		if (heldNotes != null) heldNotes[column] = noteData;

		if (FlxG.keys.pressed.CONTROL) {
			var mirrorColumn:Int = (column + _song.keyCount) % (_song.keyCount * 2);
			var noteData = _addNote(curSec, strumTime, mirrorColumn, noteType);
			if (heldNotes != null) heldNotes[mirrorColumn] = noteData;
		}

		//trace(noteData + ', ' + strumTime + ', ' + curSec);
	}

	private function _addNote(sectionNumber:Int, strumTime:Float, column:Int, noteType:String) {
		var note = NoteData.fromValues(strumTime, column, 0.0, noteType);
		new AddNoteAction(curSec, note);
		return note;
	}

	private function addEvent(noteStrum:Float) {
		var eventType:String = eventNameInput.text; //eventStuff[Std.parseInt(eventDropDown.selectedId)][0];
		var text1:String = value1InputText.text;
		var text2:String = value2InputText.text;

		var e = PsychEventNote.fromValues(noteStrum, [[eventType, text1, text2]]);
		new AddEventAction(e);
	}

	////
	@:noCompletion var utRay = new Array<ChartingAction>();
	@:noCompletion var utIdx:Int = -1;

	@:noCompletion function pushAction(action:ChartingAction) {
		action.redo(); // doing this first so that in the case it throws an exception it'll basically just not happen
		trace(action);

		utIdx += 1;
		utRay.resize(utIdx);
		utRay.push(action);
	}

	function redo()
	{
		var nidx = utIdx + 1;
		var action = utRay[nidx]; 
		if (action == null) return;
		action.redo();
		trace('REDO: $action');
		utIdx = nidx;
	}

	function undo()
	{
		if (utIdx < 0) return;
		var action = utRay[utIdx];
		if (action == null) return;
		action.undo();
		trace('UNDO: $action');
		utIdx -= 1;
	}

	////
	function getStrumTime(yPos:Float, doZoomCalc:Bool = true):Float
	{
		var leZoom:Float = doZoomCalc ? zoomList[curZoom] : 1;
		return FlxMath.remapToRange(yPos, gridBG.y, (gridBG.y + gridBG.height * leZoom), 0, 16 * Conductor.stepCrochet);
	}

	function getYfromStrum(strumTime:Float, doZoomCalc:Bool = true):Float
	{
		var leZoom:Float = doZoomCalc ? zoomList[curZoom] : 1;
		return FlxMath.remapToRange(strumTime, 0, 16 * Conductor.stepCrochet, gridBG.y, (gridBG.y + gridBG.height * leZoom));
	}
	
	inline function getYfromStrumNotes(strumTime:Float, beats:Float):Float
		return gridBG.y + (strumTime / Conductor.stepCrochet) * GRID_SIZE * zoomList[curZoom];

	function clearNotes() {
		for (sec in 0..._song.notes.length)
			_song.notes[sec].sectionNotes.resize(0);
		updateGrid();
	}

	function clearEvents() {
		_song.events.resize(0);
		updateGrid();
	}

	function autosaveSong():Void
	{		
		options.autosave = Json.stringify(_song);
		FlxG.save.data.chartingStateOptions = options;
		FlxG.save.flush();
	}

	function loadJson(songId:String):Void
	{
		var song = new Song(songId, Paths.currentModDirectory);
		var charts:Array<String> = song.getCharts();

		if (charts.length == 0) {
			showPopup('No charts found for $song');
			return;
		}

		var chartId = charts[CoolUtil.updateDifficultyIndex(-1, PlayState.difficultyName, charts)];
		var daJson:SwagSong = song.getSwagSong(chartId);
		trace(song, chartId);

		if (daJson == null){
			showPopup('An error ocurred while loading the JSON file');
		}else{
			PlayState.song = song;
			PlayState.SONG = daJson;
			PlayState.difficultyName = chartId;
			MusicBeatState.resetState();
		}
	}

	function sortNotesByTime(Obj1:NoteData, Obj2:NoteData):Int
		return FlxSort.byValues(FlxSort.ASCENDING, Obj1.strumTime, Obj2.strumTime);
	
	function sortEventsByTime(Obj1:PsychEventNote, Obj2:PsychEventNote):Int
		return FlxSort.byValues(FlxSort.ASCENDING, Obj1.strumTime, Obj2.strumTime);

	private function saveLevel()
	{
		if (_song.events != null && _song.events.length > 1) 
			_song.events.sort(sortEventsByTime);
		
		var fileName:String;
		var _song:SwagSong = Reflect.copy(_song);

		Reflect.deleteField(_song, "_chartEditor");
		Reflect.deleteField(_song, "metadata");

		if (Reflect.hasField(_song, "_path")) {
			fileName = haxe.io.Path.withoutDirectory(Reflect.field(_song, "_path"));
			Reflect.deleteField(_song, "_path");
		}else {
			fileName = _song.song + ".json";
		}

		var json = {"song": _song};
		var data:String = Json.stringify(json, "\t");

		if ((data != null) && (data.length > 0))
		{
			CoolUtil.showSaveDialog(data.trim(), "Save Chart", getSongPath(fileName), ["JSON file", "*.json"], onSaveComplete, onSaveCancel);
		}
	}

	function onSaveComplete(_):Void
	{
		FlxG.log.notice("Successfully saved LEVEL DATA.");
	}

	/**
	 * Called when the save file dialog is cancelled.
	 */
	function onSaveCancel():Void
	{
		FlxG.log.notice("Save file dialog cancelled.");
	}

	inline function getSectionBeats(section:Int):Null<Float>
		return _song.notes[section]?.sectionBeats;

	override function destroy() {
		_session.curSec = curSec;
		_session.songPosition = Conductor.songPosition;
		_session.trackVolumes.clear();
		for (id => snd in soundTracksMap) {
			if (snd != null)
				_session.trackVolumes.set(id, snd.volume);
		}
		super.destroy();
	}
}

/** dont sort my shit **/
class CustomFlxUITabMenu extends FlxUITabMenu {
	override function sortTabs(a, b):Int
		return 0;
}

private class CustomFlxUINumericStepper extends flixel.addons.ui.FlxUINumericStepper {
	public var hoveringText:Bool = false;

	override function update(elapsed:Float) {
		if (hoveringText = FlxG.mouse.overlaps(text_field, text_field.camera)) {
			if (FlxG.mouse.wheel > 0) _onPlus();
			else if (FlxG.mouse.wheel < 0) _onMinus();
		}
		super.update(elapsed);
	}
}

/**
	Allow quick mouse wheel option scrolling without having to open the dropdown
**/
private class CustomFlxUIDropDownMenu extends flixel.addons.ui.FlxUIDropDownMenu.FlxUIDropDownMenu {
	override function checkClickOff() {
		if (!dropPanel.visible && header.button.status == FlxButton.HIGHLIGHT)
		{
			if (FlxG.mouse.wheel != 0) {
				var idx:Int = 0;
				for (i => btn in list) {
					if (btn.label.text != selectedLabel) continue;
					idx = i;
					break;
				}
				idx = CoolUtil.updateIndex(idx, -FlxG.mouse.wheel, list.length);
				onClickItem(idx);
			}
		}
		super.checkClickOff();
	}
}

/** 
	Allow mouse wheel to slide the handle
**/
private class CustomFlxUISlider extends flixel.addons.ui.FlxUISlider {
	public var scrollStep:Float = 0.1;

	override function update(elapsed) {
		if (_justHovered && !dragging && scrollStep != 0.0 && FlxG.mouse.wheel != 0)
		{
			var relativePos:Float = relativePos + FlxG.mouse.wheel * scrollStep;

			value = minValue + (maxValue - minValue) * relativePos;
			if (value < minValue) value = minValue;
			else if (value > maxValue) value = maxValue; 

			if ((setVariable) && (varString != null))
			{
				Reflect.setProperty(_object, varString, value);
			}

			_lastPos = relativePos;

			if (callback != null)
				callback(relativePos);

			handle.x = expectedPos;
		}

		super.update(elapsed);
	}
}

private class TimelineDisplay extends FlxBasic {
	public var uaWidth = 250;
	public var uaHeight = 16;

	public var curIdx:Int = -1;
	public var scrollIdx:Int = 0;

	public var bgs:Array<FlxSprite> = [];
	public var txts:Array<FlxText> = [];

	public function new(x:Float = 0, y:Float = 0, displayLength:Int = 10) {
		super();

		var text_hPadding = 5;

		for (i in 0...displayLength) {
			var bg = CoolUtil.blankSprite(uaWidth, uaHeight, 0xFF262626);
			bg.scrollFactor.set();
			bg.setPosition(x, y + i * uaHeight);
			bgs[i] = bg;

			var txt = new FlxText(
				(bg.x + text_hPadding), 
				(bg.y), 
				(uaWidth - text_hPadding - text_hPadding),
				"", 
				8
			);

			txt.y += (uaHeight - txt.height) / 2;
			txt.scrollFactor.set();
			txt.wordWrap = false;
			txts[i] = txt;
		}
	}

	public function updateDisplay() {
		final utRay = ChartingState.instance.utRay;
		var half = Math.floor(txts.length / 2);
		var offi = (utRay.length - curIdx);
		var offi2 = FlxMath.maxInt(0, offi - half);
		var scrollIdx = scrollIdx + offi2;

		for (i in 1...txts.length + 1) {
			var actionIdx = utRay.length - i - scrollIdx;
			var action = (actionIdx < 0) ? null : utRay[actionIdx];

			var txtIdx = txts.length - i;
			var txt = (txtIdx < 0) ? null : txts[txtIdx];
			if (txt == null) continue;

			var bg = bgs[txtIdx];
			var action_reverted = actionIdx > curIdx;

			if (action == null) bg.color = 0xFF262626; // none
			else if (actionIdx == curIdx) bg.color = 0xFF195BA0; // is current
			else if (action_reverted) bg.color = 0xFF8C8C8C; // was reverted
			else bg.color = 0xFF262626; // is past

			txt.color = action_reverted ? 0xFF000000 : 0xFFFFFFFF;
			txt.text = (action == null) ? "" : Std.string(action);
		}
	}

	override function update(elapsed:Float) {
		if (FlxG.keys.justPressed.V) {
			scrollIdx--;
			updateDisplay();
		}
		if (FlxG.keys.justPressed.N) {
			scrollIdx++;
			updateDisplay();	
		}

		if (curIdx != ChartingState.instance.utIdx) {
			curIdx = ChartingState.instance.utIdx;
			scrollIdx = 0;
			updateDisplay();
		}

		for (obj in bgs) obj.update(elapsed);
		for (obj in txts) obj.update(elapsed);
	}

	override function draw() {
		for (obj in bgs) obj.draw();
		for (obj in txts) obj.draw();
	}
}

private class ChangeMustHitSectionAction extends ChartingAction {
	public var sectionNumber:Int;
	public var adjustNotes:Bool;
	
	public function new(sectionNumber:Int, adjustNotes:Bool = true) {
		this.sectionNumber = sectionNumber;
		this.adjustNotes = adjustNotes;
		super();
	}

	public function redo() {
		var section = getSection(sectionNumber);
		section.mustHitSection = !section.mustHitSection;

		if (adjustNotes) {
			for (note in section.sectionNotes)
				note.column = (note.column + _song.keyCount) % (_song.keyCount * 2);
		}

		instance.check_mustHitSection.checked = section.mustHitSection;
		instance.updateGrid();
		instance.updateHeads();
	}

	public function undo() {
		redo();
	}
}

private class ChangeSustainAction extends NoteAction {
	public var change:Float;

	public function new(noteData:NoteData, value:Float, isAbs:Bool = false) {
		this.noteData = noteData;
		this.change = isAbs ? value - noteData.sustainLength : value;
		if (this.change < 0)
			this.change = Math.max(change, -noteData.sustainLength);

		super();
	}

	public function redo() {
		noteData.sustainLength += change;
		instance.updateGrid();
		instance.updateNoteUI();
	}

	public function undo() {
		noteData.sustainLength -= change;	
		instance.updateGrid();
		instance.updateNoteUI();
	}

	public function toString() {
		return 'Change Sustain (${Math.floor(change)})';
	}
}

private class RemoveEventAction extends ChartingAction {
	var eventData:PsychEventNote;

	public function new(eventData:PsychEventNote) {
		this.eventData = eventData;
		super();
	}

	public function redo() {
		_song.events.remove(eventData);
		instance.updateGrid();

		if (instance.curSelectedEvent == eventData) {
			instance.subEventIdx = 0;
			instance.curSelectedEvent = null;
			instance.changeEventSelected();
		}
	}
	
	public function undo() {
		_song.events.push(eventData);
		instance.updateGrid();

		instance.subEventIdx = 0;
		instance.curSelectedEvent = eventData;
		instance.changeEventSelected();
	}

	public function toString() {
		return 'Remove Event (${Math.floor(eventData.strumTime)})';
	}
}

private class AddEventAction extends ChartingAction {
	var eventData:PsychEventNote;

	public function new(eventData:PsychEventNote) {
		this.eventData = eventData;
		super();
	}

	public function redo() {
		_song.events.push(eventData);
		instance.updateGrid();

		instance.subEventIdx = 0;
		instance.curSelectedEvent = eventData;
		instance.changeEventSelected();
	}

	public function undo() {
		_song.events.remove(eventData);
		instance.updateGrid();

		if (instance.curSelectedEvent == eventData) {
			instance.subEventIdx = 0;
			instance.curSelectedEvent = null;
			instance.changeEventSelected();
		}
	}

	public function toString() {
		return 'Remove Event (${Math.floor(eventData.strumTime)})';
	}
}

private class RemoveNoteAction extends NoteAction {
	public var sectionNumber:Int;

	public function new(sectionNumber:Int, noteData:NoteData) {
		this.sectionNumber = sectionNumber;
		this.noteData = noteData;
		super();
	}
		
	public function redo() {
		getSection(sectionNumber).sectionNotes.remove(noteData);
		if (instance.curSelectedNote == noteData) {
			instance.curSelectedNote = null;
			instance.updateNoteUI();
		}
		instance.updateGrid();
	}

	public function undo() {
		getSection(sectionNumber).sectionNotes.push(noteData);
		instance.curSelectedNote = noteData;
		instance.updateNoteUI();
		instance.updateGrid();
	}

	public function toString() {
		return 'Remove Note (${noteData.column}, ${Math.floor(noteData.strumTime)})';
	}
}

private class AddNoteAction extends NoteAction {
	public var sectionNumber:Int;

	public function new(sectionNumber:Int, noteData:NoteData)
	{
		this.noteData = noteData;
		this.sectionNumber = sectionNumber;
		super();
	}
	
	public function redo() {
		getSection(sectionNumber).sectionNotes.push(noteData);
		instance.curSelectedNote = noteData;
		instance.updateNoteUI();
		instance.updateGrid();
	}

	public function undo() {
		getSection(sectionNumber).sectionNotes.remove(noteData);
		if (instance.curSelectedNote == noteData) {
			instance.curSelectedNote = null;
			instance.updateNoteUI();
		}
		instance.updateGrid();
	}

	public function toString() {
		return 'Add Note (${noteData.column}, ${Math.floor(noteData.strumTime)})';
	}
}

private abstract class NoteAction extends ChartingAction {
	var noteData:NoteData;
}

private abstract class ChartingAction
{
	/** Apply the effects of this action **/
	abstract public function redo():Void;

	/** Revert the effects of this action **/
	abstract public function undo():Void;

	public function new()
		instance.pushAction(this);

	////
	public var instance(get, never):ChartingState; 
	@:noCompletion inline function get_instance():ChartingState
		return ChartingState.instance;

	public var _song(get, never):SwagSong; 
	@:noCompletion inline function get__song():SwagSong
		return instance._song;

	inline function getSection(idx:Int):SwagSection
		return _song.notes[idx];
}