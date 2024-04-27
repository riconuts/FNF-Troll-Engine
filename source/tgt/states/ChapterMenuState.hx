package tgt;

import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.addons.transition.FlxTransitionableState;
import tgt.TGTTextButton;
import ChapterData;

using StringTools;

class ChapterMenuState extends MusicBeatState
{
	//
	public var chapData:ChapterMetadata;

	public var cameFromStoryMenu = false;

	public function new(chapData:ChapterMetadata){
		super();

		trace('Loading: ${chapData.name}');

		this.chapData = chapData;
		Paths.currentModDirectory = chapData.directory;
		ChapterData.curChapter = chapData;
	}

	public static function getChapterCover(name:String){
		var artGraph = Paths.image('chaptercovers/' + Paths.formatToSongPath(name));

		return artGraph != null ? artGraph : Paths.image('tgtmenus/mainmenu/cover_story_mode');
	}

	override function create()
	{
		#if !FLX_NO_MOUSE
		FlxG.mouse.visible = true;
		#end

		if (cameFromStoryMenu)
			FlxTransitionableState.skipNextTransIn = true;
		else if (FlxTransitionableState.skipNextTransIn)
			CustomFadeTransition.nextCamera = null;

		super.create();

		var halfScreen:Float = FlxG.width * 0.5;
		var startY:Float = 0;

		// Create sprites
		
		var coverArt = new FlxSprite(75, 130, getChapterCover(chapData.name));
		coverArt.updateHitbox();
		add(coverArt);

		var chapterText = new FlxText(coverArt.x, coverArt.y + coverArt.height + 4, coverArt.width, chapData.name, 32);
		chapterText.setFormat(Paths.font("calibri.ttf"), 32, FlxColor.WHITE, FlxTextAlign.CENTER, FlxTextBorderStyle.NONE, FlxColor.WHITE);
		add(chapterText);

		//
		var cornerLeftText = tgt.TGTMenuShit.newBackTextButton(goBack);
		add(cornerLeftText);

		var cornerRightText = new TGTTextButton(1280, 720, 0, "PLAY →", 32, playWeek);
		cornerRightText.label.setFormat(Paths.font("calibri.ttf"), 32, tgt.TGTMenuShit.YELLOW, FlxTextAlign.LEFT, FlxTextBorderStyle.NONE);
		cornerRightText.label.underline = true;
		add(cornerRightText);

		cornerRightText.x -= cornerRightText.width + 15;
		cornerLeftText.y = cornerRightText.y -= cornerRightText.height + 15;

		//// SONGS - HI-SCORE
		halfScreen = FlxG.width * 0.5;
		startY = coverArt.y + 48;

		var songText = new FlxText(halfScreen, startY, 0, "SONGS", 32);
		songText.setFormat(Paths.font("calibrib.ttf"), 32, FlxColor.WHITE, FlxTextAlign.RIGHT, FlxTextBorderStyle.NONE, FlxColor.WHITE);
		add(songText);

		var scoreText = new FlxText(1205, startY, 0, "HI-SCORE", 32);
		scoreText.setFormat(Paths.font("calibrib.ttf"), 32, FlxColor.WHITE, FlxTextAlign.LEFT, FlxTextBorderStyle.NONE, FlxColor.WHITE);
		scoreText.x -= scoreText.width + 15;
		add(scoreText);

		// SONG NAME - SONG SCORE
		var songAmount:Int = chapData.songs.length;

		for (idx in 0...songAmount)
		{
			var yPos = startY + (idx + 2) * 48;
			var songName = chapData.songs[idx];

			var newSongTxt = new FlxText(halfScreen, yPos, 0, songName, 32);
			newSongTxt.setFormat(Paths.font("calibri.ttf"), 32, 0xFFF4CC34, FlxTextAlign.RIGHT, FlxTextBorderStyle.NONE);
			add(newSongTxt);

			var newScoreTxt = new FlxText(1205, yPos, 0, '' + Highscore.getScore(songName), 32);
			newScoreTxt.setFormat(Paths.font("calibri.ttf"), 32, FlxColor.WHITE, FlxTextAlign.RIGHT, FlxTextBorderStyle.NONE, FlxColor.WHITE);
			newScoreTxt.x -= newScoreTxt.width + 15;
			add(newScoreTxt);
		}

		// CHAPTER - TOTAL CHAPTER SCORE
		var totalSongTxt = new FlxText(halfScreen, startY + (songAmount + 2) * 48, 0, "CHAPTER", 32);
		totalSongTxt.setFormat(Paths.font("calibri.ttf"), 32, FlxColor.WHITE, FlxTextAlign.RIGHT, FlxTextBorderStyle.NONE, FlxColor.WHITE);
		add(totalSongTxt);

		var totalScoreTxt = new FlxText(1205, totalSongTxt.y, 0, Std.string(Highscore.getWeekScore(ChapterData.curChapter.directory)), 32);
		totalScoreTxt.setFormat(Paths.font("calibri.ttf"), 32, FlxColor.WHITE, FlxTextAlign.RIGHT, FlxTextBorderStyle.NONE, FlxColor.WHITE);
		totalScoreTxt.x -= totalScoreTxt.width + 15;
		add(totalScoreTxt);

		////
		var funkyRectangle = new flixel.addons.display.shapes.FlxShapeBox(10, 10, 1260, 700, {thickness: 3, color: 0xFFF4CC34}, FlxColor.BLACK);
		funkyRectangle.cameras = cameras;
		add(funkyRectangle);

		FlxTween.num(1, 0, 0.12, {ease: FlxEase.quadOut}, function(yo){
			funkyRectangle.fillColor = FlxColor.fromRGBFloat(0,0,0,yo);
		});
	}

	function goBack()
	{
		FlxTransitionableState.skipNextTransOut = true;

		var state = new tgt.StoryMenuState();
		state.cameFromChapterMenu = true;
		MusicBeatState.switchState(state);
	}

	override function update(elapsed:Float)
	{
		if (controls.BACK)
			goBack();
		else if (controls.ACCEPT)
			playWeek();
		/*else if (flixel.FlxG.keys.justPressed.CONTROL)
			openSubState(new GameplayChangersSubstate());*/

		super.update(elapsed);
	}

	public function playWeek()
	{
		if (chapData == null){
			trace("No chapter data!");
			return;
		}

		Paths.currentModDirectory = chapData.directory;
		ChapterData.curChapter = chapData;

		// Nevermind that's stupid lmao
		PlayState.storyPlaylist = chapData.songs;
		PlayState.isStoryMode = true;

		PlayState.SONG = Song.loadFromJson(PlayState.storyPlaylist[0].toLowerCase(), PlayState.storyPlaylist[0].toLowerCase());
		PlayState.difficulty = 1;
		PlayState.difficultyName = '';
		PlayState.campaignScore = 0;
		PlayState.campaignMisses = 0;

		var nextSong = PlayState.storyPlaylist[0];
		function playNextSong(){
			PlayState.SONG = Song.loadFromJson(nextSong, nextSong);
			LoadingState.loadAndSwitchState(new PlayState(), true);
		}

		#if VIDEOS_ALLOWED
		var videoPath:String = Paths.video('${Paths.formatToSongPath(nextSong)}');
		if (Paths.exists(videoPath))
			LoadingState.loadAndSwitchState(new VideoPlayerState(videoPath, playNextSong), true);
		else
			playNextSong();
		#else
		playNextSong();
		#end

		//FreeplayState.destroyFreeplayVocals();
	}
}