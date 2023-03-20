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

	// thanks schmoovin'
	function rotateV3(vec:Vector3, xA:Float, yA:Float, zA:Float):Vector3
	{
		var rotateZ = CoolUtil.rotate(vec.x, vec.y, zA);
		var offZ = new Vector3(rotateZ.x, rotateZ.y, vec.z);

		var rotateX = CoolUtil.rotate(offZ.z, offZ.y, xA);
		var offX = new Vector3(offZ.x, rotateX.y, rotateX.x);

		var rotateY = CoolUtil.rotate(offX.x, offX.z, yA);
		var offY = new Vector3(rotateY.x, offX.y, rotateY.y);

		rotateZ.putWeak();
		rotateX.putWeak();
		rotateY.putWeak();

		return offY;
	}

	override function modifyVert(beat:Float, vert:Vector3, idx:Int, obj:FlxSprite, pos:Vector3, player:Int, data:Int):Vector3
	{
		// TODO: add proper confusion where the notes spin as they travel up to the receptor instead of confusion just being confusionOffset
        // also TODO: confusion for every axis (X, Y and Z)
        
        var angle:Float = 0;
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
		vert = rotateV3(vert, 0, 0, FlxAngle.TO_RAD * angle);
        return vert;
	}

   /*override function updateNote(beat:Float, note:Note, player:Int)
    {
        if(!note.isSustainNote)
			note.angle = (getValue(player) + getSubmodValue('confusion${note.noteData}', player) + getSubmodValue('note${note.noteData}Angle',player));
        else
            note.angle = note.mAngle;
    }

    override function updateReceptor(beat:Float, receptor:StrumNote, player:Int)
		receptor.angle = (getValue(player)
		+ getSubmodValue('confusion${receptor.noteData}', player)
			+ getSubmodValue('receptor${receptor.noteData}Angle', player));*/

    

    override function getSubmods(){
        var subMods:Array<String> = ["noteAngle","receptorAngle"];

        for(i in 0...4){
            subMods.push('note${i}Angle');
            subMods.push('receptor${i}Angle');
            subMods.push('confusion${i}');
        }

        return subMods;
    }
}
