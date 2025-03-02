package funkin.states;

import funkin.scripts.Globals;
import hxvlc.util.typeLimit.OneOfThree;
import funkin.scripts.FunkinHScript;
import haxe.io.Path;
import sys.io.File;
import haxe.Json;
import flixel.util.FlxSignal;
import flixel.system.FlxAssets.FlxGraphicAsset;
import animateatlas.AtlasFrameMaker;
import flixel.group.FlxSpriteGroup;
import flixel.util.FlxSort;
import flixel.math.FlxMath;
import flixel.group.FlxSpriteGroup.FlxTypedSpriteGroup;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.util.typeLimit.OneOfTwo;
using StringTools;
using funkin.CoolerStringTools;

@:structInit
class LevelSongData {
	public var displayName(get, default):String = '';
	function get_displayName(){
		if(displayName.trim() == '')
			return songName.capitalize();

		return displayName;
	}
	public var songName:String;
}

// i know its v-slice core but bleeehh :P
// allows good customization


// TODO: Move all of these to a seperate proper Level class to allow for scripting etc
typedef LevelPropAnimation = {
	name:String,
	prefix:String,
	?looped:Bool,
	?fps:Int,
	?indices:Array<Int>,
	?offset:Array<Float>,
	?haltsDancing:Bool
}

typedef LevelPropData = {
	?template:String,
	?layer:String, // Used for fading out the background
	?characterId:Float,
	?x:Float,
	?y:Float,
	graphic:String,
	?alpha:Float,
	?scale:Array<Float>,
	?antialiasing:Bool,
	?animations:Array<LevelPropAnimation>,

	?danceSequence:Array<String>, // Cycles through this every dance
	?danceBeat:Float, // What beat to dance on. 0 = disabled
}

typedef JSONSongData = OneOfTwo<LevelSongData, String>;

class LevelStageProp extends FlxSprite
{
	public var canDance:Bool = true;
	public var bopTime:Float = 0;
	public var idleSequence:Array<String> = ['idle'];
	public var onDance:FlxTypedSignal<Bool->Void> = new FlxTypedSignal<Bool->Void>(); // Dispatched with false if it failed to dance
	public var onConfirm:FlxTypedSignal<Void->Void> = new FlxTypedSignal<Void->Void>(); 
	public var offsets:Map<String, Array<Float>> = [];
	public var interruptDanceAnims:Array<String> = [];

	var sequenceIndex:Int = 0;

	var nextDanceBeat:Float = 0;
	override public function new(?x:Float, ?y:Float, ?graphic:FlxGraphicAsset){
		nextDanceBeat = Conductor.curDecBeat;
		super(x, y, graphic);
	}

	public function dance(){
		if (!canDance || animation.curAnim != null && interruptDanceAnims.contains(animation.curAnim.name)){
			onDance.dispatch(false);
			return;
		}

		sequenceIndex++;
		if (sequenceIndex >= idleSequence.length)
			sequenceIndex = 0;

		playAnim(idleSequence[sequenceIndex], true);
		onDance.dispatch(true);
	}

	public function playAnim(animName:String, forced:Bool, reversed:Bool = false, frame:Int = 0){
		animation.play(animName, forced, reversed, frame);
		var theOffset = offsets.get(animName) ?? [0, 0];
		offset.set(theOffset[0], theOffset[1]);
	}

	override function update(elapsed:Float){
		if (Math.abs(Conductor.curDecBeat - nextDanceBeat) >= bopTime * 4) // To fix song reset breaking the bop, if next beat is too far out of range then just reset
			nextDanceBeat = Conductor.curBeat;

		if(bopTime > 0){
			while (Conductor.curDecBeat >= nextDanceBeat){
				nextDanceBeat += bopTime;
				dance();
			}

		}else
			nextDanceBeat = Conductor.curBeat;

		
		
		super.update(elapsed);
	}

