package gallery;

import openfl.text.TextFormat;
import flixel.group.FlxSpriteGroup;
import flixel.group.FlxGroup;
import haxe.io.Path;
import flixel.*;
import flixel.math.*;
import flixel.text.FlxText;
import sowy.*;

typedef ChapterData = {
	var pages:Array<PageData>;

	var ?directory:String;

	var ?prevChapter:ChapterData;
	var ?nextChapter:ChapterData;
}
typedef PageData = {
	var chapter:ChapterData;
	var name:String;

	var ?prevPage:PageData;
	var ?nextPage:PageData;
};

class ComicsMenuState extends MusicBeatState
{
	public var data:Array<ChapterData> = [];

	private var textOptionArray = [];

	override public function create()
	{
		//// GET THE CUTSCENES
		var lastChapter:ChapterData = null;
		var lastPage:PageData = null;
		
		#if MODS_ALLOWED
		for (modDir in Paths.getModDirectories())
		{
			var rawList = Paths.getContent(Paths.mods(modDir + "/data/freeplaySonglist.txt"));
			if (rawList == null) continue;

			var pages:Array<PageData> = [];

			var daChapter = {pages: pages, directory: modDir, prevChapter: lastChapter};
			data.push(daChapter);

			if (lastChapter != null)
				lastChapter.nextChapter = daChapter;
			
			lastChapter = daChapter;

			////
			for (line in CoolUtil.listFromString(rawList)){
				var shid = line.split(":");
				
				// TODO
				var category = shid[1]; 
				if (category != "main")
					continue;

				var name = shid[0];
				var formattedName = Paths.formatToSongPath(name);

				var daComicPath = Paths.mods('$modDir/images/cutscenes');
				var num = 0;

				while (true){
					var name = '$formattedName-${num+1}';
					if (Paths.exists('$daComicPath/${name}.png')){
						var newPage = {name: name, chapter: daChapter, prevPage: lastPage};

						if (lastPage != null)
							lastPage.nextPage = newPage;
						lastPage = newPage;

						pages.push(newPage);
						num++;
					}else
						break;
				}
			}
		}
		#end

		/*
		for (sowy in data){
			for (page in sowy.pages){
				trace(sowy.directory, page.name);
			}
		}
		*/

		super.create();

		MusicBeatState.switchState(new ComicReader(data[0].pages[0]));
	}

	override public function update(e)
	{
		if (controls.BACK) MusicBeatState.switchState(new GalleryMenuState());
		super.update(e);
	}
}

// haha vs /v/

class ComicReader extends MusicBeatState
{
	var camBackground = new FlxCamera();
	var camComic = new FlxCamera();

	var camFollow = new FlxPoint(); // goal position
	var camFollowPos = new FlxObject(); // displayed position

	var zoom:Float = 1;

	var curPanel:FlxSprite;
	static var pageData:PageData;
	static var panelNumber:Int = 0;

	public function new(?Page:PageData)
	{
		super();

		if (Page != null)
			pageData = Page;
	}

	override function add(Object:FlxBasic)
	{
		if (Std.isOfType(Object, FlxSprite))
			cast(Object, FlxSprite).antialiasing = ClientPrefs.globalAntialiasing;

		return super.add(Object);
	}

