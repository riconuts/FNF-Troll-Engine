package;

import WeekData;
import flixel.FlxBasic;
import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.FlxSubState;
import flixel.addons.display.shapes.FlxShapeBox;
import flixel.addons.transition.FlxTransitionableState;
import flixel.addons.ui.FlxUIButton;
import flixel.graphics.FlxGraphic;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.group.FlxGroup;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxSpriteUtil;
import flixel.util.FlxTimer;

using StringTools;
#if desktop
import Discord.DiscordClient;
#end

// roblox tier code

class StoryMenuState extends MusicBeatState
{
	public static var weekCompleted:Map<String, Bool> = new Map<String, Bool>();

	final chapterSelectPositions:Array<Array<Int>> = [ // on screen positions for the chapter options
		[51, 109], [305, 109], [542, 109], [788, 109], [1034, 109],
		[51, 417], [305, 417], [542, 417], [788, 417], [1034, 417]
	];

	var mainMenu = new FlxTypedGroup<FlxBasic>(); // group for the main menu where you select achapter!
	var subMenu = new StoryModeSubMenu(); // custom group class for the sub menu where yu select a song!
	
	var funkyRectangle = new FlxShapeBox(0, 0, 206, 206, {thickness: 3, color: FlxColor.fromRGB(255, 242, 0)}, FlxColor.BLACK); // cool rectanlge used for transitions
	var lastButton:SowyChapterOption; // used the square transition
	var doingTransition = false; // to prevent unintended behaviour

	var isOnSubMenu = false;

	function weekIsLocked(name:String):Bool {
		var leWeek:WeekData = WeekData.weeksLoaded.get(name);
		return (!leWeek.startUnlocked && leWeek.weekBefore.length > 0 && (!weekCompleted.exists(leWeek.weekBefore) || !weekCompleted.get(leWeek.weekBefore)));
	}

	override function create()
	{
		#if desktop
		// Updating Discord Rich Presence
		DiscordClient.changePresence("In the Menus", null);
		
		FlxG.mouse.visible = true;
		#end
		
		FlxG.camera.bgColor = FlxColor.BLACK;

		WeekData.reloadWeekFiles(true);

		var chapN:Int = -1;
		for (daWeek in WeekData.weeksList){
			var weekFile:WeekData = WeekData.weeksLoaded.get(daWeek);
			var isLocked:Bool = weekIsLocked(daWeek);
			
			if (weekFile.hideStoryMode)
				continue;

			chapN++;
			
			var pos = chapterSelectPositions[chapN];
			var previewImage = Paths.image("newmenuu/songselect/" + weekFile.fileName + (isLocked ? "lock" : ""));
			previewImage = previewImage != null ? previewImage : Paths.image("newmenuu/songselect/unknown");
			
			var newWeek = new SowyChapterOption(pos[0], pos[1], weekFile);
			newWeek.loadGraphic(previewImage);

			var yellowBorder = new FlxShapeBox(pos[0] - 3, pos[1] - 3, 200, 200, {thickness: 6, color: FlxColor.fromRGB(255, 242, 0)}, FlxColor.BLACK);
			var textTitle = new FlxText(pos[0]-3, pos[1]-24, 206, weekFile.weekName, 12);

			if (isLocked){
				newWeek.onUp.callback = function(){
					if (doingTransition)
						return;
					FlxG.sound.play(Paths.sound('lockedMenu'));
				}
			}else{
				newWeek.onUp.callback = function()
				{
					if (doingTransition)
						return;
					FlxG.sound.play(Paths.sound('cancelMenu')); // swoosh
					openWeekMenu(newWeek);
				}
			}

			mainMenu.add(textTitle);
			mainMenu.add(yellowBorder);
			mainMenu.add(newWeek);
		}
		
		add(mainMenu);
		funkyRectangle.visible = false;
		add(funkyRectangle);
		
		super.create();
	}

	override function closeSubState()
	{
		persistentUpdate = true;
		// changeWeek();
		super.closeSubState();
	}

	override function update(elapsed:Float)
	{
		if (controls.BACK && !doingTransition)
		{
			FlxG.sound.play(Paths.sound('cancelMenu'));

			if (isOnSubMenu)
				closeWeekMenu();
			else if (!doingTransition)
				MusicBeatState.switchState(new MainMenuState());
		}

		super.update(elapsed);
	}

