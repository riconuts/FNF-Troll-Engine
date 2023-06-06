package modchart.modifiers;

import flixel.FlxSprite;
import math.Vector3;

class XModeModifier extends NoteModifier
{
	override function getName()
		return 'xmode';

	override function getPos(diff:Float, tDiff:Float, beat:Float, pos:Vector3, data:Int, player:Int, obj:FlxSprite)
	{
		if (getValue(player) == 0)
			return pos;

        //fPixelOffsetFromCenter += fEffects[PlayerOptions::EFFECT_XMODE]*-(fYOffset);

		var mod = (player + 1) * 2 - 3;
        pos.x += getValue(player) * (diff * mod);
		return pos;
	}
}