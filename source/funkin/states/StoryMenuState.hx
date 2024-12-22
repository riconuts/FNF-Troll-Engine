package funkin.states;

import flixel.addons.transition.FlxTransitionableState;
import flixel.math.FlxMath;
import funkin.data.Level;
import funkin.data.Highscore;
import flixel.util.FlxColor;
import flixel.util.FlxGradient;
import flixel.text.FlxText;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.FlxCamera.FlxCameraFollowStyle;

class StoryMenuState extends MusicBeatState 
{
	var levels:Array<Level> = [
		new Level("week1"),
		Level.fromId("weekend1")
	];
	var curLevel:Level = null;

	var cam:FlxCamera;
	var camOptions:FlxCamera;

	var weekObjects = new FlxTypedGroup<FlxSprite>(); // bg, characters, and extra stuff maybe
	var optionsGrp = new FlxTypedGroup<FlxSprite>(); // week title option
	var camFollowPos:FlxObject; // option scrolling

	var titleText:FlxText;
	var scoreText:FlxText;

	// placeholder loll
	var songListText:FlxText;
	var diffText:FlxText;

	//// status
	var curSelected = 0;
	var selSpr:FlxSprite = null;

	var curDiffIdx:Int = -1;
	var curDiffStr:String = "normal";
	var curDiffList:Array<String>;

	var intendedScore:Float = 0;
	var lerpScore:Float = 0;

	override function create() {
		cam = FlxG.camera;
		cam.bgColor = 0xFFF9CF51;
		cam.height = 54 + 386;
		cam.scrollOffset.y += 54;
		this.cameras = [cam];

		//
		camOptions = new FlxCamera();
		camOptions.bgColor = 0xFF000000;
		camOptions.height = Math.floor(FlxG.height - cam.height);
		camOptions.setPosition(0, FlxG.height - camOptions.height);
		FlxG.cameras.add(camOptions, false);

		// I hate it here
		var transitionCamera = new FlxCamera();
		transitionCamera.bgColor = 0;
		FlxG.cameras.add(transitionCamera, false);
		FadeTransitionSubstate.nextCamera = transitionCamera;

		//
		camFollowPos = new FlxObject(0, -30, camOptions.width, camOptions.height);
		camOptions.follow(camFollowPos, FlxCameraFollowStyle.NO_DEAD_ZONE);
		camOptions.scrollOffset.y -= 30;
		add(camFollowPos);

		//
		add(weekObjects);

		//
		var topBar = CoolUtil.blankSprite(FlxG.width, 54, 0xFF000000);
		topBar.scrollFactor.set();
		add(topBar);

		//
		titleText = new FlxText(0, 10, FlxG.width - 10, "");
		titleText.setFormat(Paths.font("vcr.ttf"), 32, 0xFFFFFFFF, RIGHT);
		titleText.scrollFactor.set();
		add(titleText);

		//
		scoreText = new FlxText(10, 10, 0, 'LEVEL SCORE: 0', 36);
		scoreText.setFormat(Paths.font("vcr.ttf"), 32);
		scoreText.scrollFactor.set();
		add(scoreText);

		//
		var optionsGrad = FlxGradient.createGradientFlxSprite(camOptions.width, camOptions.height, [0, 0x00FFFFFF, 0x22FFFFFF, 0x55FFFFFF]);
		optionsGrad.color = cam.color.getInverted();
		optionsGrad.alpha = 0.4;
		optionsGrad.scrollFactor.set();
		optionsGrad.camera = camOptions;
		add(optionsGrad);

		var txtTracklist = new FlxText(15, 50, (FlxG.width-100) / 3, "Tracks", 32);
		txtTracklist.setFormat(Paths.font("vcr.ttf"), 32, 0xFFe55777, CENTER);
		txtTracklist.scrollFactor.set();
		txtTracklist.camera = camOptions;
		add(txtTracklist);

		// placeholder
		songListText = new FlxText(15, 100, (FlxG.width-100) / 3, "songs");
		songListText.setFormat(Paths.font("vcr.ttf"), 32, 0xFFe55777, CENTER);
		songListText.scrollFactor.set();
		songListText.camera = camOptions;
		add(songListText);
		
		// placeholder
		diffText = new FlxText(15, 60, (FlxG.width-100) / 3, "normal");
		diffText.x = FlxG.width - 15 - diffText.fieldWidth;
		diffText.setFormat(Paths.font("vcr.ttf"), 32, 0xFFe55777, CENTER);
		diffText.scrollFactor.set();
		diffText.camera = camOptions;
		add(diffText);

		//
		optionsGrp.cameras = [camOptions];
		add(optionsGrp);

		var prev:FlxSprite = null;
		for (i => level in levels) {
			var optionSpr = new FlxSprite(
				FlxG.width / 2,
				0,
				level.getLevelAsset()	
			);
			optionSpr.x -= optionSpr.width / 2;
			optionSpr.y = prev==null ? 0 : prev.y + prev.height + 30;
			optionsGrp.add(optionSpr);
			optionSpr.ID = i;

			prev = optionSpr;
		}

		//
		changeSelection(0, true);
		super.create();
	}

	function changeSelection(val:Int, isAbs:Bool=false) {
		if (!isAbs)
			FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);

		curSelected = (isAbs) ? val : CoolUtil.updateIndex(curSelected, val, optionsGrp.length);
		curLevel = levels[curSelected];

		curDiffList = curLevel.getDifficulties();
		changeDifficulty(CoolUtil.updateDifficultyIndex(curDiffIdx, curDiffStr, curDiffList), true);
		
		intendedScore = Highscore.getWeekScore(curLevel.id/*, curDiffStr*/);
		titleText.text = curLevel.getTitle();
		selSpr = optionsGrp.members[curSelected];

		songListText.text = curLevel.getDisplayedSongs().join('\n');
	}

	function changeDifficulty(val:Int, isAbs:Bool=false) {
		curDiffIdx = (isAbs) ? val : CoolUtil.updateIndex(curDiffIdx, val, curDiffList.length);
		curDiffStr = curDiffList[curDiffIdx];

		////
		diffText.text = '< ${curDiffStr.toUpperCase()} >';
	}

	override function update(elapsed:Float) {
		if (controls.UI_UP_P) {
			changeSelection(-1);
		}
		if (controls.UI_DOWN_P) {
			changeSelection(1);			
		}
		if (controls.UI_LEFT_P) {
			changeDifficulty(-1);
		}
		if (controls.UI_RIGHT_P) {
			changeDifficulty(1);			
		}
		if (controls.BACK) {
			MusicBeatState.switchState(new funkin.states.MainMenuState());
		}

		camFollowPos.y = CoolUtil.coolLerp(camFollowPos.y, selSpr.y, elapsed * 10);

		if (lerpScore != intendedScore) {
			lerpScore = Math.abs(lerpScore - intendedScore) < 10 ? intendedScore : CoolUtil.coolLerp(lerpScore, intendedScore, elapsed * 30);
			scoreText.text = 'LEVEL SCORE: ${Math.ceil(lerpScore)}';
		}

		var focusY = camFollowPos.y + camFollowPos.height / 2;
		for (i => obj in optionsGrp) {
			if (i == curSelected) {
				obj.alpha = 1.0;
				continue;
			}

			var mid = obj.y + obj.height / 2;
			var distance = Math.abs(focusY - mid);
			var stepsAway = Math.max(0.6, distance / 180);
			obj.alpha = (1.0 - stepsAway * 0.5);
		}
		
		super.update(elapsed);
	}
}