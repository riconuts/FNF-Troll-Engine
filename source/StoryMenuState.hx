package;

import WeekData;
import flash.ui.Mouse;
import flash.ui.MouseCursor;
import flixel.FlxBasic;
import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.addons.display.shapes.FlxShapeBox;
import flixel.addons.transition.FlxTransitionableState;
import flixel.addons.ui.FlxUIButton;
import flixel.graphics.FlxGraphic;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.group.FlxGroup;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.ui.FlxButton;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import sowy.*;

using StringTools;
#if desktop
import Discord.DiscordClient;
#end

class StoryMenuState extends MusicBeatState
{
	public static var weekCompleted:Map<String, Bool> = new Map<String, Bool>();
	public static var instance:StoryMenuState;

	public var camFollowPos:FlxObject;

	final chapterSelectPositions:Array<Array<Int>> = [ // Screen positions for the chapter options
		[51, 109], [305, 109], [542, 109], [788, 109], [1034, 109],
		[51, 417], [305, 417], [542, 417], [788, 417], [1034, 417]
	];

	var mainMenu = new FlxTypedGroup<FlxBasic>(); // group for the main menu where you select achapter!
	var subMenu:ChapterMenuState; // custom group class for the menu where yu select a song!
	
	var funkyRectangle = new FlxShapeBox(0, 0, 206, 206, {thickness: 3, color: FlxColor.fromRGB(255, 242, 0)}, FlxColor.BLACK); // cool rectanlge used for transitions
	var lastButton:ChapterOption; // used the square transition
	var doingTransition = false; // to prevent unintended behaviour

	var cornerLeftText:SowyTextButton;

	var isOnSubMenu = false;

	public static function weekIsLocked(leWeek:WeekData):Bool {
		return (!leWeek.startUnlocked && leWeek.weekBefore.length > 0 && (!weekCompleted.exists(leWeek.weekBefore) || !weekCompleted.get(leWeek.weekBefore)));
	}

	override function create()
	{
		#if desktop
		// Updating Discord Rich Presence
		DiscordClient.changePresence("In the Menus", null);
		
		FlxG.mouse.visible = true;
		#end
		
		camFollowPos = new FlxObject(FlxG.width / 2, FlxG.height / 2);
		FlxG.camera.follow(camFollowPos);
		FlxG.camera.bgColor = FlxColor.BLACK;

		WeekData.reloadWeekFiles(true);
		trace(WeekData.weeksList);

		var chapN:Int = -1;
		for (weekName in WeekData.weeksList){
			var daWeek:WeekData = WeekData.weeksLoaded.get(weekName);
			var isLocked:Bool = weekIsLocked(daWeek);
			
			if (daWeek.hideStoryMode)
				continue;

			chapN++;
			
			var pos = chapterSelectPositions[chapN];
			var previewImage = Paths.image("newmenuu/songselect/" + daWeek.fileName + (isLocked ? "lock" : ""));
			previewImage = previewImage != null ? previewImage : Paths.image("newmenuu/songselect/unknown");
			
			var newButton = new ChapterOption(pos[0], pos[1], daWeek);
			newButton.loadGraphic(previewImage);

			var yellowBorder = new FlxShapeBox(pos[0] - 3, pos[1] - 3, 200, 200, {thickness: 6, color: FlxColor.fromRGB(255, 242, 0)}, FlxColor.TRANSPARENT);
			var textTitle = new FlxText(pos[0]-3, pos[1]-24, 206, daWeek.weekName, 12);
			textTitle.setFormat(Paths.font("calibri.ttf"), 12, FlxColor.WHITE, FlxTextAlign.CENTER, FlxTextBorderStyle.NONE);

			if (isLocked){
				newButton.onUp.callback = function(){
					if (doingTransition)
						return;
					FlxG.sound.play(Paths.sound('lockedMenu'));
					newButton.shake();
				}
			}else{
				newButton.onUp.callback = function()
				{
					if (doingTransition)
						return;
					FlxG.sound.play(Paths.sound('cancelMenu')); // swoosh
					openRectangleTransition(newButton.x, newButton.y, function(){
						lastButton = newButton;
						subMenu.curWeek = newButton.daWeek;
						openSubState(subMenu);
					});
				}
			}

			mainMenu.add(textTitle);
			mainMenu.add(newButton);
			mainMenu.add(yellowBorder);
		}
		
		cornerLeftText = new SowyTextButton(15, 720, 0, "← BACK", 32, goBack);
		cornerLeftText.label.setFormat(Paths.font("calibri.ttf"), 32, FlxColor.YELLOW, FlxTextAlign.RIGHT, FlxTextBorderStyle.NONE, FlxColor.YELLOW);
		cornerLeftText.y -= cornerLeftText.height + 15;
		mainMenu.add(cornerLeftText);
		
		add(mainMenu);
		funkyRectangle.visible = false;
		add(funkyRectangle);
		
		destroySubStates = false;
		instance = this;
		subMenu = new ChapterMenuState();
		super.create();
	}

