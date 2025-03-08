package funkin.modchart.modifiers;

import math.CoolMath;
import math.CoolMath.triangle;
import math.CoolMath.square;
import flixel.math.FlxMath.fastSin as sin;
import flixel.math.FlxMath.fastCos as cos;
import math.CoolMath.fastTan as tan;
class PathModifier extends NoteModifier
{	
	override function getName()
		return 'tornado';

	inline function getDigitalAngle(yOffset:Float, offset:Float, period:Float) {
		return Math.PI * (yOffset + (1 * offset)) / (Note.swagWidth + (period * Note.swagWidth));
	}

	static final PI_THIRD:Float = Math.PI / 3.0;
	override function getPos(diff:Float, tDiff:Float, beat:Float, pos:Vector3, column:Int, player:Int, obj:FlxSprite, field:NoteField)
	{
		var zigzag = getSubmodValue("zigzag", player);
		if (zigzag != 0) {
			var offset = getSubmodValue("zigzagOffset", player);
			var period = getSubmodValue("zigzagPeriod", player);
			var result:Float = triangle((Math.PI * (1 / (period + 1)) * ((diff + 100 * offset) / Note.swagWidth)));

			pos.x += (zigzag * Note.halfWidth) * result;
		}

		var zigzagZ = getSubmodValue("zigzagZ", player);
		if (zigzagZ != 0) {
			var offset = getSubmodValue("zigzagZOffset", player);
			var period = getSubmodValue("zigzagZPeriod", player);
			var result:Float = triangle((Math.PI * (1 / (period + 1)) * ((diff + 100 * offset) / Note.swagWidth)));

			pos.z += (zigzagZ * Note.halfWidth) * result;
		}
		

		var sawtooth = getSubmodValue("sawtooth", player);
		if (sawtooth != 0) {
			var period = getSubmodValue("sawtoothPeriod", player) + 1;
			var p = (0.5 / period * diff) / Note.swagWidth;

			pos.x += (sawtooth * Note.swagWidth) * (p - Math.floor(p));
		}

		var squareVal = getSubmodValue("square", player);
		if (squareVal != 0) {
			var offset = getSubmodValue("squareOffset", player);
			var period = getSubmodValue("squarePeriod", player);
			var cum = (Math.PI * (diff + offset) / (Note.swagWidth + (period * Note.swagWidth)));

			pos.x += squareVal * Note.halfWidth * square(cum);
		}

		var bounceVal = getSubmodValue("bounce", player);
		if (bounceVal != 0) {
			var offset = getSubmodValue("bounceOffset", player);
			var period = getSubmodValue("bouncePeriod", player);
			if (period != -1.0){
				var bounce = Math.abs(sin((diff + offset) / (90.0 + 90.0 * period)));
				pos.x += bounceVal * Note.halfWidth * bounce;
			}
		}

		var bounceZVal = getSubmodValue("bounceZ", player);
		if (bounceZVal != 0) {
			var offset = getSubmodValue("bounceZOffset", player);
			var period = getSubmodValue("bounceZPeriod", player);
			if (period != -1.0) {
				var bounce = Math.abs(sin((diff + offset) / (90.0 + 90.0 * period)));
				pos.z += bounceZVal * Note.halfWidth * bounce;
			}
		}


		var xmode = getSubmodValue("xmode", player);
		if (xmode != 0) {
			var mod = (player + 1) * 2 - 3;
			pos.x += xmode * (diff * mod);
		}

		var keyCunt:Float = field.field.keyCount - 1;

		var tornadoVal = getValue(player);
		if (tornadoVal != 0) {
			// from schmovin!!
			var playerColumn = column % field.field.keyCount;
			var columnPhaseShift = (playerColumn * PI_THIRD) + getSubmodValue("tornadoOffset", player);
			var phaseShift = (diff / 135) * (1 + getSubmodValue("tornadoPeriod", player));
			var returnReceptorToZeroOffsetX = (-cos(-columnPhaseShift) + 1) * Note.halfWidth * keyCunt;
			var offsetX = (-cos(phaseShift - columnPhaseShift) + 1) * Note.halfWidth * keyCunt - returnReceptorToZeroOffsetX;
			pos.x += offsetX * tornadoVal;
		}

		var tornadoTanVal = getSubmodValue("tornadoTan", player);
		if (tornadoTanVal != 0) {
			// from schmovin!!
			var playerColumn = column % field.field.keyCount;
			var columnPhaseShift = (playerColumn * PI_THIRD) + getSubmodValue("tornadoTanOffset", player);
			var phaseShift = (diff / 135) * (1 + getSubmodValue("tornadoTanPeriod", player));
			var returnReceptorToZeroOffsetX = (-cos(-columnPhaseShift) + 1) * Note.halfWidth * keyCunt;
			var offsetX = (-tan(phaseShift - columnPhaseShift) + 1) * Note.halfWidth * keyCunt - returnReceptorToZeroOffsetX;
			pos.x += offsetX * tornadoTanVal;
		}

		var tornadoZVal = getSubmodValue("tornadoZ", player);
		if (tornadoZVal != 0) {
			// from schmovin!!
			var playerColumn = column % field.field.keyCount;
			var columnPhaseShift = (playerColumn * PI_THIRD) + getSubmodValue("tornadoZOffset", player);
			var phaseShift = (diff / 135) * (1 + getSubmodValue("tornadoZPeriod", player));
			var returnReceptorToZeroOffsetX = (-sin(-columnPhaseShift) + 1) * Note.halfWidth * keyCunt;
			var offsetX = (-sin(phaseShift - columnPhaseShift) + 1) * Note.halfWidth * keyCunt - returnReceptorToZeroOffsetX;
			pos.z += offsetX * tornadoZVal;
		}

		var tornadoTanZVal = getSubmodValue("tornadoTanZ", player);
		if (tornadoTanZVal != 0) {
			// from schmovin!!
			var playerColumn = column % field.field.keyCount;
			var columnPhaseShift = (playerColumn * PI_THIRD) + getSubmodValue("tornadoTanZOffset", player) + Math.PI;
			var phaseShift = (diff / 135) * (1 + getSubmodValue("tornadoTanZPeriod", player));
			var returnReceptorToZeroOffsetX = (-sin(-columnPhaseShift) + 1) * Note.halfWidth * keyCunt;
			var offsetX = (-tan(phaseShift - columnPhaseShift) + 1) * Note.halfWidth * keyCunt - returnReceptorToZeroOffsetX;
			pos.z += offsetX * tornadoTanZVal;
		}
		
		var itgTornadoVal = getSubmodValue("itgTornado", player);
		var itgTornadoTanVal = getSubmodValue("itgTornadoTan", player);

		if (itgTornadoVal != 0 || itgTornadoTanVal != 0){
			// OpenITG/NotITG Tornado

			var wide = field.field.keyCount > 4;
			var width = wide ? 2 : 3;
			var startColumn:Int = Std.int(CoolMath.boundTo(column - width, 0, field.field.keyCount - 1));
			var endColumn:Int = Std.int(CoolMath.boundTo(column + width, 0, field.field.keyCount - 1));

			var minX = field.field.getBaseX(startColumn);
			var maxX = field.field.getBaseX(endColumn);
			var realPixel = field.field.getBaseX(column);

			var posBetween = CoolMath.scale(realPixel, minX, maxX, -1, 1);

			if (itgTornadoVal != 0){
				var rads = Math.acos(posBetween);
				var period = getSubmodValue("itgTornadoPeriod", player);
				var offset = getSubmodValue("itgTornadoOffset", player);
				rads += (diff + offset) * (6 + period * 6) / FlxG.height;
				var adjusted = CoolMath.scale(cos(rads), -1, 1, minX, maxX);
				pos.x += (adjusted - realPixel) * itgTornadoVal;
			}

			if (itgTornadoTanVal != 0){
				var rads = Math.acos(posBetween);
				var period = getSubmodValue("itgTornadoTanPeriod", player);
				var offset = getSubmodValue("itgTornadoTanOffset", player);
				rads += (diff + offset) * (6 + period * 6) / FlxG.height;
				var adjusted = CoolMath.scale(tan(rads), -1, 1, minX, maxX);
				pos.x += (adjusted - realPixel) * itgTornadoTanVal;
			}
		}

		var digitalVal = getSubmodValue("digital", player);
		if(digitalVal > 0){
			var steps = this.getSubmodValue("digitalSteps", player) + 1;
			var period = this.getSubmodValue("digitalOffset", player);
			var offset = this.getSubmodValue("digitalPeriod", player);

			pos.x += (digitalVal * Note.halfWidth) * Math.floor(0.5 + (steps * FlxMath.fastSin(getDigitalAngle(diff, offset, period)))) / steps;
		}

		var digitalZVal = getSubmodValue("digitalZ", player);
		if (digitalZVal > 0) {
			var steps = this.getSubmodValue("digitalZSteps", player) + 1;
			var period = this.getSubmodValue("digitalZOffset", player);
			var offset = this.getSubmodValue("digitalZPeriod", player);

			pos.z += (digitalZVal * Note.halfWidth) * Math.floor(0.5 + (steps * FlxMath.fastSin(getDigitalAngle(diff, offset, period)))) / steps;
		}

		return pos;
	}

