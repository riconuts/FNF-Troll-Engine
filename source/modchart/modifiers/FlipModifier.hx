package modchart.modifiers;

import flixel.FlxSprite;
import math.Vector3;

class FlipModifier extends NoteModifier {
	override function getName()return 'flip';

	override function getPos( diff:Float, tDiff:Float, beat:Float, pos:Vector3, data:Int, player:Int, obj:FlxSprite){
		if (getValue(player) == 0)
			return pos;

		var distance = Note.swagWidth * 2 * (1.5 - data);
		pos.x += distance * getValue(player);
        return pos;
    }
}