	public static function buildFromData(propData:LevelPropData){
		var prop:LevelStageProp;
		if(propData.template != null){
			var json:Null<Dynamic> = Paths.json('${propData.template}.json');

			if (json == null){
				trace('${propData.template} doesnt exist bozo');
				prop = new LevelStageProp(0, 0);
			}else
				prop = buildFromData(json);

			prop.x += propData.x ?? 0.0;
			prop.y += propData.y ?? 0.0;
			
		}else
			prop = new LevelStageProp(propData.x ?? 0.0, propData.y ?? 0.0);

		if (propData.characterId != null)
			prop.x = (100 + (50 * (propData.characterId + 1)) + FlxG.width * 0.25 * propData.characterId) + (propData.x ?? 0.0); // not doing .x += because of templates. if you  set charsacterId on smth it should override lol!

		if (Paths.fileExists('images/${propData.graphic}/Animation.json', TEXT))
			prop.frames = AtlasFrameMaker.construct(propData.graphic);
		else if (Paths.fileExists('images/${propData.graphic}.txt', TEXT))
			prop.frames = Paths.getPackerAtlas(propData.graphic);
		else if (Paths.fileExists('images/${propData.graphic}.xml', TEXT))
			prop.frames = Paths.getSparrowAtlas(propData.graphic);
		else
			prop.loadGraphic(Paths.image(propData.graphic));

		if (propData.scale != null)
			prop.scale.set(propData.scale[0], propData.scale[1]);
		prop.updateHitbox();

		if (propData.animations != null) {
			for (animation in propData.animations) {
				if (animation.indices != null)
					prop.animation.addByIndices(animation.name, animation.prefix, animation.indices, '', animation.fps ?? 24, animation.looped ?? false);
				else
					prop.animation.addByPrefix(animation.name, animation.prefix, animation.fps ?? 24, animation.looped ?? false);

				if (animation.offset != null && animation.offset.length == 2)
					prop.offsets.set(animation.name, animation.offset);

				if (animation.haltsDancing == true)
					prop.interruptDanceAnims.push(animation.name);

				if (prop.animation.curAnim == null)
					prop.playAnim(animation.name, true);
			}
		}

		if (propData.antialiasing != null)
			prop.antialiasing = propData.antialiasing; // if null then dont set, because default antialiasing should be affecting it

		if (propData.danceSequence != null)
			prop.idleSequence = propData.danceSequence;

		if (propData.danceBeat != null) {
			prop.bopTime = propData.danceBeat;
			prop.playAnim(prop.idleSequence[0], true);
		}
		
		prop.alpha = propData?.alpha ?? 1.0;

		return prop;
	}
}


// fuck structInit bro im doing it the way i already know
typedef JSONLevelData = {
	?id:String,
	?index:Int,
	name:String,
	asset:String,
	songs:Array<JSONSongData>,
	?bgColor:String,
	?difficulties:Array<String>,
	?props:Array<LevelPropData>
}

class Level {
	var script:FunkinHScript;

	public static function fromFile(fileName:String, ?index:Int = 0, ?id:String){
		var json:Null<JSONLevelData> = Paths.exists(fileName + ".json") ? Json.parse(File.getContent(fileName + ".json")) : null;


/* 		var scriptFile = Paths.getHScriptPath(fileName);
		if (hscriptFile != null) {
			var script = FunkinHScript.fromFile(hscriptFile, hscriptFile, defaultVars);
			pushScript(script);
			return this;
		} */

		var level:Level = new Level();
		level.bgColor = CoolUtil.colorFromString(json?.bgColor ?? "#F9CF51");
		
		level.id = id ?? json?.id ?? Path.withoutDirectory(fileName);
		level.index = json?.index ?? index;
		level.name = json?.name ?? "NAME DOESNT EXIST IDIOT";
		level.asset = json?.asset ?? "storymenu/titles/week1";
		level.difficulties = json?.difficulties ?? level.difficulties;
		level.props = json?.props ?? level.props;
		level.songs = json?.songs ?? ["Test"];

		for (ext in Paths.HSCRIPT_EXTENSIONS) {
			var scriptPath = '$fileName.$ext';
			if (Paths.exists(scriptPath))
				level.script = FunkinHScript.fromFile(scriptPath, level.name, ["this"=>level]);
		}

		return level;
	}

	function callScript(call:String, ?args:Array<Dynamic>):Null<Dynamic>
	{
		if(script != null && script.exists(call))
			return script.call(call, args);

		return null;
	}

	public function new(){}

	public var id:String = 'broken';
	public var bgColor:FlxColor = 0xFFF9CF51;
	public var index:Int = 0;
	public var name:String = "PLACEHOLDER";
	public var asset:String = "storymenu/titles/week1";
	public var songs:Array<LevelSongData> = [];
	public var difficulties:Array<String> = ["easy", "normal", "hard"];
	public var props:Array<LevelPropData> = [];

	/**
	 * Returns a file path to the title asset
	 */
	public function getAsset():String {
		return callScript("getAsset") ?? asset;
	}

