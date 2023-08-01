package modchart.modifiers;
import flixel.FlxSprite;
import ui.*;
import modchart.*;
import flixel.math.FlxPoint;
import flixel.math.FlxMath;
import flixel.FlxG;
import math.*;
import playfields.NoteField;

class DrunkModifier extends NoteModifier {
    override function getName()return 'drunk';

	inline function applyDrunk(axis:String, player:Int, time:Float, visualDiff:Float, data:Float){
        var perc = axis == '' ? getValue(player) : getSubmodValue('drunk${axis}', player);
		var speed = getSubmodValue('drunk${axis}Speed', player);
		var period = getSubmodValue('drunk${axis}Period', player);
		var offset = getSubmodValue('drunk${axis}Offset', player);

        if(perc!=0){
            var angle = time * (1 + speed) + data * ((offset * 0.2) + 0.2) + visualDiff * ((period * 10) + 10) / FlxG.height;
            return perc * (FlxMath.fastCos(angle) * Note.swagWidth * 0.5);
        }
        return 0;
    }

	inline function applyTipsy(axis:String, player:Int, time:Float, visualDiff:Float, data:Float)
	{
        var perc = getSubmodValue('tipsy${axis}', player);
		var speed = getSubmodValue('tipsy${axis}Speed', player);
		var offset = getSubmodValue('tipsy${axis}Offset', player);

		if (perc != 0)
		    return perc * (FlxMath.fastCos((time * ((speed * 1.2) + 1.2) + data * ((offset * 1.8) + 1.8))) * Note.swagWidth * .4);
        
        return 0;
    }

	inline function applyBumpy(axis:String, player:Int, time:Float, visualDiff:Float, data:Float){
        var perc = getSubmodValue('bumpy${axis}', player);
		var period = getSubmodValue('bumpy${axis}Period', player);
		var offset = getSubmodValue('bumpy${axis}Offset', player);
		if (perc != 0 && period != -1){
            var angle = (visualDiff + (100.0 * offset)) / ((period * 24.0) + 24.0);
		    return (perc * 40 * FlxMath.fastSin(angle));
        }
        return 0;
    }


	 override function getPos( visualDiff:Float, timeDiff:Float, beat:Float, pos:Vector3, data:Int, player:Int, obj:FlxSprite, field:NoteField)
	{
        var time = (Conductor.songPosition/1000);
		pos.x += 
            applyDrunk("", player, time, visualDiff, data) 
            + applyTipsy("X", player, time, visualDiff, data)
			+ applyBumpy("X", player, time, visualDiff, data);
		pos.y += 
            applyDrunk("Y", player, time, visualDiff, data) 
            + applyTipsy("", player, time, visualDiff, data)
			+ applyBumpy("Y", player, time, visualDiff, data);
		pos.z += 
            applyDrunk("Z", player, time, visualDiff, data)
            + applyTipsy("Z", player, time, visualDiff, data)
			+ applyBumpy("", player, time, visualDiff, data);
        return pos;
    }

    override function getAliases(){
        return [
            "tipZ" => "tipsyZ",
            "tipZSpeed" => "tipsyZSpeed",
            "tipZOffset" => "tipsyZOffset"
        ];
    }

    override function getSubmods(){
        return [
            // Z
            "bumpy",
            "bumpyOffset",
            "bumpyPeriod",

			"tipsyZ",
			"tipsyZSpeed",
			"tipsyZOffset", 

			"drunkZ",
			"drunkZSpeed",
			"drunkZOffset",
			"drunkZPeriod",
            // Y
			"tipsy",
			"tipsySpeed",
			"tipsyOffset",

			"bumpyY", 
            "bumpyYOffset", 
            "bumpyYPeriod",
            
			"drunkY",
			"drunkYSpeed",
			"drunkYOffset",
			"drunkYPeriod",

            // X
			"tipsyX", 
            "tipsyXSpeed",
			"tipsyXOffset", 

			"bumpyX",
			"bumpyXOffset",
			"bumpyXPeriod",

			"drunkSpeed",
			"drunkOffset",
			"drunkPeriod"
        ];
    }

}
