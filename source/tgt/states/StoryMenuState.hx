package tgt;

import ChapterData;
import flixel.addons.display.shapes.FlxShapeBox;
import flixel.group.FlxGroup;
import flixel.math.FlxPoint;
import flixel.text.FlxText;
import flixel.ui.FlxButton;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import sowy.*;

using StringTools;
#if discord_rpc
import Discord.DiscordClient;
#end

typedef ChapterButton = {
	var button:ChapterOption;
	var border:FlxShapeBox;
	var text:FlxText;
}

class StoryMenuState extends MusicBeatState
{
	// Screen positions for the chapter options
	/// grrr make this shit dynamic
	final chapterSelectPositions:Array<Array<Int>> = [
		[51, 109], [305, 109], [542, 109], [788, 109], [1034, 109],
		[51, 417], [305, 417], [542, 417], [788, 417], [1034, 417]
	];
	var chapterButtons:Array<ChapterButton> = [];

	public var cameFromChapterMenu = false;
	var doingTransition = false;

	static var curSelected:Int = 0;
	var selectionArrow:FlxSprite;

	override function create()
	{
		#if discord_rpc
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
				dur: 0.45
			}
			this.transIn = STS;
		}

		super.create();

		var chapN:Int = -1;

		for (chapData in ChapterData.reloadChapterFiles())
		{
			// this is to hide the christmas stuff from story mode, since im not sure if we're gonna make extra stuff for the story mode
			if (chapData.category != "main")
				continue;

			/*
			if (chapData.hideStoryMode)
				continue;
			*/

			chapN++;
			var pos = chapterSelectPositions[chapN];
			if (pos == null)
				continue;

			// For Now
			var isLocked = chapData.unlockCondition != true;

			Paths.currentModDirectory = chapData.directory;
			

			var previewImage = Paths.image("chapters/" + Paths.formatToSongPath(chapData.name) + (isLocked ? "-lock" : ""));
			previewImage = previewImage != null ? previewImage : Paths.image("chapters/unknown");
			
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
					SquareTransitionSubstate.info = {
							sX: newButton.x - 3,
							sY: newButton.y - 3,
							sW: 200,
							sH: 200,
							eX: cam.scroll.x + 10,
							eY: cam.scroll.y + 10,
							eW: 1260,
							eH: 700,
							dur: 0.45
					}
					this.transOut = SquareTransitionSubstate;

					var nState = new ChapterMenuState(newButton.data);
					nState.cameFromStoryMenu = true;
					MusicBeatState.switchState(nState);
				}
			}

			chapterButtons.push({
				button: newButton,
				text: textTitle,
				border: yellowBorder
			});

			add(textTitle);
			add(newButton);
			add(yellowBorder);			
		}

		selectionArrow = new FlxSprite(0,0, Paths.image("tgtmenus/selectionArrow"));
		selectionArrow.color = 0xFFF4CC34;
		add(selectionArrow);

		changeSelection(curSelected, true);
		
		var cornerLeftText = tgt.TGTMenuShit.newBackTextButton(goBack);
		add(cornerLeftText);
	}

	function changeSelection(val:Int = 0, ?absolute:Bool = false)
	{
		var prev = curSelected;
		curSelected = absolute == true ? val : curSelected + val;

		if (curSelected < 0 || curSelected >= chapterButtons.length)
			curSelected = prev;

		/*
		if (curSelected < 0)
			curSelected += chapterButtons.length;
		else if (curSelected >= chapterButtons.length)
			curSelected -= chapterButtons.length;
		*/

		var curButton = chapterButtons[curSelected];
		if (curButton != null){	
			selectionArrow.y = curButton.border.y + curButton.border.height + 10;
			selectionArrow.x = curButton.border.x + (curButton.border.width - selectionArrow.width) * 0.5; 
		}
	}

	function goBack()
	{
		if (doingTransition)
			return;

		curSelected = 0;
		
		FlxG.sound.play(Paths.sound('cancelMenu'));
		MusicBeatState.switchState(new MainMenuState());
	} 

	override function update(elapsed:Float)
	{
		if (controls.BACK)
			goBack();

		if (controls.UI_LEFT_P)
			changeSelection(-1);
		if (controls.UI_RIGHT_P)
			changeSelection(1);
		if (controls.UI_DOWN_P)
			changeSelection(5);
		if (controls.UI_UP_P)
			changeSelection(-5);
		
		if (controls.ACCEPT){
			var curButton = chapterButtons[curSelected].button;
			curButton.onUp.callback();
		}

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

	var fuckYouSound:FlxSound;
	var violations:Int = 0;
	var elapsedSecond:Float = 0;

	override function update(e){
		elapsedSecond += e;
		if (elapsedSecond > 0.6 && violations > 0){
			violations--;
			elapsedSecond -= 0.6;
		}

		super.update(e);
	}
	override function shake(){
		if (twen != null){ // if shaking
			violations++;
			if (violations >= 10){
				if (fuckYouSound != null){
					#if sys
					Sys.exit(0);
					return;
					#end
				}

				FlxG.camera.shake(0.005,0.25,null,true,X);

				fuckYouSound = FlxG.sound.play(Paths.sound("notyet"));
				fuckYouSound.onComplete = ()->{
					fuckYouSound = null;
				};
				violations = 0;


			}
		}
		
		super.shake();
	}
}