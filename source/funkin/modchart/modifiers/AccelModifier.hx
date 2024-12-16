package funkin.modchart.modifiers;

class AccelModifier extends NoteModifier
{ // this'll be boost in ModManager
	override function getName()
		return 'boost';

	override function getPos(visualDiff:Float, timeDiff:Float, beat:Float, pos:Vector3, data:Int, player:Int, obj:FlxSprite, field:NoteField)
	{
		if (getOtherValue("movePastReceptors", player) == 0 && visualDiff<=0)
			return pos;
		
		var wave = getSubmodValue("wave", player);
		var brake = getSubmodValue("brake", player);
		var boost = getValue(player);
		var effectHeight = 720;

		var yAdjust:Float = 0;
		var reverse:Dynamic = modMgr.register.get("reverse");
		var reversePercent = reverse.getReverseValue(data, player);
		var mult = CoolUtil.scale(reversePercent, 0, 1, 1, -1);

		if (brake != 0)
		{
			var scale = CoolUtil.scale(visualDiff, 0, effectHeight, 0, 1);
			var off = visualDiff * scale;
			yAdjust += CoolUtil.clamp(brake * (off - visualDiff), -600, 600);
		}

		if (boost != 0)
		{
			var off = visualDiff * 1.5 / ((visualDiff + effectHeight / 1.2) / effectHeight);
			yAdjust += CoolUtil.clamp(boost * (off - visualDiff), -600, 600);
		}

		if (getSubmodValue("wavePeriod", player) != -1 /**< no division by 0**/ && wave != 0) 
			yAdjust += wave * 40 * FlxMath.fastSin(visualDiff / ((114 * getSubmodValue("wavePeriod", player)) + 114));

		pos.y += yAdjust * mult;
		return pos;
	}

	override function getSubmods()
	{
		var subMods:Array<String> = ["brake", "wave", "wavePeriod"];
		return subMods;
	}
}
