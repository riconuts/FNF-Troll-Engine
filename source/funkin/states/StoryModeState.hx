package funkin.states;

import funkin.data.Highscore;
import funkin.data.Song;
import funkin.data.Level;
import animateatlas.AtlasFrameMaker;
import flixel.util.FlxSignal;
import flixel.system.FlxAssets.FlxGraphicAsset;
import flixel.tweens.FlxTween;
import flixel.group.FlxSpriteGroup;
import flixel.util.FlxSort;
import flixel.math.FlxMath;
import flixel.group.FlxSpriteGroup.FlxTypedSpriteGroup;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import haxe.io.Path;

using funkin.CoolerStringTools;
using StringTools;

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

		// TODO: allow FlxAnimate and multisparrow
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

				if(animation.name == 'confirm'){
					prop.onConfirm.add(() -> {
						prop.playAnim("confirm", true);
					});
				}

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

	public var isFlashing:Bool = false;

	var flashTick:Float = 0;
	final flashFramerate:Float = 20;

	public override function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (isFlashing) {
			flashTick += elapsed;
			if (flashTick >= 1 / flashFramerate) {
				flashTick %= 1 / flashFramerate;
				color = (color == FlxColor.WHITE) ? 0xFF33ffff : FlxColor.WHITE;
			}
		}
	}
}

class StoryModeState extends MusicBeatState {
	static var selectedLevel:Int = 0;
	static var selectedDifficultyName:String = 'normal';

	var levels:Array<Level> = [];
	var selectedDifficultyIdx:Int = 1;
	var selectedLevelDifficulties:Array<String> = [];

	var inputsActive:Bool = true;

	var targetHighscore:Float = 0;
	var lerpHighscore:Float = 0;

	var levelBG:FlxSprite;
	var levelName:FlxText;
	var trackList:FlxText;
	var scoreText:FlxText;

	var difficultySpr:FlxSprite;
	var difficultyLeft:FlxSprite;
	var difficultyRight:FlxSprite;
	
	var levelTitles:FlxTypedSpriteGroup<LevelTitle>;
	var levelBGGroups:Array<FlxSpriteGroup> = []; // used for fading when going between levels
	var levelProps:Array<FlxSpriteGroup> = [];

	// this will be moved to something else i'm currently working on :o
	public static function scanContentLevels(folder:String):Array<Level>
	{
		var levelDir = Paths.getFolderPath(folder) + '/levels/';

		var contentLevelPaths:Array<String> = [];
		Paths.iterateDirectory(levelDir, function(file:String){
			var name = Path.withoutExtension(levelDir + file);
			if(!contentLevelPaths.contains(name))
				contentLevelPaths.push(name);
		});

		var contentLevels:Array<Level> = [];
		for (filePath in contentLevelPaths) {
			var id:String = Path.withoutDirectory(filePath);
			var index:Int = contentLevelPaths.indexOf(filePath);
			contentLevels.push(Level.fromFile(filePath, id, folder, index));
		}

		contentLevels.sort((a,b)-> return a.getIndex() - b.getIndex());
		return contentLevels;
	}

	public static function getStoryModeLevels():Array<Level>
	{
		var levels:Array<Level> = [];
		var shitToCheck = [''];
		for (mod in Paths.getModDirectories())
			shitToCheck.push(mod);

		for (folder in shitToCheck) {
			for (level in scanContentLevels(folder))
				levels.push(level);
		}

		return levels;
	}
	
	public override function create(){
		if (FlxG.sound.music == null || !FlxG.sound.music.playing)
			MusicBeatState.playMenuMusic();

		// Get the levels
		levels = getStoryModeLevels();

		levelBG = new FlxSprite(0, 56).makeGraphic(FlxG.width, 400, 0xFFFFFFFF);
		levelBG.color = 0xFFF9CF51;
		
		levelTitles = new FlxTypedSpriteGroup<LevelTitle>(FlxG.width / 2, 540);
		add(levelTitles);

		var infoBar:FlxSprite = new FlxSprite().makeGraphic(FlxG.width, 56, FlxColor.BLACK);
		
		levelName = new FlxText(0, 10, FlxG.width - 10, "DADDY DEAREST", 32);
		levelName.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.fromRGB(180, 180, 180, 255), RIGHT);
		add(levelBG);

		scoreText = new FlxText(10, 10, 0, 'HIGH SCORE: 42069420');
		scoreText.setFormat(Paths.font("vcr.ttf"), 32);

		trackList = new FlxText(-100, 500, 600, "TRACKS:\n\npenis\nshit\nfuck", 32);
		trackList.setFormat(Paths.font("vcr.ttf"), 32, 0xFFE55777, CENTER);
		add(trackList);

		difficultySpr = new FlxSprite(FlxG.width - 200, levelTitles.y);
		add(difficultySpr);

		difficultyLeft = new FlxSprite();
		difficultyLeft.frames = Paths.getSparrowAtlas('storymenu/ui/arrows');
		difficultyLeft.animation.addByPrefix("idle", "leftIdle", 24);
		difficultyLeft.animation.addByPrefix("press", "leftConfirm", 24, false);
		difficultyLeft.animation.play("idle");
		difficultyLeft.updateHitbox();
		difficultyLeft.animation.finishCallback = function(name:String){
			difficultyLeft.animation.play("idle", true);
			difficultyLeft.updateHitbox();
		}
		add(difficultyLeft);

		difficultyRight = new FlxSprite();
		difficultyRight.frames = Paths.getSparrowAtlas('storymenu/ui/arrows');
		difficultyRight.animation.addByPrefix("idle", "rightIdle", 24);
		difficultyRight.animation.addByPrefix("press", "rightConfirm", 24, false);
		difficultyRight.animation.play("idle");
		difficultyRight.updateHitbox();
		difficultyRight.animation.finishCallback = function(name:String){
			difficultyRight.animation.play("idle", true);
			difficultyRight.updateHitbox();
		}
		add(difficultyRight);

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
		add(scoreText);
		
