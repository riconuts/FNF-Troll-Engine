package modchart.modifiers;

import flixel.FlxSprite;
import math.Vector3;
import playfields.NoteField;

class SwapModifier extends NoteModifier
{
	override function getName()
		return 'flip';

	override function getPos(diff:Float, tDiff:Float, beat:Float, pos:Vector3, data:Int, player:Int, obj:FlxSprite, field:NoteField)
	{
        if(getSubmodValue('invert', player) != 0){
			var distance = Note.swagWidth * ((data % 2 == 0) ? 1 : -1);
			pos.x += distance * getSubmodValue('invert', player);
        }
        
		if (getValue(player) != 0){
            var distance = Note.swagWidth * 2 * (1.5 - data);
            pos.x += distance * getValue(player);
        }
		return pos;
	}

	override function getSubmods()
	{
		return ["invert"];
	}
}