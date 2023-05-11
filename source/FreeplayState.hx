package;

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
import sowy.TGTSquareButton;

using StringTools;
#if desktop
import Discord.DiscordClient;
#end
#if MODS_ALLOWED
import sys.FileSystem;
#end

//// a lot of the category code isn't needed so rewritting it would be good i think.
class FreeplayState extends MusicBeatState
{
	var songs:Array<SongMetadata> = [];

	private var categories:Map<String, FreeplayCategory> = [];
	private var categoryIDs:Array<String> = []; // "The order of both values and keys in any type of map is undefined"

	static var lastCamY:Float = 360;
	var camFollow = new FlxPoint(640, lastCamY);
	var camFollowPos = new FlxObject(640, lastCamY);

	var selectedSong:Null<SongMetadata> = null;
	var buttons:Array<FreeplaySongButton> = [];

	//// Keyboard shit
	var curCat:Int = 0;
	var curX:Int = 0;
	var curY:Int = 0;

	//
	var hintText:FlxText;

	function setCategory(id, name){
		var catTitle = new FlxText(0, 50, FlxG.width, name, 32, true);
		catTitle.setFormat(Paths.font("calibrib.ttf"), 32, 0xFFF4CC34, FlxTextAlign.CENTER, FlxTextBorderStyle.NONE);
		catTitle.underline = true;
		catTitle.scrollFactor.set(1, 1);
		
		var category = new FreeplayCategory(catTitle);
		categories.set(id, category);

		categoryIDs.push(id);
	}

	function resSelSongFunc(){
		selectedSong = null;
	};

	function setupButtonCallbacks(songButton:FreeplaySongButton)
	{
		if (songButton.isLocked)
			songButton.onUp.callback = songButton.shake;
		else{
			songButton.onOver.callback = ()->{
				selectedSong = songButton.metadata;
			};
			songButton.onOut.callback = resSelSongFunc;
		
			songButton.onUp.callback = function(){
				this.transOut = SquareTransitionSubstate;
				SquareTransitionSubstate.nextCamera = FlxG.camera;
				SquareTransitionSubstate.info = {
					sX: songButton.x - 3, sY: songButton.y - 3,
					sW: 200, sH: 200,

					eX: FlxG.camera.scroll.x - 3, eY: FlxG.camera.scroll.y - 3,
					eW: FlxG.width + 6, eH: FlxG.height + 6
				};

				persistentUpdate = false;

/* 				if (FlxG.keys.pressed.ALT){
					var alters = SongChartSelec.getAlters(songButton.metadata);
					if (alters.length > 0)
						switchTo(new SongChartSelec(songButton.metadata, alters));
				}else */
				playSong(songButton.metadata);
			};
		}			
	}

	function newSongButton(songName:String, ?categoryId:String):Null<FreeplaySongButton>
	{
		var songButton = addSong(songName, Paths.currentModDirectory, categoryId, false);
		if (songButton != null) setupButtonCallbacks(songButton);

		return songButton;
	}

	function loadFreeplayList(path:String)
	{
		for (i in CoolUtil.coolTextFile(path))
		{
			if (i == null || i.length < 1)
				continue;
			
			var song:Array<String> = i.split(":");
			newSongButton(song[0], song[1]);
		}
	}

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
		setCategory("main", "MAIN STORY");
		setCategory("side", "SIDE STORIES");
		setCategory("remix", "REMIXES / COVERS");

		//// Load the songs!!!
		loadFreeplayList(Paths.txt('freeplaySonglist'));
		loadFreeplayList(Paths.mods('global/data/freeplaySonglist.txt'));

