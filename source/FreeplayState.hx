package;

import WeekData;
import editors.ChartingState;
import flixel.*;
import flixel.addons.display.shapes.FlxShapeBox;
import flixel.addons.transition.FlxTransitionableState;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.*;
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
import sys.io.File;
#end

class FreeplayState extends MusicBeatState
{
	var songs:Array<SongMetadata> = [];

	private var categories:Map<String, FreeplayCategory> = new Map();

	static var lastY:Float = 360;
	var camFollow = new FlxPoint(640, lastY);
	var camFollowPos = new FlxObject(640, lastY);

	var selectedSong:Null<SongMetadata> = null;
	var buttons:Array<FreeplaySongButton> = [];

	override function create()
	{
		#if desktop
		// Updating Discord Rich Presence
		DiscordClient.changePresence("In the Menus", null);
		#end

		persistentUpdate = false;
		
		Paths.clearStoredMemory();
		
		PlayState.isStoryMode = false;

		FlxG.camera.follow(camFollowPos);
		FlxG.camera.bgColor = FlxColor.BLACK;

		////
		var categoryNames:Map<String, String> = new Map();
		
		categoryNames.set("main", "MAIN STORY");
		categoryNames.set("side", "SIDE STORIES");
		categoryNames.set("remix", "REMIXES / COVERS");

		for (id => name in categoryNames)
		{
			var catTitle = new FlxText(0, 50, FlxG.width, name, 32, true);
			catTitle.setFormat(Paths.font("calibrib.ttf"), 32, FlxColor.YELLOW, FlxTextAlign.CENTER, FlxTextBorderStyle.NONE, FlxColor.YELLOW);
			catTitle.scrollFactor.set(1, 1);
			
			var category = new FreeplayCategory(catTitle);
			categories.set(id, category);
		}

		//// Load the songs!!!
		var resSelSongFunc = function(){selectedSong = null;};

		for (i in CoolUtil.coolTextFile(Paths.txt('freeplaySonglist')))
		{
			if (i != null && i.length > 0){
				var song:Array<String> = i.split(":");
				var isLocked = false; // For now
				var songButton = addSong(song[0], "", song[1], isLocked);

				if (songButton == null)
					continue;

				if (isLocked)
					songButton.onUp.callback = function(){songButton.shake();}
				else{
					songButton.onUp.callback = function(){playSong(songButton.metadata);};
					songButton.onOver.callback = function(){
						selectedSong = songButton.metadata;
					}
					songButton.onOut.callback = resSelSongFunc;
				}
					
			}
		}

		#if MODS_ALLOWED
		for (mod in Paths.getModDirectories())
		{
			Paths.currentModDirectory = mod;

			for (i in CoolUtil.coolTextFile(Paths.modsTxt('freeplaySonglist')))
			{
				if (i != null && i.length > 0){
					var song:Array<String> = i.split(":");
					var isLocked = false; // For now
					var songButton = addSong(song[0], null, song[1], isLocked);

					if (songButton == null)
						continue;

					if (isLocked)
						songButton.onUp.callback = function(){songButton.shake();}
					else{
						songButton.onOver.callback = function(){selectedSong = songButton.metadata;};
						songButton.onOut.callback = resSelSongFunc;
					
						songButton.onUp.callback = function(){
							//ChapterData.curChapter = mod; // ChapterData shit still in progress
							// actually that wasn't necessary because this is freeplay so, lol.

							var sPos = songButton;
							var cam = FlxG.camera;
							SquareTransitionSubstate.nextCamera = cam;
							SquareTransitionSubstate.info = cast {
								sX: sPos.x - 3,
								sY: sPos.y - 3,
								sW: 200,
								sH: 200,

								eX: cam.scroll.x - 3,
								eY: cam.scroll.y - 3,
								eW: FlxG.width + 6,
								eH: FlxG.height + 6
							};
							this.transOut = SquareTransitionSubstate;
							playSong(songButton.metadata);
						};
					}
				}
			}
		}
		Paths.currentModDirectory = '';
		#end

		//// Add categories
		var prevCat:Null<FreeplayCategory> = null;
		for (n => category in categories)
		{
			if (prevCat == null)
				category.y = 50;
			else
				category.y = 50 + prevCat.y + prevCat.height;

			prevCat = category;
			add(category);
		}
		maxY = prevCat.y + prevCat.height;

		super.create();

		#if !FLX_NO_MOUSE
		FlxG.mouse.visible = true;
		#end
	}

	public function playSong(metadata:SongMetadata){
		persistentUpdate = false;

		Paths.currentModDirectory = metadata.folder;

		var songLowercase:String = Paths.formatToSongPath(metadata.songName);
		trace('${Paths.currentModDirectory}, $songLowercase');

		PlayState.SONG = Song.loadFromJson(songLowercase, songLowercase);
		PlayState.isStoryMode = false;

		if (FlxG.keys.pressed.SHIFT)
		{
			PlayState.chartingMode = true;
			LoadingState.loadAndSwitchState(new ChartingState());
		}else
			LoadingState.loadAndSwitchState(new PlayState());

		FlxG.sound.music.volume = 0;
	} 

	override function closeSubState() 
	{
		//changeSelection(0, false);
		for (button in buttons)
			button.updateHighscore();

		super.closeSubState();
	}

