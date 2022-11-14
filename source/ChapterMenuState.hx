package;

import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.addons.transition.FlxTransitionableState;
import sowy.SowyTextButton;
import ChapterData;

using StringTools;

class ChapterMenuState extends MusicBeatState{
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
	public var chapData:ChapterMetadata;

	public var cameFromStoryMenu = false;

	public function new(chapData:ChapterMetadata){
		super();

		trace('Loading: ${chapData.name}');

		this.chapData = chapData;
		Paths.currentModDirectory = chapData.directory;
	}

	override function create()
	{
		#if desktop
		FlxG.mouse.visible = true;
		#end

		if (cameFromStoryMenu){
			FlxTransitionableState.skipNextTransIn = true;
		}else{
			if (FlxTransitionableState.skipNextTransIn)
				CustomFadeTransition.nextCamera = null;
		}

		super.create();

		var funkyRectangle = new flixel.addons.display.shapes.FlxShapeBox(10, 10, 1260, 700, {thickness: 3, color: FlxColor.fromRGB(255, 242, 0)}, FlxColor.BLACK);
		funkyRectangle.cameras = cameras;
		add(funkyRectangle);

		// Create sprites
		var artGraph = Paths.image('chaptercovers/' + Paths.formatToSongPath(chapData.name));
		coverArt = new FlxSprite(75, 130);
		coverArt.loadGraphic(artGraph != null ? artGraph : Paths.image('newmenuu/mainmenu/cover_story_mode'));
		coverArt.updateHitbox();
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

		/////////

		//// Update menu
		chapterText.setPosition(coverArt.x, coverArt.y + coverArt.height + 4);
		chapterText.fieldWidth = coverArt.width;
		chapterText.text = chapData.name;

		// Make a text boxes for every song.
		var songAmount:Int = 0;

		for (songName in chapData.songs)
		{
			var yPos = startY + (songAmount + 2) * 48;

			var newSongTxt = new FlxText(halfScreen, yPos, 0, songName, 32);
			newSongTxt.setFormat(Paths.font("calibri.ttf"), 32, FlxColor.YELLOW, FlxTextAlign.RIGHT, FlxTextBorderStyle.NONE, FlxColor.YELLOW);

			var newScoreTxt = new FlxText(1205, yPos, 0, '' + Highscore.getScore(songName), 32);
			newScoreTxt.setFormat(Paths.font("calibri.ttf"), 32, FlxColor.WHITE, FlxTextAlign.RIGHT, FlxTextBorderStyle.NONE, FlxColor.WHITE);
			newScoreTxt.x -= newScoreTxt.width + 15;

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
	}

	function close()
	{
		FlxTransitionableState.skipNextTransOut = true;

		var state = new StoryMenuState();
		state.cameFromChapterMenu = true;
		MusicBeatState.switchState(state);
	}

	override function update(elapsed:Float)
	{
		if (controls.BACK)
			close();
		else if (controls.ACCEPT)
			playWeek();
		else if (flixel.FlxG.keys.justPressed.CONTROL)
			openSubState(new GameplayChangersSubstate());

		super.update(elapsed);
	}

	public function playWeek(){
		if (chapData == null)
			return;

		Paths.currentModDirectory = chapData.directory;
		//PlayState.storyWeek = chapData;

		// Nevermind that's stupid lmao
		PlayState.storyPlaylist = chapData.songs;
		PlayState.isStoryMode = true;

		PlayState.SONG = Song.loadFromJson(PlayState.storyPlaylist[0].toLowerCase(), PlayState.storyPlaylist[0].toLowerCase());
		PlayState.campaignScore = 0;
		PlayState.campaignMisses = 0;

		flixel.FlxG.state.destroySubStates = true;

		LoadingState.loadAndSwitchState(new PlayState(), true);
		//FreeplayState.destroyFreeplayVocals();
	}
}