package funkin.modchart.modifiers;

class SpiralModifier extends NoteModifier {
	override function getPos(visualDiff:Float, timeDiff:Float, beat:Float, pos:Vector3, data:Int, player:Int, obj:FlxSprite, field:NoteField) {
		var spiralX = getValue(player);
		var spiralY = getSubmodValue("spiralY", player);
		var spiralZ = getSubmodValue("spiralZ", player);

		if (spiralX != 0) {
			var offset = getSubmodValue("spiralXOffset", player);
			var period = getSubmodValue("spiralXPeriod", player);
			pos.x += visualDiff * spiralX * FlxMath.fastCos((period + 1) * visualDiff + offset);
		}
		if (spiralY != 0) {
			var offset = getSubmodValue("spiralYOffset", player);
			var period = getSubmodValue("spiralYPeriod", player);
			pos.y += visualDiff * spiralY * FlxMath.fastSin((period + 1) * visualDiff + offset);
		}
		if (spiralZ != 0) {
			var offset = getSubmodValue("spiralZOffset", player);
			var period = getSubmodValue("spiralZPeriod", player);
			pos.z += visualDiff * spiralZ * FlxMath.fastSin((period + 1) * visualDiff + offset);
		}
		return pos;
	}

	override function getName() {
		return "spiralX";
	}

	override function getSubmods() {
		return [
			"spiralY",
			"spiralZ",
			"spiralXOffset",
			"spiralXPeriod",
			"spiralYOffset",
			"spiralYPeriod",
			"spiralZOffset",
			"spiralZPeriod"
		];
	}
}