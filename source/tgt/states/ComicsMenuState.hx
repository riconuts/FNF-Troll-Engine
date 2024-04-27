package tgt.gallery;

import tgt.*;
import openfl.filters.ShaderFilter;
import flixel.addons.transition.FlxTransitionableState;
import openfl.ui.Mouse;
import openfl.ui.MouseCursor;
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
	var ?name:String;
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
	
	/**
		Displayed name of this page.
	**/
	var visualName:String;

	/**
		Name of the image file that belongs to this page
	**/
	var name:String;

	var ?prevPage:PageData;
	var ?nextPage:PageData;
};

class Tails extends FlxSprite{
	var isAlt:Bool = false;

	public function new(?x, ?y, ?isAlt:Bool){
		if (isAlt != null)
			this.isAlt = isAlt;
		else
			this.isAlt = FlxG.random.bool();
	
		super(x, y, Paths.image(this.isAlt ? "tailsalt" : "tails"));
	}

	var isOverlapping = false;

	override public function update(e) {
		if (FlxG.mouse.overlaps(this) != isOverlapping)
		{
			isOverlapping = !isOverlapping;

			if (isAlt)
				loadGraphic(Paths.image(isOverlapping ? "tails" : "tailsalt"));
			else
				loadGraphic(Paths.image(isOverlapping ? "tailsalt" : "tails"));
		}
		
		super.update(e);
	}
}

class ComicsMenuState extends MusicBeatState
{
	public static var seenBefore:Array<String> = [];
	
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
		// lol im running out of names
		for (mod in std.ChapterData.reloadChapterFiles())
		{
			var modDir = mod.directory;
			var rawList = Paths.getContent(Paths.mods(modDir + "/data/freeplaySonglist.txt"));
			if (rawList == null) continue;

			var daChapter = {
				directory: modDir,
				
				name: mod.name,
				pages: null, 
				 
				prevChapter: lastChapter
			};

			////

			var pages:Array<PageData> = [];
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
					var visualName = '$name ${num+1}';
					var pathName = '$formattedName-${num+1}';

					if (Paths.exists('$daComicPath/${pathName}.png')){
						
						var newPage = {visualName: visualName, name: pathName, chapter: daChapter, prevPage: lastPage};

						if (lastPage != null)
							lastPage.nextPage = newPage;
						lastPage = newPage;

						pages.push(newPage);
						num++;
					}else
						break;
				}

