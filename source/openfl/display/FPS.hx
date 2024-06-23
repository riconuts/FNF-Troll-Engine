package openfl.display;

import funkin.ClientPrefs;

import haxe.Timer;
import openfl.events.Event;
import openfl.text.TextField;
import openfl.text.TextFormat;
import flixel.math.FlxMath;
#if gl_stats
import openfl.display._internal.stats.Context3DStats;
import openfl.display._internal.stats.DrawCallContext;
#end
#if flash
import openfl.Lib;
#end

#if openfl
import openfl.system.System;
#end

/**
	The FPS class provides an easy-to-use monitor to display
	the current frame rate of an OpenFL project
**/
#if !openfl_debug
@:fileXml('tags="haxe,release"')
@:noDebug
#end
class FPS extends TextField
{
	/**
		The current frame rate, expressed using frames-per-second
	**/
	public var currentFPS(default, null):Float = 0.0;
	public var currentState(default, null):String = "";

	#if final
	public var showMemory:Bool = false;
	#else
	public var showMemory:Bool = true;
	#end

	@:noCompletion private var cacheCount:Int;
	@:noCompletion private var currentTime:Float;
	@:noCompletion private var times:Array<Float>;

	public function new(x:Float = 10, y:Float = 10, color:Int = 0x000000)
	{
		super();

		this.x = x;
		this.y = y;

		currentFPS = 0;
		selectable = false;
		mouseEnabled = false;

		multiline = true;
		text = "FPS: ";

		var textFormat = new TextFormat(null, 12, color);

		#if mobile
		textFormat.align = CENTER;
		autoSize = CENTER;

		var onGameResize = (stageWidth, stageHeight)->
			this.x = (stageWidth - this.width) / 2.0;
		
		FlxG.signals.gameResized.add(onGameResize);
		onGameResize(FlxG.width, FlxG.height);

		#else
		autoSize = LEFT;
		#end
		
		#if tgt
		var fontPath = funkin.Paths.font("calibri.ttf");
		if (Assets.exists(fontPath, openfl.utils.AssetType.FONT)){
			embedFonts = true;
			textFormat.size = 14;
			textFormat.font = Assets.getFont(fontPath).fontName;
		}
		else
		#end
		{
			embedFonts = false;
			textFormat.font = "_sans";
		}
		defaultTextFormat = textFormat;

		cacheCount = 0;
		currentTime = 0;
		times = [];

		#if flash
		addEventListener(Event.ENTER_FRAME, function(e)
		{
			var time = Lib.getTimer();
			__enterFrame(time - currentTime);
		});
		#end

		#if (debug && false)
		FlxG.signals.preStateCreate.add((nextState)->{
			currentState = Type.getClassName(Type.getClass(nextState));
		});
		#end
	}

	// Event Handlers
	@:noCompletion
	private #if !flash override #end function __enterFrame(deltaTime:Float):Void
	{
		currentTime += deltaTime;
		times.push(currentTime);

		while (times[0] < currentTime - 1000)
		{
			times.shift();
		}

		var currentCount = times.length;
		currentFPS = Math.ffloor((currentCount + cacheCount)* 0.5);
		if (currentFPS > ClientPrefs.framerate)
			currentFPS = ClientPrefs.framerate;

		if (currentCount != cacheCount)
		{
			text = "FPS: " + currentFPS;
			
			if (showMemory)
				text += ' • Memory: ${Math.abs(FlxMath.roundDecimal(System.totalMemory / 1000000, 1))}MB';

			#if (debug && false)
			text += '\nState: $currentState';
			#end

			if (currentFPS <= ClientPrefs.framerate * 0.5)
				textColor = 0xFFFF0000;
			else
				textColor = 0xFFFFFFFF;

			#if (gl_stats && !disable_cffi && (!html5 || !canvas))
			text += "\ntotalDC: " + Context3DStats.totalDrawCalls();
			text += "\nstageDC: " + Context3DStats.contextDrawCalls(DrawCallContext.STAGE);
			text += "\nstage3DDC: " + Context3DStats.contextDrawCalls(DrawCallContext.STAGE3D);
			#end
		}

		cacheCount = currentCount;
	}
}
