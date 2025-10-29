package openfl.display;

#if cpp
import funkin.api.Memory;
#end

import flixel.util.FlxStringUtil;
import flixel.FlxG;

import openfl.text.TextField;
import openfl.text.TextFormat;
import openfl.text.TextFormatAlign;
import openfl.events.Event;

#if gl_stats
import openfl.display._internal.stats.Context3DStats;
import openfl.display._internal.stats.DrawCallContext;
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
	/** The current frame rate, expressed using frames-per-second **/
	public var currentFPS(default, null):Int = 0;
	/** The current state class name **/
	public var currentState(default, null):String = "";
	/** Whether to show a memory usage counter or not **/
	public var showMemory:Bool = #if final false #else true #end;

	public var align(default, set):TextFormatAlign;
	function set_align(val) {		
		return align = defaultTextFormat.align = switch (val){
			default: 
				this.x = 10;
				autoSize = LEFT;
				LEFT;

			case CENTER: 
				this.x = (this.stage.stageWidth - this.textWidth) * 0.5; 
				autoSize = CENTER;
				CENTER;

			case RIGHT: 
				this.x = (this.stage.stageWidth - this.textWidth) - 10; 
				autoSize = RIGHT;
				RIGHT;
		}
	}

	function onGameResized(windowWidth, ?windowHeight)
		align = align;

	@:noCompletion private var lastTime:Float = 0;
	@:noCompletion private var framesCounted:Int = 0;

	public function new(x:Float = 10, y:Float = 10, color:Int = 0xFFFFFF)
	{
		super();

		this.x = x;
		this.y = y;

		mouseEnabled = false;
		selectable = false;

		background = true;
		backgroundColor = 0x000000;

		multiline = true;
		embedFonts = false;
		defaultTextFormat = new TextFormat("_sans", 12, color);

		////
		addEventListener(Event.ADDED_TO_STAGE, (e:Event)->{
			if (align == null)
				align = #if mobile CENTER #else LEFT #end;
		});
		
		/*
		addEventListener(openfl.events.KeyboardEvent.KEY_DOWN, (e)->{
			if (e.keyCode == flixel.input.keyboard.FlxKey.F3)
				this.align = switch (this.align){
					case LEFT: CENTER;
					case CENTER: RIGHT;
					case RIGHT: LEFT;
					default: LEFT;
				}
		});
		*/

		FlxG.signals.gameResized.add(onGameResized);

		#if (debug && false)
		FlxG.signals.preStateCreate.add((nextState)->{
			currentState = Type.getClassName(Type.getClass(nextState));
		});
		#end
	}

	inline static function formatMemory(Bytes:Float):String
	{
		var units:Int = 0;
		while (Bytes >= 1024) {
			Bytes /= 1024;
			units++;
		}

		return Math.round(Bytes * 100) / 100 + switch(units) {
			case 0: "Bytes";
			case 1: "kB";
			case 2: "MB";
			default: "GB";
		};
	}

	private static inline function get_memoryUsageString():String
	{
		#if cpp
		return formatMemory(Memory.getCurrentRSS()) + " / " + formatMemory(Memory.getPeakRSS());
		#else
		return formatMemory(openfl.system.System.totalMemoryNumber);
		#end
	}

	// Event Handlers
	@:noCompletion
	private override function __enterFrame(deltaTime:Float):Void
	{
		var nowTime = Main.getTime();
		if (nowTime - lastTime > 1000) {
			currentFPS = framesCounted;
			framesCounted = 0;
			lastTime = nowTime;
		}

		framesCounted++;

		var text:String = 'FPS: $currentFPS';
		
		if (showMemory)
			text += ' • MEM: ' + get_memoryUsageString();

		#if (debug && false)
		text += '\nState: $currentState';
		#end

		if (currentFPS <= FlxG.drawFramerate * 0.5)
			textColor = 0xFFFF0000;
		else
			textColor = 0xFFFFFFFF;

		#if (gl_stats && !disable_cffi && (!html5 || !canvas))
		text += "\ntotalDC: " + Context3DStats.totalDrawCalls();
		text += "\nstageDC: " + Context3DStats.contextDrawCalls(DrawCallContext.STAGE);
		text += "\nstage3DDC: " + Context3DStats.contextDrawCalls(DrawCallContext.STAGE3D);
		#end

		this.text = text;
	}
}
