package funkin.modchart.modifiers;

import math.CoolMath.triangle;
import math.CoolMath.square;
import flixel.math.FlxMath.fastSin as sin;
import flixel.math.FlxMath.fastCos as cos;

class PathModifier extends NoteModifier
{
	override function getName()
		return 'tornado';

	inline function getDigitalAngle(yOffset:Float, offset:Float, period:Float) {
		return Math.PI * (yOffset + (1 * offset)) / (Note.swagWidth + (period * Note.swagWidth));
	}

	static final PI_THIRD:Float = Math.PI / 3.0;
	override function getPos(diff:Float, tDiff:Float, beat:Float, pos:Vector3, data:Int, player:Int, obj:FlxSprite, field:NoteField)
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

		var tornadoVal = getValue(player);
		if (tornadoVal != 0) {
			// from schmovin!!
			var playerColumn = data % 4;
			var columnPhaseShift = playerColumn * PI_THIRD;
			var phaseShift = diff / 135;
			var returnReceptorToZeroOffsetX = (-cos(-columnPhaseShift) + 1) * Note.halfWidth * 3;
			var offsetX = (-cos(phaseShift - columnPhaseShift) + 1) * Note.halfWidth * 3 - returnReceptorToZeroOffsetX;
			pos.x += offsetX * tornadoVal;
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
			"digitalZPeriod"

			// TODO: maybe some sorta scrollDirectionX/Y/Z which'll make it so the note moves towards the receptor in that direction
		];
	}
}