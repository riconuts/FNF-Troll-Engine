package;

import WeekData;
import editors.ChartingState;
import flash.text.TextField;
import flixel.*;
import flixel.addons.display.FlxGridOverlay;
import flixel.addons.display.shapes.FlxShapeBox;
import flixel.addons.transition.FlxTransitionableState;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.system.FlxSound;
import flixel.text.FlxText;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import lime.utils.Assets;
import openfl.utils.Assets as OpenFlAssets;
import sowy.TGTSquareButton;

using StringTools;
#if desktop
import Discord.DiscordClient;
#end
#if MODS_ALLOWED
import sys.FileSystem;
#end

class FreeplayState extends MusicBeatState
{
	var songs:Array<SongMetadata> = [];

	var selector:FlxText;
	private static var curSelected:Int = 0;

	var scoreBG:FlxSprite;
	var scoreText:FlxText;
	var lerpScore:Int = 0;
	var lerpRating:Float = 0;
	var intendedScore:Int = 0;
	var intendedRating:Float = 0;

	private var grpSongs:FlxTypedGroup<Alphabet>;
	private var curPlaying:Bool = false;

	private var categories:Map<String, FreeplayCategory> = new Map();

	public var camFollowPos:FlxObject;

	override function create()
	{
		#if desktop
		// Updating Discord Rich Presence
		DiscordClient.changePresence("In the Menus", null);
		
		FlxG.mouse.visible = true;
		#end
		
		Paths.clearStoredMemory();
		//Paths.clearUnusedMemory();
		
		persistentUpdate = true;
		PlayState.isStoryMode = false;
		WeekData.reloadWeekFiles(false);

		camFollowPos = new FlxObject(640, 360);
		FlxG.camera.follow(camFollowPos);
		FlxG.camera.bgColor = FlxColor.BLACK;

		// Load categories (wip!!)
		var categoryNames:Map<String, String> = new Map();
		
		/*
		categoryNames.set("mainStory", "MAIN STORY");
		categoryNames.set("sideStory", "SIDE STORIES");
		*/
		categoryNames.set("ALL SONGS", "ALL SONGS");

		for (id in ["ALL SONGS"/*, "sideStory"*/]){
			var catText = new FlxText(0, 0, FlxG.width, categoryNames.get(id), 32, true);
			catText.setFormat(Paths.font("calibrib.ttf"), 32, FlxColor.YELLOW, FlxTextAlign.CENTER, FlxTextBorderStyle.NONE, FlxColor.YELLOW);
			var category = new FreeplayCategory(catText);
			add(category);

			categories.set(id, category);
		}

		// Load the songs!!!
		for (i in 0...WeekData.weeksList.length) {
			var isLocked = weekIsLocked(WeekData.weeksList[i]);

			var leWeek:WeekData = WeekData.weeksLoaded.get(WeekData.weeksList[i]);
			WeekData.setDirectoryFromWeek(leWeek);

			var generic;
			
			for (song in leWeek.songs){
				var songButton = addSong(song[0], i, "ALL SONGS", isLocked/*song[1]*/);
				if (songButton == null)
					continue;

				if (isLocked)
					songButton.onUp.callback = function(){
						songButton.shake();
					}
				else
					songButton.onUp.callback = function(){
						playSong(songButton.metadata);
					};
			}
		}
		Paths.loadTheFirstEnabledMod();

		super.create();
	}

	public function playSong(metadata:SongMetadata){
		persistentUpdate = false;

		var weekName = WeekData.getWeekFileName();

		WeekData.setDirectoryFromWeek(WeekData.weeksLoaded.get(weekName));
		trace('CURRENT WEEK: $weekName' + weekName);

		Paths.currentModDirectory = metadata.folder;

		var songLowercase:String = Paths.formatToSongPath(metadata.songName);
		trace(songLowercase);

		PlayState.SONG = Song.loadFromJson(songLowercase, songLowercase);
		PlayState.isStoryMode = false;

		if (FlxG.keys.pressed.SHIFT)
			LoadingState.loadAndSwitchState(new ChartingState());
		else
			LoadingState.loadAndSwitchState(new PlayState());

		FlxG.sound.music.volume = 0;
	} 

	override function closeSubState() {
		//changeSelection(0, false);
		persistentUpdate = true;
		super.closeSubState();
	}

