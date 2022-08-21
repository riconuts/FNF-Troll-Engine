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

	var chapterSelectPositions:Array<Array<Int>> = [
		[51, 109], [305, 109], [542, 109], [788, 109], [1034, 109],
		[51, 417], [305, 417], [542, 417], [788, 417], [1034, 417]
	];
	var YELLOW = FlxColor.fromRGB(255, 242, 0);

	var selectMenu = new FlxTypedGroup<FlxBasic>();
	var funkyRectangle = new FlxShapeBox(0, 0, 206, 206, {thickness: 3, color: FlxColor.fromRGB(255, 242, 0)},
	FlxColor.fromRGB(0, 0, 0, 255));

	var doingTransition = false;
	var curSubMenu:FlxTypedGroup<FlxBasic>;
	var lastSubMenu:FlxTypedGroup<FlxBasic>;
	var lastButton:SowyChapterOption;

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
		for (daWeek in WeekData.weeksList)
		{
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

			selectMenu.add(yellowBorder);
			selectMenu.add(newWeek);
		}
		
		add(selectMenu);
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

			if (curSubMenu != null)
				closeWeekMenu();
			else if (!doingTransition)
				MusicBeatState.switchState(new MainMenuState());
		}

		super.update(elapsed);
	}

	function openWeekMenu(chapterOption:SowyChapterOption){
		funkyRectangle.setPosition(chapterOption.x, chapterOption.y);
		
		funkyRectangle.visible = true;

		doingTransition = true;
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
				
				remove(selectMenu);

				if (lastButton.weekFile != chapterOption.weekFile){
					if (lastButton != null) // NOR
						lastSubMenu.destroy();
					lastSubMenu = makeWeekMenu(chapterOption.weekFile);	
				}
				add(lastSubMenu);

				curSubMenu = lastSubMenu;
				lastButton = chapterOption;
			}
		}
		);
	}

	function closeWeekMenu(){
		doingTransition = true;

		remove(lastSubMenu);
		add(selectMenu);
		
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
				curSubMenu = null;
				doingTransition = false;
				funkyRectangle.visible = false;
			}
		});
	}

	function makeWeekMenu(weekFile:WeekData):FlxTypedGroup<FlxBasic>
	{
		var newMenu:FlxTypedGroup<FlxBasic> = new FlxTypedGroup<FlxBasic>();
		trace(weekFile.songs);

		var chapterImage = new FlxSprite(75, 130).loadGraphic(Paths.image('newmenuu/mainmenu/cover_promo'));
		chapterImage.updateHitbox();
		newMenu.add(chapterImage);

		var chapterText = new FlxText(chapterImage.x, chapterImage.y + chapterImage.height + 4, chapterImage.width, weekFile.weekName, 32);
		chapterText.setFormat(Paths.font("calibri.ttf"), 32, FlxColor.WHITE, FlxTextAlign.CENTER, FlxTextBorderStyle.NONE, FlxColor.WHITE);
		newMenu.add(chapterText);

		var cornerLeftText = new FlxText(15, 720, 0, "← BACK", 32);
		cornerLeftText.setFormat(Paths.font("calibri.ttf"), 32, FlxColor.YELLOW, FlxTextAlign.RIGHT, FlxTextBorderStyle.NONE, FlxColor.YELLOW);
		newMenu.add(cornerLeftText);

		var cornerRightText = new FlxText(1280, 720, 0, "PLAY →", 32);
		cornerRightText.setFormat(Paths.font("calibri.ttf"), 32, FlxColor.YELLOW, FlxTextAlign.LEFT, FlxTextBorderStyle.NONE, FlxColor.YELLOW);
		newMenu.add(cornerRightText);

		cornerRightText.x -= cornerRightText.width + 15;
		cornerLeftText.y = cornerRightText.y -= cornerRightText.height + 15;

		//// SONGS - HI-SCORE
		var halfScreen = 1280 / 2;
		var startY = chapterImage.y + 48;

		var songText = new FlxText(halfScreen, startY, 0, "SONGS", 32);
		songText.setFormat(Paths.font("calibrib.ttf"), 32, FlxColor.WHITE, FlxTextAlign.RIGHT, FlxTextBorderStyle.NONE, FlxColor.WHITE);
		newMenu.add(songText);

		var scoreText = new FlxText(1205, startY, 0, "HI-SCORE", 32);
		scoreText.setFormat(Paths.font("calibrib.ttf"), 32, FlxColor.WHITE, FlxTextAlign.LEFT, FlxTextBorderStyle.NONE, FlxColor.WHITE);
		scoreText.x -= scoreText.width + 15;
		newMenu.add(scoreText);

		// Make every song.
		var songAmount:Int = 0;
		var newScoreTxt:FlxText;
		var newSongTxt:FlxText;

		for (song in weekFile.songs)
		{
			var songName = song[0];
			var yPos = startY + (songAmount + 2) * 48;

			newSongTxt = new FlxText(halfScreen, yPos, 0, songName, 32);
			newSongTxt.setFormat(Paths.font("calibri.ttf"), 32, FlxColor.YELLOW, FlxTextAlign.RIGHT, FlxTextBorderStyle.NONE, FlxColor.YELLOW);

			newScoreTxt = new FlxText(1205, yPos, 0, "0", 32);
			newScoreTxt.setFormat(Paths.font("calibri.ttf"), 32, FlxColor.WHITE, FlxTextAlign.LEFT, FlxTextBorderStyle.NONE, FlxColor.WHITE);
			newScoreTxt.x -= newScoreTxt.width + 15;

			newMenu.add(newSongTxt);
			newMenu.add(newScoreTxt);

			songAmount++;
		}

		// TOTAL - TOTAL SCORE
		var yPos = startY + (songAmount + 2) * 48;
		var totalSongTxt = new FlxText(halfScreen, yPos, 0, "TOTAL", 32);
		totalSongTxt.setFormat(Paths.font("calibri.ttf"), 32, FlxColor.WHITE, FlxTextAlign.RIGHT, FlxTextBorderStyle.NONE, FlxColor.WHITE);

		var totalScoreTxt = new FlxText(1205, yPos, 0, "0", 32);
		totalScoreTxt.setFormat(Paths.font("calibri.ttf"), 32, FlxColor.WHITE, FlxTextAlign.LEFT, FlxTextBorderStyle.NONE, FlxColor.WHITE);
		totalScoreTxt.x -= totalScoreTxt.width + 15;

		newMenu.add(totalSongTxt);
		newMenu.add(totalScoreTxt);

		//
		lastSubMenu = newMenu;

		return newMenu;
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

