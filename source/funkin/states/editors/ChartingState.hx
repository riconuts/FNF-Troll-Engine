package funkin.states.editors;

import funkin.objects.AttachedFlxText;
import funkin.objects.hud.HealthIcon;
import funkin.scripts.FunkinHScript;
import funkin.scripts.FunkinScript;

import funkin.Conductor.BPMChangeEvent;
import funkin.data.Section;
import funkin.data.Song;

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
import haxe.format.JsonParser;
import openfl.events.Event;
import openfl.events.IOErrorEvent;
import openfl.net.FileReference;
import openfl.utils.ByteArray;
import openfl.utils.Assets as OpenFlAssets;
import openfl.media.Sound;
import lime.media.AudioBuffer;
import haxe.io.Bytes;
import openfl.geom.Rectangle;
import flixel.util.FlxSort;

#if discord_rpc
import funkin.api.Discord.DiscordClient;
#end

#if sys
import sys.io.File;
import sys.FileSystem;
import openfl.media.Sound;
#end

using StringTools;
using Lambda;

@:access(flixel.sound.FlxSound._sound)
@:access(openfl.media.Sound.__buffer)

class ChartingState extends MusicBeatState
{
	public static var instance:ChartingState;
	
	public var notetypeScripts:Map<String, FunkinHScript> = [];
	public static var noteTypeList:Array<String> = //Used for backwards compatibility with 0.1 - 0.3.2 charts, though, you should add your hardcoded custom note types here too.
	[
		'',
		'Alt Animation',
		'Hey!',
		'Hurt Note',
		'GF Sing',
		'No Animation'
	];

    var hudList:Array<String> = [
        'Default'
    ];

	private var noteTypeIntMap:Map<Int, String> = new Map<Int, String>();
	private var noteTypeMap:Map<String, Null<Int>> = new Map<String, Null<Int>>();
	public var ignoreWarnings = false;
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
		["Constant SV", "Speed changes which don't affect note positions.\n(For example, a speed of 0 stops notes\ninstead of making them go onto the receptors.)\nValue 1: New Speed"],
		["Mult SV", "Speed changes which don't affect note positions.\n(For example, a speed of 0 stops notes\ninstead of making them go onto the receptors.)\nValue 1: Speed Multiplier"]
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
	var CAM_OFFSET:Int = GRID_SIZE * 5;

	var dummyArrow:FlxSprite;

	var curRenderedSustains:FlxTypedGroup<FlxSprite>;
	var curRenderedNotes:FlxTypedGroup<Note>;
	var curRenderedNoteType:FlxTypedGroup<FlxText>;

	var nextRenderedSustains:FlxTypedGroup<FlxSprite>;
	var nextRenderedNotes:FlxTypedGroup<Note>;

	var gridBG:FlxSprite;
	var nextGridBG:FlxSprite;

	var daquantspot = 0;
	var curEventSelected:Int = 0;
	var curUndoIndex = 0;
	var curRedoIndex = 0;
	var _song:SwagSong;
	/* WILL BE THE CURRENT / LAST PLACED NOTE */
	var curSelectedNote:Array<Dynamic> = null;

	/** HELD NOTE FROM CLICKING **/
	private var heldNotesClick:Array<Array<Dynamic>> = []; 
	/** HELD NOTES FROM VORTEX **/
	private var heldNotesVortex:Array<Array<Dynamic>> = []; 

	var tempBpm:Float = 0;

	var extraTracks:Array<FlxSound> = [];
	var vocals:FlxSound = null;
	var soundTracksMap:Map<String, FlxSound> = [];

	var leftIcon:HealthIcon;
	var rightIcon:HealthIcon;

	var value1InputText:FlxUIInputText;
	var value2InputText:FlxUIInputText;
	var currentSongName:String;

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
	private var blockPressWhileScrolling:Array<FlxUIDropDownMenuCustom> = [];

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

	public var playbackSpeed:Float = 1.0;

	public static var vortex:Bool = false;
	public var mouseQuant:Bool = false;

	override function create()
	{
		persistentUpdate = true;
		persistentDraw = true;

		instance = this;
		PlayState.chartingMode = true;

		if (PlayState.SONG != null)
			_song = PlayState.SONG;
		else
		{
			_song = {
				song: 'Test',
				bpm: 150.0,
				speed: 1,

				stage: 'stage',

				player1: 'bf',
				player2: 'dad',
				gfVersion: 'gf',

				arrowSkin: '',
				splashSkin: '',

				needsVoices: true,
				extraTracks: [],

				validScore: false,

				notes: [],
				events: [],
			};
			pushSection();
			PlayState.SONG = _song;
		}
		/*
		if(_song.metadata==null){
			_song.metadata = {
				artist: "Unspecified",
				charter: "Unspecified"
			}
		}
		*/

		// Paths.clearMemory();

		#if discord_rpc
		// Updating Discord Rich Presence
		DiscordClient.changePresence("Chart Editor", StringTools.replace(_song.song, '-', ' '));
		#end

		vortex = FlxG.save.data.chart_vortex;
		ignoreWarnings = FlxG.save.data.ignoreWarnings;

		var bg:FlxSprite = new FlxSprite(0, 0, Paths.image('menuDesat'));
		bg.color = FlxColor.fromHSB(Std.random(360), 0x16 /255, 0x24/255);
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

		leftIcon.setPosition(GRID_SIZE + 10, 5);
		rightIcon.setPosition(GRID_SIZE * 5.2, 5);

		curRenderedSustains = new FlxTypedGroup<FlxSprite>();
		curRenderedNotes = new FlxTypedGroup<Note>();
		curRenderedNoteType = new FlxTypedGroup<FlxText>();

		nextRenderedSustains = new FlxTypedGroup<FlxSprite>();
		nextRenderedNotes = new FlxTypedGroup<Note>();

		if(curSec >= _song.notes.length) curSec = _song.notes.length - 1;

		FlxG.mouse.visible = true;
		//FlxG.save.bind('funkin', 'ninjamuffin99');

		tempBpm = _song.bpm;

		pushSection();

		// sections = _song.notes;

		currentSongName = Paths.formatToSongPath(_song.song);

		Conductor.changeBPM(_song.bpm);
		Conductor.mapBPMChanges(_song);

		loadSong();
		fixEvents();

		bpmTxt = new FlxText(12, 50, 0, "", 20);
		bpmTxt.setFormat(null, 18, 0xFFFFFFFF, LEFT, FlxTextBorderStyle.OUTLINE, 0xFF000000);
		bpmTxt.borderSize = 2;
		bpmTxt.scrollFactor.set();
		add(bpmTxt);

		strumLine = new FlxSprite(0, 50).makeGraphic(Std.int(GRID_SIZE * 9), 4);
		add(strumLine);

		camPos = new FlxObject();
		camPos.setPosition(strumLine.x + CAM_OFFSET, strumLine.y);
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
		for (i in 0...8){
			var note:StrumNote = new StrumNote(GRID_SIZE * (i+1), strumLine.y, i % 4);
			note.setGraphicSize(GRID_SIZE, GRID_SIZE);
			note.updateHitbox();
			note.playAnim('static', true);
			strumLineNotes.add(note);
			note.scrollFactor.set(1, 1);
		}
		add(strumLineNotes);

		dummyArrow = new FlxSprite().makeGraphic(GRID_SIZE, GRID_SIZE);
		add(dummyArrow);

		/*
		var text =
		"W/S or Mouse Wheel - Change Conductor's strum time
		\nA/D - Go to the previous/next section
		\nUp/Down - Change Conductor's Strum Time with Snapping
		\nLeft/Right - Change Snap
		\nHold Shift to move 4x faster
		\nHold Control and click on an arrow to select it
		\nZ/X - Zoom in/out
		\n
		\nEnter - Play your chart
		\nQ/E - Decrease/Increase Note Sustain Length
		\nSpace - Stop/Resume song";
		
		var tipTextArray:Array<String> = text.split('\n');
		for (i in 0...tipTextArray.length) {
			var tipText:FlxText = new FlxText(12, FlxG.height/2 + GRID_SIZE + i * 12, 0, tipTextArray[i], 14);
			tipText.setFormat(null, 10, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE_FAST, FlxColor.BLACK);
			tipText.borderSize = 1.25;
			tipText.scrollFactor.set();
			add(tipText);
		}
		*/

		var tabs = [
			{name: "Song", label: 'Song'},
			{name: "Section", label: 'Section'},
			{name: "Note", label: 'Note'},
			{name: "Events", label: 'Events'},
			{name: "Charting", label: 'Charting'},
		];

		var ui_start = {
			var chart_grid_end = FlxG.width / 2 + GRID_SIZE * 4;

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

			ui_start;
		}

		UI_box = new FlxUITabMenu(null, tabs, true);
		UI_box.resize(300, 400);
		UI_box.setPosition(ui_start, 25);
		UI_box.scrollFactor.set();
		add(UI_box);

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

		if (lastSong != currentSongName){
			changeSection();
			lastSong = currentSongName;
		}

		reloadGridLayer();
		updateHeads();

		super.create();
	}

	override function startOutro(fuck){
		this.persistentUpdate = false;
		super.startOutro(fuck);
	}

	function fixEvents(){
		var rawEventsData:Array<Array<Dynamic>> = _song.events;
		rawEventsData.sort((a, b) -> return Std.int(a[0] - b[0]));
		var eventsData:Array<Array<Dynamic>> = [];
		for (event in rawEventsData)
		{
			var last = eventsData[eventsData.length - 1];
			if (last == null)
			{
				eventsData.push(event);
			}
			else
			{
				if (Math.abs(last[0] - event[0]) <= Conductor.stepCrochet / (192 / 16))
				{
					var fuck:Array<Array<Dynamic>> = event[1];
					for (shit in fuck)
						eventsData[eventsData.length - 1][1].push(shit);
				}
				else
				{
					eventsData.push(event);
				}
			}
		}

		_song.events = eventsData;	
	}

