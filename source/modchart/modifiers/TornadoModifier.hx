package modchart.modifiers;

import flixel.FlxSprite;
import math.Vector3;

class TornadoModifier extends NoteModifier
{
	override function getName()
		return 'tornado';

	override function getPos(diff:Float, tDiff:Float, beat:Float, pos:Vector3, data:Int, player:Int, obj:FlxSprite)
	{
		if (getValue(player) == 0)
			return pos;

/* 		fPixelOffsetFromCenter += CalculateTornadoOffsetFromMagnitude(dim_x, iColNum, fEffects[PlayerOptions::EFFECT_TORNADO],
			fEffects[PlayerOptions::EFFECT_TORNADO_OFFSET], fEffects[PlayerOptions::EFFECT_TORNADO_PERIOD], pCols, pPlayerState -> m_NotefieldZoom, data,
			fYOffset, false); */

		var playerColumn = data % 4;
		var columnPhaseShift = playerColumn * Math.PI / 3;
		var phaseShift = diff / 135;
		var returnReceptorToZeroOffsetX = (-Math.cos(-columnPhaseShift) + 1) / 2 * Note.swagWidth * 3;
		var offsetX = (-Math.cos(phaseShift - columnPhaseShift) + 1) / 2 * Note.swagWidth * 3 - returnReceptorToZeroOffsetX;
		return pos.add(new Vector3(offsetX * getValue(player)));
	}
}