		#if MODS_ALLOWED
		for (mod in Paths.getModDirectories())
		{
			Paths.currentModDirectory = mod;
			loadFreeplayList(Paths.mods('$mod/data/freeplaySonglist.txt'));

			#if (sys && PE_MOD_COMPATIBILITY)
			//// psych engine
			var weeksFolderPath = Paths.mods('$mod/weeks/');
			
			if (FileSystem.exists(weeksFolderPath) && FileSystem.isDirectory(weeksFolderPath))
			{	
				var addedCat = false;
				for (weekFileName in FileSystem.readDirectory(weeksFolderPath))
				{
					if (!weekFileName.endsWith(".json")) continue;

					var rawFile = Paths.getContent(weeksFolderPath + weekFileName);
					if (rawFile == null) continue;

					var theJson = haxe.Json.parse(rawFile);
					if (!Reflect.hasField(theJson, "songs")){trace("Songs unavailable"); continue;}

					var songs:Array<Array<Dynamic>> = theJson.songs;
					if (songs.length < 1){trace("No songs"); continue;}

					if (!addedCat){ 
						addedCat = true;
						setCategory(mod, mod);
					}

					var daDiffs = theJson.difficulties.split(",");
					var topDiff = daDiffs.length==0?null:daDiffs[0];
					if(daDiffs.length>1)topDiff = daDiffs[daDiffs.length-1].trim(); // play the top difficulty
						
					for (song in songs){
						var songButton = addSong(song[0], null, mod, false);
						setupButtonCallbacks(songButton);
						songButton.onUp.callback = function(){
							this.transOut = SquareTransitionSubstate;
							SquareTransitionSubstate.nextCamera = FlxG.camera;
							SquareTransitionSubstate.info = {
								sX: songButton.x - 3, sY: songButton.y - 3,
								sW: 200, sH: 200,

								eX: FlxG.camera.scroll.x - 3, eY: FlxG.camera.scroll.y - 3,
								eW: FlxG.width + 6, eH: FlxG.height + 6
							};

							persistentUpdate = false;

			/* 				if (FlxG.keys.pressed.ALT){
								var alters = SongChartSelec.getAlters(songButton.metadata);
								if (alters.length > 0)
									switchTo(new SongChartSelec(songButton.metadata, alters));
							}else */
							playSong(songButton.metadata, topDiff, daDiffs.length-1);
						};
/* 
						var icon = Paths.image('icons/${song[1]}');
						if (icon == null)
							icon = Paths.image('icons/icon-${song[1]}');


						
						if (icon != null){
							songButton.loadGraphic(icon);

							
							if (songButton.width > 194)
								songButton.setGraphicSize(194, 0);
							if (songButton.height > 194)
								songButton.setGraphicSize(0, 194);
							
							
							songButton.clipRect = new FlxRect(0, 0, songButton.frameHeight, songButton.frameHeight);
							songButton.updateHitbox();

							songButton.offset.set(
								-(194 - songButton.frameHeight) * 0.5,
								-(194 - songButton.frameHeight) * 0.5
							);
						}else if(icon == null) */

						// TODO ^ make this work
						// honestly probably just make a graphic and then stamp the icon onto it w/ healthicon n shit
						

						songButton.loadGraphic(Paths.image('songs/placeholder'));
						
					}
				}
			}
			#end
		}
		Paths.currentModDirectory = '';
		#end

		//// Add categories
		var lastCat:Null<FreeplayCategory> = null;
		for (id in categoryIDs)
		{
			var category = categories.get(id);

			if (lastCat == null)
				category.y = 50;
			else
				category.y = 50 + lastCat.y + lastCat.height;

			lastCat = category;
			add(category);
		}
		maxY = lastCat.y + lastCat.height;

		////
		var hintBg = new FlxSprite(0, FlxG.height-20).makeGraphic(1,1,0xFF000000);
		hintBg.scale.set(FlxG.width, 24);
		hintBg.updateHitbox();
		hintBg.scrollFactor.set();
		hintBg.antialiasing = false;
		hintBg.alpha = 0.6;
		add(hintBg);

		hintText = new FlxText(FlxG.width, FlxG.height - 20, 0, "Press CTRL to open the Gameplay Modifiers menu | Press R to reset a song's score.", 18);
		hintText.font = Paths.font("calibri.ttf");
		hintText.antialiasing = false;
		hintText.scrollFactor.set();
		add(hintText);

		////
		super.create();

