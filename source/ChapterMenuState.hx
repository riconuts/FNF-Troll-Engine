package;

import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import sowy.SowyTextButton;

using StringTools;

class ChapterMenuState extends MusicBeatSubstate{
	var coverArt:FlxSprite;
	var chapterText:FlxText;

	var cornerLeftText:SowyTextButton;
	var cornerRightText:SowyTextButton;

	var songText:FlxText;
	var scoreText:FlxText;

	// recycle bin
	var songTxtArray:Array<FlxText> = [];
	var scoreTxtArray:Array<FlxText> = [];

	var totalSongTxt:FlxText;
	var totalScoreTxt:FlxText;

	// values used for positioning and shith
	var sowyStr:String = "sowy";
	var halfScreen:Float = 1280 / 2;
	var startY:Float = 0;

	//
	private static var lastDifficultyName:String = '';
	var curDifficulty:Int = 1;

	//
	public var curWeek(default, set):WeekData;

	public function new(){
		super();
		
		// Load difficulties
		CoolUtil.difficulties = CoolUtil.defaultDifficulties.copy();
		if (lastDifficultyName == '')
			lastDifficultyName = CoolUtil.defaultDifficulty;
		curDifficulty = Math.round(Math.max(0, CoolUtil.defaultDifficulties.indexOf(lastDifficultyName)));

		// Create sprites
		coverArt = new FlxSprite(75, 130);
		add(coverArt);

		chapterText = new FlxText(0, 0, 1, sowyStr, 32);
		chapterText.setFormat(Paths.font("calibri.ttf"), 32, FlxColor.WHITE, FlxTextAlign.CENTER, FlxTextBorderStyle.NONE, FlxColor.WHITE);
		add(chapterText);
		
		cornerLeftText = new SowyTextButton(15, 720, 0, "← BACK", 32, close);
		cornerLeftText.label.setFormat(Paths.font("calibri.ttf"), 32, FlxColor.YELLOW, FlxTextAlign.RIGHT, FlxTextBorderStyle.NONE, FlxColor.YELLOW);
		add(cornerLeftText);

		cornerRightText = new SowyTextButton(1280, 720, 0, "PLAY →", 32, playWeek);
		cornerRightText.label.setFormat(Paths.font("calibri.ttf"), 32, FlxColor.YELLOW, FlxTextAlign.LEFT, FlxTextBorderStyle.NONE, FlxColor.YELLOW);
		add(cornerRightText);

		cornerRightText.x -= cornerRightText.width + 15;
		cornerLeftText.y = cornerRightText.y -= cornerRightText.height + 15;

		//// SONGS - HI-SCORE
		halfScreen = 1280 / 2;
		startY = coverArt.y + 48;

		songText = new FlxText(halfScreen, startY, 0, "SONGS", 32);
		songText.setFormat(Paths.font("calibrib.ttf"), 32, FlxColor.WHITE, FlxTextAlign.RIGHT, FlxTextBorderStyle.NONE, FlxColor.WHITE);
		add(songText);

		scoreText = new FlxText(1205, startY, 0, "HI-SCORE", 32);
		scoreText.setFormat(Paths.font("calibrib.ttf"), 32, FlxColor.WHITE, FlxTextAlign.LEFT, FlxTextBorderStyle.NONE, FlxColor.WHITE);
		scoreText.x -= scoreText.width + 15;
		add(scoreText);

		// TOTAL - TOTAL SCORE
		totalSongTxt = new FlxText(halfScreen, 0, 0, "TOTAL", 32);
		totalSongTxt.setFormat(Paths.font("calibri.ttf"), 32, FlxColor.WHITE, FlxTextAlign.RIGHT, FlxTextBorderStyle.NONE, FlxColor.WHITE);

		totalScoreTxt = new FlxText(1205, 0, 0, "0", 32);
		totalScoreTxt.setFormat(Paths.font("calibri.ttf"), 32, FlxColor.WHITE, FlxTextAlign.RIGHT, FlxTextBorderStyle.NONE, FlxColor.WHITE);
		totalScoreTxt.x -= totalScoreTxt.width + 15;

		add(totalSongTxt);
		add(totalScoreTxt);
	}

	override function update(elapsed:Float)
	{
		if (controls.BACK)
			close();
		else if (controls.ACCEPT)
			playWeek();
		/*else if (flixel.FlxG.keys.justPressed.CONTROL)
			StoryMenuState.instance.openSubState(new GameplayChangersSubstate());*/

		super.update(elapsed);
	}
	