	function openWeekMenu(chapterOption:SowyChapterOption){
		doingTransition = true;
		isOnSubMenu = true;

		funkyRectangle.setPosition(chapterOption.x, chapterOption.y);
		funkyRectangle.visible = true;
		
		FlxTween.tween(funkyRectangle, {
			x: 10,
			y: 10,
			width: 1260,
			height: 700,
			shapeWidth: 1260,
			shapeHeight: 700,
		},
		0.6,
		{
			ease: FlxEase.quadOut,
			onComplete: function(twn){
				doingTransition = false;
				
				subMenu.updateChapterDetails(chapterOption.weekFile);
				add(subMenu);

				remove(mainMenu);
				
				lastButton = chapterOption;
			}
		}
		);
	}

	function closeWeekMenu(){
		doingTransition = true;
		isOnSubMenu = false;

		add(mainMenu);
		remove(subMenu);
		
		FlxTween.tween(funkyRectangle, {
			x: lastButton.x - 3,
			y: lastButton.y - 3,
			width: 206,
			height: 206,
			shapeWidth: 206,
			shapeHeight: 206,
		}, 0.6, {
			ease: FlxEase.quadOut,
			onComplete: function(twn)
			{
				doingTransition = false;
				funkyRectangle.visible = false;
			}
		});
	}
}

class SowyChapterOption extends FlxUIButton{
	public var weekFile:WeekData;

	public function new(?X:Float = 0, ?Y:Float = 0, WeekFile:WeekData)
	{
		weekFile = WeekFile;
		super(X, Y);
	}
}

class StoryModeSubMenu extends FlxTypedGroup<FlxBasic>{
	var chapterImage:FlxSprite;
	var chapterText:FlxText;

	var cornerLeftText:FlxText;
	var cornerRightText:FlxText;

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

	public function new(){
		super();

		chapterImage = new FlxSprite(75, 130);
		add(chapterImage);

		chapterText = new FlxText(0, 0, 1, sowyStr, 32);
		chapterText.setFormat(Paths.font("calibri.ttf"), 32, FlxColor.WHITE, FlxTextAlign.CENTER, FlxTextBorderStyle.NONE, FlxColor.WHITE);
		add(chapterText);

		cornerLeftText = new FlxText(15, 720, 0, "← BACK", 32);
		cornerLeftText.setFormat(Paths.font("calibri.ttf"), 32, FlxColor.YELLOW, FlxTextAlign.RIGHT, FlxTextBorderStyle.NONE, FlxColor.YELLOW);
		add(cornerLeftText);

		cornerRightText = new FlxText(1280, 720, 0, "PLAY →", 32);
		cornerRightText.setFormat(Paths.font("calibri.ttf"), 32, FlxColor.YELLOW, FlxTextAlign.LEFT, FlxTextBorderStyle.NONE, FlxColor.YELLOW);
		add(cornerRightText);

		cornerRightText.x -= cornerRightText.width + 15;
		cornerLeftText.y = cornerRightText.y -= cornerRightText.height + 15;

		//// SONGS - HI-SCORE
		halfScreen = 1280 / 2;
		startY = chapterImage.y + 48;

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
		totalScoreTxt.setFormat(Paths.font("calibri.ttf"), 32, FlxColor.WHITE, FlxTextAlign.LEFT, FlxTextBorderStyle.NONE, FlxColor.WHITE);
		totalScoreTxt.x -= totalScoreTxt.width + 15;

		add(totalSongTxt);
		add(totalScoreTxt);
	}
	
	public function updateChapterDetails(weekFile:WeekData){
		trace(weekFile.songs);

		chapterImage.loadGraphic(Paths.image('newmenuu/mainmenu/cover_promo'));
		chapterImage.updateHitbox();
		
		chapterText.setPosition(chapterImage.x, chapterImage.y + chapterImage.height + 4);
		chapterText.fieldWidth = chapterImage.width;
		chapterText.text = weekFile.weekName;

		// Make a text boxes for every song.
		var songAmount:Int = 0;

		for (song in weekFile.songs)
		{
			var songName = song[0];
			var yPos = startY + (songAmount + 2) * 48;

			var newSongTxt = songTxtArray[songAmount]; // find a previously created text
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
			if (newScoreTxt != null) { // if found then reuse it
				newScoreTxt.text = songName;
				newScoreTxt.visible = true;
			}
			else // if not then make one
			{
				newScoreTxt = new FlxText(1205, yPos, 0, "0", 32);
				newScoreTxt.setFormat(Paths.font("calibri.ttf"), 32, FlxColor.WHITE, FlxTextAlign.LEFT, FlxTextBorderStyle.NONE, FlxColor.WHITE);
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
	}
}