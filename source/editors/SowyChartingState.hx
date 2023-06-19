package editors;

import flixel.util.FlxSort;
import openfl.events.IOErrorEvent;
import openfl.events.Event;
import openfl.net.FileReference;
import flixel.ui.FlxButton;
import haxe.io.Path;
import flixel.addons.ui.FlxUITabMenu;
#if sys
import sys.FileSystem;
#end
using StringTools;
import flixel.addons.ui.FlxUI;
import haxe.Json;
import flixel.math.FlxRect;
import Section.SwagSection;
import flixel.system.FlxSound;
import flixel.text.FlxText;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.input.FlxBaseKeyList;
import flixel.graphics.FlxGraphic;
import flixel.addons.display.FlxBackdrop;
import Song;

// im just doing this for troll slaiyers because im too dumb to figure out the chart editor code
// code might or might not be shit (i've never done or touched a chart editor before)

// TODO: zoom and everything else thats missing.



// anyways say bye bye to showing custom note textures
class ChartNote extends FlxSprite
{
	public var parentSection:SwagSection;
	public var noteInfo:Array<Dynamic>;
	public var noteData(default, set):Int;
	public var strumTime:Float;

	public var tail:Null<ChartTail> = null;
	public var notetypeText:Null<FlxText> = null;

	var colArray:Array<String> = ["purple", "blue", "green", "red"];
	function set_noteData(val){
		noteData = val;

		var name = colArray[val];
		animation.addByPrefix(name, name + '0', 0, false);
		animation.play(name, true);

		setGraphicSize(ChartingState.GRID_SIZE, ChartingState.GRID_SIZE);
		updateHitbox();

		return val;
	}

	public var colorSwap = new ColorSwap();
	public function new()
	{
		super();
		this.shader = colorSwap.shader;
		frames = Paths.getSparrowAtlas("QUANTNOTE_assets");
	}

	public static var quants:Array<Int> = [
		4, // quarter note
		8, // eight
		12, // etc
		16,
		20,
		24,
		32,
		48,
		64,
		96,
		192
	];

	public static function getQuant(beat:Float){
		var row = Conductor.beatToNoteRow(beat);
		for(data in quants){
			if(row%(Conductor.ROWS_PER_MEASURE/data) == 0){
				return data;
			}
		}
		return quants[quants.length-1]; // invalid
	}

	public function setup(parentSection, noteInfo, strumTime, noteData)
	{
		this.parentSection = parentSection;
		this.noteInfo = noteInfo;
		this.strumTime = strumTime;
		this.noteData = noteData;
		this.tail = null;
		this.notetypeText = null;

		if (ClientPrefs.noteSkin == "Quants"){
			var beat = Conductor.getBeatSinceChange(strumTime);
			var quant = getQuant(beat);
			var idx = quants.indexOf(quant);

			colorSwap.hue = ClientPrefs.quantHSV[idx][0] / 360;
			colorSwap.saturation = ClientPrefs.quantHSV[idx][1] / 100;
			colorSwap.brightness = ClientPrefs.quantHSV[idx][2] / 100;			
		}else{
			colorSwap.hue = ClientPrefs.arrowHSV[noteData % 4][0] / 360;
			colorSwap.saturation = ClientPrefs.arrowHSV[noteData % 4][1] / 100;
			colorSwap.brightness = ClientPrefs.arrowHSV[noteData % 4][2] / 100;
		}
	}
}
class ChartTail extends FlxSprite
{
	public var colorSwap = new ColorSwap();
	public function new(?x, ?y, ?graph){
		super(x, y, graph);
		this.shader = colorSwap.shader;
	}
}

@:allow(ChartingUI)
class SowyChartingState extends MusicBeatState
{
	public static var instance:SowyChartingState;
	public var _song:SwagSong; 

	var tracks:Map<String, FlxSound>;
	var inst:FlxSound; // for ez reference