	function set_curWeek(DaWeek:WeekData):WeekData{
		curWeek = DaWeek;
		trace('loaded week: ${curWeek.fileName}');

		WeekData.setDirectoryFromWeek(curWeek);

		//// Update difficulties
		CoolUtil.difficulties = CoolUtil.defaultDifficulties.copy();
		var diffStr:String = WeekData.getCurrentWeek().difficulties;
		if (diffStr != null)
			diffStr = diffStr.trim(); // Fuck you HTML5

		if (diffStr != null && diffStr.length > 0)
		{
			var diffs:Array<String> = diffStr.split(',');
			var i:Int = diffs.length - 1;
			while (i > 0){
				if (diffs[i] != null){
					diffs[i] = diffs[i].trim();
					if (diffs[i].length < 1)
						diffs.remove(diffs[i]);
				}
				--i;
			}

			if (diffs.length > 0 && diffs[0].length > 0)
			{
				CoolUtil.difficulties = diffs;
			}
		}

		if (CoolUtil.difficulties.contains(CoolUtil.defaultDifficulty))	
			curDifficulty = Math.round(Math.max(0, CoolUtil.defaultDifficulties.indexOf(CoolUtil.defaultDifficulty)));
		else
			curDifficulty = 0;

		var newPos:Int = CoolUtil.difficulties.indexOf(lastDifficultyName);
		// trace('Pos of ' + lastDifficultyName + ' is ' + newPos);
		if (newPos > -1)
			curDifficulty = newPos;
		
		changeDifficulty();

		//// Update menu
		var artGraph = Paths.image('chaptercovers/' + DaWeek.fileName);
		coverArt.loadGraphic(artGraph != null ? artGraph : Paths.image('newmenuu/mainmenu/cover_story_mode'));
		coverArt.updateHitbox();
		
		chapterText.setPosition(coverArt.x, coverArt.y + coverArt.height + 4);
		chapterText.fieldWidth = coverArt.width;
		chapterText.text = DaWeek.weekName;

		// Make a text boxes for every song.
		var songAmount:Int = 0;

		for (song in DaWeek.songs)
		{
			var songName = song[0];
			var yPos = startY + (songAmount + 2) * 48;

			var newSongTxt = songTxtArray[songAmount]; // find previously created text
			if (newSongTxt != null) { // if found then reuse it
				newSongTxt.text = songName;
				newSongTxt.visible = true;
			}
			else // if not then make one
			{
				newSongTxt = new FlxText(halfScreen, yPos, 0, songName, 32);
				newSongTxt.setFormat(Paths.font("calibri.ttf"), 32, FlxColor.YELLOW, FlxTextAlign.RIGHT, FlxTextBorderStyle.NONE, FlxColor.YELLOW);
			}
			
			var newScoreTxt = scoreTxtArray[songAmount]; // find a previously created text
			var highScore = Highscore.getScore(songName, curDifficulty);
			if (newScoreTxt != null) { // if found then reuse it
				newScoreTxt.visible = true;
				newScoreTxt.text = '' + highScore;
			}
			else // if not then make one
			{
				newScoreTxt = new FlxText(1205, yPos, 0, '' + highScore, 32);
				newScoreTxt.setFormat(Paths.font("calibri.ttf"), 32, FlxColor.WHITE, FlxTextAlign.RIGHT, FlxTextBorderStyle.NONE, FlxColor.WHITE);
				newScoreTxt.x -= newScoreTxt.width + 15;
			}

			add(newSongTxt);
			add(newScoreTxt);

			songAmount++;
		}
		// Hide the rest of the previously created texts
		for (i in songAmount...songTxtArray.length)
		{
			var songTxt = songTxtArray[songAmount];
			var scoreTxt = scoreTxtArray[songAmount];
			songTxt.visible = scoreTxt.visible = false;
		}

		// Accomodate the total week score text
		totalSongTxt.y = totalScoreTxt.y = startY + (songAmount + 2) * 48;

		changeDifficulty();

		return DaWeek;
	}

	function changeDifficulty(change:Int = 0):Void
	{
		curDifficulty += change;

		if (curDifficulty < 0)
			curDifficulty = CoolUtil.difficulties.length - 1;
		if (curDifficulty >= CoolUtil.difficulties.length)
			curDifficulty = 0;

		WeekData.setDirectoryFromWeek(curWeek);

		var diff:String = CoolUtil.difficulties[curDifficulty];
		// trace(Paths.currentModDirectory + ', menudifficulties/' + Paths.formatToSongPath(diff));
		
		lastDifficultyName = diff;

		#if !switch
		totalScoreTxt.text = Std.string(Highscore.getWeekScore(curWeek.fileName, curDifficulty));
		#end
	}

	public function playWeek(){
		if (curWeek == null)
			return;

		WeekData.setDirectoryFromWeek(curWeek);
		
		PlayState.isStoryMode = true;

		// We can't use Dynamic Array .copy() because that crashes HTML5, here's a workaround.
		var songArray:Array<String> = [];
		
		var leWeek:Array<Dynamic> = curWeek.songs;
		for (i in 0...leWeek.length)
		{
			songArray.push(leWeek[i][0]);
		}

		// Nevermind that's stupid lmao
		PlayState.storyPlaylist = songArray;
		PlayState.isStoryMode = true;
		
		var diffic = CoolUtil.getDifficultyFilePath(curDifficulty);
		if (diffic == null || diffic == "null")
			diffic = '';

		PlayState.storyDifficulty = curDifficulty;

		PlayState.SONG = Song.loadFromJson(PlayState.storyPlaylist[0].toLowerCase() + diffic, PlayState.storyPlaylist[0].toLowerCase());
		PlayState.campaignScore = 0;
		PlayState.campaignMisses = 0;

		flixel.FlxG.state.destroySubStates = true;

		LoadingState.loadAndSwitchState(new PlayState(), true);
		FreeplayState.destroyFreeplayVocals();
	}
}