package flixel.system.ui;

#if FLX_SOUND_SYSTEM
import flixel.FlxG;
import flixel.system.FlxAssets;
import openfl.display.Sprite;
#if flash
import flash.text.AntiAliasType;
import flash.text.GridFitType;
#end

/**
 * The flixel sound tray, the little volume meter that pops down sometimes.
 * Accessed via `FlxG.game.soundTray` or `FlxG.sound.soundTray`.
 */
class FlxSoundTray extends Sprite
{
	/** Whether the sound tray should be updated or not. **/
	public var active:Bool;

	/**The sound used when increasing the volume.**/
	public var volumeUpSound:String = "flixel/sounds/beep";

	/**The sound used when decreasing the volume.**/
	public var volumeDownSound:String = 'flixel/sounds/beep';

	/**Whether or not changing the volume should make noise.**/
	public var silent:Bool = false;

	/**
	 * This function just updates the sound tray object.
	 */
	public function update(MS:Float):Void
	{
		
	}

	/**
	 * Makes the little volume tray slide out.
	 *
	 * @param	up Whether the volume is increasing.
	 */
	public function show(up:Bool = false):Void
	{
		playVolumeSound(up);
		saveVolumeData();
	}

	public function playVolumeSound(up:Bool = false)
	{
		if (!silent)
		{
			var sound = FlxAssets.getSound(up ? volumeUpSound : volumeDownSound);
			if (sound != null)
				FlxG.sound.load(sound).play();
		}
	}

	/** Save sound preferences **/
	public function saveVolumeData()
	{
		if (FlxG.save.isBound)
		{
			FlxG.save.data.mute = FlxG.sound.muted;
			FlxG.save.data.volume = FlxG.sound.volume;
			FlxG.save.flush();
		}
	}

	public function screenCenter():Void
	{

	}
}
#end