				if (num == 1 && lastPage != null){
					lastPage.visualName = name;
				}
			}

			if (pages.length <= 0) 
				continue; // Don't add this mod as a chapter if it doesn't have any pages

			if (lastChapter != null){
				lastChapter.nextChapter = daChapter;
			}
			lastChapter = daChapter;

			daChapter.pages = pages;
			data.push(daChapter);
		}
		#end
	}

	inline static function cleanupData()
	{
		data = null;
	}

	static inline function boundInt(Value:Int, ?Min:Int, ?Max:Int):Int
	{
		var lowerBound:Int = (Min != null && Value < Min) ? Min : Value;
		return (Max != null && lowerBound > Max) ? Max : lowerBound;
	}

	static function switchToChapterNum(chapterNum:Int){
		curChapter = chapterNum;
		FlxTransitionableState.skipNextTransIn = true;
		FlxTransitionableState.skipNextTransOut = true;
		MusicBeatState.switchState(new ComicsMenuState());

		FlxG.mouse.visible = true;
		Mouse.cursor = __WAIT_ARROW;
	}
	static function switchToChapterData(chapterData:ChapterData){
		switchToChapterNum(data.indexOf(chapterData));
	}

	var doingTransition:Bool = false;
	override public function create()
	{
		#if !FLX_NO_MOUSE
		FlxG.mouse.visible = true;
		Mouse.cursor = ARROW;
		#end

		persistentUpdate = true;
		super.create();

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

		var cornerLeftText = TGTMenuShit.newBackTextButton(goBack);
		add(cornerLeftText);

		//// GET THE CUTSCENES
		if (data == null)
			loadData();

		if (data.length <= 0){
			trace("Chapter data not found!");
			add(new Tails().screenCenter());
			return;
		}

		curChapter = boundInt(curChapter, 0, data.length-1);

		var curData:ChapterData = data[curChapter];
		if (curData == null){
			trace("Error: Chapter data is null!?");
			add(new Tails().screenCenter());
			return;
		}

		var curPages:Array<PageData> = curData.pages;

		var chapterNameTxt = new FlxText(0, 8, 0, '${curData.name}', 18);
		chapterNameTxt.font = Paths.font("consola.ttf");
		chapterNameTxt.screenCenter(X);
		add(chapterNameTxt);

		Paths.currentModDirectory = curData.directory;
		var coverArt = new FlxSprite(0, chapterNameTxt.y + chapterNameTxt.height + 18, ChapterMenuState.getChapterCover(curData.name));
		coverArt.screenCenter(X);
		add(coverArt);

		var tail = coverArt.y + coverArt.height + 12;

		if (curData.prevChapter != null){
			var prevChapterTxt = new TGTTextButton(coverArt.x, tail, 0, "← Chapter", 18, ()->{
				if (doingTransition) return;
				doingTransition = true;

				switchToChapterData(curData.prevChapter);
			});
			prevChapterTxt.label.font = Paths.font("consola.ttf");
			prevChapterTxt.label.underline = true;
			add(prevChapterTxt);
		}
		if (curData.nextChapter != null){
			var nextChapterTxt = new TGTTextButton(coverArt.x + coverArt.width, tail, 0, "Chapter →", 18, ()->{
				if (doingTransition) return;
				doingTransition = true;

				switchToChapterData(curData.nextChapter);
			});
			nextChapterTxt.x -= nextChapterTxt.width;
			nextChapterTxt.label.font = Paths.font("consola.ttf");
			nextChapterTxt.label.underline = true;
			add(nextChapterTxt);
		}

		tail += 48;

		for (idx in 0...curPages.length){
			var page:PageData = curData.pages[idx];
			
			////
			var pageTxt = new tgt.TGTTextButton(
				0, 
				tail + 20*idx, 
				0, 
				page.visualName, 
				18, 
				function()
				{
					if (doingTransition) return;
					doingTransition = true;

					// TODO: make a shader that'll load it from top to bottom
					FlxTransitionableState.skipNextTransIn = true;
					FlxTransitionableState.skipNextTransOut = true;
					
					ComicReader.zoom = 1;
					
					MusicBeatState.switchState(new ComicReader(page));

					FlxG.mouse.visible = true;
					Mouse.cursor = __WAIT_ARROW;
				}
			);
			pageTxt.scrollFactor.set(1, 1);
			pageTxt.label.font = Paths.font("consola.ttf");
			pageTxt.label.underline = true;
			pageTxt.label.updateHitbox();
			pageTxt.width = pageTxt.label.width;
			pageTxt.screenCenter(X);
			pageTxt.height = 18; // for the hitbox so you don't click on two texts at the same time
			add(pageTxt);

			options.push(pageTxt);
		}
	}

	function goBack(){
		if (doingTransition) return;
		doingTransition = true;

		curSelected = 0;

		cleanupData();
		FlxG.sound.play(Paths.sound('cancelMenu'));
		Mouse.cursor = ARROW;
		MusicBeatState.switchState(new GalleryMenuState());
	}

	override public function update(e)
	{
		if (controls.BACK) goBack();

		// TODO: uhhh scrolling code in case you can't fit all chapter pages into the screen (This probably won't happen though)

		super.update(e);
	}
}

// haha vs /v/

class ComicReader extends MusicBeatState
{
	var camBackground = new FlxCamera();
	var camComic = new FlxCamera();
	var camHUD = new FlxCamera();

	var camFollow = new FlxPoint(); // goal position
	var camFollowPos = new FlxObject(); // displayed position

	public static var zoom:Float = 1;

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
		Mouse.cursor = ARROW;
		#end

		//
		camComic.bgColor = 0x00000000;
		camHUD.bgColor = 0x00000000;