	override function getSubmods()
	{
		return [
			'xmode',

			'zigzag',
			'zigzagPeriod',
			'zigzagOffset',

			'sawtooth',
			'sawtoothPeriod',

			'square',
			'squareOffset',
			'squarePeriod',

			'bounce',
			'bounceOffset',
			'bouncePeriod',

			'zigzagZ',
			'zigzagZPeriod',
			'zigzagZOffset',

			'bounceZ',
			'bounceZOffset',
			'bounceZPeriod',	

			'digital',
			"digitalSteps",
			"digitalOffset",
			"digitalPeriod",

			"digitalZ",
			'digitalZSteps',
			"digitalZOffset",
			"digitalZPeriod",
			
			"tornadoPeriod",
			"tornadoOffset",
			
			"tornadoZ",
			"tornadoZPeriod",
			"tornadoZOffset",
			
			"tornadoTan",
			"tornadoTanPeriod",
			"tornadoTanOffset",

			"tornadoTanZ",
			"tornadoTanZPeriod",
			"tornadoTanZOffset",

			"itgTornado",
			"itgTornadoTan",
			"itgTornadoOffset",
			"itgTornadoPeriod",
			"itgTornadoTanOffset",
			"itgTornadoTanPeriod",


			// TODO: maybe some sorta scrollDirectionX/Y/Z which'll make it so the note moves towards the receptor in that direction
		];
	}
}