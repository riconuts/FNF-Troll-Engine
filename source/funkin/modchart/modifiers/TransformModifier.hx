package funkin.modchart.modifiers;
import flixel.FlxSprite;
import funkin.ui.*;
import funkin.modchart.*;
import flixel.math.FlxPoint;
import flixel.math.FlxMath;
import flixel.FlxG;
import math.Vector3;
import math.*;
import funkin.objects.playfields.NoteField;

class TransformModifier extends NoteModifier { // this'll be transformX in ModManager
    inline function lerp(a:Float,b:Float,c:Float){
        return a+(b-a)*c;
    }

	override function getName()
		return 'transformX';

    override function getOrder()
        return Modifier.ModifierOrder.LAST;

     override function getPos( visualDiff:Float, timeDiff:Float, beat:Float, pos:Vector3, data:Int, player:Int, obj:FlxSprite, field:NoteField)
    {
        pos.x += getValue(player) + getSubmodValue("transformX-a",player);
		pos.y += getSubmodValue("transformY", player) + getSubmodValue("transformY-a",player);
        pos.z += getSubmodValue('transformZ', player) + getSubmodValue("transformZ-a",player);
        
		pos.x += getSubmodValue('transform${data}X', player) + getSubmodValue('transform${data}X-a', player);
		pos.y += getSubmodValue('transform${data}Y', player) + getSubmodValue('transform${data}Y-a', player);
		pos.z += getSubmodValue('transform${data}Z', player) + getSubmodValue('transform${data}Z-a', player);
        
        return pos;
    }

    override function getAliases(){
        return [
            // Outfox/ITG modifiers
            "moveX" => "transformX", 
            "moveY" => "transformY",
            "moveZ" => "transformZ",
        ];
    }

    override function getSubmods(){
		var subMods:Array<String> = ["transformY", "transformZ", "transformX-a", "transformY-a", "transformZ-a"];

        for(i in 0...4){
			subMods.push('transform${i}X');
			subMods.push('transform${i}Y');
			subMods.push('transform${i}Z');
			subMods.push('transform${i}X-a');
			subMods.push('transform${i}Y-a');
			subMods.push('transform${i}Z-a');
        }
        return subMods;
    }
}