		changeLevel(selectedLevel, true, true);
		updateDifficultyText(selectedDifficultyName);
		
		this.persistentUpdate = true;
		super.create();
	}

	override function update(elapsed:Float){
		super.update(elapsed);
		var radius:Float = 60 + (levels.length * 15);
		var lerpVal:Float = 1.0 - Math.exp(-elapsed * 16.0);

		lerpHighscore = CoolUtil.coolLerp(lerpHighscore, targetHighscore, elapsed * 12);
		scoreText.text = 'HIGH SCORE: ${Math.round(lerpHighscore)}';
		
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

		updateInput(elapsed);
	}

	function updateInput(elapsed:Float) {
		if (!inputsActive)
			return;

		if(controls.UI_DOWN_P)
			changeLevel(1);

		if (controls.UI_UP_P)
			changeLevel(-1);

		if (controls.UI_RIGHT_P)
			changeDifficulty(1);

		if (controls.UI_LEFT_P)
			changeDifficulty(-1);

		if(controls.ACCEPT){
			acceptLevel();
		}

		if(controls.BACK) {
			inputsActive = false;
			FlxG.sound.play(Paths.sound('cancelMenu'));
			MusicBeatState.switchState(new funkin.states.MainMenuState());
		}
	}

	function updateTexts(){
		levelName.text = levels[selectedLevel].name;
		trackList.text = "TRACKS\n\n";
		trackList.text += levels[selectedLevel].getDisplayedSongs(selectedDifficultyName).join("\n");
	}

	function updateDifficultyText(diffName:String)
	{
		difficultySpr.loadGraphic(Paths.image('storymenu/difficulties/$diffName'));
		difficultySpr.updateHitbox();
		difficultySpr.x = (FlxG.width - 200) - (difficultySpr.width / 2);
		difficultySpr.y = levelTitles.y;

		if (selectedLevelDifficulties.length > 1) {
			difficultyLeft.visible = true;
			difficultyLeft.x = difficultySpr.x - difficultyLeft.width - 10;
			difficultyLeft.y = difficultySpr.y + difficultySpr.height / 2 - difficultyLeft.height / 2;
			
			difficultyRight.visible = true;
			difficultyRight.x = difficultySpr.x + difficultySpr.width + 10;
			difficultyRight.y = difficultySpr.y + difficultySpr.height / 2 - difficultyRight.height / 2;
		}
		else {
			difficultyLeft.visible = false;

			difficultyRight.visible = false;
		}

		difficultySpr.alpha = 0.0;
		FlxTween.tween(difficultySpr, {y: difficultySpr.y, alpha: 1.0}, 0.07);
		difficultySpr.y -= 25;
	}
	
	function changeLevel(selection:Int, abs:Bool = false, silent:Bool = false){
		var newLevel = abs ? selection : selectedLevel + selection;
		if(newLevel < 0)
			newLevel = levels.length - 1;
		else if(newLevel >= levels.length)
			newLevel = 0;

		selectedLevelDifficulties = levels[newLevel].getDifficulties();
		var newIdx = CoolUtil.updateDifficultyIndex(selectedDifficultyIdx, selectedDifficultyName, selectedLevelDifficulties);
		changeDifficulty(newIdx, true);

		/* // TODO: level scoressss
		targetHighscore = Highscore.getLevelScore(levels[newLevel].id, selectedDifficultyName);
		*/

		for (group in levelProps)
			group.visible = group.ID == newLevel;
		
		if (!silent)
			FlxG.sound.play(Paths.sound("scrollMenu"));

		selectedLevel = newLevel;
		updateTexts();
	}

	function changeDifficulty(selection:Int, abs:Bool = false){
		var newIdx:Int = abs ? selection : selectedDifficultyIdx + selection;
		if (newIdx < 0)
			newIdx = selectedLevelDifficulties.length - 1;
		else if(newIdx >= selectedLevelDifficulties.length)
			newIdx = 0;

		if (!abs && selection != 0) {
			(selection < 0 ? difficultyLeft : difficultyRight).animation.play("press", true);
		}

		var prevDiff:String = selectedDifficultyName;
		selectedDifficultyName = selectedLevelDifficulties[newIdx];
		selectedDifficultyIdx = newIdx;
		if (prevDiff != selectedDifficultyName)
			updateDifficultyText(selectedDifficultyName);

		updateTexts();

		trace(selectedDifficultyIdx, selectedDifficultyName);
	}

	function acceptLevel() {
		FlxG.sound.play(Paths.sound('confirmMenu'));

		inputsActive = false;

		for (title in levelTitles.members) {
			if (title.ID == selectedLevel) {
				title.isFlashing = true;
				break;
			}
		}
		for (group in levelProps){
			if(group.visible)
				for(prop in group.members)
					if (prop is LevelStageProp)
						cast(prop, LevelStageProp).onConfirm.dispatch();
					
				
					
		}
		// TODO: play the character anims

		new FlxTimer().start(1, function(tmr:FlxTimer) {
			playLevel(levels[selectedLevel], selectedDifficultyName);
		});
	}

	static function playLevel(level:Level, chartId:String) {
		PlayState.loadPlaylist(level.getPlaylist(), chartId);

		PlayState.isStoryMode = true;
		PlayState.level = level;

		trace(PlayState.level.id, PlayState.difficultyName, PlayState.songPlaylist);

		MusicBeatState.switchState(new PlayState());
	}
}