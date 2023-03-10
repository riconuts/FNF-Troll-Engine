package;

import ChapterData;
import flixel.addons.display.shapes.FlxShapeBox;
import flixel.group.FlxGroup;
import flixel.math.*;
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

	//public var camFollowPos:FlxObject;

	final chapterSelectPositions:Array<Array<Int>> = [ // Screen positions for the chapter options
		[51, 109], [305, 109], [542, 109], [788, 109], [1034, 109],
		[51, 417], [305, 417], [542, 417], [788, 417], [1034, 417]
	];

	var mainMenu = new FlxTypedGroup<FlxBasic>(); // group for the main menu where you select achapter!
	
	var funkyRectangle = new FlxShapeBox(0, 0, 206, 206, {thickness: 3, color: FlxColor.fromRGB(255, 242, 0)}, FlxColor.BLACK); // cool rectanlge used for transitions
	var lastButton:ChapterOption; // used the square transition
	var doingTransition = false; // to prevent unintended behaviour

	var cornerLeftText:SowyTextButton;

	public var cameFromChapterMenu = false;

	override function create()
	{
		#if desktop
		// Updating Discord Rich Presence
		DiscordClient.changePresence("In the Menus", null);
		#end
		#if !FLX_NO_MOUSE
		FlxG.mouse.visible = true;
		#end
		
		var cam = FlxG.camera;
		cam.focusOn(new FlxPoint(FlxG.width* 0.5, FlxG.height* 0.5));
		cam.bgColor = FlxColor.BLACK;

		if (cameFromChapterMenu){
			trace('uuoohhhhh im cummmminggg aaaaa');

			FlxG.sound.play(Paths.sound('cancelMenu')); // swoosh

			final STS = SquareTransitionSubstate;
			STS.nextCamera = cam;
			STS.info = cast {
				sX: STS.info.eX,
				sY: STS.info.eY,
				sW: STS.info.eW,
				sH: STS.info.eH,
				eX: STS.info.sX,
				eY: STS.info.sY,
				eW: STS.info.sW,
				eH: STS.info.sH,
				dur: 0.6
			}
			this.transIn = STS;
		}

		super.create();

		var chapN:Int = -1;

		for (chapData in ChapterData.reloadChapterFiles())
		{
			// For Now
			var isLocked = chapData.unlockCondition != true;

			// this is to hide the christmas stuff from story mode, since im not sure if we're gonna make extra stuff for the story mode
			if (chapData.category != "main")
				continue;

			/*
			if (chapData.hideStoryMode)
				continue;
			*/

			Paths.currentModDirectory = chapData.directory;
			chapN++;

			var previewImage = Paths.image("chapters/" + Paths.formatToSongPath(chapData.name) + (isLocked ? "-lock" : ""));
			previewImage = previewImage != null ? previewImage : Paths.image("chapters/unknown");
			
			var pos = chapterSelectPositions[chapN];
			var xPos = pos[0];
			var yPos = pos[1];

			var newButton = new ChapterOption(xPos, yPos, chapData);
			newButton.loadGraphic(previewImage);

			var yellowBorder = new FlxShapeBox(xPos - 3, yPos - 3, 200, 200, {thickness: 6, color: 0xFFF4CC34}, FlxColor.TRANSPARENT);
			var textTitle = new FlxText(xPos - 3, yPos - 30, 206, chapData.name, 12);
			textTitle.setFormat(Paths.font("calibri.ttf"), 18, FlxColor.WHITE, FlxTextAlign.CENTER, FlxTextBorderStyle.NONE);

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
					
					var cam = FlxG.camera;
					SquareTransitionSubstate.nextCamera = cam;
					SquareTransitionSubstate.info = cast {
							sX: newButton.x - 3,
							sY: newButton.y - 3,
							sW: 200,
							sH: 200,
							eX: cam.scroll.x + 10,
							eY: cam.scroll.y + 10,
							eW: 1260,
							eH: 700,
							dur: 0.6
					}
					this.transOut = SquareTransitionSubstate;

					lastButton = newButton;
					var nState = new ChapterMenuState(newButton.data);
					nState.cameFromStoryMenu = true;
					MusicBeatState.switchState(nState);
				}
			}

			mainMenu.add(textTitle);
			mainMenu.add(newButton);
			mainMenu.add(yellowBorder);			
		}
		
		cornerLeftText = new SowyTextButton(15, 720, 0, "← BACK", 32, goBack);
		cornerLeftText.label.setFormat(Paths.font("calibri.ttf"), 32, 0xFFF4CC34, FlxTextAlign.RIGHT, FlxTextBorderStyle.NONE);
		cornerLeftText.y -= cornerLeftText.height + 15;
		mainMenu.add(cornerLeftText);
		
		add(mainMenu);
		funkyRectangle.visible = false;
		add(funkyRectangle);
		
		instance = this;
	}

	override function closeSubState()
	{
		super.closeSubState();
	}

	public function goBack()
	{
		if (!doingTransition)
		{
			FlxG.sound.play(Paths.sound('cancelMenu'));
			
			if (!doingTransition){
				//subMenu.destroy();
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
}
class ChapterOption extends TGTSquareButton{
	public var data:ChapterMetadata;

	public function new(?X:Float = 0, ?Y:Float = 0, Data:ChapterMetadata){
		data = Data;
		super(X, Y);
	}
	override function onover(){
		//if (!StoryMenuState.weekIsLocked(daWeek))
			super.onover();
	}
}