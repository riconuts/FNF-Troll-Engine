package modchart.modifiers;
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

    function getConfusion(?suffix:String = '', beat:Float, column:Int, player:Int){
		var main = (suffix == '' ? getValue(player) : getSubmodValue('confusion$suffix', player)) + getSubmodValue('confusion${suffix}${column}', player);
        var mainAngle:Float = ((beat * main) % 360) * -180 / Math.PI;
		var constAngle:Float = getSubmodValue('confusion${suffix}Offset', player) + getSubmodValue('confusion${suffix}Offset${column}', player);

		return mainAngle + constAngle;
    }

	override function modifyVert(beat:Float, vert:Vector3, idx:Int, obj:FlxSprite, pos:Vector3, player:Int, data:Int):Vector3
	{
/*         var angle:Float = 0;
        if((obj is Note)){
            var note:Note = cast obj;
			if (!note.isSustainNote){
				angle = (getValue(player) + getSubmodValue('noteAngle', player) + getSubmodValue('confusion${note.noteData}', player) + getSubmodValue('note${note.noteData}Angle', player));
            }
            
        }else if((obj is StrumNote)){
            var receptor:StrumNote = cast obj;
			angle = (getValue(player) + getSubmodValue('receptorAngle', player) + getSubmodValue('confusion${receptor.noteData}', player)
				+ getSubmodValue('receptor${receptor.noteData}Angle', player));
        }
		//vert = vert.subtract(pos);
		vert = VectorHelpers.rotateV3(vert, 0, 0, FlxAngle.TO_RAD * angle);
        return vert; */

		

		var angleX:Float = getConfusion("X", beat, data, player);
		var angleY:Float = getConfusion("Y", beat, data, player);
        var angleZ = getConfusion(beat, data, player);
        if((obj is Note)){
			var note:Note = cast obj;
			var speed = PlayState.instance.songSpeed * note.multSpeed * modMgr.getValue("xmod", player);
			var yPos:Float = ((Conductor.visualPosition - note.visualTime)) * speed;

			angleX += getSubmodValue("roll", player) * yPos / 2;
			angleY += getSubmodValue("twirl", player) * yPos / 2;
			angleX += getSubmodValue("noteAngleX", player) + getSubmodValue("note" + data + "AngleX", player);
			angleY += getSubmodValue("noteAngleY", player) + getSubmodValue("note" + data + "AngleY", player);

			if(note.isSustainNote)
				angleZ = 0;	
			else{
				var noteBeat = Conductor.getBeat(note.strumTime) - beat;
				
				angleZ += (noteBeat * getSubmodValue("dizzy", player) % 360) * (180 / Math.PI);
				angleZ += getSubmodValue("noteAngle", player) + getSubmodValue("note" + data + "Angle", player);

			}
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
