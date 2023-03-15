package modchart.modifiers;

import flixel.FlxSprite;
import math.Vector3;

class FlipModifier extends NoteModifier {
	override function getName()return 'flip';

	override function getPos( diff:Float, tDiff:Float, beat:Float, pos:Vector3, data:Int, player:Int, obj:FlxSprite){
		if (getValue(player) == 0)
			return pos;

		//var receptors = modMgr.receptors[player]; // TODO: rwrite to use playfields (I should prob pass the current playfield into getPos)

		//var distance = Note.swagWidth * (receptors.length* 0.5) * (1.5 - data);
		var distance = Note.swagWidth * 2 * (1.5 - data);
		pos.x += distance * getValue(player);
        return pos;
    }
}