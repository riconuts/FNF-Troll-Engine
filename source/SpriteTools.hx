package;

import flixel.util.FlxAxes;
import flixel.FlxObject;

class SpriteTools {
	public static inline function objectCenter(object1:FlxObject, object2:FlxObject, ?axes:FlxAxes = XY) {

		if (axes.x)
			object1.x = object2.x + (object2.width - object1.width) / 2;

		if (axes.y)
			object1.y = object2.y + (object2.height - object1.height) / 2;

		return object1;
	}
}