		FlxG.cameras.reset();
		FlxG.cameras.add(camBackground, false);
		FlxG.cameras.add(camComic, true);
		FlxG.cameras.add(camHUD, false);

		//camComic.antialiasing = ClientPrefs.globalAntialiasing;
		camComic.follow(camFollowPos, LOCKON, 1);

		//
		var bg = new FlxSprite().loadGraphic(Paths.image("menuDesat"));
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

		var pageNameTitle = new FlxText(curPanel.x, head -42*2, curPanel.width, pageData.visualName, 18);
		pageNameTitle.font = Paths.font("consola.ttf");
		pageNameTitle.alignment = CENTER;
		pageNameTitle.scrollFactor.set(1, 1);
		add(pageNameTitle);

		var listPage = new TGTTextButton(curPanel.getMidpoint().x, head, 0, "Page List", 18, goToPageList);
		listPage.label.font = Paths.font("consola.ttf");
		listPage.label.underline = true;
		listPage.x -= listPage.frameWidth * 0.5;
		listPage.y -= 18;
		listPage.scrollFactor.set(1, 1);
		add(listPage);

		var listPage = new TGTTextButton(curPanel.getMidpoint().x, tail, 0, "Page List", 18, goToPageList);
		listPage.label.font = Paths.font("consola.ttf");
		listPage.label.underline = true;
		listPage.x -= listPage.frameWidth * 0.5;
		listPage.scrollFactor.set(1, 1);
		add(listPage);

