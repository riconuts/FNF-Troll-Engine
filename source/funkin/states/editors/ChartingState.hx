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
import openfl.events.Event;
import openfl.events.IOErrorEvent;
import openfl.net.FileReference;
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

@:access(flixel.sound.FlxSound._sound)
@:access(openfl.media.Sound.__buffer)
class ChartingState extends MusicBeatState
{
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
	var undos = [];
	var redos = [];
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

	var _file:FileReference;

	var UI_box:FlxUITabMenu;

	public static var curSec:Int = 0;
	public static var lastSection:Int = 0;
	private static var lastSong:String = '';

	var bpmTxt:FlxText;

	var camPos:FlxObject;
	var strumLine:FlxSprite;
	var quant:AttachedSprite;
	var strumLineNotes:FlxTypedGroup<StrumNote>;
	var curSong:String = 'Test';
	var amountSteps:Int = 0;

	var highlight:FlxSprite;

	public static var GRID_SIZE:Int = 40;
	public static var GRID_HALF:Float = GRID_SIZE * 0.5;

	var dummyArrow:FlxSprite;

	var curRenderedSustains:FlxTypedGroup<FlxSprite>;
	var curRenderedNotes:FlxTypedGroup<Note>;
	var curRenderedNoteType:FlxTypedGroup<FlxText>;

	var nextRenderedSustains:FlxTypedGroup<FlxSprite>;
	var nextRenderedNotes:FlxTypedGroup<Note>;

	var gridBG:FlxSprite;
	var nextGridBG:FlxSprite;

	var curEventSelected:Int = 0;
	var curUndoIndex = 0;
	var curRedoIndex = 0;
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
	private var blockPressWhileTypingOnStepper:Array<FlxUINumericStepper> = [];
	private var blockPressWhileScrolling:Array<FlxUIDropDownMenu> = [];

	var waveformSprite:FlxSprite;
	var gridLayer:FlxTypedGroup<FlxSprite>;

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
	// ok not adding it yet because it doesn't change the note column to accomodate mustHitSection changes
	function fixNotes() {
		var allSections:Array<SwagSection> = _song.notes;
		var allNotes:Array<NoteData> = [];
		var sectionStarts:Array<Float> = [];
		
		var beat:Float = 0;
		for (i => section in allSections) {			
			while (section.sectionNotes.length > 0)
				allNotes.push(section.sectionNotes.pop());
			
			sectionStarts[i] = (Conductor.stepToMs(beat * 4));
			beat += getSectionBeats(i);
		}
		
		allNotes.sort((a, b) -> return Std.int(b.strumTime - a.strumTime)); // descending order

		var curSection = 0;
		while (allNotes.length > 0) {
			var note:NoteData = allNotes.pop();

			for (i => sectionStart in sectionStarts) {
				if (note.strumTime >= sectionStart) {
					curSection = i;		
				}
			}

			allSections[curSection].sectionNotes.push(note); 
		}
	}