	override function closeSubState()
	{
		super.closeSubState();

		if (isOnSubMenu)
			closeRectangleTransition();
	}

	public function goBack()
	{
		if (!doingTransition)
		{
			FlxG.sound.play(Paths.sound('cancelMenu'));
			
			if (!doingTransition)
			{
				subMenu.destroy();
				MusicBeatState.switchState(new MainMenuState());
			}
		}
	} 

	override function update(elapsed:Float)
	{
		if (controls.BACK)
			goBack();

		super.update(elapsed);
	}

	function openRectangleTransition(?x:Float, ?y:Float, ?onEnd:Void->Void){
		doingTransition = true;
		isOnSubMenu = true;

		funkyRectangle.setPosition(x != null ? x : funkyRectangle.x, y != null ? y : funkyRectangle.y);
		funkyRectangle.visible = true;

		cornerLeftText.visible = false;
		
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
				remove(mainMenu);

				if (onEnd != null)
					onEnd();
				else
					trace("xd no function");
			}
		}
		);
	}

	function closeRectangleTransition(){
		doingTransition = true;
		isOnSubMenu = false;
		
		add(mainMenu);
		
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
				cornerLeftText.visible = true;
			}
		});
	}
}
class ChapterOption extends SowyBaseButton{
	public var daWeek:WeekData;

	public function new(?X:Float = 0, ?Y:Float = 0, DaWeek:WeekData){
		daWeek = DaWeek;
		super(X, Y);
	}
	override function onover(){
		if (!StoryMenuState.weekIsLocked(daWeek))
			super.onover();
	}

	// fucking lmao
	var shk = 0;
	var twen:FlxTween;
	var its:Float = .05;
	public function shake(){
		shk = 0;
		if (twen != null){
			twen.cancel();
			twen.destroy();
		}
		doShake();
	}
	function doShake(){
		if (shk >= 4){
			shk = 0;
			return;
		}else if (shk == 0)
			FlxTween.tween(this, {color:0xFF0000}, 0.1, {
				ease: FlxEase.backOut,
				onComplete: function(twn){
					twn.destroy();
					FlxTween.tween(this, {color: 0xFFFFFF}, 0.1, {ease: FlxEase.backOut, onComplete: function(twn) {twn.destroy();}});
				}
			});

		var state:Array<Dynamic> = [
			{x: -width * its, y: height * its},
			{x: width * its, y: -height * its},
			{x: -width * (its / 4), y: height * (its / 4)},
			{x: width * (its / 4), y: -height * (its / 4)},
			{x: 0, y: 0},
		];

		twen = FlxTween.tween(offset, state[shk], 0.05, {
			ease: FlxEase.backOut,
			onComplete: function(twn)
			{
				shk++;
				doShake();
				twn.destroy();
			}
		});
	}
}