	/**
	 * Returns an integer to decide placement of the level
	 */
	public function getIndex():Int {
		return callScript("getIndex") ?? index;
	}

	/**
	 * Returns an array of difficulties available to be played for the level
	 */
	public function getDifficulties():Array<String>
	{ 
		return callScript("getDifficulties") ?? difficulties;
	}

	/**
	 * Returns an array of props to show in the story menu
	 */
	public function getProps():Array<LevelPropData> {
		return callScript("getProps") ?? props;
	}

	/**
	 * Returns an array of song IDs to be played during the level
	 */
	public function getPlaylist(difficultyID:Int = 1):Array<String> 
		return cast callScript("getPlaylist", [difficultyID]) ?? [for(song in songs)song.songName];
	

	/**
	 * Returns an array of song names to be displayed in the story menu
	 */
	public function getDisplayedSongs(difficultyID:Int = 1):Array<String>
		return cast callScript("getDisplayedSongs", [difficultyID]) ?? [for (song in songs) song.displayName ?? song.songName.capitalize()];
	

	/**
	 * WIP (still gotta add to freeplay)
	 * Returns an array of song data to be shown in freeplay. 
	 */
	public function getFreeplaySongs():Array<LevelSongData> 
		return cast callScript("getFreeplaySongs") ??  songs;
	

	/**
	 * Returns a LevelTitle object for the story menu
	 */
	public function createTitle()
		return callScript("createTitle") ?? new LevelTitle(0, 0, getAsset());
	

	/**
	 * Creates the props for the visuals in the story menu.
	 * This is usually the main characters of the level (BF, GF, and Opponent)
	 * Sometimes includes a background in Psych Engine and similar engines
	 * @param group The group to be populated by props.
	 * @param bgGroup The background group to be populated by props. This group is automatically layered behind all props and fades when changing levels.
	 */

	public function populateGroup(group:FlxSpriteGroup, bgGroup:FlxSpriteGroup){
		if (callScript("prePopulateGroup", [group, bgGroup]) == Globals.Function_Stop)
			return;

		for(propData in getProps()){
			var prop = LevelStageProp.buildFromData(propData);
			var layer = propData.layer.toLowerCase();

			if (layer == 'background' || layer == 'bg')
				bgGroup.add(prop);
			else
				group.add(prop);
		}

		callScript("postPopulateGroup", [group, bgGroup]);
	}
}

class LevelTitle extends flixel.group.FlxSpriteGroup {
	public var week:FlxSprite;
	var lock:FlxSprite; // TODO: make this like.. exist
	public function new(x:Float, y:Float, path:String) {
		super(x, y);
		week = new FlxSprite(Paths.image(path));
		add(week);

		week.x -= week.width / 2;
		week.y -= week.height / 2; 
	}
}

class StoryModeState extends MusicBeatState {
	var levelBG:FlxSprite;
	var levelName:FlxText;
	var trackList:FlxText;
	
	var levels:Array<Level> = [];
	
	static var selectedLevel:Int = 0;
	var levelTitles:FlxTypedSpriteGroup<LevelTitle>;
	var levelBGGroups:Array<FlxSpriteGroup> = []; // used for fading when going between levels
	var levelProps:Array<FlxSpriteGroup> = [];
	
	public override function create(){
		if (FlxG.sound.music == null || !FlxG.sound.music.playing)
			MusicBeatState.playMenuMusic();

		// Get the levels
		var shitToCheck = [
			for (mod in Paths.getModDirectories())mod
		];
		shitToCheck.insert(0, 'assets');

		for (folderPath in shitToCheck) {
			var levelDir = folderPath == 'assets' ? Paths.getPreloadPath('levels/') : Paths.mods('$folderPath/levels/');

			var contentLevelNames:Array<String> = [];
			Paths.iterateDirectory(levelDir, function(file:String){
				var name = Path.withoutExtension(levelDir + file);
				if(!contentLevelNames.contains(name))
					contentLevelNames.push(name);
			});

			var contentLevels:Array<Level> = []; // for sorting reasons
			for(name in contentLevelNames)
				contentLevels.push(Level.fromFile(name, contentLevelNames.indexOf(name)));

			contentLevels.sort((a,b)-> return a.getIndex() - b.getIndex());
			
			for(level in contentLevels)levels.push(level);
		}

		levelBG = new FlxSprite(0, 56).makeGraphic(FlxG.width, 400, 0xFFFFFFFF);
		levelBG.color = 0xFFF9CF51;
		
		levelTitles = new FlxTypedSpriteGroup<LevelTitle>(FlxG.width / 2, 540);
		add(levelTitles);

		var infoBar:FlxSprite = new FlxSprite().makeGraphic(FlxG.width, 56, FlxColor.BLACK);
		
		levelName = new FlxText(0, 10, FlxG.width, "DADDY DEAREST", 32);
		levelName.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.fromRGB(180, 180, 180, 255), RIGHT);
		add(levelBG);