	var UI_songTitle:FlxUIInputText;
	//var noteSkinInputText:FlxUIInputText;
	//var noteSplashesInputText:FlxUIInputText;
	function addSongUI():Void
	{
		UI_songTitle = new FlxUIInputText(10, 10, 70, _song.song, 8);
		blockPressWhileTypingOn.push(UI_songTitle);

		var check_voices = new FlxUICheckBox(10, 25, null, null, "Has voice track", 100);
		check_voices.checked = _song.needsVoices;
		check_voices.callback = function(){
			_song.needsVoices = check_voices.checked;
		};

		var saveButton:FlxButton = new FlxButton(110, 8, "Save", saveLevel);

		var reloadSong:FlxButton = new FlxButton(saveButton.x + 90, saveButton.y, "Reload Audio", function()
		{
			currentSongName = Paths.formatToSongPath(UI_songTitle.text);
			loadSong();
			updateWaveform();
		});

		var reloadSongJson:FlxButton = new FlxButton(reloadSong.x, saveButton.y + 30, "Reload JSON", function()
		{
			openSubState(new Prompt('This action will clear current progress.\n\nProceed?', 0, function(){loadJson(_song.song.toLowerCase()); }, null,ignoreWarnings));
		});

		var loadAutosaveBtn:FlxButton = new FlxButton(reloadSongJson.x, reloadSongJson.y + 30, 'Load Autosave', function()
		{
			PlayState.SONG = Song.parseJSONshit(FlxG.save.data.autosave);
			MusicBeatState.resetState();
		});

		var loadEventJson:FlxButton = new FlxButton(loadAutosaveBtn.x, loadAutosaveBtn.y + 30, 'Load Events', function()
		{

			var songName:String = Paths.formatToSongPath(_song.song);
			var file:String = Paths.songJson(songName + '/events');
			#if sys
			if (#if MODS_ALLOWED FileSystem.exists(Paths.modsSongJson(songName + '/events')) || #end FileSystem.exists(file))
			#else
			if (OpenFlAssets.exists(file))
			#end
			{
				clearEvents();
				var events:SwagSong = Song.loadFromJson('events', songName);
				_song.events = events.events;
				changeSection(curSec);
			}
		});

		var saveEvents:FlxButton = new FlxButton(110, reloadSongJson.y, 'Save Events', saveEvents);

		/*
		var saveMetadata:FlxButton = new FlxButton(110, saveEvents.y + 30, 'Save Metadata', function(){

		});

		var loadMetadata:FlxButton = new FlxButton(110, saveMetadata.y + 30, 'Load Metadata', function(){
			var songName:String = Paths.formatToSongPath(_song.song);
			var jsonPath = Paths.___getPath('songs/$songName/metadata.json');

			if (Paths.exists(jsonPath)){
				var metadata:Song.SongCreditdata = Json.parse(Paths.getContent(jsonPath));
				_song.metadata = metadata;
			}
			
		});
		*/

		var clear_events:FlxButton = new FlxButton(loadAutosaveBtn.x, 300, 'Clear events', function()
			{
				openSubState(new Prompt('This action will clear current progress.\n\nProceed?', 0, clearEvents, null,ignoreWarnings));
			});
		clear_events.color = FlxColor.RED;
		clear_events.label.color = FlxColor.WHITE;

		var clear_notes:FlxButton = new FlxButton(clear_events.x, clear_events.y + 30, 'Clear notes', function()
			{
				openSubState(new Prompt('This action will clear current progress.\n\nProceed?', 0, function(){for (sec in 0..._song.notes.length) {
					_song.notes[sec].sectionNotes = [];
				}
				updateGrid();
			}, null,ignoreWarnings));

			});
		clear_notes.color = FlxColor.RED;
		clear_notes.label.color = FlxColor.WHITE;

		var stepperBPM:FlxUINumericStepper = new FlxUINumericStepper(10, 70, 1, 1, 1, 9000, 3);
		stepperBPM.value = Conductor.bpm;
		stepperBPM.name = 'song_bpm';
		blockPressWhileTypingOnStepper.push(stepperBPM);

		var stepperSpeed:FlxUINumericStepper = new FlxUINumericStepper(10, stepperBPM.y + 35, 0.1, 1, 0.1, 10, 1);
		stepperSpeed.value = _song.speed;
		stepperSpeed.name = 'song_speed';
		blockPressWhileTypingOnStepper.push(stepperSpeed);

		////
		var characters:Array<String> = Character.getAllCharacters();
        var skins:Array<String> = ['default'];
        #if MODS_ALLOWED
		var skinsLoaded:Map<String, Bool> = new Map();
		var directories:Array<String> = Paths.getFolders('hudskins');
		for (i in 0...directories.length) {
			var directory:String = directories[i];
			if(FileSystem.exists(directory)) {
				for (file in FileSystem.readDirectory(directory)) {
					var path = haxe.io.Path.join([directory, file]);
					if (!FileSystem.isDirectory(path) && file.endsWith('.hscript')) {
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

		var player1DropDown = new FlxUIDropDownMenuCustom(10, stepperSpeed.y + 45, FlxUIDropDownMenuCustom.makeStrIdLabelArray(characters, true), function(character:String)
		{
			_song.player1 = characters[Std.parseInt(character)];
			updateHeads();
		});
		player1DropDown.selectedLabel = _song.player1;
		blockPressWhileScrolling.push(player1DropDown);

		var gfVersionDropDown = new FlxUIDropDownMenuCustom(player1DropDown.x, player1DropDown.y + 40, FlxUIDropDownMenuCustom.makeStrIdLabelArray(characters, true), function(character:String)
		{
			_song.gfVersion = characters[Std.parseInt(character)];
			updateHeads();
		});
		gfVersionDropDown.selectedLabel = _song.gfVersion;
		blockPressWhileScrolling.push(gfVersionDropDown);

		var player2DropDown = new FlxUIDropDownMenuCustom(player1DropDown.x, gfVersionDropDown.y + 40, FlxUIDropDownMenuCustom.makeStrIdLabelArray(characters, true), function(character:String)
		{
			_song.player2 = characters[Std.parseInt(character)];
			updateHeads();
		});
		player2DropDown.selectedLabel = _song.player2;
		blockPressWhileScrolling.push(player2DropDown);


		////
		var stages = Stage.getAllStages();
		if (stages.length == 0) stages.push("stage");

		var stageDropDown = new FlxUIDropDownMenuCustom(
			player1DropDown.x + 140, 
			player1DropDown.y, 
			FlxUIDropDownMenuCustom.makeStrIdLabelArray(stages, true), 
			function(character:String)
			{
				_song.stage = stages[Std.parseInt(character)];
				trace('stage changed. index:$character, result:${_song.stage}');
			}
		);
		stageDropDown.selectedLabel = _song.stage;
		blockPressWhileScrolling.push(stageDropDown);

		var skinDropdown = new FlxUIDropDownMenuCustom(
			stageDropDown.x, stageDropDown.y + 40, 
			FlxUIDropDownMenuCustom.makeStrIdLabelArray(skins, true), 
			function(skin:String){
				_song.hudSkin = skins[Std.parseInt(skin)];
			}
		);
		skinDropdown.selectedLabel = _song.hudSkin;
		blockPressWhileScrolling.push(skinDropdown);

		var skin = PlayState.SONG.arrowSkin;
		if(skin == null) skin = '';
		/*
		noteSkinInputText = new FlxUIInputText(player2DropDown.x, player2DropDown.y + 50, 150, skin, 8);
		blockPressWhileTypingOn.push(noteSkinInputText);

		noteSplashesInputText = new FlxUIInputText(noteSkinInputText.x, noteSkinInputText.y + 35, 150, _song.splashSkin, 8);
		blockPressWhileTypingOn.push(noteSplashesInputText);

		var reloadNotesButton:FlxButton = new FlxButton(noteSplashesInputText.x + 5, noteSplashesInputText.y + 20, 'Change Notes', function() {
			_song.arrowSkin = noteSkinInputText.text;
			updateGrid();
		});
		*/

		var tab_group_song = new FlxUI(null, UI_box);
		tab_group_song.name = "Song";
		tab_group_song.add(UI_songTitle);

		tab_group_song.add(check_voices);
		tab_group_song.add(clear_events);
		tab_group_song.add(clear_notes);
		tab_group_song.add(saveButton);
		tab_group_song.add(saveEvents);

        // TODO: per-song metadata 
/* 		tab_group_song.add(saveMetadata);
		tab_group_song.add(loadMetadata); */
		tab_group_song.add(reloadSong);
		tab_group_song.add(reloadSongJson);
		tab_group_song.add(loadAutosaveBtn);
		tab_group_song.add(loadEventJson);
		tab_group_song.add(stepperBPM);
		tab_group_song.add(stepperSpeed);
		//tab_group_song.add(reloadNotesButton);
		//tab_group_song.add(noteSkinInputText);
		//tab_group_song.add(noteSplashesInputText);
		tab_group_song.add(new FlxText(stepperBPM.x, stepperBPM.y - 15, 0, 'Song BPM:'));
		tab_group_song.add(new FlxText(stepperSpeed.x, stepperSpeed.y - 15, 0, 'Song Speed:'));

		tab_group_song.add(new FlxText(skinDropdown.x, skinDropdown.y - 15, 0, 'HUD Skin:'));
		tab_group_song.add(new FlxText(player2DropDown.x, player2DropDown.y - 15, 0, 'Opponent:'));
		tab_group_song.add(new FlxText(gfVersionDropDown.x, gfVersionDropDown.y - 15, 0, 'Girlfriend:'));
		tab_group_song.add(new FlxText(player1DropDown.x, player1DropDown.y - 15, 0, 'Boyfriend:'));
		tab_group_song.add(new FlxText(stageDropDown.x, stageDropDown.y - 15, 0, 'Stage:'));
		/*
		tab_group_song.add(new FlxText(noteSkinInputText.x, noteSkinInputText.y - 15, 0, 'Note Texture:'));
		tab_group_song.add(new FlxText(noteSplashesInputText.x, noteSplashesInputText.y - 15, 0, 'Note Splashes Texture:'));
		*/
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
	var notesCopied:Array<Dynamic>;

	function addSectionUI():Void
	{
		var tab_group_section = new FlxUI(null, UI_box);
		tab_group_section.name = 'Section';

		check_mustHitSection = new FlxUICheckBox(10, 15, null, null, "Must hit section", 100);
		check_mustHitSection.name = 'check_mustHit';
		check_mustHitSection.checked = _song.notes[curSec].mustHitSection;

		check_gfSection = new FlxUICheckBox(10, check_mustHitSection.y + 22, null, null, "GF section", 100);
		check_gfSection.name = 'check_gf';
		check_gfSection.checked = _song.notes[curSec].gfSection;

		check_altAnim = new FlxUICheckBox(check_gfSection.x + 120, check_gfSection.y, null, null, "Alt Animation", 100);
		check_altAnim.checked = _song.notes[curSec].altAnim;

		stepperBeats = new FlxUINumericStepper(10, 100, 1, 1, 1, 9000, 3);
		stepperBeats.value = getSectionBeats();
		stepperBeats.name = 'section_beats';
		blockPressWhileTypingOnStepper.push(stepperBeats);
		check_altAnim.name = 'check_altAnim';

		check_changeBPM = new FlxUICheckBox(10, stepperBeats.y + 30, null, null, 'Change BPM', 100);
		check_changeBPM.checked = _song.notes[curSec].changeBPM;
		check_changeBPM.name = 'check_changeBPM';

		stepperSectionBPM = new FlxUINumericStepper(10, check_changeBPM.y + 20, 1, Conductor.bpm, 0, 999, 1);
		if(check_changeBPM.checked) {
			stepperSectionBPM.value = _song.notes[curSec].bpm;
		} else {
			stepperSectionBPM.value = Conductor.bpm;
		}
		stepperSectionBPM.name = 'section_bpm';
		blockPressWhileTypingOnStepper.push(stepperSectionBPM);

		var check_eventsSec:FlxUICheckBox = null;
		var check_notesSec:FlxUICheckBox = null;
		var copyButton:FlxButton = new FlxButton(10, 190, "Copy Section", function()
		{
			notesCopied = [];
			sectionToCopy = curSec;
			for (i in 0..._song.notes[curSec].sectionNotes.length)
			{
				var note:Array<Dynamic> = _song.notes[curSec].sectionNotes[i];
				notesCopied.push(note);
			}

			var startThing:Float = fuckFloatingPoints(sectionStartTime());
			var endThing:Float = fuckFloatingPoints(sectionStartTime(1));
			for (event in _song.events)
			{
				var strumTime:Float = fuckFloatingPoints(event[0]);
				if(endThing > event[0] && event[0] >= startThing)
				{
					var copiedEventArray:Array<Dynamic> = [];
					for (i in 0...event[1].length)
					{
						var eventToPush:Array<Dynamic> = event[1][i];
						copiedEventArray.push([eventToPush[0], eventToPush[1], eventToPush[2]]);
					}
					notesCopied.push([strumTime, -1, copiedEventArray]);
				}
			}
		});

		var pasteButton:FlxButton = new FlxButton(copyButton.x + 100, copyButton.y, "Paste Section", function()
		{
			if(notesCopied == null || notesCopied.length < 1)
			{
				return;
			}

			var addToTime:Float = Conductor.stepCrochet * (getSectionBeats() * 4 * (curSec - sectionToCopy));
			//trace('Time to add: ' + addToTime);

			for (note in notesCopied)
			{
				var copiedNote:Array<Dynamic> = [];
				var newStrumTime:Float = note[0] + addToTime;
				if(note[1] < 0)
				{
					if(check_eventsSec.checked)
					{
						var copiedEventArray:Array<Dynamic> = [];
						for (i in 0...note[2].length)
						{
							var eventToPush:Array<Dynamic> = note[2][i];
							copiedEventArray.push([eventToPush[0], eventToPush[1], eventToPush[2]]);
						}
						_song.events.push([newStrumTime, copiedEventArray]);
					}
				}
				else
				{
					if(check_notesSec.checked)
					{
						if(note[4] != null) {
							copiedNote = [newStrumTime, note[1], note[2], note[3], note[4]];
						} else {
							copiedNote = [newStrumTime, note[1], note[2], note[3]];
						}
						_song.notes[curSec].sectionNotes.push(copiedNote);
					}
				}
			}

			if(check_eventsSec.checked)
			{
				fixEvents();
			}
			updateGrid();
		});

		var clearSectionButton:FlxButton = new FlxButton(pasteButton.x + 100, pasteButton.y, "Clear", function()
		{
			if(check_notesSec.checked)
			{
				_song.notes[curSec].sectionNotes = [];
			}

			if(check_eventsSec.checked)
			{
				var i:Int = _song.events.length - 1;
				var startThing:Float = sectionStartTime();
				var endThing:Float = sectionStartTime(1);
				while(i > -1) {
					var event:Array<Dynamic> = _song.events[i];
					if(event != null && endThing > event[0] && event[0] >= startThing)
					{
						_song.events.remove(event);
					}
					--i;
				}
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

		var swapSection:FlxButton = new FlxButton(10, check_notesSec.y + 40, "Swap section", function()
		{
			for (i in 0..._song.notes[curSec].sectionNotes.length)
			{
				var note:Array<Dynamic> = _song.notes[curSec].sectionNotes[i];
				note[1] = (note[1] + 4) % 8;
				_song.notes[curSec].sectionNotes[i] = note;
			}
			updateGrid();
		});

		var stepperCopy:FlxUINumericStepper = null;
		var copyLastButton:FlxButton = new FlxButton(10, swapSection.y + 30, "Copy last section", function()
		{
			var value:Int = Std.int(stepperCopy.value);
			if(value == 0) return;

			var daSec = FlxMath.maxInt(curSec, value);

			if(check_notesSec.checked){
				for (note in _song.notes[daSec - value].sectionNotes)
				{
					var strum = note[0] + Conductor.stepCrochet * (getSectionBeats(daSec) * 4 * value);


					var copiedNote:Array<Dynamic> = [strum, note[1], note[2], note[3]];
					_song.notes[daSec].sectionNotes.push(copiedNote);
				}
			}

			var startThing:Float = sectionStartTime(-value);
			var endThing:Float = sectionStartTime(-value + 1);
			if(check_eventsSec.checked){
				for (event in _song.events)
				{
					var strumTime:Float = fuckFloatingPoints(event[0]);
					
					if(endThing > event[0] && event[0] >= startThing)
					{
						strumTime += Conductor.stepCrochet * (getSectionBeats(daSec) * 4 * value);
						var copiedEventArray:Array<Dynamic> = [];
						for (i in 0...event[1].length)
						{
							var eventToPush:Array<Dynamic> = event[1][i];
							copiedEventArray.push([eventToPush[0], eventToPush[1], eventToPush[2]]);
						}
						_song.events.push([strumTime, copiedEventArray]);
					}
				}
				fixEvents();
			}
			updateGrid();
		});
		copyLastButton.setGraphicSize(80, 30);
		copyLastButton.updateHitbox();
		
		stepperCopy = new FlxUINumericStepper(copyLastButton.x + 100, copyLastButton.y, 1, 1, -999, 999, 0);
		blockPressWhileTypingOnStepper.push(stepperCopy);

		var duetButton:FlxButton = new FlxButton(10, copyLastButton.y + 45, "Duet Notes", function()
		{
			var duetNotes:Array<Array<Dynamic>> = [];
			for (note in _song.notes[curSec].sectionNotes)
			{
				var boob = note[1];
				if (boob>3){
					boob -= 4;
				}else{
					boob += 4;
				}

				var copiedNote:Array<Dynamic> = [note[0], boob, note[2], note[3]];
				duetNotes.push(copiedNote);
			}

			for (i in duetNotes){
			_song.notes[curSec].sectionNotes.push(i);

			}

			updateGrid();
		});
		var mirrorButton:FlxButton = new FlxButton(duetButton.x + 100, duetButton.y, "Mirror Notes", function()
		{
			var duetNotes:Array<Array<Dynamic>> = [];
			for (note in _song.notes[curSec].sectionNotes)
			{
				var boob = note[1]%4;
				boob = 3 - boob;
				if (note[1] > 3) boob += 4;

				note[1] = boob;
				var copiedNote:Array<Dynamic> = [note[0], boob, note[2], note[3]];
				//duetNotes.push(copiedNote);
			}

			for (i in duetNotes){
			//_song.notes[curSec].sectionNotes.push(i);

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

	var stepperSusLength:FlxUINumericStepper;
	var strumTimeInputText:FlxUIInputText; //I wanted to use a stepper but we can't scale these as far as i know :(
	var noteTypeDropDown:FlxUIDropDownMenuCustom;
	var currentType:Int = 0;

	function addNoteUI():Void
	{
		var tab_group_note = new FlxUI(null, UI_box);
		tab_group_note.name = 'Note';

		stepperSusLength = new FlxUINumericStepper(10, 25, Conductor.stepCrochet* 0.5, 0, 0, Conductor.stepCrochet * 64);
		stepperSusLength.value = 0;
		stepperSusLength.name = 'note_susLength';
		blockPressWhileTypingOnStepper.push(stepperSusLength);

		strumTimeInputText = new FlxUIInputText(10, 65, 180, "0");
		tab_group_note.add(strumTimeInputText);
		blockPressWhileTypingOn.push(strumTimeInputText);

		var key:Int = 0;
		var displayNameList:Array<String> = [];
		while (key < noteTypeList.length) {
			displayNameList.push(noteTypeList[key]);
			noteTypeMap.set(noteTypeList[key], key);
			noteTypeIntMap.set(key, noteTypeList[key]);
			key++;
		}

		#if (sys && (hscript || LUA_ALLOWED))
		var directories:Array<String> = Paths.getFolders('notetypes');
		var allowedFormats = [
			#if hscript
			'.hscript',
			#end
			#if LUA_ALLOWED
			'.lua'
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

		noteTypeDropDown = new FlxUIDropDownMenuCustom(10, 105, FlxUIDropDownMenuCustom.makeStrIdLabelArray(displayNameList, true), function(character:String)
		{
			currentType = Std.parseInt(character);
			if(curSelectedNote != null && curSelectedNote[1] > -1) {
				curSelectedNote[3] = noteTypeIntMap.get(currentType);
				updateGrid();
			}
		});
		blockPressWhileScrolling.push(noteTypeDropDown);

		tab_group_note.add(new FlxText(10, 10, 0, 'Sustain length:'));
		tab_group_note.add(new FlxText(10, 50, 0, 'Strum time (in miliseconds):'));
		tab_group_note.add(new FlxText(10, 90, 0, 'Note type:'));

		tab_group_note.add(stepperSusLength);
		tab_group_note.add(strumTimeInputText);
		tab_group_note.add(noteTypeDropDown);

		UI_box.addGroup(tab_group_note);
	}

	var eventDropDown:FlxUIDropDownMenuCustom;
	var eventNameInput:FlxUIInputText;
	var descText:FlxText;
	var selectedEventText:FlxText;

	function setSelectedEventType(typeName:String)
	{
		if (curSelectedNote != null && eventStuff != null)
		{
			if (curSelectedNote[2] == null)
				curSelectedNote[1][curEventSelected][0] = typeName;

			updateGrid();
		}
	}

	function addEventsUI():Void
	{
		var tab_group_event = new FlxUI(null, UI_box);
		tab_group_event.name = 'Events';

		descText = new FlxText(20, 200, 0, eventStuff[0][0]);
		
		#if (sys && (hscript || LUA_ALLOWED))
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

		eventDropDown = new FlxUIDropDownMenuCustom(
			20, 50, 
			FlxUIDropDownMenuCustom.makeStrIdLabelArray(leEvents, true), 
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
		blockPressWhileTypingOn.push(value1InputText);

		var text:FlxText = new FlxText(20, 130, 0, "Value 2:");
		tab_group_event.add(text);
		value2InputText = new FlxUIInputText(20, 150, 100, "");
		blockPressWhileTypingOn.push(value2InputText);

		// New event buttons
		var removeButton:FlxButton = new FlxButton(eventDropDown.x + eventDropDown.width + 10, eventDropDown.y, '-', function()
		{
			if(curSelectedNote != null && curSelectedNote[2] == null) //Is event note
			{
				if(curSelectedNote[1].length < 2)
				{
					_song.events.remove(curSelectedNote);
					curSelectedNote = null;
				}
				else
				{
					curSelectedNote[1].remove(curSelectedNote[1][curEventSelected]);
				}

				var eventsGroup:Array<Dynamic>;
				--curEventSelected;
				if(curEventSelected < 0) curEventSelected = 0;
				else if(curSelectedNote != null && curEventSelected >= (eventsGroup = curSelectedNote[1]).length) curEventSelected = eventsGroup.length - 1;

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
			if(curSelectedNote != null && curSelectedNote[2] == null) //Is event note
			{
				var eventsGroup:Array<Dynamic> = curSelectedNote[1];
				eventsGroup.push(['', '', '']);

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
			if (curSelectedNote == null || curSelectedNote[2] != null) // Isn't event note
				return;

			if (FlxG.keys.pressed.SHIFT){
				var noteEvents:Array<Array<Dynamic>> = curSelectedNote[1];
				var selectedEvent:Array<Dynamic> = noteEvents[curEventSelected];
				var switchPos:Int = (curEventSelected-1 < 0) ?  noteEvents.length-1 : curEventSelected-1;

				curSelectedNote[1].remove(selectedEvent);
				curSelectedNote[1].insert(switchPos, selectedEvent);

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
			if (curSelectedNote == null || curSelectedNote[2] != null) // Isn't event note
				return;

			if (FlxG.keys.pressed.SHIFT)
			{
				var noteEvents:Array<Array<Dynamic>> = curSelectedNote[1];
				var selectedEvent:Array<Dynamic> = noteEvents[curEventSelected];
				var switchPos:Int = (curEventSelected+1 == curSelectedNote[1].length) ? 0 : curEventSelected+1;

				curSelectedNote[1].remove(selectedEvent);
				curSelectedNote[1].insert(switchPos, selectedEvent);

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
		if(curSelectedNote != null && curSelectedNote[2] == null) //Is event note
		{
			curEventSelected += change;
			if(curEventSelected < 0) curEventSelected = Std.int(curSelectedNote[1].length) - 1;
			else if(curEventSelected >= curSelectedNote[1].length) curEventSelected = 0;
			selectedEventText.text = 'Selected Event: ' + (curEventSelected + 1) + ' / ' + curSelectedNote[1].length;
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

	var metronome:FlxUICheckBox;
	var metronomeStepper:FlxUINumericStepper;
	var metronomeOffsetStepper:FlxUINumericStepper;
	var disableAutoScrolling:FlxUICheckBox;
	var mouseScrollingQuant:FlxUICheckBox;

	var check_vortex:FlxUICheckBox = null;
	var check_warnings:FlxUICheckBox = null;

	var playSoundBf:FlxUICheckBox = null;
	var playSoundDad:FlxUICheckBox = null;
	var playSoundEvents:FlxUICheckBox = null;

	var waveformTrackDropDown:FlxUIDropDownMenuCustom;
	var waveformTrack:Null<FlxSound> = null;
	var trackVolumeSlider:FlxUISlider;

	function selectTrack(trackName:String){
		waveformTrack = soundTracksMap.get(trackName); 

		if (waveformTrack != null){
			trackVolumeSlider.value = waveformTrack.volume;
			trackVolumeSlider.visible = true;
		/*}else{
			trackVolumeSlider.visible = false;*/
		}
		
		updateWaveform();
	}

	function changeSelectedTrackVolume(val:Float)
	{
		if (waveformTrack != null)
			waveformTrack.volume = val;
		/*else
			trace("Erm. No track is selected!");*/
		
		trackVolumeSlider.value = val;
	}

	function addChartingUI() {
		var tab_group_chart = new FlxUI(null, UI_box);
		tab_group_chart.name = 'Charting';

		////////

		var trackNamesArray = ["None"];
		for (trackName in soundTracksMap.keys())
			trackNamesArray.push(trackName);

		/*var curSelectedTrackName = "None";
		for (trackName => snd in soundTracksMap){
			trackNamesArray.push(trackName);
			if (snd == waveformTrack) 
				curSelectedTrackName = trackName;
		}*/

		////
		waveformTrackDropDown = new FlxUIDropDownMenuCustom(
			10, 100, 
			FlxUIDropDownMenuCustom.makeStrIdLabelArray(trackNamesArray, false), 
			selectTrack
		);
		waveformTrackDropDown.selectedId = "None"; //curSelectedTrackName;
		blockPressWhileScrolling.push(waveformTrackDropDown);

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
		trackVolumeSlider.value = 1.0;

		////////

		var startY = 165;

		check_warnings = new FlxUICheckBox(10, startY, null, null, "Ignore Progress Warnings", 100);
		if (FlxG.save.data.ignoreWarnings == null) FlxG.save.data.ignoreWarnings = false;
		check_warnings.callback = function()
		{
			FlxG.save.data.ignoreWarnings = check_warnings.checked;
			ignoreWarnings = FlxG.save.data.ignoreWarnings;
		};
		check_warnings.checked = FlxG.save.data.ignoreWarnings;


		check_vortex = new FlxUICheckBox(10, startY + 40, null, null, "Vortex Editor (BETA)", 100);
		if (FlxG.save.data.chart_vortex == null) FlxG.save.data.chart_vortex = false;
		check_vortex.callback = function()
		{
			FlxG.save.data.chart_vortex = check_vortex.checked;
			vortex = FlxG.save.data.chart_vortex;
			reloadGridLayer();
		};
		check_vortex.checked = FlxG.save.data.chart_vortex;


		mouseScrollingQuant = new FlxUICheckBox(10, startY + 80, null, null, "Mouse Scrolling Quantization", 100);
		if (FlxG.save.data.mouseScrollingQuant == null) FlxG.save.data.mouseScrollingQuant = false;
		mouseQuant = FlxG.save.data.mouseScrollingQuant;
		mouseScrollingQuant.callback = function()
		{
			FlxG.save.data.mouseScrollingQuant = mouseScrollingQuant.checked;
			mouseQuant = FlxG.save.data.mouseScrollingQuant;
		};
		mouseScrollingQuant.checked = FlxG.save.data.mouseScrollingQuant;

		////////
		var xPos = 10 + 150;

		playSoundBf = new FlxUICheckBox(xPos, startY, null, null, 'Play Sound (Boyfriend notes)', 100,
			()->{FlxG.save.data.chart_playSoundBf = playSoundBf.checked;}
		);
		playSoundBf.checked = FlxG.save.data.chart_playSoundBf == true;


		playSoundDad = new FlxUICheckBox(xPos, startY + 40, null, null, 'Play Sound (Opponent notes)', 100,
			()->{FlxG.save.data.chart_playSoundDad = playSoundDad.checked;}
		);
		playSoundDad.checked = FlxG.save.data.chart_playSoundDad == true;

		
		playSoundEvents = new FlxUICheckBox(xPos, startY + 80, null, null, 'Play Sound (Event notes)', 100,
			()->{FlxG.save.data.chart_playSoundEvents = playSoundEvents.checked;}
		);
		playSoundEvents.checked = FlxG.save.data.chart_playSoundEvents == true;

		////////
		metronome = new FlxUICheckBox(10, 15, null, null, "Metronome Enabled", 100,
			()->{FlxG.save.data.chart_metronome = metronome.checked;}
		);
		metronome.checked = FlxG.save.data.chart_metronome == true;

		metronomeStepper = new FlxUINumericStepper(15, 55, 5, _song.bpm, 1, 9000, 3);
		metronomeOffsetStepper = new FlxUINumericStepper(metronomeStepper.x + 146, metronomeStepper.y, 25, 0, 0, 1000, 1);
		blockPressWhileTypingOnStepper.push(metronomeStepper);
		blockPressWhileTypingOnStepper.push(metronomeOffsetStepper);

		disableAutoScrolling = new FlxUICheckBox(metronome.x + 150, metronome.y, null, null, "Disable Section Autoscroll", 120,
			()->{FlxG.save.data.chart_noAutoScroll = disableAutoScrolling.checked;}
		);
		disableAutoScrolling.checked = FlxG.save.data.chart_noAutoScroll == true;

		var sliderRate = new FlxUISlider(this, 'playbackSpeed', 68, 300, 0.5, 3, 150, null, 5, FlxColor.WHITE, FlxColor.BLACK);
		sliderRate.nameLabel.text = 'Playback Rate';
		sliderRate.value = playbackSpeed;

		tab_group_chart.add(sliderRate);

		tab_group_chart.add(mouseScrollingQuant);
		tab_group_chart.add(check_vortex);
		tab_group_chart.add(check_warnings);

		tab_group_chart.add(playSoundEvents);
		tab_group_chart.add(playSoundDad);
		tab_group_chart.add(playSoundBf);

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

	function loadSong():Void
	{
		MusicBeatState.stopMenuMusic();

		for (trackName in _song.extraTracks){
			var file:Sound = Paths.track(currentSongName, trackName);
			if (file != null) {
				var newTrack = new FlxSound();

				soundTracksMap.set(
					trackName, 
					newTrack.loadEmbedded(file)
				);
				extraTracks.push(newTrack);
				FlxG.sound.list.add(newTrack);
			}
		}
		
		vocals = new FlxSound();
		vocals.context = MUSIC;

		var file:Sound = Paths.voices(currentSongName);
		if (file != null) {
			soundTracksMap.set(
				"Vocals", 
				vocals.loadEmbedded(file)
			);
			FlxG.sound.list.add(vocals);
		}else{
			vocals = null;
		}

		FlxG.sound.playMusic(Paths.inst(currentSongName), 0.6 /*, false*/);
		soundTracksMap.set("Inst", FlxG.sound.music);

		/*
		if (instVolume != null) 
			FlxG.sound.music.volume = instVolume.value;
		
		if (check_mute_inst != null && check_mute_inst.checked) 
			FlxG.sound.music.volume = 0;
		*/

		FlxG.sound.music.onComplete = function()
		{
			FlxG.sound.music.pause();
			Conductor.songPosition = 0;
			if(vocals != null) {
				vocals.pause();
				vocals.time = 0;
			}
			for (track in extraTracks){
				track.pause();
				track.time = 0;
			}
			
			changeSection();
			curSec = 0;
			updateGrid();
			updateSectionUI();
			
			vocals.play();
			for (track in extraTracks) track.play();
		};

		FlxG.sound.music.pause();
		Conductor.songPosition = sectionStartTime();
		FlxG.sound.music.time = Conductor.songPosition;
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
		else if (id == FlxUINumericStepper.CHANGE_EVENT && (sender is FlxUINumericStepper))
		{
			var nums:FlxUINumericStepper = cast sender;
			var wname = nums.name;
			FlxG.log.add(wname);
			if (wname == 'section_beats')
			{
				_song.notes[curSec].sectionBeats = nums.value;
				reloadGridLayer();
			}
			else if (wname == 'song_speed')
			{
				_song.speed = nums.value;
			}
			else if (wname == 'song_bpm')
			{
				tempBpm = nums.value;
				Conductor.mapBPMChanges(_song);
				Conductor.changeBPM(nums.value);
			}
			else if (wname == 'note_susLength')
			{
				if(curSelectedNote != null && curSelectedNote[1] > -1) {
					curSelectedNote[2] = nums.value;
					updateGrid();
				} else {
					sender.value = 0;
				}
			}
			else if (wname == 'section_bpm')
			{
				_song.notes[curSec].bpm = nums.value;
				updateGrid();
			}
		}
		else if(id == FlxUIInputText.CHANGE_EVENT && (sender is FlxUIInputText)) {
			/*if(sender == noteSplashesInputText) {
				_song.splashSkin = noteSplashesInputText.text;
			}
			else*/ 
			if (sender == UI_songTitle){
				_song.song = UI_songTitle.text;
			}else if(curSelectedNote != null)
			{
                if(curSelectedNote[1][curEventSelected] != null){
				    if(sender == value1InputText) {
                        curSelectedNote[1][curEventSelected][1] = value1InputText.text;
                        updateGrid();
                    }
                    else if(sender == value2InputText) {
                        curSelectedNote[1][curEventSelected][2] = value2InputText.text;
                        updateGrid();
                    }
                }
                if(sender == strumTimeInputText) {
                    var value:Float = Std.parseFloat(strumTimeInputText.text);
                    if(Math.isNaN(value)) value = 0;
                    curSelectedNote[0] = value;
                    updateGrid();
                }
                
			}
		}
		else if (id == FlxUISlider.CHANGE_EVENT && (sender is FlxUISlider))
		{
			var sender:FlxUISlider = cast sender;

			
		}

		// FlxG.log.add(id + " WEED " + sender + " WEED " + data + " WEED " + params);
	}

	var updatedSection:Bool = false;

	function setSectionStartTime(sec:Int = 0):Float
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

	function sectionStartTime(add:Int = 0):Float
	{
		var daBPM:Float = _song.bpm;
		var daPos:Float = 0;

		for (i in 0...curSec + add)
		{
			if(_song.notes[i] == null)
				continue;
			
			if (_song.notes[i].changeBPM)
				daBPM = _song.notes[i].bpm;
			
			daPos += getSectionBeats(i) * (1000 * 60 / daBPM);		
		}
		return daPos;
	}

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

	override function update(elapsed:Float)
	{
		curStep = recalculateSteps();

		if(FlxG.sound.music.time < 0) {
			FlxG.sound.music.pause();
			FlxG.sound.music.time = 0;
		}
		else if(FlxG.sound.music.time > FlxG.sound.music.length) {
			FlxG.sound.music.pause();
			FlxG.sound.music.time = 0;
			changeSection();
		}

		for (track in soundTracksMap)
			track.pitch = playbackSpeed;

		FlxG.mouse.visible = true; //cause reasons. trust me

		if(!disableAutoScrolling.checked) 
		{
			if (Math.ceil(strumLine.y) >= gridBG.height){
				if (_song.notes[curSec + 1] == null)
					pushSection();

				changeSection(curSec + 1, false);
			} else if(strumLine.y < -10)
				changeSection(curSec - 1, false);
		}

		var movedDummyY:Bool = false;
		var onGrid:Bool =	FlxG.mouse.x >= gridBG.x
						&&	FlxG.mouse.x <= gridBG.x + gridBG.width
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
							curSelectedNote[3] = noteTypeIntMap.get(currentType);
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
				addNote();
			}
		}else if(FlxG.mouse.pressed){

			if (movedDummyY)
			{
				for (note in heldNotesClick){
					if (note == null) continue;
				
					var zoomMult:Float = zoomList[curZoom];
					var step:Float = Conductor.stepCrochet;

					var diff:Float = (curDummyY - startDummyY);
					var notePos:Float = (diff < 0) ? curDummyY : startDummyY;

					note[0] = sectionStartTime() + (notePos / zoomMult) * step;
					note[2] = Math.abs((diff / zoomMult) * step);

					updateNoteUI();
					updateGrid();
				}
			}

		}else {
			if (!heldNotesClick.empty()) heldNotesClick = [];
			startDummyY = null;
			curDummyY = null;
		}

		var blockInput:Bool = false;
		for (inputText in blockPressWhileTypingOn) {
			if(inputText.hasFocus) {
				StartupState.specialKeysEnabled = false;
				blockInput = true;
				break;
			}
		}

		if(!blockInput) {
			for (stepper in blockPressWhileTypingOnStepper) {
				@:privateAccess
				var leText:Dynamic = stepper.text_field;
				var leText:FlxUIInputText = leText;
				if(leText.hasFocus) {
					StartupState.specialKeysEnabled = false;
					blockInput = true;
					break;
				}
			}
		}

		if(!blockInput) {
			StartupState.specialKeysEnabled = true;
			for (dropDownMenu in blockPressWhileScrolling) {
				if(dropDownMenu.dropPanel.visible) {
					blockInput = true;
					break;
				}
			}
		}

		if (!blockInput)
		{
			if (FlxG.keys.justPressed.ENTER)
			{
				autosaveSong();
				if (_song.events != null && _song.events.length > 1)
					_song.events.sort(sortByTime);
				PlayState.SONG = _song;
				PlayState.chartingMode = true;

				if (FlxG.keys.pressed.SHIFT)
					PlayState.startOnTime = Conductor.songPosition;

				FlxG.sound.pause();

				LoadingState.loadAndSwitchState(new PlayState());

				return;
			}

			if (FlxG.keys.justPressed.M)
			{
				var mustHit = !_song.notes[curSec].mustHitSection;
				_song.notes[curSec].mustHitSection = mustHit;
				check_mustHitSection.checked = mustHit;

				if (FlxG.keys.pressed.CONTROL){
					for (i in 0..._song.notes[curSec].sectionNotes.length)
					{
						var note:Array<Dynamic> = _song.notes[curSec].sectionNotes[i];
						note[1] = (note[1] + 4) % 8;
						_song.notes[curSec].sectionNotes[i] = note;
					}
				}

				updateGrid();
				updateHeads();	
			}	

			if(curSelectedNote != null && curSelectedNote[1] > -1) {
				if (FlxG.keys.justPressed.E)
				{
					changeNoteSustain(Conductor.stepCrochet);
				}
				if (FlxG.keys.justPressed.Q)
				{
					changeNoteSustain(-Conductor.stepCrochet);
				}
			}


			if (FlxG.keys.justPressed.BACKSPACE) {
				//if(onMasterEditor) {
					PlayState.chartingMode = false;
					MusicBeatState.switchState(new funkin.states.editors.MasterEditorMenu());
					MusicBeatState.playMenuMusic(true);
				//}
				FlxG.mouse.visible = false;
				return;
			}

			if(FlxG.keys.justPressed.Z && FlxG.keys.pressed.CONTROL) {
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

			if (FlxG.keys.justPressed.TAB)
			{
				if (FlxG.keys.pressed.SHIFT)
				{
					if (--UI_box.selected_tab < 0)
						UI_box.selected_tab = UI_box.get_numTabs() - 1;
				}
				else
				{					
					if (++UI_box.selected_tab < 0)
						UI_box.selected_tab = 0;
				}
			}

			if (FlxG.keys.justPressed.SPACE)
			{
				if (FlxG.sound.music.playing)
				{
					FlxG.sound.music.pause();
					if(vocals != null) vocals.pause();
					for (track in extraTracks) track.pause();
				}
				else
				{
					FlxG.sound.music.play();

					if(vocals != null) {
						vocals.pause();
						vocals.time = FlxG.sound.music.time;
						vocals.play(false, FlxG.sound.music.time);
					}

					for (track in extraTracks){
						track.pause();
						track.time = FlxG.sound.music.time;
						track.play(false, FlxG.sound.music.time);
					}
				}
			}

			if (FlxG.keys.justPressed.R)
				resetSection(FlxG.keys.pressed.SHIFT);

			if (FlxG.mouse.wheel != 0)
			{
				FlxG.sound.music.pause();
				if(vocals != null) vocals.pause();
				for (track in extraTracks) track.pause();

				if (!mouseQuant)
					FlxG.sound.music.time -= (FlxG.mouse.wheel * Conductor.stepCrochet);
				else{
					var snap = Conductor.stepCrochet / quantizationMult;
					FlxG.sound.music.time = CoolUtil.snap(FlxG.sound.music.time, snap) - (snap * FlxG.mouse.wheel);
				}
			}

			if (FlxG.keys.pressed.W || FlxG.keys.pressed.S)
			{
				FlxG.sound.music.pause();

				var holdingShift:Float = 1;
				if (FlxG.keys.pressed.CONTROL) holdingShift = 0.25;
				else if (FlxG.keys.pressed.SHIFT) holdingShift = 4;

				var daTime:Float = 720 * FlxG.elapsed * holdingShift;

				if (FlxG.keys.pressed.W)
					FlxG.sound.music.time -= daTime;
				else
					FlxG.sound.music.time += daTime;

				if(vocals != null) {
					vocals.pause();
					vocals.time = FlxG.sound.music.time;
				}
				for (track in extraTracks){
					track.pause();
					track.time = FlxG.sound.music.time;
				}
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
			
			//ARROW VORTEX SHIT NO DEADASS
			if(vortex){
				var controlArray:Array<Bool> = [
					FlxG.keys.justPressed.ONE, FlxG.keys.justPressed.TWO, FlxG.keys.justPressed.THREE, FlxG.keys.justPressed.FOUR,
					FlxG.keys.justPressed.FIVE, FlxG.keys.justPressed.SIX, FlxG.keys.justPressed.SEVEN, FlxG.keys.justPressed.EIGHT
				];
				var holdArray:Array<Bool> = [
					FlxG.keys.pressed.ONE, FlxG.keys.pressed.TWO, FlxG.keys.pressed.THREE, FlxG.keys.pressed.FOUR,
					FlxG.keys.pressed.FIVE, FlxG.keys.pressed.SIX, FlxG.keys.pressed.SEVEN, FlxG.keys.pressed.EIGHT
				];

				if (heldNotesVortex.length > 0 && holdArray.contains(true))
				{
					for(i in 0...holdArray.length){
						if (holdArray[i]){
							var note = heldNotesVortex[i];
							if (note != null){
								var len = CoolUtil.snap(Conductor.songPosition - note[0], Conductor.stepCrochet);
								setNoteSustain(len, note);
							}
						}else if(heldNotesVortex[i]!=null)
							heldNotesVortex[i] = null;
						
					}
				}else{
					heldNotesVortex = [];
				}

				if (controlArray.contains(true))
				{
					for (i in 0...controlArray.length)
					{
						if(controlArray[i])
							doANoteThing(Conductor.songPosition, i, currentType);
					}
				}
			}	

			if (FlxG.keys.justPressed.UP || FlxG.keys.justPressed.DOWN)
			{
				FlxG.sound.music.pause();
				if (vocals != null) vocals.pause();
				for (track in extraTracks) track.pause();

				var snap:Float = Conductor.stepCrochet / quantizationMult;
				var feces:Float = CoolUtil.snap(FlxG.sound.music.time, snap) + (FlxG.keys.justPressed.UP ? -snap : snap);

				FlxTween.tween(FlxG.sound.music, {time: feces}, 0.1, {ease: FlxEase.circOut});
			}
			

			var shiftThing:Int = 1;
			if (FlxG.keys.pressed.SHIFT)
				shiftThing = 4;

			for(i in curSec ... curSec + shiftThing + 1){
				if(_song.notes[i] == null){
					if(setSectionStartTime(i) < FlxG.sound.music.length)
						insertSection(i);
				}
			}

			if (FlxG.keys.justPressed.D)
				changeSection(curSec + shiftThing);
			if (FlxG.keys.justPressed.A) {
				if(curSec <= 0){

					// sectionStartTime() but for
					// getting the last accessible section
					
					var daBPM:Float = _song.bpm;
					var daPos:Float = 0;
			
					for (i in 0..._song.notes.length - 1)
					{
						if(_song.notes[i] == null)
							continue;
						
						if (_song.notes[i].changeBPM)
							daBPM = _song.notes[i].bpm;
						
						daPos += getSectionBeats(i) * (1000 * 60 / daBPM);	

						if (daPos > FlxG.sound.music.length){
							changeSection(i);
							break;
						}
					}
				}else 
					changeSection(curSec - shiftThing);
			}
		} 
		else if (FlxG.keys.justPressed.ENTER) {
			for (i in 0...blockPressWhileTypingOn.length) {
				if(blockPressWhileTypingOn[i].hasFocus) {
					blockPressWhileTypingOn[i].hasFocus = false;
				}
			}
		}

		_song.bpm = tempBpm;
		
		lastConductorPos = Conductor.songPosition;
		Conductor.songPosition = FlxG.sound.music.time;

		strumLineUpdateY();
		camPos.y = strumLine.y;

		if (strumLineNotes.visible = quant.visible = vortex){
			for (i in 0...8){
				strumLineNotes.members[i].y = strumLine.y;
				strumLineNotes.members[i].alpha = FlxG.sound.music.playing ? 1 : 0.35;
			}
		}

		bpmTxt.text =
		"Time: " + Std.string(FlxMath.roundDecimal(Conductor.songPosition / 1000, 2)) + " / " + Std.string(FlxMath.roundDecimal(FlxG.sound.music.length / 1000, 2)) +
		"\n\nSection: " + curSec +
		"\nBeat: " + funkin.data.Highscore.floorDecimal(curDecBeat, 2) +
		"\nStep: " + curStep;

		var playedSound:Array<Bool> = []; //Prevents ouchy GF sex sounds
		var updateSelectedNote = curSelectedNote != null;

		curRenderedNotes.forEachAlive(function(note:Note) {
			if (updateSelectedNote) 
			{
				var columnToCheck:Int = note.column;
				if(columnToCheck > -1 && note.mustPress != _song.notes[curSec].mustHitSection) columnToCheck += 4;

				if (curSelectedNote[0] == note.strumTime && (curSelectedNote[2]==null ? columnToCheck<0 : curSelectedNote[1]==columnToCheck))
				{
					colorSine += elapsed;

					var colorVal:Float = 0.7 + 0.3 * FlxMath.fastSin(Math.PI * colorSine);
					var colorVal:Int = Math.round(colorVal * 255);

					note.color = FlxColor.fromRGB(colorVal, colorVal, colorVal, 255);

					updateSelectedNote = false;
				}
			}
			
			if (note.strumTime <= Conductor.songPosition) 
			{
				if (note.alpha != 0.4 && FlxG.sound.music.playing) 
				{
					if (note.column > -1)
					{
						// This is a note.

						if (!note.ignoreNote)
						{
							var data:Int = note.column;
							var columnToCheck:Int = data;
							if (columnToCheck > -1 && note.mustPress != _song.notes[curSec].mustHitSection) 
								columnToCheck += 4;

							var strum:StrumNote = strumLineNotes.members[columnToCheck];
							strum.playAnim('confirm', true, note);
							strum.resetAnim = (note.sustainLength / 1000) + 0.15;
						
							if (!note.hitsoundDisabled && playedSound[data]!=true && (note.mustPress ? playSoundBf.checked : playSoundDad.checked))
							{
								var soundToPlay = 'hitsound';
								if(_song.player1 == 'gf') // Easter egg
									soundToPlay = 'GF_${data + 1}';
	
								FlxG.sound.play(Paths.sound(soundToPlay)).pan = (note.column < 4) ? -0.3 : 0.3; //would be coolio
								playedSound[data] = true;
							}
							
						}
					}else{
						// This is an event.

						if (playSoundEvents.checked)
							FlxG.sound.play(Paths.sound('hitsound'));
					}
				}

				note.alpha = 0.4;
			}else
				note.alpha = 1;
		});

		if(metronome.checked && lastConductorPos != Conductor.songPosition) {
			var metroInterval:Float = 60 / metronomeStepper.value;
			var metroStep:Int = Math.floor(((Conductor.songPosition + metronomeOffsetStepper.value) / metroInterval) / 1000);
			var lastMetroStep:Int = Math.floor(((lastConductorPos + metronomeOffsetStepper.value) / metroInterval) / 1000);
			if(metroStep != lastMetroStep) { // this should be rewritten to be in sync w/ some shit like playScheduled but not really since we dont have that in flixel
				FlxG.sound.play(Paths.sound('Metronome_Tick'));
				//trace('Ticked');
			}
		}

		super.update(elapsed);
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
		var leBeats = getSectionBeats();
		var leHeight:Int = Std.int(GRID_SIZE * leBeats * 4 * zoomList[curZoom]);
		
		var nextStartTime:Float = sectionStartTime(1); 
		var nextBeats = getSectionBeats(curSec + 1);
		if (nextBeats == null) nextBeats = 0;
		
		gridBG = FlxGridOverlay.create(GRID_SIZE, GRID_SIZE, GRID_SIZE * 9, leHeight);

		if (nextStartTime <= FlxG.sound.music.length && nextBeats > 0)
		{
			var nextHeight:Int = Std.int(GRID_SIZE * nextBeats * 4 * zoomList[curZoom]);

			nextGridBG = FlxGridOverlay.create(GRID_SIZE, GRID_SIZE, GRID_SIZE * 9, nextHeight);
			nextGridBG.y = gridBG.height;
			gridLayer.add(nextGridBG);
			
			var gridBlack:FlxSprite = new FlxSprite(0, gridBG.height).makeGraphic(Std.int(GRID_SIZE * 9), Std.int(nextGridBG.height), FlxColor.BLACK);
			gridBlack.alpha = 0.4;
			gridLayer.add(gridBlack);

			leHeight += nextHeight;
		}
		
		gridLayer.add(gridBG);

		//if(vortex)
		for (i in 1...Std.int((leBeats + nextBeats) / 2)) {
			var beatsep1:FlxSprite = new FlxSprite(gridBG.x, (GRID_SIZE * (4 * curZoom)) * i).makeGraphic(Std.int(gridBG.width), 1, 0x44FF0000);
			gridLayer.add(beatsep1);
		}
		
		// player - opponent separator
		var gridBlackLine:FlxSprite = new FlxSprite(gridBG.x + gridBG.width - (GRID_SIZE * 4)).makeGraphic(2, leHeight, FlxColor.BLACK);
		gridLayer.add(gridBlackLine);

		// event separator
		var gridBlackLine:FlxSprite = new FlxSprite(gridBG.x + GRID_SIZE).makeGraphic(2, leHeight, FlxColor.BLACK);
		gridLayer.add(gridBlackLine);

		updateWaveform();
		updateGrid();

		lastSecBeats = leBeats;
		lastSecBeatsNext = (nextStartTime > FlxG.sound.music.length) ? 0 : nextBeats;
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
		if(waveformPrinted) { 
			waveformSprite.makeGraphic(Std.int(GRID_SIZE * 8), Std.int(gridBG.height), 0x00FFFFFF);
			waveformSprite.pixels.fillRect(new Rectangle(0, 0, gridBG.width, gridBG.height), 0x00FFFFFF);
		}
		waveformPrinted = false;

		if (waveformTrack == null)
		{
			//trace("No track selected.");
			return;
		}

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
		var gSize:Int = Std.int(GRID_SIZE * 8);
		var hSize:Int = Std.int(gSize* 0.5);

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

	function setNoteSustain(value:Float, ?note:Array<Dynamic>):Void
	{
		if (note == null)
			note = curSelectedNote;

		if (note != null)
		{
			if (note[2] != null)
			{
				if(note[2] == value)
					return;
				note[2] = value;
				note[2] = Math.max(note[2], 0);
			}
		}

		updateNoteUI();
		updateGrid();
	}

	function changeNoteSustain(value:Float, ?note:Array<Dynamic>):Void
	{
		if (note == null)
			note = curSelectedNote;
		setNoteSustain(note[2] + value, note);
	}

	function recalculateSteps(add:Float = 0):Int
	{
		var lastChange:BPMChangeEvent = {
			stepTime: 0,
			songTime: 0,
			bpm: 0
		}
		for (i in 0...Conductor.bpmChangeMap.length)
		{
			if (FlxG.sound.music.time > Conductor.bpmChangeMap[i].songTime)
				lastChange = Conductor.bpmChangeMap[i];
		}

		curStep = lastChange.stepTime + Math.floor((FlxG.sound.music.time - lastChange.songTime + add) / Conductor.stepCrochet);
		updateBeat();

		return curStep;
	}

	function resetSection(songBeginning:Bool = false):Void
	{
		updateGrid();

		FlxG.sound.music.pause();
		// Basically old shit from changeSection???
		FlxG.sound.music.time = sectionStartTime();

		if (songBeginning)
		{
			FlxG.sound.music.time = 0;
			curSec = 0;
		}

		if(vocals != null) {
			vocals.pause();
			vocals.time = FlxG.sound.music.time;
		}
		for (track in extraTracks){
			track.pause();
			track.time = FlxG.sound.music.time;
		}
		updateCurStep();

		updateGrid();
		updateSectionUI();
		updateWaveform();
	}

	function changeSection(sec:Int = 0, ?updateMusic:Bool = true):Void
	{
		if (_song.notes[sec] != null)
		{
			curSec = sec;
			if (updateMusic)
			{
				FlxG.sound.music.pause();
				if (vocals != null) vocals.pause();
				for (track in extraTracks) track.pause();

				FlxG.sound.music.time = sectionStartTime();

				updateCurStep();
			}

			var blah1:Float = getSectionBeats();
			var blah2:Float = (sectionStartTime(1) > FlxG.sound.music.length) ? 0 : getSectionBeats(curSec + 1);
	
			if(blah1 != lastSecBeats || blah2 != lastSecBeatsNext)
				reloadGridLayer();
			else
				updateGrid();
			
			updateSectionUI();
		}

		Conductor.songPosition = FlxG.sound.music.time;
		updateWaveform();
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
		rightIcon.setGraphicSize(0, 45);
	}

	function updateNoteUI():Void
	{
		if (curSelectedNote != null) {
			if(curSelectedNote[2] != null) {
				stepperSusLength.value = curSelectedNote[2];
				if(curSelectedNote[3] != null) {
					currentType = noteTypeMap.get(curSelectedNote[3]);
					if(currentType <= 0) {
						noteTypeDropDown.selectedLabel = '';
					} else {
						noteTypeDropDown.selectedLabel = currentType + '. ' + curSelectedNote[3];
					}
				}
			} else {
				var eventData:Array<String> = curSelectedNote[1][curEventSelected];
				var eventName:String = eventData[0];

				eventDropDown.selectedLabel = eventNameInput.text = eventName;
				value1InputText.text = eventData[1];
				value2InputText.text = eventData[2];

				var selectedIdx:Int = 0;
				for (i in 0...eventStuff.length){
					if (eventStuff[i][0] == eventName){
						selectedIdx = i;
						break;
					}
				}

				eventDropDown.selectedId = Std.string(selectedIdx);
				eventDropDown.header.text.text = eventName;
				
				descText.text = eventStuff[selectedIdx][1];
			}
			strumTimeInputText.text = '' + curSelectedNote[0];
		}
	}

	
	inline function fuckFloatingPoints(n:Float):Float // haha decimals
		return CoolUtil.snap(n, Conductor.stepCrochet / (192 / 16));

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

			if(i[3] != null && note.noteType != null && note.noteType.length > 0) {
				var typeInt:Null<Int> = noteTypeMap.get(i[3]);
				var theType:String = '' + typeInt;
				if(typeInt == null) theType = '?';

				var daText:AttachedFlxText = new AttachedFlxText(0, 0, 100, theType, 24);
				daText.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
				daText.xAdd = -32;
				daText.yAdd = 6;
				daText.borderSize = 1;
				curRenderedNoteType.add(daText);
				daText.sprTracker = note;
			}
			note.mustPress = _song.notes[curSec].mustHitSection;
			if(i[1] > 3) note.mustPress = !note.mustPress;
		}
		// CURRENT EVENTS
		var startThing:Float = fuckFloatingPoints(sectionStartTime());
		var endThing:Float = fuckFloatingPoints(sectionStartTime(1));
		for (i in _song.events)
		{
			var t = fuckFloatingPoints(i[0]);
			if(t >= startThing && t < endThing)
			{
				var note:Note = setupNoteData(i, false);
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
			var t:Float = fuckFloatingPoints(i[0]);
			if(t >= startThing && t < endThing)
			{
				var note:Note = setupNoteData(i, true);
				note.alpha = 0.6;
				nextRenderedNotes.add(note);
			}
		}
	}

	function initNoteType(notetype:String){
		if(notetype == '')return;
		if(notetypeScripts.exists(notetype))return;
		var did:Bool = false;
		#if PE_MOD_COMPATIBILITY
		var fuck = ["notetypes", "custom_notetypes"];
		for (file in fuck)
		{
			var baseScriptFile:String = '$file/$notetype';
		#else
		var baseScriptFile:String = 'notetypes/$notetype';
		#end
			var exts = ["hscript"]; // TODO: maybe FunkinScript.extensions, FunkinScript.hscriptExtensions and FunkinScript.luaExtensions??
			for (ext in exts)
			{
				if (did)
					break;
				var baseFile = '$baseScriptFile.$ext';
				var files = [#if MODS_ALLOWED Paths.modFolders(baseFile), #end Paths.getPreloadPath(baseFile)];
				for (file in files)
				{
					if (!Paths.exists(file))
						continue;
					if (ext == 'hscript')
					{
						var script = FunkinHScript.fromFile(file);
						notetypeScripts.set(notetype, script);
						did = true;
					}
					if (did)
						break;
				}
			}
		#if PE_MOD_COMPATIBILITY
		}
		#end
	}

	function setupNoteData(i:Array<Dynamic>, isNextSection:Bool):Note
	{
		var daColumn = i[1];
		var daStrumTime = i[0];
		var daSus:Dynamic = i[2];

		var note:Note = new Note(daStrumTime, daColumn % 4, null, false, false, true);
		if(daSus != null) { //Common note
			if(!Std.isOfType(i[3], String)) //Convert old note type to new note type format
			{
				i[3] = noteTypeIntMap.get(i[3]);
			}
			if(i.length > 3 && (i[3] == null || i[3].length < 1))
			{
				i.remove(i[3]);
			}
			note.sustainLength = daSus;
			initNoteType(i[3]);
			note.noteType = i[3];
		} else { //Event note
			note.loadGraphic(Paths.image('eventArrow'));
			note.eventName = getEventName(i[1]);
			note.eventLength = i[1].length;
			if(i[1].length < 2)
			{
				note.eventVal1 = i[1][0][1];
				note.eventVal2 = i[1][0][2];
			}
			note.column = -1;
			daColumn = -1;
		}

		note.setGraphicSize(GRID_SIZE, GRID_SIZE);
		note.updateHitbox();
		note.x = Math.floor(daColumn * GRID_SIZE) + GRID_SIZE;
		if(isNextSection && _song.notes[curSec].mustHitSection != _song.notes[curSec+1].mustHitSection) {
			if(daColumn > 3) {
				note.x -= GRID_SIZE * 4;
			} else if(daSus != null) {
				note.x += GRID_SIZE * 4;
			}
		}

		var beats:Float = getSectionBeats(isNextSection ? 1 : 0);
		note.y = getYfromStrumNotes(daStrumTime - sectionStartTime(), beats);
		//if(isNextSection) note.y += gridBG.height;
		if(note.y < -150) note.y = -150;
		return note;
	}

	function getEventName(names:Array<Dynamic>):String
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

	#if tgt
	var noteColors:Array<FlxColor> = [0xFFA349A4, 0xFFED1C24, 0xFFB5E61D, 0xFF00A2E8];
	#else
	var noteColors:Array<FlxColor> = [0xFFC24B99, 0xFF00FFFF, 0xFF12FA05, 0xFFF9393F];
	#end
	var susWidth:Float = 8;

	function setupSusNote(note:Note):Null<FlxSprite> 
	{
		var tailOffset:Float = GRID_SIZE * 0.5;
		var height:Float = (note.sustainLength / Conductor.stepCrochet) * GRID_SIZE * zoomList[curZoom];

		if (height <= 0) return null;
		
		var spr:FlxSprite = new FlxSprite(
			note.x + (GRID_SIZE - susWidth) * 0.5, 
			note.y + tailOffset
		);
		spr.makeGraphic(1, 1, note.isQuant ? 0xFFFF0000 : noteColors[note.column % noteColors.length]);
		spr.scale.set(susWidth, height);
		spr.updateHitbox();
		spr.shader = note.shader;
		
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
		var columnToCheck:Int = note.column;

		if(columnToCheck > -1)
		{
			if(note.mustPress != _song.notes[curSec].mustHitSection) columnToCheck += 4;
			for (i in _song.notes[curSec].sectionNotes)
			{
				if (i != curSelectedNote && i.length > 2 && i[0] == note.strumTime && i[1] == columnToCheck)
				{
					curSelectedNote = i;
					break;
				}
			}
		}
		else
		{
			for (i in _song.events)
			{
				if(i != curSelectedNote && i[0] == note.strumTime)
				{
					curSelectedNote = i;
					curEventSelected = Std.int(curSelectedNote[1].length) - 1;
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
		var columnToCheck:Int = note.column;
		if(columnToCheck > -1 && note.mustPress != _song.notes[curSec].mustHitSection) columnToCheck += 4;

		if(note.column > -1) //Normal Notes
		{
			for (i in _song.notes[curSec].sectionNotes)
			{
				if (i[0] == note.strumTime && i[1] == columnToCheck)
				{
					if(i == curSelectedNote) curSelectedNote = null;
					//FlxG.log.add('FOUND EVIL NOTE');
					_song.notes[curSec].sectionNotes.remove(i);
					break;
				}
			}
		}
		else //Events
		{
			for (i in _song.events)
			{
				if(i[0] == note.strumTime)
				{
					if(i == curSelectedNote)
					{
						curSelectedNote = null;
						changeEventSelected();
					}
					//FlxG.log.add('FOUND EVIL EVENT');
					_song.events.remove(i);
					break;
				}
			}
		}

		updateGrid();
	}

	public function doANoteThing(cs, d, style){
		var delnote = false;
		if(strumLineNotes.members[d].overlaps(curRenderedNotes))
		{
			curRenderedNotes.forEachAlive(function(note:Note)
			{
				if (note.overlapsPoint(new FlxPoint(strumLineNotes.members[d].x + 1,strumLine.y+1)) && note.column == d%4)
				{
						//trace('tryin to delete note...');
						if(!delnote) deleteNote(note);
						delnote = true;
				}
			});
		}

		if (!delnote){
			addNote(cs, d, style, false);
		}
	}
	function clearSong():Void
	{
		for (daSection in 0..._song.notes.length)
		{
			_song.notes[daSection].sectionNotes = [];
		}

		updateGrid();
	}

	private function addNote(strum:Null<Float> = null, data:Null<Int> = null, type:Null<Int> = null, click:Bool=true):Void
	{
		var noteStrum:Float = strum!=null ? strum : getStrumTime(dummyArrow.y * (getSectionBeats() / 4), false) + sectionStartTime();
		var column:Int = data!=null ? data : Math.floor((FlxG.mouse.x - GRID_SIZE) / GRID_SIZE);
		var noteSus:Float = 0.0;
		var daType:Int = type!=null ? type : currentType;
		var isEvent:Bool = column < 0;

		if (isEvent)
		{
			var eventType:String = eventNameInput.text; //eventStuff[Std.parseInt(eventDropDown.selectedId)][0];
			var text1:String = value1InputText.text;
			var text2:String = value2InputText.text;

			_song.events.push([noteStrum, [[eventType, text1, text2]]]);
			curSelectedNote = _song.events[_song.events.length - 1];
			curEventSelected = 0;
			changeEventSelected();
		}
		else		
		{
			var noteTypeName:String = noteTypeIntMap.get(daType);

			_song.notes[curSec].sectionNotes.push([noteStrum, column, noteSus, noteTypeName]);
			curSelectedNote = _song.notes[curSec].sectionNotes[_song.notes[curSec].sectionNotes.length - 1];
			
			if (click){
				heldNotesClick[column] = curSelectedNote;

				if (FlxG.keys.pressed.CONTROL){
					var note:Array<Dynamic> = [noteStrum, (column + 4) % 8, noteSus, noteTypeName];
					_song.notes[curSec].sectionNotes.push(note);
					heldNotesClick[(column + 4) % 8] = note;
				}
			}else{
				heldNotesVortex[column] = curSelectedNote;
			}
		}

		//trace(noteData + ', ' + noteStrum + ', ' + curSec);
		strumTimeInputText.text = '' + curSelectedNote[0];

		updateGrid();
		updateNoteUI();
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
		FlxG.save.data.autosave = Json.stringify({
			"song": _song
		});
		FlxG.save.flush();
	}

	function loadJson(song:String):Void
	{
		var daJson:SwagSong = Song.loadFromJson(song.toLowerCase(), song.toLowerCase());

		if (daJson == null){
			openSubState(new Prompt('An error ocurred while loading the JSON file', 0, null, null, false, "OK", "OK"));
		}else{
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

	function sortByTime(Obj1:Array<Dynamic>, Obj2:Array<Dynamic>):Int
	{
		return FlxSort.byValues(FlxSort.ASCENDING, Obj1[0], Obj2[0]);
	}

	private function saveLevel()
	{
		if(_song.events != null && _song.events.length > 1) _song.events.sort(sortByTime);
		
		var json = {"song": _song};
		var data:String = Json.stringify(json, "\t");

		if ((data != null) && (data.length > 0))
		{
			_file = new FileReference();
			_file.addEventListener(Event.COMPLETE, onSaveComplete);
			_file.addEventListener(Event.CANCEL, onSaveCancel);
			_file.addEventListener(IOErrorEvent.IO_ERROR, onSaveError);
			_file.save(data.trim(), Paths.formatToSongPath(_song.song) + ".json");
		}
	}

	private function saveMetadata(){
		var metadata = _song.metadata;
		if(metadata==null){
			metadata = {
				artist: "Unspecified",
				charter: "Unspecified"
			}
		}
		var data:String = Json.stringify(metadata, "\t");

		if ((data != null) && (data.length > 0))
		{
			_file = new FileReference();
			_file.addEventListener(Event.COMPLETE, onSaveComplete);
			_file.addEventListener(Event.CANCEL, onSaveCancel);
			_file.addEventListener(IOErrorEvent.IO_ERROR, onSaveError);
			_file.save(data.trim(), "metadata.json");
		}
	}

	private function saveEvents()
	{
		if(_song.events != null && _song.events.length > 1) _song.events.sort(sortByTime);
		var eventsSong:Dynamic = {
			events: _song.events
		};
		var json = {
			"song": eventsSong
		}

		var data:String = Json.stringify(json, "\t");

		if ((data != null) && (data.length > 0))
		{
			_file = new FileReference();
			_file.addEventListener(Event.COMPLETE, onSaveComplete);
			_file.addEventListener(Event.CANCEL, onSaveCancel);
			_file.addEventListener(IOErrorEvent.IO_ERROR, onSaveError);
			_file.save(data.trim(), "events.json");
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