	////
	public static final GRID_SIZE = 40;
	final zoomList:Array<Float> = [
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
	final quantizations:Array<Int> = [
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

	//// 
	public var playbackRate:Float = 1;
	var curZoom:Int = 2;
	var quantization:Int = 16;
	var curQuant:Int = 3;

	//
	var bgCamera:FlxCamera;
	var sectionCamera:FlxCamera;
	public var optionCamera:FlxCamera;

	var sustainGroup = new FlxTypedGroup<ChartTail>();
	var noteGroup = new FlxTypedGroup<ChartNote>();
	var notetypeTextGroup = new FlxTypedGroup<FlxText>();
	var strumLine:FlxSprite;

	var gridSelection:FlxSprite;

	var prevSecBlackout:FlxSprite;
	var nextSecBlackout:FlxSprite;

	//
	var ui:ChartingUI = new ChartingUI();
	public var console:Console = new Console();

	//
	var bpmTxt:FlxText;
	var quantTxt:FlxText;

	////
	function autosaveSong():Void
	{
		FlxG.save.data.autosave = Json.stringify({
			"song": _song
		});
		FlxG.save.flush();
		console.addTextMessage("auto saved");
	}

	function loadAutosave(){	
		try{
			if (FlxG.save.data.autosave != null){
				_song = Song.parseJSONshit(FlxG.save.data.autosave);
				return true;
			}
		}catch(e){}

		return false;
	}

	public var noteTypeIntMap:Map<Int, String> = new Map<Int, String>();
	public var noteTypeMap:Map<String, Null<Int>> = new Map<String, Null<Int>>();
	public var displayNameList:Null<Array<String>> = null;
	// todo: optimization pls
	public function getNotetypes(){
		if (displayNameList != null)
			return displayNameList;

		var key:Int = 0;
		displayNameList = [];

		function pushName(name:String){
			displayNameList.push(name);
			noteTypeMap.set(name, key);
			noteTypeIntMap.set(key, name);
			key++;
		}

		while (key < ChartingState.noteTypeList.length) {
			pushName(ChartingState.noteTypeList[key]);
		}

		// Get notetypes used in the chart.
		for (section in _song.notes){
			for (note in section.sectionNotes){
				var noteType:Null<Any> = note[3]; // Null<Any> cause non nullable ints get turned into 0's

				if (Std.isOfType(noteType, String) && !noteTypeMap.exists(noteType)){
					trace(noteType);
					pushName(noteType);				
				}
			}
		}

		// Get notetypes from the notetypes folder
		#if (sys && (hscript || LUA_ALLOWED))
		var directories:Array<String> = Paths.getFolders('notetypes');
		var allowedFormats = [
			#if hscript 'hscript', #end 
			#if LUA_ALLOWED 'lua' #end 
		];
		for (directory in directories)
		{
			if (!FileSystem.exists(directory))
				continue;

			for (file in FileSystem.readDirectory(directory))
			{
				if (FileSystem.isDirectory(Path.join([directory, file])))
					continue;

				var daFile = new Path(file);

				if (!allowedFormats.contains(daFile.ext)) continue;
				if (noteTypeMap.exists(daFile.file)) continue;

				pushName(daFile.file);
			}
		}
		#end

		for (i in 1...displayNameList.length)
			displayNameList[i] = '$i. ${displayNameList[i]}';

		return displayNameList;
	}

	public function new(?swagSong:SwagSong)
	{
		super();
	
		//_song = PlayState.SONG;

		if (swagSong != null){
			_song = swagSong;
		}
		// load it from the autosave cause playstate fucks up notedatas above 7 and im not fixin it
		else if (loadAutosave()){ 
			if (PlayState.SONG != null && _song.song != PlayState.SONG.song){ // but if the playstate song is different then load the playstate song ofc
				console.addTextMessage("loaded chart from playstate: "+_song.song, PlayState.SONG.song);
				_song = PlayState.SONG;
				curSec = null;
			}else{
				console.addTextMessage("loaded autosave");
			}
		}
		if (_song == null){
			_song = {song: "unknown", bpm: 100, notes: []};
			curSec = null;
		}	
	}

	override public function create()
	{
		flixel.addons.transition.FlxTransitionableState.skipNextTransIn = true;
		super.create();

		instance = this;

		persistentUpdate = true;

		var createStart = Sys.time();

		if (FlxG.sound.music != null)
			FlxG.sound.music.stop();

		getNotetypes();

		/* im not doin this lolll
		for (section in _song.notes){
			for (noteInfo in section.sectionNotes){
				var noteType = noteInfo[3];

				if (noteType is Int)
					noteType = ChartingState.noteTypeList[cast noteType];
				else if (!(noteType is String))
					noteType = "";
			}
		}
		*/

		////
		function makeTrack(trackName){
			var newTrack = new FlxSound();
			newTrack.loadEmbedded(Paths.track(_song.song, trackName), false, false);

			// prevent lag spike when first playing the song
			newTrack.volume = 0;
			newTrack.play().pause().time = 0;
			newTrack.volume = 1;

			FlxG.sound.list.add(newTrack);
			return newTrack;
		}
		tracks = ["Inst" => makeTrack("Inst")];

		inst = tracks.get("Inst");
		inst.onComplete = ()->{changeTime(0);}
		inst.volume = 0.6;

		if (_song.needsVoices != false)
			tracks.set("Voices", makeTrack("Voices"));
		for (trackName in _song.extraTracks)
			tracks.set(trackName, makeTrack(trackName));

		trace('finished loading tracks on ${Sys.time() - createStart} seconds');

		Conductor.lastSongPos = 0;
		Conductor.changeBPM(_song.bpm);
		Conductor.mapBPMChanges(_song);

		////
		FlxG.cameras.reset();
		
		bgCamera = new FlxCamera();
		sectionCamera = new FlxCamera();
		optionCamera = new FlxCamera();

		sectionCamera.bgColor = 0;
		optionCamera.bgColor = 0;

		FlxG.cameras.add(bgCamera, false);
		FlxG.cameras.add(sectionCamera, false);
		FlxG.cameras.add(optionCamera, false);
		
		////
		var bg = new FlxSprite().loadGraphic(Paths.image('menuBGDesat'));
		bg.scrollFactor.set();
		bg.color = 0xFF222222;
		bg.camera = bgCamera;
		add(bg);

		////
		sectionCamera.setSize(GRID_SIZE*8, FlxG.height);
		//sectionCamera.width *= 2; // for troll slaiyers yeah
		sectionCamera.x = (FlxG.width - sectionCamera.width) * 0.5;

		//
		var gridGraphic = FlxGraphic.fromRectangle(2, 2, 0xFFE7E6E6, true);
		gridGraphic.bitmap.setPixel(0,0,0xFFD9D5D5);
		gridGraphic.bitmap.setPixel(1,1,0xFFD9D5D5);

		var grid = new FlxBackdrop(gridGraphic);
		grid.blitMode = MAX_TILES(1);
		grid.scale.set(GRID_SIZE, GRID_SIZE);
		grid.updateHitbox();
		grid.cameras = [sectionCamera];
		add(grid);

		//
		var twoBeatSeparatorGraphic = FlxGraphic.fromRectangle(1, GRID_SIZE*8, 0, true);
		twoBeatSeparatorGraphic.bitmap.setPixel32(0, GRID_SIZE*8 - 1, 0x3FFF0000);

		var twoBeatSeparator = new FlxBackdrop(twoBeatSeparatorGraphic);
		twoBeatSeparator.blitMode = MAX_TILES(1);
		twoBeatSeparator.cameras = [sectionCamera];
		add(twoBeatSeparator);

		//
		var fieldSeparatorGraphic = FlxGraphic.fromRectangle(GRID_SIZE*4, 1, 0, true);
		fieldSeparatorGraphic.bitmap.setPixel32(GRID_SIZE*4 - 1, 0, 0xFF000000);
		fieldSeparatorGraphic.bitmap.setPixel32(GRID_SIZE*4 - 2, 0, 0xFF000000);

		var fieldSeparator = new FlxBackdrop(fieldSeparatorGraphic);
		fieldSeparator.blitMode = MAX_TILES(1);
		fieldSeparator.x++;
		fieldSeparator.cameras = [sectionCamera];
		add(fieldSeparator);

		//
		var blackSize = GRID_SIZE*16;
		prevSecBlackout = new FlxSprite(0, -blackSize).makeGraphic(1, 1);
		prevSecBlackout.color = 0xFF000000;
		prevSecBlackout.scale.set(sectionCamera.width, blackSize);
		prevSecBlackout.updateHitbox();
		prevSecBlackout.alpha = 0.5;
		prevSecBlackout.camera = sectionCamera;
		add(prevSecBlackout);

		nextSecBlackout = new FlxSprite().makeGraphic(1, 1);
		nextSecBlackout.color = 0xFF000000;
		nextSecBlackout.scale.set(sectionCamera.width, blackSize);
		nextSecBlackout.updateHitbox();
		nextSecBlackout.alpha = 0.5;
		nextSecBlackout.camera = sectionCamera;
		add(nextSecBlackout);

		gridSelection = new FlxSprite().makeGraphic(1,1);
		gridSelection.scale.set(GRID_SIZE, GRID_SIZE);
		gridSelection.updateHitbox();
		//gridSelection.visible = false;
		gridSelection.alpha = 0.95;
		gridSelection.camera = sectionCamera;
		add(gridSelection);

		//
		sustainGroup.camera = sectionCamera;
		add(sustainGroup);
		noteGroup.camera = sectionCamera;
		add(noteGroup);
		notetypeTextGroup.camera = sectionCamera;
		add(notetypeTextGroup);
		
		//
		var iconScale = GRID_SIZE/150;

		var leftIcon = new HealthIcon("dad");
		leftIcon.scale.set(iconScale, iconScale);
		leftIcon.updateHitbox();
		leftIcon.setPosition(GRID_SIZE * 1/3 * 0.5, -GRID_SIZE);
		leftIcon.scrollFactor.set();
		leftIcon.camera = sectionCamera;
		add(leftIcon);

		var rightIcon = new HealthIcon("bf");
		rightIcon.scale.set(iconScale, iconScale);
		rightIcon.updateHitbox();
		rightIcon.setPosition(leftIcon.x + GRID_SIZE*4, -GRID_SIZE);
		rightIcon.scrollFactor.set();
		rightIcon.camera = sectionCamera;
		add(rightIcon);

		strumLine = new FlxSprite(0, 0, FlxGraphic.fromRectangle(1, 1, 0xFFFFFFFF, true));
		strumLine.scale.set(sectionCamera.width, 4);
		strumLine.updateHitbox();
		strumLine.camera = sectionCamera;
		add(strumLine);

		sectionCamera.follow(strumLine);

		/////
		bpmTxt = new FlxText(12, 50, 0, "", 20);
		bpmTxt.setFormat(null, 18, 0xFFFFFFFF, LEFT, FlxTextBorderStyle.OUTLINE, 0xFF000000);
		bpmTxt.borderSize = 2;
		bpmTxt.scrollFactor.set();
		bpmTxt.camera = optionCamera;
		add(bpmTxt);
	
		quantTxt = new FlxText(12, 10 + bpmTxt.y + 20*6, 0, "Beat Snap: " + quantization + "th", 20);
		quantTxt.setFormat(null, 18, 0xFFFFFFFF, LEFT, FlxTextBorderStyle.OUTLINE, 0xFF000000);
		quantTxt.borderSize = 2;
		quantTxt.scrollFactor.set();
		quantTxt.camera = optionCamera;
		add(quantTxt);

		console.camera = optionCamera;
		add(console);

		/////
		openSubState(ui);

		if (curSec != null){
			Conductor.songPosition = inst.time = getSectionStartTime(curSec);
			curSec = null;
		}
		onTimeChanged();

		////
		nextSecBlackout.y = GRID_SIZE * Conductor.getStep(inst.length);

		console.addTextMessage('Loaded on ${Sys.time() - createStart} seconds');
	}

	public static var curSec:Null<Int> = null; // its only null for the daSection!=lastSection in the section update thing 
	var curSecStartTime:Float;
	var curSecEndTime:Float;

	var prevSectionStartTime:Null<Float> = null;
	var nextSectionEndTime:Float = 0;
	function updateCurrentSection():Bool
	{
		prevSectionStartTime = _song.notes[curSec-1] != null ? getSectionStartTime(curSec-1) : null;
		nextSectionEndTime = getSectionStartTime(curSec+2);

		//
		var lastSection = curSec;

		var daSection:Int = 0;
		var daStartTime:Float = 0;
		var daEndTime:Float = 0; // Needs to be initialized

		for (idx in 0..._song.notes.length)
		{
			var startTime = getSectionStartTime(idx);

			if (startTime > Conductor.songPosition){
				daEndTime = startTime;
				daSection = idx-1;
				break;
			}else{
				daStartTime = startTime;
			}
		}
		
		curSec = daSection;
		curSecStartTime = daStartTime;
		curSecEndTime = daEndTime;

		return curSec!=lastSection;
	}

	function getSectionBeats(section:Int)
	{
		var val:Null<Float> = null;
		
		if(_song.notes[section] != null) 
			val = _song.notes[section].sectionBeats;
		
		return val != null ? val : 4;
	}

	function getSectionStartTime(section:Int):Float
	{
		var daBPM:Float = _song.bpm;
		var daPos:Float = 0;

		for (i in 0...section)
		{
			if(_song.notes[i] == null)
				continue;
			
			if (_song.notes[i].changeBPM)
				daBPM = _song.notes[i].bpm;
			
			daPos += getSectionBeats(i) * (1000 * 60 / daBPM);		
		}
		return daPos;
	}
	function getTimeSection(time:Float){
		var curTime:Float = 0;
		var lastSection:Int = 0;
		var daBPM:Float = _song.bpm;

		for (idx in 0..._song.notes.length){
			var section = _song.notes[idx];
			
			if (section == null) continue;
			if (section.changeBPM) daBPM = section.bpm;

			curTime += getSectionBeats(idx) * (60 / daBPM) * 1000;

			if (curTime > time) 
				return idx;
			else if (idx+1 < _song.notes.length)
				lastSection = idx;
		}

		return lastSection;
	}	

	function getCurSectionProgress(time:Float):Float
	{
		if (time == curSecEndTime) return 0;

		var sectionTime = curSecEndTime - time;
		var sectionLength = curSecEndTime - curSecStartTime;

		return 1 - sectionTime/sectionLength;
	}

	inline function getSectionSteps(sectionNumber:Int){
		return getSectionBeats(sectionNumber)*4;
	}

	var notesHitten:Array<Array<Dynamic>> = []; // yes, hitten.
	function updateCameraPosition()
	{
		strumLine.y = Conductor.getStep(Conductor.songPosition)*GRID_SIZE;
		
		for (noteSpr in noteGroup){
			var playSound = false;
			
			if (Conductor.songPosition >= noteSpr.strumTime){
				noteSpr.alpha = 0.5;

				if (inst.playing && !notesHitten.contains(noteSpr.noteInfo)){
					playSound = true;
					notesHitten.push(noteSpr.noteInfo);
				}
			}else
				noteSpr.alpha = 1;

			if (!playSound) continue;

			var noteData = noteSpr.noteInfo[1];
			var isBf = (noteSpr.parentSection.mustHitSection) ? (noteData%8 < 4) : (noteData%8 > 3);

			if ((playSoundBf && playSoundDad) || (playSoundBf && isBf) || (playSoundDad && !isBf)){
				FlxG.sound.play(Paths.sound("hitsound")).pan = isBf ? 0.3 : -0.3; //would be coolio
			}			
		}
	}
	var playSoundDad:Bool = false;
	var playSoundBf:Bool = false;

	var noteColors = [0xFFA349A4, 0xFFED1C24, 0xFFB5E61D, 0xFF00A2E8];
	
	public var currentlyUsedNotes:Map<Array<Dynamic>, ChartNote> = [];
	public var curSelectedNote:Array<Dynamic>;

	function updateNotePos(noteSpr:ChartNote){
		var notePos = noteSpr.noteInfo[1];
		var noteData:Int = Std.int(notePos % 8);

		// mustHitSections are so retarded :(
		// ig ninjamuffin did it cause the week 1 songs had the same patterns for the opponent and player
		if (noteSpr.parentSection.mustHitSection){
			if (noteData >= 0 && noteData <= 3)
				notePos += 4;
			else if (noteData >= 4 && noteData <= 7)
				notePos -= 4;
		}

		noteSpr.setPosition(
			notePos * GRID_SIZE,
			Conductor.getStep(noteSpr.noteInfo[0]) * GRID_SIZE
		);
	}

	function makeTail(noteSpr:ChartNote, size:Float)
	{
		var width = 8;
				
		var newTrail = sustainGroup.recycle(ChartTail, ()->{return cast new ChartTail().makeGraphic(1,1);}); 
		newTrail.setPosition(
			noteSpr.x + (GRID_SIZE - width)*0.5, 
			noteSpr.y + GRID_SIZE*0.5
		);
		if (ClientPrefs.noteSkin == "Quants")
			newTrail.color = 0xFFFF0000;
		else
			newTrail.color = noteColors[noteSpr.noteData%4];

		newTrail.scale.set(
			width, 
			size
		);
		newTrail.updateHitbox();
		sustainGroup.add(newTrail);

		noteSpr.tail = newTrail;
	}
	public function updateNoteTail(noteSpr:ChartNote){
		var section = noteSpr.parentSection;
		var sustainLength = noteSpr.noteInfo[2];

		if (sustainLength > 0){
			var daBPM = section.changeBPM ? section.bpm : Conductor.getBPMFromSeconds(noteSpr.strumTime).bpm;
			var daStepCrochet = ((60 / daBPM) * 1000) / 4;
			var size = (sustainLength / daStepCrochet + 0.5) * GRID_SIZE; // 0.5 cause this sprite starts from the middle of the note texture i guess?????

			if (noteSpr.tail == null)
				makeTail(noteSpr, size);
			else{
				noteSpr.tail.scale.y = size;
				noteSpr.tail.updateHitbox();
			}

			noteSpr.tail.colorSwap.hue = noteSpr.colorSwap.hue;
			noteSpr.tail.colorSwap.saturation = noteSpr.colorSwap.saturation;
			noteSpr.tail.colorSwap.brightness = noteSpr.colorSwap.brightness;
		}
		else if (noteSpr.tail != null){
			noteSpr.tail.kill();
			noteSpr.tail = null;
		}
	}

	function makeNoteTypeText(noteSpr:ChartNote, ?text:String){
		if (text == null) text = "123";

		var newText = notetypeTextGroup.recycle(FlxText, ()->{
			var daText = new FlxText(0, 0, 100, "123");
			daText.setFormat(Paths.font("vcr.ttf"), 24, 0xFFFFFFFF, CENTER, FlxTextBorderStyle.OUTLINE, 0xFF000000);
			daText.borderSize = 1;
			daText.camera = sectionCamera;
			return daText;
		});
		newText.setPosition(
			noteSpr.x + (noteSpr.width - newText.width)/2,
			noteSpr.y + (noteSpr.height - newText.height)/2
		);
		newText.text = text;
		notetypeTextGroup.add(newText);

		noteSpr.notetypeText = newText;
	}
	public function updateNoteType(noteSpr:ChartNote){
		var noteType:Null<Any> = noteSpr.noteInfo[3];
		var text:Null<String> = null;
		
		if (Std.isOfType(noteType, String) && noteType != "" && noteTypeMap.exists(noteType)) 
			text = Std.string(noteTypeMap.get(noteType));

		if (text == null || text == ""){
			if (noteSpr.notetypeText != null){
				noteSpr.notetypeText.kill();
				noteSpr.notetypeText = null;
			}
		}else{
			if (noteSpr.notetypeText != null)
				noteSpr.notetypeText.text = text;
			else
				makeNoteTypeText(noteSpr, text);
		}
	}

	function createSectionNotes(section:SwagSection)
	{
		for (noteInfo in section.sectionNotes)
		{
			if (currentlyUsedNotes.exists(noteInfo))
				continue;

			var noteSpr = noteGroup.recycle(ChartNote);
			noteSpr.setup(section, noteInfo, noteInfo[0], Std.int(noteInfo[1]%4));
			noteSpr.camera = sectionCamera;

			updateNotePos(noteSpr);
			updateNoteTail(noteSpr);
			updateNoteType(noteSpr);

			noteGroup.add(noteSpr);
			currentlyUsedNotes.set(noteInfo, noteSpr);
		}
	}

	function killNoteSpr(noteSpr:ChartNote){
		if (noteSpr.tail != null){
			noteSpr.tail.kill();
			noteSpr.tail = null;
		}
		if (noteSpr.notetypeText != null){
			noteSpr.notetypeText.kill();
			noteSpr.notetypeText = null;
		}

		noteSpr.kill();

		currentlyUsedNotes.remove(noteSpr.noteInfo);
	}
	function belongsToSection(note:ChartNote, section:SwagSection){
		return section != null && note.parentSection == section;
	}
	function createCurSectionNotes()
	{
		var prevSection = _song.notes[curSec-1];
		var nextSection = _song.notes[curSec+1];
		var currSection = _song.notes[curSec];

		for (noteSpr in noteGroup.members){ 
			if (belongsToSection(noteSpr, prevSection) && belongsToSection(noteSpr, currSection) && belongsToSection(noteSpr, nextSection)){
				// nothing dumbass
			}else{
				killNoteSpr(noteSpr);
			}
		}
		
		if (prevSection != null)
			createSectionNotes(prevSection);
		
		if (nextSection != null)
			createSectionNotes(nextSection);

		if (currSection != null)
			createSectionNotes(currSection);
		else
			trace("what the fuck!!! " + curSec);

		/* These should stay the same.
		var alive = 0;
		noteGroup.forEachAlive((n)->{alive++;});

		var used=0; 
		for(n in currentlyUsedNotes.keys())used++;

		trace(used, alive);
		*/
	}

	function changeTime(time:Float){
		if (time < inst.time){
			for (note in notesHitten){
				if (note[0] > time)
					notesHitten.remove(note);
			}
		}

		for (_ => track in tracks)
			track.pause().time = time;
	}

	override function stepHit(){
		for (_ => track in tracks){
			if (track == inst) continue;

			if (inst.time <= track.length && Math.abs(track.time-inst.time)>25)
				track.time = inst.time;
		}

		super.stepHit();
	}

	function increaseSustainLength(diff:Float = 0){
		var noteSpr = currentlyUsedNotes.get(curSelectedNote);

		if (noteSpr == null){
			console.addTextMessage("No note has been selected");
			curSelectedNote = null;
		}else{
			var section = noteSpr.parentSection;
			var daBPM = section.changeBPM ? section.bpm : Conductor.getBPMFromSeconds(noteSpr.strumTime).bpm;
			
			curSelectedNote[2] += ((60 / daBPM) * 1000) / 4 * diff; // increase by a step
			curSelectedNote[2] = Math.max(curSelectedNote[2], 0); // cap 
			
			updateNoteTail(noteSpr);
		}		
	}

	var holdingNote = false;
	function set_selected(?spr:ChartNote){
		var prevSpr = currentlyUsedNotes.get(curSelectedNote);

		if (prevSpr != null){ 
			prevSpr.colorSwap.flash = 0;
			prevSpr.colorSwap.brightness = 0;
		}

		if (spr != null){
			spr.colorSwap.flash = 0;
			spr.colorSwap.brightness = -0.5;

			curSelectedNote = spr.noteInfo;
			
			@:privateAccess
			if (ui != null){
				var noteTypeName:Null<Any> = curSelectedNote[3];

				if (Std.isOfType(noteTypeName, String) && noteTypeName != ""){
					var noteTypeId = noteTypeMap.get(noteTypeName);
					//var wtf:Null<Null<Null<Null<Null<Null<Null<Null<Null<Null<Null<Null<Null<Null<Null<Null<Null<Null<Null<Int>>>>>>>>>>>>>>>>>>>;

					ui.noteTypeDropDown.selectedLabel = (noteTypeId == null) ? "" : ('$noteTypeId. $noteTypeName');
				}else
					ui.noteTypeDropDown.selectedLabel = "";
			}
		}else{
			curSelectedNote = null;
		}
	}

	function mouseUpdate(){
		if (FlxG.mouse.x >= sectionCamera.x && FlxG.mouse.x <= sectionCamera.x+sectionCamera.width){
			var mousePos = null;
			
			if (holdingNote){
				if (FlxG.mouse.justReleased || curSelectedNote == null || !currentlyUsedNotes.exists(curSelectedNote))
					holdingNote = false;
				else if (FlxG.mouse.deltaY != 0){
					if (mousePos == null)
						mousePos = FlxG.mouse.getWorldPosition(sectionCamera);

					var quantMult = (16/quantization);
					var snap = GRID_SIZE * quantMult;
					var griddY:Int = Math.floor(mousePos.y/snap); 
					var forUkraine:Conductor.BPMChangeEvent = Conductor.getBPMFromStep(griddY);
					
					var noteTime:Float = curSelectedNote[0];
					var mouseTime:Float = forUkraine.songTime + forUkraine.stepCrochet * (griddY*quantMult-forUkraine.stepTime);
					var sustainLength:Float = mouseTime-noteTime; //Math.max(0, mouseTime-noteTime);

					var noteSpr = currentlyUsedNotes.get(curSelectedNote);

					if (sustainLength == 0){

					}else if (sustainLength < 0){
						curSelectedNote[2] -= sustainLength;
						curSelectedNote[0] = mouseTime; // this doesn't move them from sections!!!!!
						
						if (noteSpr != null){
							updateNotePos(noteSpr);
							updateNoteTail(noteSpr);

							if (noteSpr.tail !=null){
								// idk if i should put this in the tail update or the pos update
								// this is the only place that needs to update the tail position anyways so whatever
								noteSpr.tail.setPosition(
									noteSpr.x + (GRID_SIZE - noteSpr.tail.width)*0.5, 
									noteSpr.y + GRID_SIZE*0.5
								);
							}

							return;
						} 
					}else{
						curSelectedNote[2] = sustainLength;
						if (noteSpr != null){
							updateNoteTail(noteSpr);
							return;
						}
					}
				}
			}
			
			var noteOverlapped:Null<ChartNote> = null;
			for (note in noteGroup){
				if (note.exists && note.alive && FlxG.mouse.overlaps(note, sectionCamera)){
					noteOverlapped = note;
					break;
				}
			}

			if (lastHoveredNote != null){
				lastHoveredNote.colorSwap.flash = 0;
			}

			if (noteOverlapped == null){
				if (mousePos == null)
					mousePos = FlxG.mouse.getWorldPosition(sectionCamera);
				gridSelection.visible = true;

				var noteData:Int = Math.floor(mousePos.x/GRID_SIZE);
				var quantMult = (16/quantization);
				var snap = GRID_SIZE * quantMult;
				var griddY:Int = Math.floor(mousePos.y/snap); 

				gridSelection.setPosition(
					noteData*GRID_SIZE,
					griddY*snap
				);
				if (FlxG.mouse.justPressed){
					var forUkraine = Conductor.getBPMFromStep(griddY);
					
					var time:Float = forUkraine.songTime + forUkraine.stepCrochet * (griddY*quantMult-forUkraine.stepTime);
					var section:SwagSection = _song.notes[getTimeSection(time)];
					var realNoteData:Int = noteData;

					if (section.mustHitSection){
						var noteData = realNoteData % 8;
						if (noteData >= 0 && noteData <= 3)
							realNoteData+=4;
						else if (noteData >= 4 && noteData <= 7)
							realNoteData-=4;
					}

					var noteInfo:Array<Dynamic> = [
						time,
						realNoteData,
						0,
						@:privateAccess{
							if (ui != null){
								var id = Std.parseInt(ui.noteTypeDropDown._selectedId);
								noteTypeIntMap.exists(id) ? noteTypeIntMap.get(id) : "";	
							}else
								"";
						}
					];
					section.sectionNotes.push(noteInfo);
					section.sectionNotes.sort((note1, note2)->{
						if (note1[0] == note2[0]) return 0;
						return note1[0]>note2[0] ? 1 : -1;
					});

					////
					var newNoteSpr = noteGroup.recycle(ChartNote);
					newNoteSpr.setup(section, noteInfo, time, noteData%4);
					newNoteSpr.camera = sectionCamera;

					updateNotePos(newNoteSpr);
					updateNoteType(newNoteSpr);
					// updateNoteTail(newNoteSpr); // notes start with 0 sustain lentght brah

					noteGroup.sort(FlxSort.byY);

					////
					currentlyUsedNotes.set(noteInfo, newNoteSpr);
					set_selected(newNoteSpr); //curSelectedNote = noteInfo;

					holdingNote = true;
				}
			}else{
				if (FlxG.mouse.justPressed){
					if (FlxG.keys.pressed.CONTROL){
						set_selected(noteOverlapped); //curSelectedNote = noteOverlapped.noteInfo;
					}else{
						set_selected(null); //curSelectedNote = null;

						noteOverlapped.parentSection.sectionNotes.remove(noteOverlapped.noteInfo);
						killNoteSpr(noteOverlapped);
					}
				}else{
					lastHoveredNote = noteOverlapped;
					noteOverlapped.colorSwap.flash = 1;
				}

				gridSelection.visible = false;
			}
		}else{
			if (lastHoveredNote != null){
				lastHoveredNote.colorSwap.flash = 0;
			}
			gridSelection.visible = false;
		}
	}

	override public function update(elapsed)
	{
		FlxG.mouse.visible = true; // why the fuck?

		var justPressed = FlxG.keys.justPressed;
		var isPressing = FlxG.keys.pressed;
		
		var movement = -FlxG.mouse.wheel;
		if (justPressed.W)
			movement--;
		if (justPressed.S)
			movement++;

		if (movement != 0){
			for (_ => track in tracks)
				track.pause();

			updateCurStep();

			var quantization = 16;
			var beat:Float = curDecBeat;
			var snap:Float = quantization / 4;
			var increase:Float = 1 / snap;
			var fuck:Float = CoolUtil.quantize(beat, snap) + increase*movement;
			var newPos:Float = Conductor.beatToSeconds(fuck);

			if (newPos < 0) 
				newPos = inst.length + newPos;
			else if (newPos > inst.length) 
				newPos = newPos % inst.length;

			changeTime(newPos);
		}

		if (justPressed.A){
			var nextSecNum = curSec - (isPressing.SHIFT ? 3 : 1);
			if (nextSecNum < 0)
				changeTime(inst.length);
			else
				changeTime(getSectionStartTime(nextSecNum));
		}
		if (justPressed.D){
			var nextSecNum = curSec + (isPressing.SHIFT ? 3 : 1);
			if (nextSecNum > _song.notes.length) nextSecNum = nextSecNum % _song.notes.length;

			var time = getSectionStartTime(nextSecNum);
			if (time > inst.length) time = 0;
			changeTime(time);
		}

		if (justPressed.Q)
			increaseSustainLength(-1);
		if (justPressed.E)
			increaseSustainLength(1);

		if (justPressed.EIGHT){
			playSoundDad = !playSoundDad;
			console.addTextMessage(playSoundDad ? "Play Dad Notes: ON" : "Play Dad Notes: OFF");
		}
		if (justPressed.NINE){
			playSoundBf = !playSoundBf;
			console.addTextMessage(playSoundBf ? "Play BF Notes: ON" : "Play BF Notes: OFF");
		}
		if (justPressed.SIX){
			inst.volume = inst.volume==0 ? 0.6 : 0; 
			console.addTextMessage(inst.volume==0 ? "Mute Inst" : "Unmute Inst");
		}
		
		Conductor.lastSongPos = Conductor.songPosition;
		Conductor.songPosition = inst.time;

		if (justPressed.SPACE){
			if (inst.playing){
				for (_ => track in tracks)
					track.pause();   
			}else{
				inst.play();
				for (_ => track in tracks){
					if (inst.time <= track.length && track != inst){
						track.time = inst.time;
						track.play();
					} 
				}
			}
		}

		if (justPressed.LEFT){
			curQuant = FlxMath.maxInt(curQuant-1, 0);
			quantization = quantizations[curQuant];
			quantTxt.text = "Beat Snap: " + quantization + "th";
		}
		if (justPressed.RIGHT){
			curQuant = FlxMath.minInt(curQuant+1, quantizations.length-1);
			quantization = quantizations[curQuant];
			quantTxt.text = "Beat Snap: " + quantization + "th";
		}

		mouseUpdate();

		if (Conductor.songPosition != Conductor.lastSongPos)
		{
			onTimeChanged();
		}

		if (FlxG.keys.justPressed.BACKSPACE){
			autosaveSong();

			MusicBeatState.switchState(new MasterEditorMenu());
			PlayState.chartingMode = false;

		}else if (FlxG.keys.justPressed.ENTER){
			autosaveSong();

			PlayState.SONG = _song;
			PlayState.chartingMode = true;

			if (!FlxG.keys.pressed.SHIFT)
				PlayState.startOnTime = Conductor.songPosition;

			MusicBeatState.switchState(new PlayState());
		}

		super.update(elapsed);
	}
	var lastHoveredNote:Null<ChartNote> = null;

	function onTimeChanged(){
		var sectionChanged = updateCurrentSection();

		if (sectionChanged){
			createCurSectionNotes();

			Conductor.changeBPM(Conductor.getBPMFromSeconds(Conductor.songPosition/1000).bpm);
		}

		updateCameraPosition();

		bpmTxt.text =
		"Time: " + Std.string(FlxMath.roundDecimal(Conductor.songPosition / 1000, 2)) + " / " + Std.string(FlxMath.roundDecimal(inst.length / 1000, 2)) +
		
		"\n\nSection: " + curSec +
		"\nBeat: " + FlxMath.roundDecimal(curDecBeat, 2)+
		"\nStep: " + FlxMath.roundDecimal(curDecStep, 2);
	}
}

//// made this a separate class so it doesn't clutter the editor code
// ill maybe regret doing this
class ChartingUI extends MusicBeatSubstate{
	var instance:SowyChartingState;
	
	var UI_box:FlxUITabMenu;
	var noteTypeDropDown:FlxUIDropDownMenuCustom;

	override function create(){
		super.create();

		instance = SowyChartingState.instance;	

		var tabs = [
			{name: "Song", label: 'Song'},
			{name: "Section", label: 'Section'},
			{name: "Note", label: 'Note'},
			{name: "Events", label: 'Events'},
			{name: "Charting", label: 'Charting'},
		];

		UI_box = new FlxUITabMenu(null, tabs, true);
		UI_box.resize(300, 400);
		UI_box.x = FlxG.width - 10 - 300;
		UI_box.y = 20;
		UI_box.scrollFactor.set();
		UI_box.camera = instance.optionCamera;
		add(UI_box);

		makeNoteUI();
		makeSongUI();
	}

	function makeSongUI(){
		var tab_group = new FlxUI(null, UI_box);
		tab_group.name = 'Song';

		var _file:FileReference;

		var saveButton = new FlxButton(10, 10, "Save JSON", ()->{
			var _song = instance._song;
			var json = {"song": _song};
			var data:String = Json.stringify(json, "\t");

			var cleanUpFileReference = (?e)->{}; // shut up man
			cleanUpFileReference = (?e)->{
				if (_file == null)
					return;
				_file.removeEventListener(Event.COMPLETE, cleanUpFileReference);
				_file.removeEventListener(Event.CANCEL, cleanUpFileReference);
				_file.removeEventListener(IOErrorEvent.IO_ERROR, cleanUpFileReference);
				_file = null;
			}
	
			if (data != null && data.length > 0){
				_file = new FileReference();
				_file.addEventListener(Event.COMPLETE, cleanUpFileReference);
				_file.addEventListener(Event.CANCEL, cleanUpFileReference);
				_file.addEventListener(IOErrorEvent.IO_ERROR, cleanUpFileReference);
				_file.save(data.trim(), Paths.formatToSongPath(_song.song) + ".json");
			}
		});
		
		var loadButton = new FlxButton(saveButton.x + saveButton.width + 10, 10, "Load From Song JSON", ()->{
			MusicBeatState.switchState(new SowyChartingState(Song.loadFromJson(
				instance._song.song,
				instance._song.song
			)));

			/*
			_file = new FileReference();
			var cleanUpFileReference;

			function onComplete(e){
				//instance._song =
				instance.resetasfksfdsfndsfnkjds
				cleanUpFileReference(null);
			}
			
			cleanUpFileReference = (?e)->{
				if (_file == null) return;
				_file.removeEventListener(Event.COMPLETE, onComplete);
				_file.removeEventListener(Event.CANCEL, cleanUpFileReference);
				_file.removeEventListener(IOErrorEvent.IO_ERROR, cleanUpFileReference);
				_file = null;
			}

			_file.addEventListener(Event.COMPLETE, onComplete);
			_file.addEventListener(Event.CANCEL, cleanUpFileReference);
			_file.addEventListener(IOErrorEvent.IO_ERROR, cleanUpFileReference);
			_file.load();
			*/
		});
		
		tab_group.add(saveButton);
		tab_group.add(loadButton);

		UI_box.addGroup(tab_group);
	}

	function makeNoteUI(){
		var tab_group = new FlxUI(null, UI_box);
		tab_group.name = 'Note';

		noteTypeDropDown = new FlxUIDropDownMenuCustom(10, 105, FlxUIDropDownMenuCustom.makeStrIdLabelArray(instance.getNotetypes(), true), function(selected:String)
		{
			var idx = Std.parseInt(selected);
			var curNote = instance.curSelectedNote;

			instance.console.addTextMessage(noteTypeDropDown.selectedLabel);

			if (idx != null && curNote != null && curNote[1] > -1) {
				curNote[3] = instance.noteTypeIntMap.get(idx);
				instance.updateNoteType(instance.currentlyUsedNotes.get(curNote));
			}
		});
		tab_group.add(noteTypeDropDown);

		UI_box.addGroup(tab_group);
	}

	override public function update(e){
		super.update(e);
	}
}

// omg
class Console extends FlxTypedGroup<ConsoleText>
{
	function updatePositions(){
		for (i in 0...members.length){
			var prevInst = members[i-1];
			var instance = members[i];
			instance.targetY = (prevInst != null ? prevInst.targetY : FlxG.height) - instance.frameHeight; 
		}
	}
	override function remove(instance:ConsoleText, splice:Bool = true):ConsoleText
	{
		var r = super.remove(instance, splice);
		updatePositions();
		return r;
	}
	override function add(instance:ConsoleText):ConsoleText
	{
		instance.parent = this;

		var r = super.add(instance);
		updatePositions();
		return r;	
	}

	public var addTextMessage:Dynamic;
	public function new(){
		super();

		addTextMessage = Reflect.makeVarArgs((toTrace:Array<Dynamic>)->{
			var text:String = toTrace==null ? "" : toTrace.join(", ");
			var msg = new ConsoleText(0, camera.height/2, 0, text);
			msg.cameras = cameras;
			add(msg);
		});
	}

	override function set_camera(val){
		for (text in members){
			text.camera = val;
		}
		return val;
	}
}
class ConsoleText extends FlxText
{
	public var timeElapsed:Float = 0;
	public var parent:Console;
	public var targetY:Float = 0;

	override function update(elapsed:Float){
		timeElapsed += elapsed;

		y = Std.int(FlxMath.lerp(y, targetY, elapsed * 10.2));
		alpha = FlxMath.lerp(1, 0.15, (timeElapsed / 6));

		super.update(elapsed);

		if (timeElapsed > 6){
			if (parent != null) parent.remove(this);
			destroy();
		}
	}
}