	override function create()
	{
		#if !FLX_NO_MOUSE
		FlxG.mouse.visible = true;
		#end

		//
		camComic.bgColor = 0x00000000;

		FlxG.cameras.reset();
		FlxG.cameras.add(camBackground, false);
		FlxG.cameras.add(camComic, true);

		camComic.antialiasing = ClientPrefs.globalAntialiasing;
		camComic.follow(camFollowPos, LOCKON, 1);

		//
		var bg = new FlxSprite().loadGraphic(Paths.image("menuBGDesat"));
		bg.color = 0xFF001010;
		bg.cameras = [camBackground];
		bg.scrollFactor.set();
		bg.screenCenter();
		add(bg);

		//
		//trace('loaded page: ${pageData.name}\n${pageData.prevPage == null ? 'no': 'has'} prev page\n${pageData.nextPage == null ? 'no': 'has'} next page');

		Paths.currentModDirectory = pageData.chapter.directory;
		loadPanel(pageData.name);

		//
		var tail = curPanel.y + curPanel.height + 24;	

		var listPage = new SowyTextButton(curPanel.getMidpoint().x, tail, 0, "Page List", 18);
		listPage.label.font = Paths.font("consola.ttf");
		listPage.label.underline = true;
		listPage.x -= listPage.frameWidth * 0.5;
		listPage.scrollFactor.set(1, 1);
		add(listPage);

		if (pageData.prevPage != null){
			var prevPage = new SowyTextButton(0, tail, 0, "← Page", 18, function(){
				pageData = pageData.prevPage;
				MusicBeatState.resetState();
			});
			prevPage.label.font = Paths.font("consola.ttf");
			prevPage.label.underline = true;

			prevPage.x = curPanel.x + 18;

			prevPage.scrollFactor.set(1, 1);
			add(prevPage);
		}

		if (pageData.nextPage != null){
			var nextPage = new SowyTextButton(0, tail, 0, "Page →", 18, function(){
				pageData = pageData.nextPage;
				MusicBeatState.resetState();
			});
			nextPage.label.font = Paths.font("consola.ttf");
			nextPage.label.underline = true;

			nextPage.x = curPanel.x + curPanel.width - nextPage.width - 18;

			nextPage.scrollFactor.set(1, 1);
			add(nextPage);
		}

		super.create();
	}

	// Camera limits
	var minX:Float = 0;
	var maxX:Float = 0;
	var minY:Float = 0;
	var maxY:Float = 0;

	function loadPanel(path:String)
	{
		if (curPanel != null)
			remove(curPanel).destroy();

		curPanel = new FlxSprite().loadGraphic(Paths.image('cutscenes/$path'));
		curPanel.cameras = [camComic];

		var scrWidth = FlxG.width;
		var scrHeight = FlxG.height;

		var fuu = Math.min(scrWidth, scrHeight);
		fuu = (curPanel.width > fuu) ? (fuu / curPanel.width) : 1;
		
		curPanel.scale.set(fuu, fuu);
		curPanel.updateHitbox();

		curPanel.x -= curPanel.width* 0.5;
		add(curPanel);

		minX = curPanel.x;
		maxX = curPanel.x + curPanel.width;
		minY = curPanel.y - scrHeight / 8;
		maxY = curPanel.y + curPanel.height + scrHeight / 8;
		
		var mid = curPanel.getMidpoint();
		camFollow.set(mid.x, curPanel.height > FlxG.height ? 0 : mid.y);
	}

	var baseSpeed = 8;

	override function update(elapsed:Float)
	{
		var justPressed = FlxG.keys.justPressed;
		var pressed = FlxG.keys.pressed;

		if (controls.BACK) MusicBeatState.switchState(new GalleryMenuState());

		//
		var speed = pressed.SHIFT ? baseSpeed * 2 : baseSpeed;

		var mouseWheel = FlxG.mouse.wheel;
		var yScroll:Float = 0;

		if (justPressed.R){
			zoom = 1;
			camFollow.x = curPanel.getMidpoint().x;
		}

		if (justPressed.C)
			zoom -= .1;
		if (justPressed.V)
			zoom += .1;

		if (pressed.CONTROL)
			zoom += mouseWheel * 0.1;
		else
			yScroll -= mouseWheel * speed * 8;

		if (pressed.UP || pressed.W)
			camFollow.y -= speed;
		if (pressed.DOWN || pressed.S)
			camFollow.y += speed;

		if (pressed.LEFT || pressed.A)
			camFollow.x = Math.max(minX, camFollow.x - speed);
		if (pressed.RIGHT || pressed.D)
			camFollow.x = Math.min(maxX, camFollow.x + speed);
		
		camFollow.y = Math.max(minY, Math.min(camFollow.y + yScroll, maxY));

		zoom = Math.max(0.25, Math.min(zoom, 5));

		// update camera
		var lerpVal = Math.min(1, elapsed * 6);
		camFollowPos.setPosition(FlxMath.lerp(camFollowPos.x, camFollow.x, lerpVal), FlxMath.lerp(camFollowPos.y, camFollow.y, lerpVal));
		camComic.zoom = FlxMath.lerp(camComic.zoom, zoom, lerpVal);
		
		//	Causes some rendering glitches with the fade transition?
		//	camComic.pixelPerfectRender = subState == null && camComic.zoom == 1;

		super.update(elapsed);
	}
}