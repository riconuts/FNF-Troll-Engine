package tgt;

import Song;
import Paths;
import haxe.Json;
import editors.ChartingState;
import flixel.*;
import flixel.math.*;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.addons.display.shapes.FlxShapeBox;
import tgt.TGTSquareButton;
import SongSelectState.SongChartSelec;

using StringTools;
#if discord_rpc
import Discord.DiscordClient;
#end
#if MODS_ALLOWED
import sys.FileSystem;
#end

class FreeplayState extends MusicBeatState
{
	var songs:Array<SongMetadata> = [];

	private var categories:Map<String, FreeplayCategory> = [];
	private var categoryIDs:Array<String> = []; // "The order of both values and keys in any type of map is undefined"

	static var lastCamY:Float = 360;
	var camFollow = new FlxPoint(FlxG.width * 0.5, lastCamY);
	var camFollowPos = new FlxObject(FlxG.width * 0.5, lastCamY);

	var selectedSong:Null<SongMetadata> = null;
	var buttons:Array<FreeplaySongButton> = [];

	//// Keyboard shit
	var curCat:Int = 0;
	var curX:Int = 0;
	var curY:Int = 0;

	//
	var hintText:FlxText;

	function setCategory(id, name){
		var catTitle = new FlxText(0, 50, 0, name, 32, true);
		catTitle.setFormat(Paths.font("calibrib.ttf"), 32, 0xFFF4CC34, FlxTextAlign.CENTER, FlxTextBorderStyle.NONE);
		catTitle.underline = true;
		catTitle.scrollFactor.set();
		catTitle.screenCenter(X);
		
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

                
				var charts = SongChartSelec.getCharts(songButton.metadata);

				if (FlxG.keys.pressed.ALT && charts.length > 0){
					FlxG.switchState(new SongChartSelec(songButton.metadata, charts)); // we should make this better and add a proper chart selector
                    // maybe I'll concept up that if you dont wanna do that
					// Go ahead, I didn't want to make one cause it wouldn't get used since the TGT doesn't have alt difficulties :p
				}else{
					var diffIdx:Null<Int> = null;
					
					if ((diffIdx=charts.indexOf("hard")) != -1){}
					else if ((diffIdx=charts.indexOf("normal")) != -1){}
					else if (charts.length > 0) diffIdx = charts.length-1;
					
					playSong(songButton.metadata, charts[diffIdx], diffIdx);
				}
			};
		}			
	}

	function newSongButton(songName:String, ?categoryId:String, ?displayName:String):Null<FreeplaySongButton>
	{
		var songButton = addSong(songName, Paths.currentModDirectory, categoryId, false, displayName);
		if (songButton != null) setupButtonCallbacks(songButton);

		return songButton;
	}

	function loadFreeplayList(songs:Array<FreeplaySongMetadata>, defaultCategory:String = 'uncategorized')
	{
		for (song in songs)
			newSongButton(song.name, song.category == null ? defaultCategory : song.category, song.displayName);	
		return [for(song in songs)song.name];
	}

	function loadTxtFreeplayList(path:String)
	{
		var added:Array<String> = [];
		for (i in CoolUtil.coolTextFile(path))
		{
			if (i == null || i.length < 1)
				continue;
			
			var song:Array<String> = i.split(":");
			added.push(song[0]);
			newSongButton(song[0], song[1]);
		}
		return added;
	}

	override function create()
	{
		#if discord_rpc
		// Updating Discord Rich Presence
		DiscordClient.changePresence("In the Menus", null);
		#end

		persistentUpdate = false;
		
		Paths.clearStoredMemory();
		
		PlayState.isStoryMode = false;

		FlxG.camera.follow(camFollowPos);
		FlxG.camera.bgColor = FlxColor.BLACK;

		////
		var buttonSize = 194;
		var spacing = 50;
		var bSpace = buttonSize + spacing;

		var buttons = Math.floor(FlxG.width / bSpace);
		var baseX = (FlxG.width - (bSpace * buttons - spacing)) * 0.5;

		FreeplayCategory.posArray = [
			for (i in 0...buttons){
				baseX + bSpace * i;
			}
		];

		////
		setCategory("main", "MAIN STORY");
		setCategory("side", "SIDE STORIES");
		setCategory("remix", "REMIXES / COVERS");

		//// Load the songs!!!
		loadTxtFreeplayList(Paths.txt('freeplaySonglist'));

		#if MODS_ALLOWED
		loadTxtFreeplayList(Paths.mods('global/data/freeplaySonglist.txt'));

		for (mod in Paths.getModDirectories())
		{
			Paths.currentModDirectory = mod;
			var path = Paths.mods(mod + "/metadata.json");
			var rawJson:Null<String> = Paths.getContent(path);

			var songsAdded:Array<String> = [];

			var defaultCategory:String = '';
			if (rawJson != null && rawJson.length > 0)
			{

				// TODO: make it add the chapter songs automatically, too
				var daJson:Dynamic = Json.parse(rawJson);
				if (Reflect.field(daJson, "freeplayCategories") != null || Reflect.field(daJson, "freeplaySongs") != null)
				{
					var json:ContentMetadata = cast daJson;
					defaultCategory = json.defaultCategory == null ? "" : json.defaultCategory.trim();
					if (json.freeplayCategories != null && json.freeplayCategories.length > 0){
						for (cat in json.freeplayCategories)
							setCategory(cat.id, cat.name);
					}
					if (json.freeplaySongs != null && json.freeplaySongs.length > 0)
					{
						for (song in loadFreeplayList(json.freeplaySongs, defaultCategory))
							songsAdded.push(song.toLowerCase().replace(" ","-"));
					}
					if (json.chapters != null && json.chapters.length > 0)
					{
						for (chapter in json.chapters){
							var category = chapter.freeplayCategory==null ? chapter.category : chapter.freeplayCategory;
							for (song in chapter.songs){
								if (!songsAdded.contains(song.toLowerCase().replace(" ", "-"))){
									newSongButton(song, category);
									songsAdded.push(song.toLowerCase().replace(" ", "-"));
								}
							}
						}

					}
				}
			}

			for (song in  loadTxtFreeplayList(Paths.mods('$mod/data/freeplaySonglist.txt')))
				songsAdded.push(song.toLowerCase().replace(" ", "-"));

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

					
					for (song in songs){
						var disp:String = cast song[0];
						disp = disp.trim().replace("-", " ");
						var capitlizationizering = disp.split(" ");
						var displayName:String = '';
						for (word in capitlizationizering){
							displayName += ' ${word.substr(0,1).toUpperCase()}${word.substring(1)}';
						}
						songsAdded.push(disp.toLowerCase());
						var songButton = addSong(song[0], null, mod, false, displayName);
						setupButtonCallbacks(songButton);

						var daDiffs:Array<String> = theJson.difficulties == null ? [] : theJson.difficulties.split(",");					
						if (daDiffs.length == 0 || daDiffs[0].trim() == '')
							daDiffs = ["Easy", "Normal", "Hard"];

						var topDiff:Null<String> = null;
						var diffIdx = 1;
						while (daDiffs.length>0)
						{
							var diff = daDiffs.pop().trim();
							#if PE_MOD_COMPATIBILITY
							var input = diff == 'Normal' ? '' : '-$diff';
							#else
							var input = diff.toLowerCase() == 'normal' ? '' : '-$diff';
							#end
							var json = '${song[0]}${input}';
							var rawPath = Paths.formatToSongPath(song[0]) + '/' + Paths.formatToSongPath(json);

							var path = Paths.modsSongJson(rawPath);

							if (!Paths.exists(path))
								path = Paths.modsJson(rawPath);

							if(Paths.exists(path)){
								topDiff = diff;
								diffIdx = daDiffs.length;
								break;
							}
						}
						if (topDiff.trim() == 'normal')
							topDiff=null;

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

							playSong(songButton.metadata, topDiff, diffIdx);
						};

						var icum = new HealthIcon(song[1]);
						icum.scale.set(0.5, 0.5);
						icum.updateHitbox();


						var colours:FlxSprite = new FlxSprite(songButton.x, songButton.y).loadGraphic(Paths.image('songs/psychModIcon'), false, 0, 0, true);
						colours.color = FlxColor.fromRGB(song[2][0],song[2][1],song[2][2]); //FlxColor.fromInt(CoolUtil.dominantColor(icum));
						songButton.makeGraphic(colours.frameWidth, colours.frameHeight, FlxColor.WHITE, true);
        				songButton.stamp(colours, 0, 0);
						songButton.stamp(
							icum, 
							-Std.int((icum.frameWidth - icum.width)/2) + Std.int((songButton.width / 2) - (icum.width / 2)),
							-Std.int((icum.frameHeight - icum.height)/2) + Std.int((songButton.height / 2) - (icum.height / 2))
						);
						songButton.setGraphicSize(194, 194);
						songButton.updateHitbox();
					}
				}
			}
			#end


			if (defaultCategory.length > 0){
				var dir = Paths.mods(mod + "/songs");
				Paths.iterateDirectory(dir, function(file:String){
					if (FileSystem.isDirectory(haxe.io.Path.join([dir, file])) && !songsAdded.contains(file.toLowerCase().replace(" ", "-"))){
						file = file.trim().replace("-", " ");
						var capitlizationizering = file.split(" ");
						var displayName:String = '';
						for (word in capitlizationizering)
							displayName += ' ${word.substr(0, 1).toUpperCase()}${word.substring(1)}';
						
						newSongButton(file, defaultCategory, displayName);
					}
					

				});
			}
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

		hintText = new FlxText(FlxG.width, FlxG.height - 20, 0, Paths.getString("freeplayhint"), 18);
		hintText.font = Paths.font("calibri.ttf");
		hintText.antialiasing = false;
		hintText.scrollFactor.set();
		add(hintText);

		////
		super.create();

		////
		#if !FLX_NO_MOUSE
		FlxG.mouse.visible = true;
		#end
	}

	static public function playSong(metadata:SongMetadata, ?difficulty:String, ?difficultyIdx:Int=1){
		return Song.playSong(metadata, difficulty, difficultyIdx);
	} 

	override function closeSubState() 
	{
		//changeSelection(0, false);
		for (button in buttons)
			button.updateHighscore();

        if((subState is GameplayChangersSubstate))
			Highscore.loadData();
        
		super.closeSubState();
	}

	public function addSong(songName:String, ?folder:String, ?categoryName:String, ?isLocked = false, ?displayName:String):Null<FreeplaySongButton>
	{
		var folder = folder != null ? folder : Paths.currentModDirectory;
		var category = categories.get(categoryName);

		// trace('"$folder" / "$songName" / "$categoryName"');

		if (category == null){
			setCategory(categoryName, categoryName);
			category = categories.get(categoryName);
			//return null;
		}
		else if (category.songsInCategory.contains(songName))
			return null;

		
		

		var button:FreeplaySongButton = new FreeplaySongButton(
			new SongMetadata(songName, folder),
			isLocked
		);
		category.addItem(button);

		////
		button.yellowBorder = new FlxShapeBox(button.x - 3, button.y - 3, 200, 200, {thickness: 6, color: 0xFFF4CC34}, FlxColor.TRANSPARENT);

		button.nameText = new FlxText(button.x, button.y - 32, button.width, displayName == null ? songName : displayName, 24);
		button.nameText.setFormat(Paths.font("calibri.ttf"), 18, FlxColor.WHITE, FlxTextAlign.CENTER, FlxTextBorderStyle.NONE);

		button.scoreText = new FlxText(button.x, button.y + button.height + 12, button.width, "", 24);
		button.scoreText.setFormat(Paths.font("calibri.ttf"), 18, FlxColor.WHITE, FlxTextAlign.CENTER, FlxTextBorderStyle.NONE);

        button.medal = new FlxSprite(button.x, button.y);
        button.medal.loadGraphic(Paths.image("medals/medal_fc"));
        button.medal.updateHitbox();
        button.medal.x -= button.medal.width/2;
        button.medal.y -= button.medal.height/2;
        button.medal.y += 15;
        button.medal.x += 5;
		button.medal.visible = false;

		category.add(button.yellowBorder);
		category.add(button.nameText);
		category.add(button.scoreText);
		category.add(button.medal);
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

		var targetVolume:Float =  0.7;
		if (FlxG.sound.music != null && FlxG.sound.music.volume < targetVolume)
			FlxG.sound.music.volume += 0.5 * FlxG.elapsed;

		if (FlxG.sound.music.volume > targetVolume)
			FlxG.sound.music.volume = targetVolume;

		if (FlxG.keys.pressed.CONTROL)
		{
			openSubState(new GameplayChangersSubstate());
		}
		else if (selectedSong != null)
		{
			if (FlxG.keys.justPressed.R || FlxG.keys.justPressed.DELETE){
				Paths.currentModDirectory = selectedSong.folder;
				openSubState(new ResetScoreSubState(selectedSong.songName, false));
			}else if (FlxG.keys.justPressed.TAB){
				var song = selectedSong.songName;
				var scr = Highscore.getScore(song);
				var rat = Highscore.floorDecimal(Highscore.getRating(song) * 100, 2);

				trace('SONG: $song	| RATING: $rat%	| HI-SCORE: $scr');
			}
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

class FreeplaySongButton extends TGTSquareButton{
	public var metadata:SongMetadata;
	public var isLocked = true;

	public var yellowBorder:FlxShapeBox;
	public var nameText:FlxText;
	public var scoreText:FlxText;
    public var medal:FlxSprite;

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
        var record = Highscore.getRecord(metadata.songName);

		var ratingPercent = Highscore.getRatingRecord(record);
		scoreText.text = Highscore.floorDecimal(ratingPercent * 100, 2) + '%';
		scoreText.color = (Highscore.isWife3 ? ratingPercent >= 0.93 : ratingPercent == 1) ? 0xFFF4CC34 : Highscore.isValidScoreRecord(record) ? 0xFFFFFFFF : 0xFF8B8B8B;
        
        if(!Highscore.isWife3 && record.fcMedal != null && record.fcMedal != NONE){
            medal.visible = true;
            var medalArray:Array<String> = [
                "medal_fc",
                "medal_fc",
                "medal_gfc",
                "medal_sfc",
                "medal_efc"
            ];

			medal.loadGraphic(Paths.image("medals/" + medalArray[record.fcMedal]));
        }
        else if(Highscore.isWife3 && ratingPercent >= 0.93){
            medal.visible = true;
            var medalShid:Array<Array<Dynamic>> = [
                ["medal_aaaaa", 0.999935],
                ["medal_aaaa", 0.999],
                ["medal_aaa", 0.99],
                ["medal_aa", 0.93]
            ];
            for (data in medalShid){
                if (ratingPercent >= data[1]){
                    medal.loadGraphic(Paths.image("medals/" + data[0]));
                    break;
                }
            }
        }else
            medal.visible = false; 

        if(medal.visible){
            medal.x = x;
            medal.y = y;
            medal.updateHitbox();
            medal.x -= medal.width / 2;
            medal.y -= medal.height / 2;
            medal.y += 15;
            medal.x += 5;
        }
    }

	override function onover()
	{
		if (!isLocked)
			super.onover();
	}
}

class FreeplayCategory extends flixel.group.FlxSpriteGroup{
	public static var posArray:Array<Float> = [51, 305, 542, 788, 1034]; // Fuck it
	
	public var songsInCategory:Array<String> = [];
	public var buttonArray:Array<FreeplaySongButton> = [];
	public var positionArray:Array<Array<FreeplaySongButton>> = [];

	public var titleText:FlxText;

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
			songsInCategory.push(item.metadata.songName);
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