		trackList = new FlxText(-100, 500, 600, "TRACKS:\n\npenis\nshit\nfuck", 32);
		trackList.setFormat(Paths.font("vcr.ttf"), 32, 0xFFE55777, CENTER);
		add(trackList);

		for(idx in 0...levels.length){
			var level:Level = levels[idx];
			var title = level.createTitle();
			title.alpha = idx==selectedLevel ? 1 : 0;
			title.ID = idx;
			levelTitles.add(title);
			var backgroundGroup = new FlxSpriteGroup();
			backgroundGroup.ID = idx;
			backgroundGroup.y = 56;
			var propGroup = new FlxSpriteGroup();
			propGroup.ID = idx;
			propGroup.y = 56;
			// todo bg group
			level.populateGroup(propGroup, backgroundGroup);
			levelBGGroups.push(backgroundGroup);
			levelProps.push(propGroup);
		}

		// layer all backgrounds behind all the props lol

		for (idx in 0...levels.length){
			var bg = levelBGGroups[idx];
			if(bg != null)add(bg);
		}

		for (idx in 0...levels.length) {
			var props = levelProps[idx];
			if (props != null)
				add(props);
		}

		add(infoBar);
		add(levelName);
		
		changeLevel(selectedLevel, true, true);
		
		this.persistentUpdate = true;
		super.create();
	}

	override function update(elapsed:Float){
		super.update(elapsed);
		var radius:Float = 60 + (levels.length * 15);
		var lerpVal:Float = 1.0 - Math.exp(-elapsed * 16.0);
		
		for(idx in 0...levelTitles.members.length){
			var title:LevelTitle = levelTitles.members[idx];
			var relativeIndex:Float = (title.ID - selectedLevel);

			var ang:Float = (relativeIndex / levels.length) * (Math.PI * 2);
			
			title.scale.x = FlxMath.lerp(title.scale.x, (relativeIndex == 0 ? 1.1 : 0.9) + (((FlxMath.fastCos(ang) - 1) * radius) / 1280), lerpVal);
				
			title.y = FlxMath.lerp(title.y, levelTitles.y + ((FlxMath.fastSin(ang) * radius)), lerpVal);
			title.alpha = FlxMath.lerp(title.alpha, FlxMath.fastCos(ang) * (relativeIndex == 0 ? 1 : 0.6), lerpVal);
			title.scale.y = title.scale.x;

			if(title.alpha < 0)title.alpha = 0;
		}

		for(idx in 0...levels.length){
			var level:Level = levels[idx];
			if(idx == selectedLevel)
				levelBG.color = FlxColor.interpolate(levelBG.color, level.bgColor, lerpVal * 0.5);
			
		}

		for (group in levelBGGroups)
			group.alpha = FlxMath.lerp(group.alpha, group.ID == selectedLevel ? 1 : 0, lerpVal * 0.5);

		levelTitles.sort((order, obj1, obj2) -> {
			return FlxSort.byValues(order, obj1.alpha, obj2.alpha);
		});

		if(controls.UI_DOWN_P)
			changeLevel(1);

		if (controls.UI_UP_P)
			changeLevel(-1);

		if(controls.ACCEPT){
			
		}

		if(controls.BACK)
			MusicBeatState.switchState(new funkin.states.MainMenuState());
	}

	function updateTexts(){
		levelName.text = levels[selectedLevel].name;
		trackList.text = "TRACKS\n\n";
		trackList.text += levels[selectedLevel].getDisplayedSongs().join("\n");
	}
	
	function changeLevel(selection:Int, abs:Bool = false, silent:Bool = false){
		var newLevel = abs ? selection : selectedLevel + selection;
		if(newLevel < 0)
			newLevel = levels.length - 1;
		else if(newLevel >= levels.length)
			newLevel = 0;

		for (group in levelProps)
			group.visible = group.ID == newLevel;

		
		if (!silent)
			FlxG.sound.play(Paths.sound("scrollMenu"));

		selectedLevel = newLevel;
		updateTexts();
	}
}