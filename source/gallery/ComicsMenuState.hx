package gallery;

import openfl.text.TextFormat;
import flixel.group.FlxSpriteGroup;
import flixel.group.FlxGroup;
import haxe.io.Path;
import flixel.*;
import flixel.math.*;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import sowy.*;

typedef ChapterData = {
	var pages:Array<PageData>;

	var ?directory:String;

	var ?prevChapter:ChapterData;
	var ?nextChapter:ChapterData;
}
typedef PageData = {
	/**
		ChapterData to which this page belongs to. 
	**/
	var chapter:ChapterData;
	var name:String;

	var ?prevPage:PageData;
	var ?nextPage:PageData;
};

class ComicsMenuState extends MusicBeatState
{
	static var data:Null<Array<ChapterData>> = null;
	static var curChapter:Int = 0;

	var options = [];
	var curSelected:Int = 0;

	static function loadData()
	{	
		var lastChapter:ChapterData = null;
		var lastPage:PageData = null;

		data = [];

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
	}

	inline static function cleanupData()
	{
		data = null;
	}

	var doingTransition:Bool = false;
	override public function create()
	{
		#if !FLX_NO_MOUSE
		FlxG.mouse.visible = true;
		#end

		persistentUpdate = true;

		var bg = new flixel.addons.display.FlxBackdrop();
		bg.frames = Paths.getSparrowAtlas("jukebox/space");
		bg.animation.addByPrefix("space", "space", 50, true);
		bg.animation.play("space");
		bg.screenCenter();
		add(bg);
		
		if (FlxG.width > FlxG.height)
			add(new FlxSprite().makeGraphic(FlxG.height, FlxG.height, 0xFF000000).screenCenter(X));
		else
			add(new FlxSprite().makeGraphic(FlxG.width, FlxG.width, 0xFF000000).screenCenter(Y));

		//// GET THE CUTSCENES
		if (data == null)
			loadData();

		var curData:ChapterData = data[curChapter];
		var curPages:Array<PageData> = curData.pages;

		var chapterNameTxt = new FlxText(0, 5, 0, "CHAPTER NAME GOES HERE", 18);
		chapterNameTxt.font = Paths.font("consola.ttf");
		chapterNameTxt.screenCenter(X);
		add(chapterNameTxt);

		var coverArt = new FlxSprite(0, chapterNameTxt.y + chapterNameTxt.height+ 24, ChapterMenuState.getChapterCover(curData.directory));
		coverArt.screenCenter(X);
		add(coverArt);

		var tail = coverArt.y + coverArt.height + 20;

		for (idx in 0...curPages.length){
			var page:PageData = curData.pages[idx];
			
			////
			var pageTxt = new sowy.TGTTextButton(
				0, 
				tail + 24*idx, 
				0, 
				page.name, 
				18, 
				function()
				{
					if (doingTransition) return;
					doingTransition = true;
					MusicBeatState.switchState(new ComicReader(page));
				}
			);
			pageTxt.scrollFactor.set(1, 1);
			pageTxt.label.font = Paths.font("consola.ttf");
			pageTxt.label.underline = true;
			pageTxt.screenCenter(X);
			add(pageTxt);

			options.push(pageTxt);
		}

		super.create();

		var cornerLeftText = new sowy.TGTTextButton(15, 720, 0, "← BACK", 32, goBack);
		cornerLeftText.label.setFormat(Paths.font("calibri.ttf"), 32, FlxColor.YELLOW, FlxTextAlign.RIGHT, FlxTextBorderStyle.NONE, FlxColor.YELLOW);
		cornerLeftText.y -= cornerLeftText.height + 15;
		add(cornerLeftText);
	}

	function goBack(){
		if (doingTransition) return;
		doingTransition = true;

		cleanupData();
		FlxG.sound.play(Paths.sound('cancelMenu'));
		MusicBeatState.switchState(new GalleryMenuState());
	}

	override public function update(e)
	{
		if (controls.BACK) goBack();
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
		var head = curPanel.y - 24 - 18;
		var tail = curPanel.y + curPanel.height + 24;	

		var listPage = new TGTTextButton(curPanel.getMidpoint().x, head, 0, "Page List", 18);
		listPage.label.font = Paths.font("consola.ttf");
		listPage.label.underline = true;
		listPage.x -= listPage.frameWidth * 0.5;
		listPage.y -= 18;
		listPage.scrollFactor.set(1, 1);
		add(listPage);

		var listPage = new TGTTextButton(curPanel.getMidpoint().x, tail, 0, "Page List", 18);
		listPage.label.font = Paths.font("consola.ttf");
		listPage.label.underline = true;
		listPage.x -= listPage.frameWidth * 0.5;
		listPage.scrollFactor.set(1, 1);
		add(listPage);

		if (pageData.prevPage != null){
			function goPrevPage(){
				pageData = pageData.prevPage;
				MusicBeatState.resetState();
			}

			var prevPage = new TGTTextButton(curPanel.x + 18, head, 0, "← Page", 18, goPrevPage);
			prevPage.label.font = Paths.font("consola.ttf");
			prevPage.label.underline = true;
			prevPage.scrollFactor.set(1, 1);
			prevPage.y -= 18;
			add(prevPage);

			var prevPage = new TGTTextButton(prevPage.x, tail, 0, "← Page", 18, goPrevPage);
			prevPage.label.font = Paths.font("consola.ttf");
			prevPage.label.underline = true;
			prevPage.scrollFactor.set(1, 1);
			add(prevPage);
		}

		if (pageData.nextPage != null){
			function goNextPage(){
				pageData = pageData.nextPage;
				MusicBeatState.resetState();
			}

			var nextPage = new TGTTextButton(0, head, 0, "Page →", 18, goNextPage);
			nextPage.label.font = Paths.font("consola.ttf");
			nextPage.label.underline = true;
			nextPage.scrollFactor.set(1, 1);
			nextPage.x = curPanel.x + curPanel.width - nextPage.width - 18;
			nextPage.y -= 18;
			add(nextPage);

			nextPage = new TGTTextButton(nextPage.x, tail, 0, "Page →", 18, goNextPage);
			nextPage.label.font = Paths.font("consola.ttf");
			nextPage.label.underline = true;
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

		if (controls.BACK) MusicBeatState.switchState(new ComicsMenuState());

		//
		var speed:Float = (pressed.SHIFT ? baseSpeed * 2 : baseSpeed);

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

		speed *= elapsed / (1/60);

		if (pressed.UP || pressed.W || pressed.PAGEUP)
			camFollow.y -= speed;
		if (pressed.DOWN || pressed.S || pressed.PAGEDOWN)
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