package funkin.modchart.modifiers;

class SpiralModifier extends NoteModifier {
	override function getPos(visualDiff:Float, timeDiff:Float, beat:Float, pos:Vector3, column:Int, player:Int, obj:FlxSprite, field:NoteField) {
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

		var schmovinSpiralX = getSubmodValue("schmovinSpiralX", player);
		var schmovinSpiralY = getSubmodValue("schmovinSpiralY", player);
		var schmovinSpiralZ = getSubmodValue("schmovinSpiralZ", player);
		
		// Best combined with reverse 0.5 and flip 0.5
		if(schmovinSpiralX != 0){
			var dist = getSubmodValue("schmovinSpiralXSpacing", player) * 33.5;
			var beat = ((getSubmodValue("schmovinSpiralXSpeed", player) * beat) + (getSubmodValue("schmovinSpiralXOffset", player))) * Math.PI / 4;
			var radiusOffset = -visualDiff / 4; 
			var radius = radiusOffset + dist * column % field.field.keyCount;

			pos.x += FlxMath.fastCos(-visualDiff / Conductor.crotchet * Math.PI + beat) * radius * schmovinSpiralX;
		}
		if (schmovinSpiralY != 0) {
			var dist = getSubmodValue("schmovinSpiralYSpacing", player) * 33.5;
			var beat = ((getSubmodValue("schmovinSpiralYSpeed", player) * beat) + (getSubmodValue("schmovinSpiralYOffset", player))) * Math.PI / 4;
			var radiusOffset = -visualDiff / 4;
			var radius = radiusOffset + dist * column % field.field.keyCount;

			pos.y += FlxMath.fastSin(-visualDiff / Conductor.crotchet * Math.PI + beat) * radius * schmovinSpiralY;
		}
		if (schmovinSpiralZ != 0) {
			var dist = getSubmodValue("schmovinSpiralZSpacing", player) * 33.5;
			var beat = ((getSubmodValue("schmovinSpiralZSpeed", player) * beat) + (getSubmodValue("schmovinSpiralZOffset", player))) * Math.PI / 4;
			var radiusOffset = 	-visualDiff / 4;
			var radius = radiusOffset + dist * column % field.field.keyCount;

			pos.z += FlxMath.fastSin(-visualDiff / Conductor.crotchet * Math.PI + beat) * radius * schmovinSpiralZ;
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
			"spiralZPeriod",

			"schmovinSpiralX",
			"schmovinSpiralY",
			"schmovinSpiralZ",

			"schmovinSpiralXSpeed",
			"schmovinSpiralYSpeed",
			"schmovinSpiralZSpeed",

			"schmovinSpiralXOffset",
			"schmovinSpiralYOffset",
			"schmovinSpiralZOffset",

			"schmovinSpiralXSpacing",
			"schmovinSpiralYSpacing",
			"schmovinSpiralZSpacing"
		];
	}
}