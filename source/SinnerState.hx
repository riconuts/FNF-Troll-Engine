package;

import cpp.Lib;
import flixel.FlxBasic;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.effects.FlxFlicker;
import flixel.text.FlxText;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import lime.app.Application;
import lime.math.Vector2;
import lime.system.System;
import lime.tools.WindowData;
import lime.ui.Window;
import lime.ui.WindowAttributes;
import sys.io.Process;

class SinnerState extends FlxState
{
	var trollface:FlxSprite = new FlxSprite();

	var mainWindow:Window;

	var desktopSize:Vector2;

	var x:Float = 0;
	var y:Float = 0;

	var xSpeed:Float = 100;
	var ySpeed:Float = 100;

	var maximumX(get, null):Float;
	var maximumY(get, null):Float;

	var color:FlxColor = FlxColor.RED;
	var hue:Float = 0;
	var hueSpeed:Float = 0;
	// var exeName:String;

	var code:Int = 0;
	
	override function create()
	{
		// window shit
		mainWindow = Application.current.window;
		mainWindow.borderless = true;

		/* doesn't work.
		mainWindow.parameters.alwaysOnTop = true; 
		mainWindow.context.attributes.background = null;
		FlxG.camera.bgColor = FlxColor.fromString("0x0000000");
		*/

		//
		desktopSize = mainWindow.display.bounds.size;
		centerWindow();
		
		// make the window smaller.
		mainWindow.height = Std.int(mainWindow.height * 0.5);
		mainWindow.width = Std.int(mainWindow.height / 3 * 4);

		// get an appropriate speed
		xSpeed = ySpeed *= desktopSize.y / mainWindow.height;

		//
		add(trollface.loadGraphic(Paths.image("trollface")).screenCenter());
		trollface.setGraphicSize(0, Std.int(trollface.height * (mainWindow.height / trollface.height)));
		
		/*
		var full = Sys.programPath();
		var exeDir = StringTools.replace(Sys.getCwd(), "/", "\\");
		exeName = StringTools.replace(full, exeDir, "");

		mainWindow.onFocusOut.add(function(){

		});
		Application.current.onExit.add(function(exitCode){
			
		});
		*/

		super.create();
	}

	override function update(elapsed:Float)
	{
		switch(code){
			case 0:
				if (FlxG.keys.justPressed.UP)
					code++;
			case 1:
				if (FlxG.keys.justPressed.UP)
					code++;
			case 2:
				if (FlxG.keys.justPressed.DOWN)
					code++;
			case 3:
				if (FlxG.keys.justPressed.DOWN)
					code++;
			case 4:
				if (FlxG.keys.justPressed.LEFT)
					code++;
			case 5:
				if (FlxG.keys.justPressed.RIGHT)
					code++;
			case 6:
				if (FlxG.keys.justPressed.LEFT)
					code++;
			case 7:
				if (FlxG.keys.justPressed.RIGHT)
					code++;
			case 8:
				if (FlxG.keys.justPressed.B)
					code++;
			case 9:
				if (FlxG.keys.justPressed.A)
					code++;
			case 10:
				if (FlxG.keys.justPressed.ENTER){
					#if final
					FlxG.save.bind('funkin', 'ninjamuffin99');
					FlxG.save.data.tgtNotes = null;
					FlxG.save.flush();
					#end
					Sys.exit(0);
				}
		}

		if (mainWindow != null)
		{
			var newX = x + xSpeed * elapsed;
			var newY = y + ySpeed * elapsed;

			if (newX < 0){ // left
				xSpeed = -xSpeed;
				newX = 0;
				hueSpeed = 100;
			}else if (newX > maximumX){ // right
				xSpeed = -xSpeed;
				newX = maximumX;
				hueSpeed = 100;
			}
			if (newY < 0){ // up
				ySpeed = -ySpeed;
				newY = 0;
				hueSpeed = 100;
			}else if (newY > maximumY){ // down
				ySpeed = -ySpeed;
				newY = maximumY;
				hueSpeed = 100;
			}

			x = newX;
			y = newY;

			mainWindow.move(Std.int(x), Std.int(y));
		}

		hueSpeed = flixel.math.FlxMath.lerp(hueSpeed, 10, elapsed * 10);
		hue = (hue + hueSpeed * elapsed * 10) % 360;
		color.hue = hue;
		trollface.color = color;

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
		x = (desktopSize.x - mainWindow.width) / 2;
		y = (desktopSize.y - mainWindow.height) / 2;
	}

	/*	i originally wanted this joke to be a lot more brutal
	function anotherOne(){
		new Process(exeName, []);
	}

	public function howManyTrollings()
	{
		var amount = 0;

		var process:Process = new Process('wmic', ['process', 'get', 'Description']);
		var taskList = process.stdout.readAll().toString().split("\n");
		process.close();

		while (taskList.length != 0){
			var taskName:String = StringTools.trim(taskList.pop());
			if (taskName == exeName)
				amount++; 
		}

		return amount;
	}
	*/
}