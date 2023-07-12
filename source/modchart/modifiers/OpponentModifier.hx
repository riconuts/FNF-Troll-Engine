package modchart.modifiers;

import flixel.FlxSprite;
import modchart.*;
import math.*;
import playfields.NoteField;

class OpponentModifier extends NoteModifier {
	override function getName()
		return 'opponentSwap';

	override function getPos(diff:Float, tDiff:Float, beat:Float, pos:Vector3, data:Int, player:Int, obj:FlxSprite, field:NoteField)
    {
        var nPlayer = Std.int(CoolUtil.scale(player, 0, 1, 1, 0));

		var oppX = modMgr.getBaseX(data, nPlayer, field.field.keyCount);
		var plrX = modMgr.getBaseX(data, player, field.field.keyCount);
        var distX = oppX-plrX;

		pos.x += distX * getValue(player);

        return pos;
    }
}