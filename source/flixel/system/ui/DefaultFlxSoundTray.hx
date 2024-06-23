package flixel.system.ui;

#if FLX_SOUND_SYSTEM
import flixel.FlxG;
import flixel.system.FlxAssets;

import openfl.Lib;
import openfl.display.Bitmap;
import openfl.display.BitmapData;
import openfl.display.Sprite;
import openfl.text.TextField;
import openfl.text.TextFormat;
import openfl.text.TextFormatAlign;

/**
 * The flixel sound tray, the little volume meter that pops down sometimes.
 * Accessed via `FlxG.game.soundTray` or `FlxG.sound.soundTray`.
 */
class DefaultFlxSoundTray extends FlxSoundTray
{
	/**
	 * Helps us auto-hide the sound tray after a volume change.
	 */
	var _timer:Float;

	/**
	 * Helps display the volume bars on the sound tray.
	 */
	var _bars:Array<Bitmap>;

	/**
	 * Helps display the volume text on the sound tray.
	 */
	var _text:TextField;

	/**
	 * How wide the sound tray background is.
	 */
	var _width:Int = 80;

	var _defaultScale:Float = 2.0;

	/**
	 * Sets up the "sound tray", the little volume meter that pops down sometimes.
	 */	
	@:keep
	public function new()
	{
		super();
		visible = false;
		scaleX = _defaultScale;
		scaleY = _defaultScale;
		var tmp:Bitmap = new Bitmap(new BitmapData(_width, 30, true, 0x7F000000));
		screenCenter();
		addChild(tmp);

		_text = new TextField();
		_text.width = tmp.width;
		_text.height = tmp.height;
		_text.multiline = true;
		_text.wordWrap = true;
		_text.selectable = false;

		#if flash
		_text.embedFonts = true;
		_text.antiAliasType = AntiAliasType.NORMAL;
		_text.gridFitType = GridFitType.PIXEL;
		#end

		#if tgt
		var dtf:TextFormat = new TextFormat(funkin.Paths.font("calibrib.ttf"), 10, 0xffffff);
		#else
		var dtf:TextFormat = new TextFormat(FlxAssets.FONT_DEFAULT, 8, 0xffffff);
		#end
		dtf.align = TextFormatAlign.CENTER;
		_text.defaultTextFormat = dtf;

		_text.text = "VOLUME";
		_text.y = 16;
		addChild(_text);

		var bx:Int = 10;
		var by:Int = 14;
		_bars = new Array();

		for (i in 0...10)
		{
			tmp = new Bitmap(new BitmapData(4, i + 1, false, 0xffffff));
			tmp.x = bx;
			tmp.y = by;
			addChild(tmp);
			_bars.push(tmp);
			bx += 6;
			by--;
		}

		y = -height;
		visible = false;
	}

	/**
	 * This function just updates the soundtray object.
	 */
	override public function update(MS:Float):Void
	{
		// Animate stupid sound tray thing
		if (_timer > 0)
		{
			_timer -= (MS / 1000);
		}
		else if (y > -height)
		{
			y -= (MS / 1000) * FlxG.height * 0.5;

			if (y <= -height)
			{
				visible = false;
				active = false;

				saveVolumeData();
			}
		}
	}

	/**
	 * Makes the little volume tray slide out.
	 *
	 * @param	up Whether the volume is increasing.
	 */
	override public function show(up:Bool = false):Void
	{
		playVolumeSound(up);

		_timer = 1;
		y = 0;
		visible = true;
		active = true;
		var globalVolume:Int = Math.round(FlxG.sound.volume * 10);

		if (FlxG.sound.muted)
		{
			globalVolume = 0;
		}

		for (i in 0..._bars.length)
		{
			if (i < globalVolume)
			{
				_bars[i].alpha = 1;
			}
			else
			{
				_bars[i].alpha = 0.5;
			}
		}
	}

	override public function screenCenter():Void
	{
		scaleX = _defaultScale;
		scaleY = _defaultScale;

		x = (0.5 * (Lib.current.stage.stageWidth - _width * _defaultScale) - FlxG.game.x);
	}
}
#end