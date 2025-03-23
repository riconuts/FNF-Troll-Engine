package funkin.modchart.modifiers;

import flixel.math.FlxMath;
import math.CoolMath;//Games
using StringTools;

class SchmovinDrunkModifier extends NoteModifier {
	override function getName()return 'schmovinDrunk';
	inline function adjust(axis:String, val:Float, plr:Int):Float {
		if ((axis.startsWith("Z") || axis.startsWith("TanZ")) && getOtherValue("legacyZAxis", plr) > 0)
			return val / 1280;

		return val;
	}

	inline function applyDrunk(axis:String, player:Int, beat:Float, visualDiff:Float, column:Int, keyCount:Int, ?mathFunc:Float->Float) {
		var playerColumn = column % keyCount;
		var prefix = 'schmovinDrunk${axis}';

		var perc = axis == '' ? getValue(player) : getSubmodValue(prefix, player);
		var offset = getSubmodValue('${prefix}Offset', player);
		var period = 1 + getSubmodValue('${prefix}Period', player);
		var speed  = 1 + getSubmodValue('${prefix}Speed', player);

		var phaseShift = (playerColumn * 0.5) + offset + (visualDiff * period) / 222 * Math.PI;
		var offsetX = mathFunc((beat * speed) / 4 * Math.PI + phaseShift) * Note.halfWidth * perc;
		return adjust(axis, offsetX, player);
	}

	inline function applyTipsy(axis:String, player:Int, beat:Float, visualDiff:Float, column:Int, keyCount:Int, ?mathFunc:Float->Float) {
		var playerColumn = column % keyCount;
		var prefix = 'schmovinTipsy${axis}';

		var perc = getSubmodValue(prefix, player);
		var offset = getSubmodValue('${prefix}Offset', player);
		var speed = 1 + getSubmodValue('${prefix}Speed', player);

		var offsetY = mathFunc((beat * speed) / 4 * Math.PI + playerColumn + offset) * Note.halfWidth * perc;
		return adjust(axis, offsetY, player);
	}

	inline function applyBumpy(axis:String, player:Int, beat:Float, visualDiff:Float, column:Float, ?mathFunc:Float->Float) {
		var prefix = 'schmovinBumpy${axis}';

		var perc = getSubmodValue(prefix, player);
		var offset = getSubmodValue('${prefix}Offset', player);
		var period = 1 + getSubmodValue('${prefix}Period', player);

		var offsetY = mathFunc(visualDiff / (300 + 300 * period) * Math.PI * 2 + offset) * Note.swagWidth * perc;
		return adjust(axis, offsetY, player);
	}

	override function getPos(visualDiff:Float, timeDiff:Float, beat:Float, pos:Vector3, data:Int, player:Int, obj:FlxSprite, field:NoteField)
	{
		pos.x += 
			applyDrunk('', player, beat, visualDiff, data, field.field.keyCount, FlxMath.fastSin) +
			applyTipsy('X', player, beat, visualDiff, data, field.field.keyCount, FlxMath.fastSin) +
			applyBumpy('X', player, beat, visualDiff, data, FlxMath.fastSin);

		pos.y += 
			applyDrunk('Y', player, beat, visualDiff, data, field.field.keyCount, FlxMath.fastSin) +
			applyTipsy('', player, beat, visualDiff, data, field.field.keyCount, FlxMath.fastSin) +
			applyBumpy('Y', player, beat, visualDiff, data, FlxMath.fastSin);

		pos.z += 
			applyDrunk('Z', player, beat, visualDiff, data, field.field.keyCount, FlxMath.fastSin) +
			applyTipsy('Z', player, beat, visualDiff, data, field.field.keyCount, FlxMath.fastSin) +
			applyBumpy('', player, beat, visualDiff, data, FlxMath.fastSin);

		pos.x += applyDrunk('Tan', player, beat, visualDiff, data, field.field.keyCount, CoolMath.fastTan)
			+ applyTipsy('TanX', player, beat, visualDiff, data, field.field.keyCount, CoolMath.fastTan)
			+ applyBumpy('TanX', player, beat, visualDiff, data, CoolMath.fastTan);

		pos.y += applyDrunk('TanY', player, beat, visualDiff, data, field.field.keyCount, CoolMath.fastTan)
			+ applyTipsy('Tan', player, beat, visualDiff, data, field.field.keyCount, CoolMath.fastTan)
			+ applyBumpy('TanY', player, beat, visualDiff, data, CoolMath.fastTan);

		pos.z += applyDrunk('TanZ', player, beat, visualDiff, data, field.field.keyCount, CoolMath.fastTan)
			+ applyTipsy('TanZ', player, beat, visualDiff, data, field.field.keyCount, CoolMath.fastTan)
			+ applyBumpy('Tan', player, beat, visualDiff, data, CoolMath.fastTan);

		return pos;
	}

	override function getSubmods(){
		return [
			"schmovinDrunkY",
			"schmovinDrunkZ",

			"schmovinDrunkOffset",
			"schmovinDrunkYOffset",
			"schmovinDrunkZOffset",

			"schmovinDrunkPeriod",
			"schmovinDrunkYPeriod",
			"schmovinDrunkZPeriod",

			"schmovinDrunkSpeed",
			"schmovinDrunkYSpeed",
			"schmovinDrunkZSpeed",

			"schmovinTipsyX",
			"schmovinTipsy",
			"schmovinTipsyZ",

			"schmovinTipsyXOffset",
			"schmovinTipsyOffset",
			"schmovinTipsyZOffset",

			"schmovinTipsyXSpeed",
			"schmovinTipsySpeed",
			"schmovinTipsyZSpeed",

			"schmovinBumpyX",
			"schmovinBumpyY",
			"schmovinBumpy",

			"schmovinBumpyXOffset",
			"schmovinBumpyYOffset",
			"schmovinBumpyOffset",

			"schmovinBumpyXPeriod",
			"schmovinBumpyYPeriod",
			"schmovinBumpyPeriod",

			// tangent version

			"schmovinDrunkTan",
			"schmovinDrunkTanY",
			"schmovinDrunkTanZ",

			"schmovinDrunkTanOffset",
			"schmovinDrunkTanYOffset",
			"schmovinDrunkTanZOffset",

			"schmovinDrunkTanPeriod",
			"schmovinDrunkTanYPeriod",
			"schmovinDrunkTanZPeriod",

			"schmovinDrunkTanSpeed",
			"schmovinDrunkTanYSpeed",
			"schmovinDrunkTanZSpeed",

			"schmovinTipsyTanX",
			"schmovinTipsyTan",
			"schmovinTipsyTanZ",

			"schmovinTipsyTanXOffset",
			"schmovinTipsyTanOffset",
			"schmovinTipsyTanZOffset",

			"schmovinTipsyTanXSpeed",
			"schmovinTipsyTanSpeed",
			"schmovinTipsyTanZSpeed",

			"schmovinBumpyTanX",
			"schmovinBumpyTanY",
			"schmovinBumpyTan",

			"schmovinBumpyTanXOffset",
			"schmovinBumpyTanYOffset",
			"schmovinBumpyTanOffset",

			"schmovinBumpyTanXPeriod",
			"schmovinBumpyTanYPeriod",
			"schmovinBumpyTanPeriod",
		];
	}
}