		if (pageData.prevPage != null){
			function goPrevPage(){
				if (loadingShader.loaded >= 1)
				{
					pageData = pageData.prevPage;
					FlxTransitionableState.skipNextTransIn = true;
					FlxTransitionableState.skipNextTransOut = true;
					MusicBeatState.resetState();
					FlxG.mouse.visible = true;
					Mouse.cursor = __WAIT_ARROW;
				}
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
				if (loadingShader.loaded >= 1){
					pageData = pageData.nextPage;
					FlxTransitionableState.skipNextTransIn = true;
					FlxTransitionableState.skipNextTransOut = true;
					MusicBeatState.resetState();
					FlxG.mouse.visible = true;
					Mouse.cursor = __WAIT_ARROW;
				}
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
	//var getHintX:Void->Float;
	var hintText:FlxText;

	// Camera limits
	var minX:Float = 0;
	var maxX:Float = 0;
	var minY:Float = 0;
	var maxY:Float = 0;

	var loadTimer:Float = 0;
	var loadSteps:Int = FlxG.random.int(3, 10);
	var timeBetweenSteps:Float = FlxG.random.float(0.1, 0.3);
	var loadingShader = new shaders.LoadShader();
	var YOURINTERNETSUCKS:Bool = false;

	function loadPanel(path:String)
	{
		if (curPanel != null)
			remove(curPanel).destroy();

		curPanel = new FlxSprite().loadGraphic(Paths.image('cutscenes/$path'));
		curPanel.pixelPerfectRender = true;
		curPanel.cameras = [camComic];
		curPanel.shader = loadingShader;

		var scrWidth = FlxG.width;
		var scrHeight = FlxG.height;

		var fuu = Math.min(scrWidth, scrHeight);
		fuu = (curPanel.width > fuu) ? (fuu / curPanel.width) : 1;
		
		curPanel.scale.set(fuu, fuu);
		curPanel.updateHitbox();
		var bytes:Float = (curPanel.frameWidth * curPanel.frameHeight * 4) * 0.000001; // gets approx. how much space in memory the image uses, and bases load times on that
		loadSteps = FlxG.random.int(Math.ceil(bytes / 6), Math.ceil(bytes / 2));
		YOURINTERNETSUCKS = FlxG.random.bool(1);
		if (ComicsMenuState.seenBefore.contains(path)){
			YOURINTERNETSUCKS = false;
			loadSteps = Math.floor(loadSteps / 3);
			timeBetweenSteps /= 1.25;
		}
		if (YOURINTERNETSUCKS){
			loadSteps *= 3;
			timeBetweenSteps *= 1.5;
		}

		curPanel.x -= curPanel.width* 0.5;
		add(curPanel);

		minX = curPanel.x;
		maxX = curPanel.x + curPanel.width;
		minY = curPanel.y - scrHeight / 8;
		maxY = curPanel.y + curPanel.height + scrHeight / 8;
		
		var mid = curPanel.getMidpoint();
		camFollow.set(mid.x, curPanel.height > FlxG.height ? 0 : mid.y);

		camComic.zoom = zoom;
	}

	function goToPageList(){
		@:privateAccess(ComicsMenuState)
		ComicsMenuState.switchToChapterData(pageData.chapter);
	}

	var baseSpeed = 8;
	override function update(elapsed:Float)
	{
		if (loadingShader.loaded < 1){
			Mouse.cursor = __WAIT_ARROW;
			loadTimer += elapsed;
			while (loadTimer >= timeBetweenSteps){
				loadTimer -= timeBetweenSteps;
				loadingShader.loaded += 1 / loadSteps;
				timeBetweenSteps = FlxG.random.float(0.1, 0.3);
				if (YOURINTERNETSUCKS)
					timeBetweenSteps *= 1.5;

				if (loadingShader.loaded >= 1){
					loadingShader.loaded = 1;
					loadTimer = 0;
					Mouse.cursor = ARROW;
					if (!ComicsMenuState.seenBefore.contains(pageData.name))
						ComicsMenuState.seenBefore.push(pageData.name);

					if (ComicsMenuState.seenBefore.length > 10){
						while (ComicsMenuState.seenBefore.length > 10)
							ComicsMenuState.seenBefore.shift();
					}
				}
			}
		}


		var justPressed = FlxG.keys.justPressed;
		var pressed = FlxG.keys.pressed;

		if (justPressed.BACKSPACE) 
			goToPageList();

		if (justPressed.R){ // Reset camera view
			zoom = 1;
			camFollow.x = curPanel.getMidpoint().x;
		}

		if (justPressed.Q)
			zoom -= .1;
		if (justPressed.E)
			zoom += .1;

		var speed:Float = (pressed.SHIFT ? baseSpeed * 2 : baseSpeed);
		var yScroll:Float = 0;
		var mouseWheel = FlxG.mouse.wheel;

		
		speed *= elapsed / (1 / 60);
		
		if (mouseWheel != 0)
		{
			if (pressed.CONTROL)
				zoom += mouseWheel * 0.1;
			else
				yScroll -= mouseWheel * (speed / zoom) * 24;
		}
		zoom = FlxMath.bound(zoom, 0.25, 5);
			
		if(FlxG.mouse.pressed){
			var deltaX = FlxG.mouse.deltaX / zoom;
			var deltaY = FlxG.mouse.deltaY / zoom;
			camFollow.x -= deltaX;
			yScroll -= deltaY;
			camFollowPos.x -= deltaX;
			camFollowPos.y -= deltaY;
			camFollowPos.setPosition(
				FlxMath.bound(camFollowPos.x, minX, maxX),
				FlxMath.bound(camFollowPos.y, minY, maxY) 
			);
		}

		if (pressed.UP || pressed.W || pressed.PAGEUP)
			yScroll -= speed;
		if (pressed.DOWN || pressed.S || pressed.PAGEDOWN)
			yScroll += speed;

		if (pressed.LEFT || pressed.A)
			camFollow.x -= speed;
		if (pressed.RIGHT || pressed.D)
			camFollow.x += speed;
		
		
		camFollow.set(
			FlxMath.bound(camFollow.x, minX, maxX),
			FlxMath.bound(camFollow.y + yScroll, minY, maxY) 
		);
		
		// update camera
		var lerpVal = Math.min(1, elapsed * 6);
		camComic.zoom = FlxMath.lerp(camComic.zoom, zoom, lerpVal);
		camFollowPos.setPosition(
			FlxMath.lerp(camFollowPos.x, camFollow.x, lerpVal), 
			FlxMath.lerp(camFollowPos.y, camFollow.y, lerpVal)
		);

		super.update(elapsed);
	}
}