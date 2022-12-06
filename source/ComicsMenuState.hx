package;

import flixel.*;
import flixel.math.*;
import flixel.text.FlxText;
import sowy.*;

class ComicsMenuState extends MusicBeatState
{
	
}

// based on the vs v comic reader lololol
class ComicReader extends MusicBeatState
{
	var camBackground = new FlxCamera();
	var camComic = new FlxCamera();

	var camFollow = new FlxPoint(); // goal position
	var camFollowPos = new FlxPoint(); // real position
	var camPosition = new FlxObject(0, 0, 1, 1); // displayed position

	var zoom:Float = 1;

	var curPanel:FlxSprite;
	static var panelPaths:Array<String>;
	static var panelNumber:Int = 0;

	public function new(?PanelPaths:Array<String>)
	{
		super();
		if (PanelPaths != null)
			panelPaths = PanelPaths;
	}

	override function add(Object:FlxBasic)
	{
		if (Std.isOfType(Object, FlxSprite))
			cast(Object, FlxSprite).antialiasing = ClientPrefs.globalAntialiasing;

		return super.add(Object);
	}

	override function create()
	{
		//
		camComic.bgColor = 0x00000000;

		FlxG.cameras.reset();
		FlxG.cameras.add(camBackground, false);
		FlxG.cameras.add(camComic, true);

		camComic.antialiasing = ClientPrefs.globalAntialiasing;
		camComic.follow(camPosition, LOCKON, 1);

		//
		var bg = new FlxSprite().loadGraphic(Paths.image("menuBGDesat"));
		bg.color = 0xFF001010;
		bg.cameras = [camBackground];
		bg.scrollFactor.set();
		bg.screenCenter();
		add(bg);

		//
		loadPanel("Taste For Blood");

		//
		var tail = curPanel.y + curPanel.height + 24;

		var sep = new FlxText(-9, tail, 18, " - ", 36, true);
		sep.setFormat("calibri", 18, 0xFFFFFFFF, FlxTextAlign.CENTER, FlxTextBorderStyle.NONE, 0xFFFFFFFF);
		sep.scrollFactor.set(1, 1);
		add(sep);

		var prevPage = new SowyTextButton(-60, tail, 50, "← Page", 18);
		prevPage.label.setFormat("calibri", 18, 0xFFFECB00, FlxTextAlign.RIGHT, FlxTextBorderStyle.NONE, 0xFFFECB00);
		prevPage.scrollFactor.set(1, 1);
		add(prevPage);

		var nextPage = new SowyTextButton(10, tail, 50, "Page →", 18);
		nextPage.label.setFormat("calibri", 18, 0xFFFECB00, FlxTextAlign.LEFT, FlxTextBorderStyle.NONE, 0xFFFECB00);
		nextPage.scrollFactor.set(1, 1);
		add(nextPage);

		var listPage = new SowyTextButton(-40, tail + 24, 80, "Page List", 18);
		listPage.label.setFormat("calibri", 18, 0xFFFECB00, FlxTextAlign.CENTER, FlxTextBorderStyle.NONE, 0xFFFECB00);
		listPage.scrollFactor.set(1, 1);
		add(listPage);

		trace(sep.frameWidth, nextPage.frameWidth);

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

		curPanel = new FlxSprite().loadGraphic(Paths.image('comics/$path'));
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

	var baseSpeed = 6;

	override function update(elapsed:Float)
	{
		var justPressed = FlxG.keys.justPressed;
		var pressed = FlxG.keys.pressed;

		if (controls.BACK) MusicBeatState.switchState(new MainMenuState());

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

		if (pressed.UP)
			camFollow.y -= speed;
		if (pressed.DOWN)
			camFollow.y += speed;

		if (pressed.LEFT)
			camFollow.x = Math.max(minX, camFollow.x - speed);
		if (pressed.RIGHT)
			camFollow.x = Math.min(maxX, camFollow.x + speed);
		
		camFollow.y = Math.max(minY, Math.min(camFollow.y + yScroll, maxY));

		zoom = Math.max(0.25, Math.min(zoom, 5));

		// update camera
		var lerpVal = Math.min(1, elapsed * 6);
		camFollowPos.set(FlxMath.lerp(camFollowPos.x, camFollow.x, lerpVal), FlxMath.lerp(camFollowPos.y, camFollow.y, lerpVal));
		camPosition.setPosition(Std.int(camFollowPos.x), Std.int(camFollowPos.y)); // pixel perfect!!!
		camComic.zoom = FlxMath.lerp(camComic.zoom, zoom, lerpVal);

		super.update(elapsed);
	}
}