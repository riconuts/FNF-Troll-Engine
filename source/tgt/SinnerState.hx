package tgt;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.text.FlxText;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import lime.app.Application;
import lime.math.Vector2;
import lime.ui.Window;

class SinnerState extends FlxState
{
	var trollface:FlxSprite;

	var mainWindow:Window;

	var desktopSize:Vector2;

	var x:Float = 0;
	var y:Float = 0;

	var xSpeed:Float = 100;
	var ySpeed:Float = 100;

	var maximumX(get, null):Float;
	var maximumY(get, null):Float;

	var color:FlxColor = FlxColor.RED;
	var hueSpeed:Float = 0;
	var hueTime:Float = 0.0;
	// var exeName:String;

	var code:Int = 0;
	
	override function create()
	{
		FlxG.game.focusLostFramerate = 60;
		FlxG.autoPause = false;
		FlxG.mouse.visible = true;

		// window shit
		mainWindow = Application.current.window;
		mainWindow.borderless = true;
		mainWindow.parameters.alwaysOnTop = true; // shit doesnt work

		//
		desktopSize = mainWindow.display.bounds.size;
		centerWindow();
		
		// make the window smaller.
		mainWindow.height = Std.int(mainWindow.height * 0.5);
		mainWindow.width = Std.int(mainWindow.height / 3 * 4);

		// get an appropriate speed
		xSpeed = ySpeed *= desktopSize.y / mainWindow.height;

		//
		trollface = new FlxSprite(Paths.image("trollface"));
		trollface.screenCenter();
		trollface.setGraphicSize(0, Std.int(trollface.height * (mainWindow.height / trollface.height)));
		add(trollface);

		super.create();
	}

	override function update(elapsed:Float)
	{
		switch(code){
			case 0 | 1:
				if (FlxG.keys.justPressed.UP) code++;
				else if (FlxG.keys.justPressed.ANY) code = 0;
			case 2 | 3:
				if (FlxG.keys.justPressed.DOWN) code++;
				else if (FlxG.keys.justPressed.ANY) code = 0;
			case 4 | 6:
				if (FlxG.keys.justPressed.LEFT) code++;
				else if (FlxG.keys.justPressed.ANY) code = 0;
			case 5 | 7:
				if (FlxG.keys.justPressed.RIGHT) code++;
				else if (FlxG.keys.justPressed.ANY) code = 0;
			case 8:
				if (FlxG.keys.justPressed.B) code++;
				else if (FlxG.keys.justPressed.ANY) code = 0;
			case 9:
				if (FlxG.keys.justPressed.A) code++;
				else if (FlxG.keys.justPressed.ANY) code = 0;
			case 10:
				if (FlxG.keys.justPressed.ENTER){
					#if sys
					Sys.exit(0);
					#end
				}else if (FlxG.keys.justPressed.ANY) code = 0;
		}

		if (mainWindow != null)
		{
			var newX = x + xSpeed * elapsed;
			var newY = y + ySpeed * elapsed;

			if (newX < 0){ // left
				xSpeed = -xSpeed;
				newX = 0;
				hueSpeed = 50;
			}else if (newX > maximumX){ // right
				xSpeed = -xSpeed;
				newX = maximumX;
				hueSpeed = 50;
			}
			if (newY < 0){ // up
				ySpeed = -ySpeed;
				newY = 0;
				hueSpeed = 50;
			}else if (newY > maximumY){ // down
				ySpeed = -ySpeed;
				newY = maximumY;
				hueSpeed = 50;
			}

			x = newX;
			y = newY;

			mainWindow.move(Std.int(x), Std.int(y));
		}

		hueSpeed = flixel.math.FlxMath.lerp(hueSpeed, 8, elapsed * 10);

		inline function get_r(t:Float)
			return 0.5 + 0.5 * Math.cos(2.0*Math.PI * t);
		inline function get_g(t:Float)
			return 0.5 + 0.5 * Math.cos(2.0*Math.PI * (t - 1.0/3.0));
		inline function get_b(t:Float)
			return 0.5 + 0.5 * Math.cos(2.0*Math.PI * (t + 1.0/3.0));

		hueTime += (hueSpeed * elapsed * 10);
		
		var hueTime:Float = hueTime / 360.0;
		trollface.color = FlxColor.fromRGBFloat(
			get_r(hueTime),
			get_g(hueTime),
			get_b(hueTime)
		);

		super.update(elapsed);
	}

	//// window position stuff
	function get_maximumX():Float{
		return desktopSize.x - mainWindow.width;
	}
	function get_maximumY():Float{
		return desktopSize.y - mainWindow.height;
	}
	function getPositionWithinBounds(x:Float, y:Float):Array<Float>
	{
		var maxX:Float = maximumX;
		var maxY:Float = maximumY;

		x = (x < maxX) ? x : maxX;
		y = (y < maxY) ? y : maxY;
		x = (x < 0) ? 0 : x;
		y = (y < 0) ? 0 : y;

		return [x, y];
	}
	function centerWindow(){
		x = (desktopSize.x - mainWindow.width)* 0.5;
		y = (desktopSize.y - mainWindow.height)* 0.5;
	}
}