	function adjustCamPos() {
		camPos.x = GRID_SIZE * (1 + _song.keyCount);

		var chart_grid_end = FlxG.width / 2 + GRID_SIZE * _song.keyCount;

		var ui_width_grid_snapped = Math.ceil(300 / GRID_SIZE) * GRID_SIZE;
		var chart_grid_offset = ui_width_grid_snapped - 300;

		var ui_start = chart_grid_end + chart_grid_offset;
		var ui_end = chart_grid_end + ui_width_grid_snapped + 300;

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

	override function create()
	{
		instance = this;
		
		FlxTransitionableState.skipNextTransOut = true;

		persistentDraw = true;

		PlayState.chartingMode = true;

		this._song = PlayState.SONG ??= {
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
		this.songId = (PlayState.song?.songId) ?? Paths.formatToSongPath(_song.song);
		onLoadMetadata();
		
		MusicBeatState.stopMenuMusic();

		if (_song.notes.length == 0){
			pushSection();
			curSec = 0;
		}else if (curSec >= _song.notes.length) {
			curSec = _song.notes.length - 1;
		}

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

		gridLayer = new FlxTypedGroup<FlxSprite>();
		add(gridLayer);

		waveformSprite = new FlxSprite(GRID_SIZE, 0).makeGraphic(FlxG.width, FlxG.height, 0x00FFFFFF);
		add(waveformSprite);

		var eventIcon:FlxSprite = new FlxSprite(-GRID_SIZE - 5, 15, Paths.image('eventArrow'));
		leftIcon = new HealthIcon('bf');
		rightIcon = new HealthIcon('dad');
		eventIcon.scrollFactor.set(1, 0);
		leftIcon.scrollFactor.set(1, 0);
		rightIcon.scrollFactor.set(1, 0);

		eventIcon.setGraphicSize(30, 30);
		leftIcon.setGraphicSize(0, 45);
		rightIcon.setGraphicSize(0, 45);

		add(eventIcon);
		add(leftIcon);
		add(rightIcon);

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

		if (lastSong != songId) {
			lastSong = songId;
			curSec = 0;
		}

		changeSection(curSec);

		if (soundTracksMap.exists(lastSelectedTrack))
			selectTrack(lastSelectedTrack);
		else
			waveformTrackDropDown.selectedId = "None";

		super.create();
		FlxG.mouse.visible = true;
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

	function addSongUI():Void
	{
		var UI_songTitle = new FlxUIInputText(10, 10, 70, _song.song, 8);
		UI_songTitle.name = 'song_title';
		blockPressWhileTypingOn.push(UI_songTitle);

		var saveButton:FlxButton = new FlxButton(110, 8, "Save Chart", saveLevel);

		var reloadSong:FlxButton = new FlxButton(saveButton.x + 90, saveButton.y, "Reload Audio", function()
		{
			songId = Paths.formatToSongPath(UI_songTitle.text);
			loadTracks();
			updateWaveform();
		});

		var reloadSongJson:FlxButton = new FlxButton(reloadSong.x, saveButton.y + 30, "Reload JSON", function()
		{
			openSubState(new Prompt('This action will clear current progress.\n\nProceed?', 0, function(){loadJson(_song.song.toLowerCase()); }, null, options.ignoreWarnings));
		});

		var loadAutosaveBtn:FlxButton = new FlxButton(reloadSongJson.x, reloadSongJson.y + 30, 'Load Autosave', function()
		{
			var autosaved:Dynamic = options.autosave;
			if (autosaved == null) {
				openSubState(new Prompt("There is no autosaved data", 0, null, null, false, "OK", "OK"));
			}else if (!Std.isOfType(autosaved, String)) {
				openSubState(new Prompt("Invalid autosaved data", 0, null, null, false, "OK", "OK"));
			}else{
				PlayState.SONG = cast Json.parse(autosaved);
				MusicBeatState.resetState();
			}
		});

		////
		final eventsFileDialog = new FileDialog();
		eventsFileDialog.onOpen.add(function(resource) {
			var data:Dynamic = Json.parse((resource:Bytes).toString());

			var song:SwagSong = Reflect.field(data, "song"); 
			if (song == null)
				return;
		
			var events = ChartData.onLoadEvents(data.song).events;
			if (events == null)
				return;

			clearEvents();
			_song.events = events;
			changeSection(curSec);
		});

		var loadEventJson:FlxButton = new FlxButton(loadAutosaveBtn.x, loadAutosaveBtn.y + 30, 'Load Events', function() {
			final openEvents:Void->Void = eventsFileDialog.open.bind('json', getSongPath('events.json'), 'Load Events');
			openSubState(new Prompt('This action will clear the current events.\n\nProceed?', 0, openEvents, null, options.ignoreWarnings));
		});

		var saveEventJson:FlxButton = new FlxButton(110, reloadSongJson.y, 'Save Events', function() {
			if (_song.events != null && _song.events.length > 1)
				_song.events.sort(sortEventsByTime);

			var json = {"song": {"events": _song.events}}
			var data:String = Json.stringify(json, "\t");
			eventsFileDialog.save(data, 'json', getSongPath('events.json'), 'Save Events');
		});

		var clear_events:FlxButton = new FlxButton(loadAutosaveBtn.x, 300, 'Clear events', function()
			{
				openSubState(new Prompt('This action will clear current progress.\n\nProceed?', 0, clearEvents, null, options.ignoreWarnings));
			});
		clear_events.color = FlxColor.RED;
		clear_events.label.color = FlxColor.WHITE;

		var clear_notes:FlxButton = new FlxButton(clear_events.x, clear_events.y + 30, 'Clear notes', function()
			{
				openSubState(new Prompt('This action will clear current progress.\n\nProceed?', 0, function(){for (sec in 0..._song.notes.length) {
					_song.notes[sec].sectionNotes = [];
				}
				updateGrid();
			}, null, options.ignoreWarnings));

			});
		clear_notes.color = FlxColor.RED;
		clear_notes.label.color = FlxColor.WHITE;

		var stepperSpeed:FlxUINumericStepper = new FlxUINumericStepper(10, UI_songTitle.y + 35, 0.1, 1, 0.1, 10, 1);
		stepperSpeed.value = _song.speed;
		stepperSpeed.name = 'song_speed';
		blockPressWhileTypingOnStepper.push(stepperSpeed);

		var stepperBPM:FlxUINumericStepper = new FlxUINumericStepper(10, stepperSpeed.y + 35, 1, 1, 1, 9000, 3);
		stepperBPM.value = Conductor.bpm;
		stepperBPM.name = 'song_bpm';
		blockPressWhileTypingOnStepper.push(stepperBPM);

		#if CHART_EDITOR_KEY_COUNT_STEPPER
		var stepperKeyCount:FlxUINumericStepper = new FlxUINumericStepper(10, stepperBPM.y + 35, 1, 4, 1, 10, 0);
		stepperKeyCount.value = _song.keyCount;
		stepperKeyCount.name = 'song_keyCount';
		blockPressWhileTypingOnStepper.push(stepperKeyCount);
		#end

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
		var characters:Array<String> = CharacterData.getAllCharacters();
		characters.sort(CoolUtil.alphabeticalSort);

		#if CHART_EDITOR_KEY_COUNT_STEPPER
		var daY = stepperKeyCount.y;
		#else
		var daY = stepperBPM.y;
		#end

		var player1DropDown = new FlxUIDropDownMenu(10, daY + 45, FlxUIDropDownMenu.makeStrIdLabelArray(characters, true), function(character:String)
		{
			_song.player1 = characters[Std.parseInt(character)];
			updateHeads();
		});
		player1DropDown.selectedLabel = _song.player1;
		blockPressWhileScrolling.push(player1DropDown);

		var gfVersionDropDown = new FlxUIDropDownMenu(player1DropDown.x, player1DropDown.y + 40, FlxUIDropDownMenu.makeStrIdLabelArray(characters, true), function(character:String)
		{
			_song.gfVersion = characters[Std.parseInt(character)];
			updateHeads();
		});
		gfVersionDropDown.selectedLabel = _song.gfVersion;
		blockPressWhileScrolling.push(gfVersionDropDown);

		var player2DropDown = new FlxUIDropDownMenu(player1DropDown.x, gfVersionDropDown.y + 40, FlxUIDropDownMenu.makeStrIdLabelArray(characters, true), function(character:String)
		{
			_song.player2 = characters[Std.parseInt(character)];
			updateHeads();
		});
		player2DropDown.selectedLabel = _song.player2;
		blockPressWhileScrolling.push(player2DropDown);


		////
		var stages = Stage.getAllStages();

		if (stages.length == 0) 
			stages.push("stage");
		else
			stages.sort(CoolUtil.alphabeticalSort);
		
		var stageDropDown = new FlxUIDropDownMenu(
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

		var skinDropdown = new FlxUIDropDownMenu(
			stageDropDown.x, stageDropDown.y + 40, 
			FlxUIDropDownMenu.makeStrIdLabelArray(skins, true), 
			function(skin:String){
				_song.hudSkin = skins[Std.parseInt(skin)];
			}
		);
		skinDropdown.selectedLabel = _song.hudSkin;
		blockPressWhileScrolling.push(skinDropdown);

		var arrowSkin = PlayState.SONG.arrowSkin;
		if (arrowSkin == null) arrowSkin = '';
		
		var splashSkin = PlayState.SONG.splashSkin;
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

		tab_group_song.add(clear_events);
		tab_group_song.add(clear_notes);
		tab_group_song.add(saveButton);
		tab_group_song.add(saveEventJson);

		tab_group_song.add(reloadSong);
		tab_group_song.add(reloadSongJson);
		tab_group_song.add(loadAutosaveBtn);
		tab_group_song.add(loadEventJson);
		tab_group_song.add(stepperSpeed);
		tab_group_song.add(stepperBPM);
		#if CHART_EDITOR_KEY_COUNT_STEPPER
		tab_group_song.add(stepperKeyCount);
		#end
		tab_group_song.add(reloadNotesButton);
		tab_group_song.add(noteSkinInputText);
		tab_group_song.add(noteSplashesInputText);

		tab_group_song.add(new FlxText(stepperSpeed.x, stepperSpeed.y - 15, 0, 'Song Speed:'));
		tab_group_song.add(new FlxText(stepperBPM.x, stepperBPM.y - 15, 0, 'Song BPM:'));
		#if CHART_EDITOR_KEY_COUNT_STEPPER
		tab_group_song.add(new FlxText(stepperKeyCount.x, stepperKeyCount.y - 15, 0, 'Key Count:'));
		#end

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

	var stepperBeats:FlxUINumericStepper;
	var check_mustHitSection:FlxUICheckBox;
	var check_gfSection:FlxUICheckBox;
	var check_changeBPM:FlxUICheckBox;
	var stepperSectionBPM:FlxUINumericStepper;
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

		stepperBeats = new FlxUINumericStepper(150, 25, 1, 1, 1, 9000, 3);
		stepperBeats.value = getSectionBeats();
		stepperBeats.name = 'section_beats';
		blockPressWhileTypingOnStepper.push(stepperBeats);

		check_changeBPM = new FlxUICheckBox(150, stepperBeats.y + 30, null, null, 'Change BPM', 100);
		check_changeBPM.checked = _song.notes[curSec].changeBPM;
		check_changeBPM.name = 'check_changeBPM';

		stepperSectionBPM = new FlxUINumericStepper(150, check_changeBPM.y + 20, 1, Conductor.bpm, 0, 999, 1);
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

			var addToTime:Float = Conductor.stepCrochet * (getSectionBeats() * 4 * (curSec - sectionToCopy));
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
			if (check_notesSec.checked)
				_song.notes[curSec].sectionNotes.resize(0);

			if (check_eventsSec.checked) {
				var startThing:Float = sectionStartTime();
				var endThing:Float = sectionStartTime(1);
				_song.events.filter(function(event:PsychEventNote) {
					return !(startThing <= event.strumTime && event.strumTime < endThing);
				});
			}
			updateGrid();
			updateNoteUI();
		});
		clearSectionButton.color = FlxColor.RED;
		clearSectionButton.label.color = FlxColor.WHITE;
		
		check_notesSec = new FlxUICheckBox(10, clearSectionButton.y + 25, null, null, "Notes", 35);
		check_notesSec.checked = true;
		check_eventsSec = new FlxUICheckBox(check_notesSec.x + 105, check_notesSec.y, null, null, "Events", 50);
		check_eventsSec.checked = true;

		////
		var stepperCopy:FlxUINumericStepper = null;
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
		
		stepperCopy = new FlxUINumericStepper(copyLastButton.x + 100, copyLastButton.y, 1, 1, -999, 999, 0);
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
	var stepperSusLength:FlxUINumericStepper;
	var stepperStrumTime:FlxUINumericStepper;
	var noteTypeDropDown:FlxUIDropDownMenu;
	var currentType:Int = 0;

	function addNoteUI():Void
	{
		var tab_group_note = new FlxUI(null, UI_box);
		tab_group_note.name = 'Note';

		final DECIMALS:Int = 4;

		stepperSusLength = new FlxUINumericStepper(10, 25, 1, 0, 0, Math.POSITIVE_INFINITY, DECIMALS, 1, new FlxUIInputText(0, 0, 120));
		stepperSusLength.name = 'note_susLength';
		blockPressWhileTypingOnStepper.push(stepperSusLength);

		stepperStrumTime = new FlxUINumericStepper(10, 65, 1, 0, 0, Math.POSITIVE_INFINITY, DECIMALS, 1, new FlxUIInputText(0, 0, 120));
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

		noteTypeDropDown = new FlxUIDropDownMenu(10, 105, FlxUIDropDownMenu.makeStrIdLabelArray(displayNameList, true), function(character:String)
		{
			currentType = Std.parseInt(character);
			if (curSelectedNote != null) {
				curSelectedNote.noteType = noteTypeIntMap.get(currentType);
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
			curSelectedEvent.subEventsData[curEventSelected][0] = typeName;

			updateGrid();
		}
	}

	function addEventsUI():Void
	{
		var tab_group_event = new FlxUI(null, UI_box);
		tab_group_event.name = 'Event';

		descText = new FlxText(20, 200, 0, eventStuff[0][0]);
		
		#if (sys && (hscript))
		var eventsLoaded:Map<String, Bool> = new Map();
		var directories:Array<String> = Paths.getFolders('events');
		for (directory in directories)
		{
			if (!FileSystem.exists(directory))
				continue;

			for (file in FileSystem.readDirectory(directory))
			{
				var path = haxe.io.Path.join([directory, file]);
				if (FileSystem.isDirectory(path) || !file.endsWith('.txt'))
					continue;

				var eventToCheck:String = file.substr(0, file.length - 4);
				if (eventsLoaded.exists(eventToCheck))
					continue;

				eventsLoaded.set(eventToCheck, true);
				eventStuff.push([eventToCheck, File.getContent(path)]);
			}
		}
		#end

		var leEvents:Array<String> = [];
		for (i in 0...eventStuff.length)
			leEvents.push(eventStuff[i][0]);

		var text:FlxText = new FlxText(20, 30, 0, "Event:");
		tab_group_event.add(text);

		eventDropDown = new FlxUIDropDownMenu(
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

		var text:FlxText = new FlxText(20, 90, 0, "Value 1:");
		tab_group_event.add(text);
		value1InputText = new FlxUIInputText(20, 110, 100, "");
		value1InputText.name = 'event_value1';
		blockPressWhileTypingOn.push(value1InputText);

		var text:FlxText = new FlxText(20, 130, 0, "Value 2:");
		tab_group_event.add(text);
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
					curSelectedEvent.subEventsData.remove(curSelectedEvent.subEventsData[curEventSelected]);
				}

				var eventsGroup:Array<PsychSubEventData>;
				--curEventSelected;
				if (curEventSelected < 0) 
					curEventSelected = 0;
				else if(curSelectedEvent != null && curEventSelected >= (eventsGroup = curSelectedEvent.subEventsData).length) 
					curEventSelected = eventsGroup.length - 1;

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
				var selectedEvent:Array<String> = noteEvents[curEventSelected];
				var switchPos:Int = (curEventSelected-1 < 0) ?  noteEvents.length-1 : curEventSelected-1;

				curSelectedEvent.subEventsData.remove(selectedEvent);
				curSelectedEvent.subEventsData.insert(switchPos, selectedEvent);

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
				var selectedEvent:Array<String> = noteEvents[curEventSelected];
				var switchPos:Int = (curEventSelected+1 == curSelectedEvent.subEventsData.length) ? 0 : curEventSelected+1;

				curSelectedEvent.subEventsData.remove(selectedEvent);
				curSelectedEvent.subEventsData.insert(switchPos, selectedEvent);

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
		tab_group_event.add(value1InputText);
		tab_group_event.add(value2InputText);
		tab_group_event.add(eventDropDown);
		tab_group_event.add(eventNameInput);

		UI_box.addGroup(tab_group_event);
	}

	function changeEventSelected(change:Int = 0)
	{
		if(curSelectedEvent != null) //Is event note
		{
			curEventSelected += change;
			if(curEventSelected < 0) curEventSelected = Std.int(curSelectedEvent.subEventsData.length) - 1;
			else if(curEventSelected >= curSelectedEvent.subEventsData.length) curEventSelected = 0;
			selectedEventText.text = 'Selected Event: ' + (curEventSelected + 1) + ' / ' + curSelectedEvent.subEventsData.length;
		}
		else
		{
			curEventSelected = 0;
			selectedEventText.text = 'Selected Event: None';
		}
		updateNoteUI();
	}

	function setAllLabelsOffset(button:FlxButton, x:Float, y:Float)
	{
		for (point in button.labelOffsets)
		{
			point.set(x, y);
		}
	}

	var metronomeStepper:FlxUINumericStepper;
	var metronomeOffsetStepper:FlxUINumericStepper;

	static var lastSelectedTrack = "Voices";
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
		lastSelectedTrack = trackName;
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
		var chartPath = Reflect.field(_song, "_path");
		return (chartPath==null ? "" : Path.addTrailingSlash(Path.directory(chartPath))) + file;
	}

	function addMetadataUI() {
		var tab_group = new FlxUI(null, UI_box);
		tab_group.name = 'Metadata';

		var songNameInputText = new FlxUIInputText(10, 30, 180, _song.metadata.songName);
		songNameInputText.name = "metadata_songName";
		tab_group.add(songNameInputText);
		blockPressWhileTypingOn.push(songNameInputText);

		var artistInputText = new FlxUIInputText(10, songNameInputText.y + 30, 180, _song.metadata.artist);
		artistInputText.name = "metadata_artist";
		tab_group.add(artistInputText);
		blockPressWhileTypingOn.push(artistInputText);

		var charterInputText = new FlxUIInputText(10, artistInputText.y + 30, 180, _song.metadata.charter);
		charterInputText.name = "metadata_charter";
		tab_group.add(charterInputText);
		blockPressWhileTypingOn.push(charterInputText);

		var modcharterInputText = new FlxUIInputText(10, charterInputText.y + 30, 180, _song.metadata.modcharter);
		modcharterInputText.name = "metadata_modcharter";
		tab_group.add(modcharterInputText);
		blockPressWhileTypingOn.push(modcharterInputText);

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
			}
		});

		var loadButton = new FlxButton(10, modcharterInputText.y + 30, "Load Metadata", function() {			
			fileDialog.open('json', getSongPath("metadata.json"), 'Load Metadata');
		});

		////
		var saveButton = new FlxButton(10, loadButton.y + 30, "Save Metadata", function()
		{
			_song.metadata.songName = songNameInputText.text;
			_song.metadata.artist = artistInputText.text;
			_song.metadata.charter = charterInputText.text;
			_song.metadata.modcharter = modcharterInputText.text;

			var data:String = Json.stringify(_song.metadata, "\t");
			fileDialog.save(data, 'json', getSongPath("metadata.json"), 'Save Metadata');
		});

		////
		tab_group.add(new FlxText(songNameInputText.x, songNameInputText.y - 15, 0, 'Song Name:'));
		tab_group.add(new FlxText(artistInputText.x, artistInputText.y - 15, 0, 'Artist:'));
		tab_group.add(new FlxText(charterInputText.x, charterInputText.y - 15, 0, 'Charter:'));
		tab_group.add(new FlxText(modcharterInputText.x, modcharterInputText.y - 15, 0, 'Modcharter:'));
		
		tab_group.add(songNameInputText);
		tab_group.add(artistInputText);
		tab_group.add(charterInputText);
		tab_group.add(modcharterInputText);

		tab_group.add(loadButton);
		tab_group.add(saveButton);

		tab_group.add(new FlxText(10, saveButton.y + 30, UI_box.width - 20, 'NOTE: Metadata is saved and loaded as a separate file, it is not included in the chart file!'));

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
		waveformTrackDropDown = new FlxUIDropDownMenu(
			10, 100, 
			FlxUIDropDownMenu.makeStrIdLabelArray(trackNamesArray, false), 
			selectTrack
		);
		blockPressWhileScrolling.push(waveformTrackDropDown);

		//
		trackVolumeSlider = new FlxUISlider(
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

		metronomeStepper = new FlxUINumericStepper(15, 55, 5, _song.bpm, 1, 9000, 3);
		metronomeOffsetStepper = new FlxUINumericStepper(metronomeStepper.x + 146, metronomeStepper.y, 25, 0, 0, 1000, 1);
		blockPressWhileTypingOnStepper.push(metronomeStepper);
		blockPressWhileTypingOnStepper.push(metronomeOffsetStepper);

		var disableAutoScrolling = new FlxUICheckBox(metronome.x + 150, metronome.y, null, null, "Disable Section Autoscroll", 120);
		disableAutoScrolling.callback = () -> {options.noAutoScroll = disableAutoScrolling.checked;}
		disableAutoScrolling.checked = options.noAutoScroll == true;

		var sliderHitVol = new FlxUISlider(this, 'hitsoundVolume', 10, startY + 90, 0, 1, 125, null, 5, FlxColor.WHITE, FlxColor.BLACK);
		sliderHitVol.nameLabel.text = 'Hitsound Volume';
		sliderHitVol.value = hitsoundVolume;

		var sliderRate = new FlxUISlider(this, 'playbackSpeed', 68, 325, 0.5, 3, 150, null, 5, FlxColor.WHITE, FlxColor.BLACK);
		sliderRate.nameLabel.text = 'Playback Rate';
		sliderRate.value = playbackSpeed;

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

	var finalSectionNumber:Int = 0;
	var tracksCompleted:Bool = false;
	function onTrackCompleted(){
		tracksCompleted = true;
		Conductor.songPosition = 0.0;
		for (snd in tracks)
			snd.stop();
	}

	function loadTracks():Void
	{
		Conductor.songPosition = sectionStartTime();

		var songTrackNames:Array<String> = [];
		var jsonTracks = _song.tracks;

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
			
			newTrack.onComplete = onTrackCompleted;

			songLength = Math.max(songLength, newTrack.length);

			soundTracksMap.set(trackName, newTrack);
			tracks.push(newTrack);
		}
		
		inst = soundTracksMap.get(jsonTracks.inst[0]);
		if (inst == null)
			inst = createMusicTrack();
		inst.volume = 0.6;

		//// get final section accessible section
		var prevSec = curSec;
		var finalSectionStartTime:Float;

		curSec = _song.notes.length - 1;
		while ((finalSectionStartTime = sectionStartTime(0)) > songLength)
			curSec--;

		finalSectionNumber = curSec + 1;
		curSec = prevSec;
	}

	override function getEvent(id:String, sender:Dynamic, data:Dynamic, ?params:Array<Dynamic>)
	{
		if (id == FlxUICheckBox.CLICK_EVENT)
		{
			var check:FlxUICheckBox = cast sender;
			var label = check.getLabel().text;
			switch (label)
			{
				case 'Must hit section':
					_song.notes[curSec].mustHitSection = check.checked;

					updateGrid();
					updateHeads();
				case 'GF section':
					_song.notes[curSec].gfSection = check.checked;

					updateGrid();
					updateHeads();
				case 'Change BPM':

					_song.notes[curSec].changeBPM = check.checked;
					FlxG.log.add('changed bpm shit');
				case "Alt Animation":
					_song.notes[curSec].altAnim = check.checked;
			}
		}
		else if (id == FlxUINumericStepper.CHANGE_EVENT)
		{
			var nums:FlxUINumericStepper = cast sender;
			var wname = nums.name;

			switch(wname) {
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
						curSelectedNote.sustainLength = nums.value;
						updateGrid();
						updateNoteSteps();
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

			switch (sender.name) {
				case 'song_title':
					_song.song = sender.text;

				case 'song_noteSplashes':
					_song.splashSkin = sender.text;

				case 'event_value1':
					if (curSelectedEvent != null) {
						curSelectedEvent.subEventsData[curEventSelected][1] = sender.text;
						updateGrid();
					}

				case 'event_value2':
					if (curSelectedEvent != null) {
						curSelectedEvent.subEventsData[curEventSelected][2] = sender.text;
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
			}	
		}
		else if (id == FlxUISlider.CHANGE_EVENT)
		{
			var sender:FlxUISlider = cast sender;

			
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

	var inputBlocked = false;
	function checkInputBlocked():Bool {
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

	override function update(elapsed:Float)
	{
		if (tracksCompleted){
			tracksCompleted = false;
			trace("track completed");
			changeSection(0, true);
		}

		FlxG.mouse.visible = true; //cause reasons. trust me

		if (!options.noAutoScroll) 
		{
			if (Math.ceil(strumLine.y) >= gridBG.height){
				var nextSection = curSec + 1;
				if (_song.notes[nextSection] == null)
					pushSection();

				changeSection(nextSection, false);
			} else if(strumLine.y < -10)
				changeSection(curSec - 1, false);
		}

		var movedDummyY:Bool = false;
		var onGrid:Bool =	FlxG.mouse.x >= gridBG.x
						&&	FlxG.mouse.x <	gridBG.x + gridBG.width
						&&	FlxG.mouse.y >= gridBG.y
						&&	FlxG.mouse.y <	gridBG.y + gridBG.height;

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
			if (FlxG.mouse.overlaps(curRenderedNotes))
			{
				curRenderedNotes.forEachAlive(function(note:Note)
				{
					if (FlxG.mouse.overlaps(note))
					{
						if (FlxG.keys.pressed.CONTROL)
						{
							selectNote(note);
						}
						else if (FlxG.keys.pressed.ALT)
						{
							selectNote(note);
							curSelectedNote.noteType = noteTypeIntMap.get(currentType);
							updateGrid();
						}
						else
						{
							//trace('tryin to delete note...');
							deleteNote(note);
						}
					}
				});
			}
			else if (onGrid){
				FlxG.log.add('added note');
				var noteTime:Float = sectionStartTime() + getStrumTime(dummyArrow.y * (getSectionBeats() / 4), false);
				var column:Int = Math.floor(FlxG.mouse.x / GRID_SIZE) - 1;
				(column < 0) ? addEvent(noteTime) : addNote(noteTime, column);
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
			if (!heldNotesClick.empty()) heldNotesClick = [];
			startDummyY = null;
			curDummyY = null;
		}

		if (checkInputBlocked() != inputBlocked) {
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

		if (Conductor.playing) {
			updateSongPosition();

			if (Conductor.songPosition > inst.length)
				changeSection(0, true);
		}else {
			for (track in tracks) 
				track.time = Conductor.songPosition;
		}

		Conductor.updateSteps();

		strumLineUpdateY();
		camPos.y = strumLine.y;

		if (strumLineNotes.visible = quant.visible = options.vortex) {
			var alpha = inst.playing ? 1 : 0.35;
			for (receptor in strumLineNotes){
				receptor.y = strumLine.y;
				receptor.alpha = alpha;
			}
		}

		bpmTxt.text =
		"Time: " + Std.string(FlxMath.roundDecimal(Conductor.songPosition / 1000, 2)) + " / " + Std.string(FlxMath.roundDecimal(inst.length / 1000, 2)) +
		"\n\nSection: " + curSec +
		"\nBeat: " + math.CoolMath.floorDecimal(curDecBeat, 2) +
		"\nStep: " + curStep;

		playedSound.resize(0);
		//var updateSelectedNote = curSelectedNote != null;

		curRenderedNotes.forEachAlive(function(note:Note) {
			//if (updateSelectedNote) 
			{
				if (note.chartData == curSelectedNote || note.chartData == curSelectedEvent)
				{
					colorSine += elapsed;

					var colorVal:Float = 0.7 + 0.3 * FlxMath.fastSin(Math.PI * colorSine);
					var colorVal:Int = Math.round(colorVal * 255);

					note.color = FlxColor.fromRGB(colorVal, colorVal, colorVal, 255);

					//updateSelectedNote = false;
				}
			}
			
			if(!inst.playing)
				note.editorHitBeat = 0;

			if (note.beat <= Conductor.curDecBeat) 
			{
				note.editorHitBeat = note.beat;
				if (!note.wasGoodHit && inst.playing) 
				{
					note.wasGoodHit = true;
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

				note.alpha = 0.4;
			}else if(note.editorHitBeat < Conductor.curDecBeat){
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
			// Change mustHitSection value
			var mustHit = !_song.notes[curSec].mustHitSection;
			_song.notes[curSec].mustHitSection = mustHit;
			check_mustHitSection.checked = mustHit;

			if (!FlxG.keys.pressed.CONTROL) {
				// Move notes to accomodate for the change
				for (i in 0..._song.notes[curSec].sectionNotes.length) {
					var note:NoteData = _song.notes[curSec].sectionNotes[i];
					note.column = (note.column + _song.keyCount) % (_song.keyCount * 2);
					_song.notes[curSec].sectionNotes[i] = note;
				}
			}

			updateGrid();
			updateHeads();	
		}	

		if (curSelectedNote != null) {
			if (FlxG.keys.justPressed.E)
				changeNoteSustain(Conductor.stepCrochet);
			if (FlxG.keys.justPressed.Q)
				changeNoteSustain(-Conductor.stepCrochet);
		}

		if (FlxG.keys.justPressed.Z && FlxG.keys.pressed.CONTROL) {
			undo();
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
			(FlxG.keys.pressed.SHIFT) ? changeSection(0, true) : resetSection();

		if (FlxG.mouse.wheel != 0) {
			if (!options.mouseScrollingQuant)
				Conductor.songPosition -= (FlxG.mouse.wheel * Conductor.stepCrochet);
			else{
				var snap = Conductor.stepCrochet / quantizationMult;
				Conductor.songPosition = CoolUtil.snap(Conductor.songPosition, snap) - (snap * FlxG.mouse.wheel);
			}

			pauseTracks();
		}

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
						addNote(Conductor.songPosition, i, currentType, false);
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
			changeSection((nextSection < 0) ? finalSectionNumber + nextSection : nextSection);
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
		else if (FlxG.keys.justPressed.BACKSPACE) {
			PlayState.chartingMode = false;
			MusicBeatState.switchState(new funkin.states.editors.MasterEditorMenu());
			MusicBeatState.playMenuMusic(true);

			FlxG.mouse.visible = false;
		}
	}

	function updateZoom() {
		var daZoom:Float = zoomList[curZoom];
		var zoomThing:String = '1 / ' + daZoom;
		if(daZoom < 1) zoomThing = Math.round(1 / daZoom) + ' / 1';
		zoomTxt.text = 'Zoom: ' + zoomThing;
		reloadGridLayer();
	} 

	var lastSecBeats:Float = 0;
	var lastSecBeatsNext:Float = 0;
	function reloadGridLayer() 
	{
		wipeGroup(gridLayer);
		
		////
		final gridColor1:FlxColor = 0xffe7e6e6;
		final gridColor2:FlxColor = 0xffd9d5d5;
		
		var leBeats:Float = getSectionBeats();
		var nextBeats:Float = getSectionBeats(curSec + 1) ?? 0;
		var totalBeats:Float = leBeats + nextBeats;
		
		var gridWidth:Int = 1 + _song.keyCount * 2;
		var gridHeight:Int = Math.floor(leBeats * 4 * zoomList[curZoom]); 

		gridBG = FlxGridOverlay.create(1, 1, gridWidth, gridHeight, gridColor1, gridColor2);
		gridBG.antialiasing = false;
		gridBG.scale.set(GRID_SIZE, GRID_SIZE);
		gridBG.updateHitbox();
		gridLayer.add(gridBG);
		
		var totalHeight:Float = gridBG.height;

		// next section grid
		var nextStartTime:Float = sectionStartTime(1); 
		if (nextStartTime <= inst.length && nextBeats > 0) {
			var gridHeight:Int = Math.floor(nextBeats * 4 * zoomList[curZoom]); 
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
		for (i in 1...Math.floor(totalBeats)) {
			var beatsep1:FlxSprite = CoolUtil.blankSprite(gridBG.width, 1, 0xFFFF0000);
			beatsep1.setPosition(gridBG.x, (i * GRID_SIZE * 4) * zoomList[curZoom]);
			beatsep1.alpha = 0.25;
			gridLayer.add(beatsep1);
		}
		
		// player - opponent separator
		var gridBlackLine:FlxSprite = CoolUtil.blankSprite(2, totalHeight, FlxColor.BLACK);
		gridBlackLine.x = gridBG.x + gridBG.width - (GRID_SIZE * _song.keyCount);
		gridLayer.add(gridBlackLine);

		// event separator
		var gridBlackLine:FlxSprite = CoolUtil.blankSprite(2, totalHeight, FlxColor.BLACK);
		gridBlackLine.x = gridBG.x + GRID_SIZE;
		gridLayer.add(gridBlackLine);

		updateWaveform();
		updateGrid();

		lastSecBeats = leBeats;
		lastSecBeatsNext = (nextStartTime > inst.length) ? 0 : nextBeats;
	}

	function strumLineUpdateY()
	{
		strumLine.y = getYfromStrum((Conductor.songPosition - sectionStartTime()) / zoomList[curZoom] % (Conductor.stepCrochet * 16)) / (getSectionBeats() / 4);
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

		var steps:Int = Math.round(getSectionBeats() * 4);
		var st:Float = sectionStartTime();
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

	function setNoteSustain(value:Float, ?note:NoteData):Void
	{
		if (note == null)
			note = curSelectedNote;

		if (note != null) {
			note.sustainLength = Math.max(value, 0);

			updateNoteUI();
			updateGrid();
		}
	}

	function changeNoteSustain(value:Float, ?note:NoteData):Void
	{
		if (note == null)
			note = curSelectedNote;

		if (note != null)
			setNoteSustain(note.sustainLength + value, note);
	}

	// Go to the current section's start time
	function resetSection():Void {
		Conductor.songPosition = sectionStartTime();
		Conductor.updateSteps();
		pauseTracks();

		updateGrid();
		updateSectionUI();
		updateWaveform();
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

			var blah1:Float = getSectionBeats();
			var blah2:Float = (sectionStartTime(1) > songLength) ? 0 : getSectionBeats(curSec + 1);
	
			if (blah1 != lastSecBeats || blah2 != lastSecBeatsNext) {
				reloadGridLayer();
			}else {
				updateGrid();
				updateWaveform();
			}
			
			updateSectionUI();
		}
		stepperStrumTime.stepSize = Conductor.stepCrochet;
		stepperSusLength.stepSize = Conductor.stepCrochet;
	}

	function updateSectionUI():Void
	{
		var sec = _song.notes[curSec];

		stepperBeats.value = getSectionBeats();
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

		leftIcon.setPosition(GRID_SIZE * _song.keyCount * 0.5 - leftIcon.width * 0.5, 5);
		rightIcon.setPosition(GRID_SIZE * _song.keyCount * 1.5 - rightIcon.width * 0.5, 5);
	}

	function updateNoteSteps():Void
	{
		var strumStep:Float = Conductor.getStep(curSelectedNote.strumTime);
		var sustainSteps:Float = 0;

		if (curSelectedNote.sustainLength > 0) {
			var endStep:Float = Conductor.getStep(curSelectedNote.strumTime + curSelectedNote.sustainLength);
			sustainSteps = endStep - strumStep;
		}

		labelSusLength.text = 'Sustain Length: (${sustainSteps} Steps)';
		labelStrumTime.text = 'Strum Time: (Step ${strumStep})';
	}

	function updateNoteUI():Void
	{
		if (curSelectedNote != null) {
			updateNoteSteps();

			stepperStrumTime.value = curSelectedNote.strumTime;
			stepperSusLength.value = curSelectedNote.sustainLength;

			currentType = noteTypeMap.get(curSelectedNote.noteType);
			noteTypeDropDown.selectedLabel = (currentType <= 0) ? '' : currentType + '. ' + curSelectedNote.noteType;		
		}

		if (curSelectedEvent != null) {
			var eventData:PsychSubEventData = curSelectedEvent.subEventsData[curEventSelected];

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
		}
	}

	
	inline function fuckFloatingPoints(n:Float):Float // haha decimals
		return CoolUtil.snap(n, Conductor.jackLimit);

	inline function wipeGroup(group:FlxTypedGroup<Dynamic>)
	{
		for (obj in group) obj.destroy();
		group.clear();	
	}

	function updateGrid():Void
	{
		wipeGroup(curRenderedNotes);
		wipeGroup(curRenderedSustains);
		wipeGroup(curRenderedNoteType);
		wipeGroup(nextRenderedNotes);
		wipeGroup(nextRenderedSustains);

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

		// CURRENT SECTION
		for (i in _song.notes[curSec].sectionNotes)
		{
			var note:Note = setupNoteData(i, false);
			curRenderedNotes.add(note);
			if (note.sustainLength > 0)
			{
				curRenderedSustains.add(setupSusNote(note));
			}

			if (note.noteType.length > 0) {
				var typeInt:Null<Int> = noteTypeMap.get(note.noteType);
				var theType:String = (typeInt == null) ? '?' : '$typeInt';

				var daText:AttachedFlxText = new AttachedFlxText(0, 0, 100, theType, 24);
				daText.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
				daText.xAdd = -32;
				daText.yAdd = 6;
				daText.borderSize = 1;
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
				var note:Note = setupEventData(i, false);
				curRenderedNotes.add(note);

				var text:String = 'Event: ' + note.eventName + ' (' + Math.floor(note.strumTime) + ' ms)' + '\nValue 1: ' + note.eventVal1 + '\nValue 2: ' + note.eventVal2;
				if(note.eventLength > 1) text = note.eventLength + ' Events:\n' + note.eventName;

				var daText:AttachedFlxText = new AttachedFlxText(0, 0, 400, text, 12);
				daText.setFormat(Paths.font("vcr.ttf"), 12, FlxColor.WHITE, RIGHT, FlxTextBorderStyle.OUTLINE_FAST, FlxColor.BLACK);
				daText.xAdd = -410;
				daText.borderSize = 1;
				if(note.eventLength > 1) daText.yAdd += 8;
				curRenderedNoteType.add(daText);
				daText.sprTracker = note;

				////trace('test: ${i[0]}, startThing: $startThing, endThing: $endThing');
			}
		}

		// NEXT SECTION
		if(curSec < _song.notes.length-1) {
			for (i in _song.notes[curSec+1].sectionNotes)
			{
				var note:Note = setupNoteData(i, true);
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
				var note:Note = setupEventData(i, true);
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

	function setupNoteData(i:NoteData, isNextSection:Bool):Note
	{
		var curSection = _song.notes[curSec];
		var nextSection = _song.notes[curSec+1];
		var noteSection = isNextSection ? nextSection : curSection;

		var daField:Int = Math.floor(i.column / _song.keyCount);

		var note:Note = new Note(i.strumTime, i.column % _song.keyCount, null, daField, (i.sustainLength <= 0 ? TAP : HEAD), true);
		note.chartData = i;
		note.realColumn = i.column;
		note.mustPress = noteSection.mustHitSection ? (daField==0) : (daField!=0);
		note.sustainLength = i.sustainLength;
		note.canQuant = useQuantNotes;
		note.reloadNote();
		initNoteType(i.noteType);
		note.noteType = i.noteType;

		////
		note.setGraphicSize(GRID_SIZE, GRID_SIZE);
		note.updateHitbox();
		note.x = Math.floor(i.column * GRID_SIZE) + GRID_SIZE;

		if (isNextSection && curSection.mustHitSection != nextSection.mustHitSection) {
			if(i.column >= _song.keyCount) {
				note.x -= GRID_SIZE * _song.keyCount;
			} else {
				note.x += GRID_SIZE * _song.keyCount;
			}
		}

		note.editorHitBeat = note.beat;
		note.wasGoodHit = note.beat <= Conductor.curBeat;

		var beats:Float = getSectionBeats(isNextSection ? 1 : 0);
		note.y = getYfromStrumNotes(note.strumTime - sectionStartTime(), beats);
		if(note.y < -150) note.y = -150;
		return note;
	}

	function setupEventData(i:PsychEventNote, isNextSection:Bool) {
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

		note.setGraphicSize(GRID_SIZE, GRID_SIZE);
		note.updateHitbox();
		note.x = Math.floor(-1 * GRID_SIZE) + GRID_SIZE;

		note.editorHitBeat = note.beat;
		note.wasGoodHit = note.beat <= Conductor.curBeat;

		var beats:Float = getSectionBeats(isNextSection ? 1 : 0);
		note.y = getYfromStrumNotes(note.strumTime - sectionStartTime(), beats);
		if(note.y < -150) note.y = -150;
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
			for (i in _song.notes[curSec].sectionNotes) {
				if (i != curSelectedNote && i == note.chartData) {
					curSelectedNote = i;
					break;
				}
			}
		}else {
			for (i in _song.events) {
				if (i != curSelectedEvent && i.strumTime == note.strumTime) {
					curSelectedEvent = i;
					curEventSelected = Std.int(curSelectedEvent.subEventsData.length) - 1;
					changeEventSelected();
					break;
				}
			}
		}

		updateGrid();
		updateNoteUI();
	}

	function deleteNote(note:Note):Void
	{
		if (note.column > -1) {
			//Normal Notes
			var currentSection = _song.notes[curSec];
			for (i in currentSection.sectionNotes) {
				if (i == note.chartData) {
					// trace('FOUND EVIL NOTE');
					if (i == curSelectedNote) {
						curSelectedNote = null;
					} 
					currentSection.sectionNotes.remove(i);
					break;
				}
			}
		}else {
			//Events
			for (i in _song.events) {
				if (i == note.chartData) {
					// trace('FOUND EVIL EVENT');
					if (i == curSelectedEvent) {
						curSelectedEvent = null;
						changeEventSelected();
					}
					_song.events.remove(i);
					break;
				}
			}
		}

		updateGrid();
	}

	function clearSong():Void
	{
		for (daSection in 0..._song.notes.length)
		{
			_song.notes[daSection].sectionNotes = [];
		}

		updateGrid();
	}

	private function addNote(noteStrum:Float, column:Int, type:Null<Int> = null, click:Bool=true):Void
	{
		var noteSus:Float = 0.0;
		var noteTypeName:String = noteTypeIntMap.get(type ?? currentType);
		var heldNotes = (click ? heldNotesClick : heldNotesVortex);

		curSelectedNote = NoteData.fromValues(noteStrum, column, noteSus, noteTypeName);
		_song.notes[curSec].sectionNotes.push(curSelectedNote);
		heldNotes[column] = curSelectedNote;

		if (FlxG.keys.pressed.CONTROL) {
			var mirrorColumn = (column + _song.keyCount) % (_song.keyCount * 2);
			var note = NoteData.fromValues(noteStrum, mirrorColumn, noteSus, noteTypeName);
			_song.notes[curSec].sectionNotes.push(note);
			heldNotes[mirrorColumn] = note;
		}

		//trace(noteData + ', ' + noteStrum + ', ' + curSec);

		updateGrid();
		updateNoteUI();
	}

	private function addEvent(noteStrum:Float) {
		var eventType:String = eventNameInput.text; //eventStuff[Std.parseInt(eventDropDown.selectedId)][0];
		var text1:String = value1InputText.text;
		var text2:String = value2InputText.text;

		curSelectedEvent = PsychEventNote.fromValues(noteStrum, [[eventType, text1, text2]]);
		_song.events.push(curSelectedEvent);
		curEventSelected = 0;
		changeEventSelected();
		updateGrid();
	}

	// will figure this out l8r
	function redo()
	{
		//_song = redos[curRedoIndex];
	}

	function undo()
	{
		//redos.push(_song);
		undos.pop();
		//_song.notes = undos[undos.length - 1];
		///trace(_song.notes);
		//updateGrid();
	}

	function getStrumTime(yPos:Float, doZoomCalc:Bool = true):Float
	{
		var leZoom:Float = zoomList[curZoom];
		if(!doZoomCalc) leZoom = 1;
		return FlxMath.remapToRange(yPos, gridBG.y, gridBG.y + gridBG.height * leZoom, 0, 16 * Conductor.stepCrochet);
	}

	function getYfromStrum(strumTime:Float, doZoomCalc:Bool = true):Float
	{
		var leZoom:Float = zoomList[curZoom];
		if(!doZoomCalc) leZoom = 1;
		return FlxMath.remapToRange(strumTime, 0, 16 * Conductor.stepCrochet, gridBG.y, gridBG.y + gridBG.height * leZoom);
	}
	
	function getYfromStrumNotes(strumTime:Float, beats:Float):Float
	{
		var value:Float = strumTime / (beats * 4 * Conductor.stepCrochet);
		return GRID_SIZE * beats * 4 * zoomList[curZoom] * value + gridBG.y;
	}

	function getNotes():Array<Dynamic>
	{
		var noteData:Array<Dynamic> = [];

		for (i in _song.notes)
		{
			noteData.push(i.sectionNotes);
		}

		return noteData;
	}

	function clearEvents() {
		_song.events = [];
		updateGrid();
	}

	function autosaveSong():Void
	{		
		options.autosave = Json.stringify(_song);
		FlxG.save.data.chartingStateOptions = options;
		FlxG.save.flush();
	}

	function loadJson(song:String):Void
	{
		var daJson:SwagSong = ChartData.loadFromJson(song.toLowerCase(), song.toLowerCase());

		if (daJson == null){
			openSubState(new Prompt('An error ocurred while loading the JSON file', 0, null, null, false, "OK", "OK"));
		}else{
			PlayState.song = null;
			PlayState.SONG = daJson;
			MusicBeatState.resetState();
		}
	}
	
	function browseJson():Void
	{
		_file = new FileReference();
		_file.addEventListener(Event.SELECT, onJsonSelected);
		_file.addEventListener(Event.CANCEL, onSaveCancel);
		_file.browse([new openfl.net.FileFilter("JSON file", "*.json", "JSON")]);
	}
	
	function onJsonSelected(e){
		trace(_file.data.toString());

		_file.removeEventListener(Event.SELECT, onJsonSelected);
		_file.removeEventListener(Event.CANCEL, onSaveCancel);
		_file = null;
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

		Reflect.deleteField(_song, "metadata");

		if (Reflect.hasField(_song, "_path")) {
			fileName = haxe.io.Path.withoutDirectory(Reflect.field(_song, "_path"));
			Reflect.deleteField(_song, "_path");
		}else {
			fileName = Paths.formatToSongPath(_song.song) + ".json";
		}

		var json = {"song": _song};
		var data:String = Json.stringify(json, "\t");

		if ((data != null) && (data.length > 0))
		{
			_file = new FileReference();
			_file.addEventListener(Event.COMPLETE, onSaveComplete);
			_file.addEventListener(Event.CANCEL, onSaveCancel);
			_file.addEventListener(IOErrorEvent.IO_ERROR, onSaveError);
			_file.save(data.trim(), fileName);
		}
	}

	function onSaveComplete(_):Void
	{
		_file.removeEventListener(Event.COMPLETE, onSaveComplete);
		_file.removeEventListener(Event.CANCEL, onSaveCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		_file = null;
		FlxG.log.notice("Successfully saved LEVEL DATA.");
	}

	/**
	 * Called when the save file dialog is cancelled.
	 */
	function onSaveCancel(_):Void
	{
		_file.removeEventListener(Event.COMPLETE, onSaveComplete);
		_file.removeEventListener(Event.CANCEL, onSaveCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		_file = null;
	}

	/**
	 * Called if there is an error while saving the gameplay recording.
	 */
	function onSaveError(_):Void
	{
		_file.removeEventListener(Event.COMPLETE, onSaveComplete);
		_file.removeEventListener(Event.CANCEL, onSaveCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		_file = null;
		FlxG.log.error("Problem saving Level data");
	}

	function getSectionBeats(?section:Null<Int> = null)
	{
		if (section == null) section = curSec;
		var val:Null<Float> = null;
		
		if(_song.notes[section] != null) val = _song.notes[section].sectionBeats;
		return val != null ? val : 4;
	}
}

/** dont sort my shit **/
class CustomFlxUITabMenu extends FlxUITabMenu {
	override function sortTabs(a, b):Int
		return 0;
}