	public function addSong(songName:String, ?folder:String, ?categoryName:String, ?isLocked = true):Null<FreeplaySongButton>
	{
		var folder = folder != null ? folder : Paths.currentModDirectory;
		var category = categories.get(categoryName);

		//trace('"$folder" / "$songName" / "$categoryName"');

		if (category == null)	
			return null;

		var button:FreeplaySongButton = new FreeplaySongButton(
			new SongMetadata(songName, folder),
			isLocked
		);
		category.addItem(button);

		////
		button.yellowBorder = new FlxShapeBox(button.x - 3, button.y - 3, 200, 200, {thickness: 6, color: FlxColor.fromRGB(255, 242, 0)}, FlxColor.TRANSPARENT);

		button.nameText = new FlxText(button.x, button.y - 32, button.width, songName, 24);
		button.nameText.setFormat(Paths.font("calibri.ttf"), 18, FlxColor.WHITE, FlxTextAlign.CENTER, FlxTextBorderStyle.NONE);

		button.scoreText = new FlxText(button.x, button.y + button.height + 12, button.width, "", 24);
		button.scoreText.setFormat(Paths.font("calibri.ttf"), 18, FlxColor.WHITE, FlxTextAlign.CENTER, FlxTextBorderStyle.NONE);

		category.add(button.yellowBorder);
		category.add(button.nameText);
		category.add(button.scoreText);

		button.updateHighscore();
		buttons.push(button);

		return button;
	}

	function weekIsLocked(name:String):Bool {
		var leWeek:WeekData = WeekData.weeksLoaded.get(name);
		return (!leWeek.startUnlocked && leWeek.weekBefore.length > 0 && (!StoryMenuState.weekCompleted.exists(leWeek.weekBefore) || !StoryMenuState.weekCompleted.get(leWeek.weekBefore)));
	}
	
	var minY:Float = 360;
	var maxY:Float = 0;
	override function update(elapsed:Float)
	{
		if (FlxG.sound.music != null && FlxG.sound.music.volume < 0.7)
			FlxG.sound.music.volume += 0.5 * FlxG.elapsed;

		if (FlxG.keys.pressed.CONTROL)
		{
			openSubState(new GameplayChangersSubstate());
		}
		if (FlxG.keys.pressed.R && selectedSong != null)
		{
			Paths.currentModDirectory = selectedSong.folder;
			openSubState(new ResetScoreSubState(selectedSong.songName, false));
		}

		var speed = FlxG.keys.pressed.SHIFT ? 2 : 1;

		var mouseWheel = FlxG.mouse.wheel;
		var yScroll:Float = 0;

		if (mouseWheel != 0)
			yScroll -= mouseWheel * 160 * speed;

		if (controls.UI_UP)
			camFollow.y -= 20;
		if (controls.UI_DOWN)
			camFollow.y += 20;

		camFollow.y = Math.max(minY, Math.min(camFollow.y + yScroll, maxY));

		// update camera
		var lerpVal = Math.min(1, elapsed * 6);
		camFollowPos.setPosition(FlxMath.lerp(camFollowPos.x, camFollow.x, lerpVal), FlxMath.lerp(camFollowPos.y, camFollow.y, lerpVal));

		if (controls.BACK){
			FlxG.sound.play(Paths.sound('cancelMenu'));
			MusicBeatState.switchState(new MainMenuState());
		}
		
		super.update(elapsed);
	}

	override function destroy(){
		lastY = camFollowPos.y;
		super.destroy();
	}

	public inline static function songImage(SongName:String)
		return Paths.image("songs/" + Paths.formatToSongPath(SongName));
}

class SongMetadata
{
	public var songName:String = "";
	public var folder:String = "";

	public function new(song:String, ?folder:String)
	{
		this.songName = song;
		this.folder = folder != null ? folder : Paths.currentModDirectory;

		if(this.folder == null) this.folder = '';
	}
}

class FreeplaySongButton extends TGTSquareButton{
	public var metadata:SongMetadata;
	public var isLocked = true;

	public var yellowBorder:FlxShapeBox;
	public var nameText:FlxText;
	public var scoreText:FlxText;

	public function new(Metadata, IsLocked)
	{
		metadata = Metadata;
		isLocked = IsLocked;

		super();

		loadGraphic(FreeplayState.songImage(metadata.songName));
		setGraphicSize(194, 194);
		updateHitbox();
	}

	public function updateHighscore()
	{
		scoreText.text = Std.string(Highscore.getScore(metadata.songName));
		scoreText.color = Highscore.getRating(metadata.songName) == 1 ? 0xFFFFFF00 : 0xFFFFFFFF;
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
	public var buttonArray:Array<FreeplaySongButton> = [];

	public function new(?X = 0, ?Y = 0, ?TitleText:FlxText)
	{
		super(X, Y);

		if (TitleText != null){
			titleText = TitleText;
			add(titleText);
		}		
	}

	public function addItem(item:FreeplaySongButton){
		if (item != null){
			buttonArray.push(item);
			orderShit();
		}	

		return super.add(item);
	}

	public function orderShit()
	{
		var num:Int = -1;

		for (item in buttonArray)
		{
			num++;
			var x = num % posArray.length;
			var y = Math.floor(num / 5);

			item.setPosition(posArray[x], 50 + titleText.y + titleText.height + y * 308);
		}
	}
}