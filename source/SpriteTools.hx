package;

import flixel.util.FlxAxes;
import flixel.FlxSprite;
import flixel.FlxObject;
import flixel.FlxG;

class SpriteTools {
	public static inline function objectCenter(object1:FlxObject, object2:FlxObject, ?axes:FlxAxes = XY) {

		if (axes.x)
			object1.x = object2.x + (object2.width - object1.width) / 2;

		if (axes.y)
			object1.y = object2.y + (object2.height - object1.height) / 2;

		return object1;
	}

	/** Returns the necessary scale for the sprite to "fill" the screen **/
	public static inline function getFillScale(spr:FlxSprite) {
		var s1 = Math.max(spr.frameWidth, FlxG.width) / Math.min(spr.frameWidth, FlxG.width);
		var s2 = Math.max(spr.frameHeight, FlxG.height) / Math.min(spr.frameHeight, FlxG.height);
		return Math.max(s1, s2);
	}
}