	public function addSong(songName:String, weekNum:Int, ?categoryName:String, ?isLocked = true):Null<FreeplaySongButton>
	{
		if (categoryName == null)
			return null;
		var category = categories.get(categoryName);
		if (category == null)
			return null;

		var button:FreeplaySongButton = new FreeplaySongButton(
			0, 0, 
			new SongMetadata(songName, weekNum),
			isLocked
		);
		button.loadGraphic(Paths.image("songs/" + Paths.formatToSongPath(songName)));
		button.setGraphicSize(194, 194);
		button.updateHitbox();
		category.addItem(button);

		var yellowBorder = new FlxShapeBox(button.x-3, button.y-3, 200, 200, {thickness: 6, color: FlxColor.fromRGB(255, 242, 0)}, FlxColor.TRANSPARENT);
		add(yellowBorder);
		
		var nameText = new FlxText(button.x, button.y - 32, button.width, songName, 24);
		nameText.setFormat(Paths.font("calibri.ttf"), 18, FlxColor.WHITE, FlxTextAlign.CENTER, FlxTextBorderStyle.NONE);
		add(nameText);
		
		var scoreText = new FlxText(button.x, button.y + button.height + 12, button.width, "" + Highscore.getScore(songName), 24);
		scoreText.setFormat(Paths.font("calibri.ttf"), 18, FlxColor.WHITE, FlxTextAlign.CENTER, FlxTextBorderStyle.NONE);
		add(scoreText);

		return button;
	}

	function weekIsLocked(name:String):Bool {
		var leWeek:WeekData = WeekData.weeksLoaded.get(name);
		return (!leWeek.startUnlocked && leWeek.weekBefore.length > 0 && (!StoryMenuState.weekCompleted.exists(leWeek.weekBefore) || !StoryMenuState.weekCompleted.get(leWeek.weekBefore)));
	}
	
	var holdTime:Float = 10;
	var timeSinceLastHold:Float = 0;
	override function update(elapsed:Float)
	{
		if (FlxG.sound.music != null && FlxG.sound.music.volume < 0.7)
			FlxG.sound.music.volume += 0.5 * FlxG.elapsed;

		var up = controls.UI_UP;
		var down = controls.UI_DOWN;
		var accepted = controls.ACCEPT;
		var space = FlxG.keys.justPressed.SPACE;
		var ctrl = FlxG.keys.justPressed.CONTROL;

		var speed:Float = 0;
		#if desktop
		if (FlxG.mouse.wheel != 0)
			speed -= FlxG.mouse.wheel * 30;
		#end

		if (!(up && down)){
			timeSinceLastHold += elapsed;
			if (timeSinceLastHold > 0.25) holdTime = 10;
		}else{
			timeSinceLastHold = 0;
			holdTime += elapsed * 10;
		}	

		if (up)
			speed -= holdTime;
		if (down)
			speed += holdTime;

		camFollowPos.y += speed;

		if (controls.BACK){
			FlxG.sound.play(Paths.sound('cancelMenu'));
			MusicBeatState.switchState(new MainMenuState());
		}
		
		super.update(elapsed);
	}
}

class SongMetadata
{
	public var songName:String = "";
	public var week:Int = 0;
	public var folder:String = "";

	public function new(song:String, week:Int)
	{
		this.songName = song;
		this.week = week;
		this.folder = Paths.currentModDirectory;
		if(this.folder == null) this.folder = '';
	}
}

class FreeplaySongButton extends TGTSquareButton{
	public var metadata:SongMetadata;
	public var isLocked = true;

	public function new(X, Y, Metadata, IsLocked)
	{
		metadata = Metadata;
		isLocked = IsLocked;
		super(X, Y);
	}

	override function onover()
	{
		if (!isLocked)
			super.onover();
	}
}

class FreeplayCategory extends flixel.group.FlxSpriteGroup{
	var titleText:FlxText;
	var posArray = [51, 305, 542, 788, 1034]; // fuck it
	var buttonArray:Array<FreeplaySongButton> = [];

	public function new(?X = 0, ?Y = 0, TitleText:FlxText){
		/*
		var ocu = (200 * 5 + 5 * 4);
		var 
		FlxG.width - ;
		*/

		super(X, Y);
		super.add(titleText = TitleText);
	}

	public function addItem(item:FreeplaySongButton){
		var num = buttonArray.push(item) - 1;
		var x = num % posArray.length;
		var y = Math.floor(num / 5);

		item.setPosition(posArray[x], titleText.y + titleText.height + 50 + y * 308);
		trace(num, x, y);

		return super.add(item);
	}
}