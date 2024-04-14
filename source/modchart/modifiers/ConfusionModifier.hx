package modchart.modifiers;

import playfields.NoteField;
import ui.*;
import modchart.*;
import flixel.math.FlxPoint;
import flixel.math.FlxMath;
import math.*;
import flixel.math.FlxAngle;

class ConfusionModifier extends NoteModifier {
    override function getName()return 'confusion';
	override function shouldExecute(player:Int, val:Float)return true;
	override function isRenderMod()return true;

    function getConfusion(?suffix:String = '', beat:Float, column:Int, player:Int, onlyOffset:Bool=false){
		var mainAngle:Float = 0;
		if (!onlyOffset){
            var main = (suffix == '' ? getValue(player) : getSubmodValue('confusion$suffix', player)) + getSubmodValue('confusion${suffix}${column}', player);
		    mainAngle = -((beat * main) % 360);
        }
		var constAngle:Float = getSubmodValue('confusion${suffix}Offset', player) + getSubmodValue('confusion${suffix}Offset${column}', player);
		return mainAngle + constAngle;
    }

	override function modifyVert(beat:Float, vert:Vector3, idx:Int, obj:FlxSprite, pos:Vector3, player:Int, data:Int, field:NoteField):Vector3
	{
		var angleX:Float = getConfusion("X", beat, data, player);
		var angleY:Float = getConfusion("Y", beat, data, player);
        var angleZ:Float = getConfusion(beat, data, player);

        if((obj is Note)){
			var note:Note = cast obj;
			var speed = modMgr.getNoteSpeed(note, player);
			var yPos:Float = ((Conductor.visualPosition - note.visualTime)) * speed;

			angleX += getSubmodValue("roll", player) * yPos * 0.5;
			angleY += getSubmodValue("twirl", player) * yPos * 0.5;
			angleX += getSubmodValue("noteAngleX", player) + getSubmodValue("note" + data + "AngleX", player);
			angleY += getSubmodValue("noteAngleY", player) + getSubmodValue("note" + data + "AngleY", player);

			if(note.isSustainNote){
				angleZ = 0;	
                trace(angleX, angleY, angleZ);
            }else{
				var noteBeat = note.beat - beat;
				
				angleZ += (noteBeat * getSubmodValue("dizzy", player) % 360) * (180 / Math.PI);
				angleZ += getSubmodValue("noteAngle", player) + getSubmodValue("note" + data + "Angle", player);

			}

			angleZ += note.typeOffsetAngle;
        }else if((obj is StrumNote)){
			angleX += getSubmodValue("receptorAngleX", player) + getSubmodValue("receptor" + data + "AngleX", player);
			angleY += getSubmodValue("receptorAngleY", player) + getSubmodValue("receptor" + data + "AngleY", player);
			angleZ += getSubmodValue("receptorAngle", player) + getSubmodValue("receptor" + data + "Angle", player);
        }else{
            // probably a splash or smth
            angleX = 0;
            angleY = 0;
            angleZ = 0;
        }

		vert = VectorHelpers.rotateV3(vert, FlxAngle.TO_RAD *  angleX, FlxAngle.TO_RAD *  angleY, FlxAngle.TO_RAD * angleZ);
        return vert;
	}
    
    override function getSubmods(){
		var subMods:Array<String> = [
			"confusionOffset",
			"confusionX",
			"confusionY",
			"confusionXOffset",
			"confusionYOffset",
			"noteAngleX",
			"receptorAngleX",
			"noteAngleY",
			"receptorAngleY",
			"noteAngle", 
            "receptorAngle",
			"roll",
			"twirl",
			"dizzy"
        ];

        for(i in 0...4){
			subMods.push('note${i}AngleX');
			subMods.push('receptor${i}AngleX');
			subMods.push('note${i}AngleY');
			subMods.push('receptor${i}AngleY');
			subMods.push('note${i}Angle');
			subMods.push('receptor${i}Angle');
            subMods.push('confusion${i}');
			subMods.push('confusionOffset${i}');
			subMods.push('confusionX${i}');
			subMods.push('confusionXOffset${i}');
			subMods.push('confusionY${i}');
			subMods.push('confusionYOffset${i}');
        }

        return subMods;
    }
}