		#if !FLX_NO_MOUSE
		FlxG.mouse.visible = true;
		#end
	}

	static public function playSong(metadata:SongMetadata, ?difficulty:String, ?difficultyIdx:Int=1){
		Paths.currentModDirectory = metadata.folder;

		var songLowercase:String = Paths.formatToSongPath(metadata.songName);
		trace('${Paths.currentModDirectory}, $songLowercase');

		PlayState.SONG = Song.loadFromJson(
			'$songLowercase${difficulty == null ? "" : '-$difficulty'}', 
			songLowercase
		);
		PlayState.difficulty = difficultyIdx;
		PlayState.isStoryMode = false;

		if (FlxG.keys.pressed.SHIFT){
			PlayState.chartingMode = true;
			LoadingState.loadAndSwitchState(new ChartingState());
		}else
			LoadingState.loadAndSwitchState(new PlayState());

		if (FlxG.sound.music != null)
			FlxG.sound.music.volume = 0;
	} 

	override function closeSubState() 
	{
		//changeSelection(0, false);
		for (button in buttons)
			button.updateHighscore();

		super.closeSubState();
	}

	public function addSong(songName:String, ?folder:String, ?categoryName:String, ?isLocked = false):Null<FreeplaySongButton>
	{
		var folder = folder != null ? folder : Paths.currentModDirectory;
		var category = categories.get(categoryName);

		// trace('"$folder" / "$songName" / "$categoryName"');

		if (category == null){
			setCategory(categoryName, categoryName);
			category = categories.get(categoryName);
			//return null;
		}

		var button:FreeplaySongButton = new FreeplaySongButton(
			new SongMetadata(songName, folder),
			isLocked
		);
		category.addItem(button);

		////
		button.yellowBorder = new FlxShapeBox(button.x - 3, button.y - 3, 200, 200, {thickness: 6, color: 0xFFF4CC34}, FlxColor.TRANSPARENT);

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
	
	var minY:Float = 360;
	var maxY:Float = 0;
	override function update(elapsed:Float)
	{
		hintText.x -= 64 * elapsed;
		if (hintText.x < (FlxG.camera.scroll.x - hintText.width))
			hintText.x = FlxG.camera.scroll.x + FlxG.width;

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

		var yuh = elapsed / (1/60);
		if (controls.UI_UP || FlxG.keys.pressed.PAGEUP){
			camFollow.y -= 25*yuh;
		}
		if (controls.UI_DOWN || FlxG.keys.pressed.PAGEDOWN){
			camFollow.y += 25*yuh;
		}

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
		lastCamY = camFollowPos.y;
		super.destroy();
	}

	public inline static function songImage(SongName:String){
		var img = Paths.image("songs/" + Paths.formatToSongPath(SongName));
		if(img==null)
			img = Paths.image("songs/placeholder");

		return img;
	}
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
		var ratingPercent = Highscore.getRating(metadata.songName);
		scoreText.text = Highscore.floorDecimal(ratingPercent * 100, 2) + '%';
		scoreText.color = ratingPercent == 1 ? 0xFFF4CC34 : 0xFFFFFFFF;
	}

	override function onover()
	{
		if (!isLocked)
			super.onover();
	}
}

class FreeplayCategory extends flixel.group.FlxSpriteGroup{
	static var posArray = [51, 305, 542, 788, 1034]; // Fuck it
	
	public var buttonArray:Array<FreeplaySongButton> = [];
	public var positionArray:Array<Array<FreeplaySongButton>> = [];

	var titleText:FlxText;

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
			var y = Math.floor(num / posArray.length);

			if (positionArray[x] == null)
				positionArray[x] = [];
			positionArray[x][y] = item;

			item.setPosition(posArray[x], 50 + titleText.y + titleText.height + y * 308);
		}
	}
}

/// ouhghhh just a little experiment
class SongChartSelec extends MusicBeatState
{
	var songMeta:SongMetadata;
	var alters:Array<String>;

	var texts:Array<FlxText> = [];

	var curSel = 0;

	function changeSel(diff:Int = 0)
	{
		texts[curSel].color = 0xFFFFFFFF;

		curSel += diff;
		
		if (curSel < 0)
			curSel += alters.length;
		else if (curSel >= alters.length)
			curSel -= alters.length;

		texts[curSel].color = 0xFFFFFF00;
	}

	override function create()
	{
		for (id in 0...alters.length){
			var alt = alters[id];
			var text = new FlxText(20, 20 + id * 20 , FlxG.width - 20, alt, 16);

			texts[id] = text;

			add(text);
		}

		changeSel();
	}

	override public function update(e){
		if (controls.UI_DOWN_P)
			changeSel(1);
		if (controls.UI_UP_P)
			changeSel(-1);

		if (controls.BACK)
			MusicBeatState.switchState(new FreeplayState());

		if (controls.ACCEPT){
			var daDiff = alters[curSel];
			FreeplayState.playSong(songMeta, daDiff == "normal" ? null : daDiff);
		}

		super.update(e);
	} 

	public function new(WHO:SongMetadata, alters) 
	{
		super();
		
		songMeta = WHO;
		this.alters = alters;
	}

	public static function getAlters(metadata:SongMetadata) // dumb name
	{
		Paths.currentModDirectory = metadata.folder;

		var songName = Paths.formatToSongPath(metadata.songName);
		var folder = Paths.mods('${Paths.currentModDirectory}/songs/$songName/');

		var alts = [];

		Paths.iterateDirectory(folder, function(fileName){
			if (fileName == '$songName.json'){
				alts.insert(1, "normal");
				return;		
			}
			
			if (!fileName.startsWith('$songName-') || !fileName.endsWith('.json'))
				return;

			var prefixLength = songName.length + 1;
			alts.push(fileName.substr(prefixLength, fileName.length - prefixLength - 5));
		});

		return alts;
	} 
}