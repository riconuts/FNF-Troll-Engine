package funkin.modchart.modifiers;

import flixel.math.FlxAngle;
import flixel.FlxSprite;
import funkin.ui.*;
import funkin.modchart.*;
import flixel.math.FlxPoint;
import flixel.math.FlxMath;
import flixel.FlxG;
import math.Vector3;
import math.*;
import funkin.objects.playfields.NoteField;

class RotateModifier extends NoteModifier { // this'll be rotateX in ModManager
	override function getName()
		return '${prefix}rotateX';

	override function getOrder()
		return Modifier.ModifierOrder.LAST + 2;

    inline function lerp(a:Float,b:Float,c:Float){
        return a+(b-a)*c;
    }
    var daOrigin:Vector3;
    var prefix:String;
	public function new(modMgr:ModManager, ?prefix:String = '', ?origin:Vector3, ?parent:Modifier){
        this.prefix=prefix;
        this.daOrigin=origin;
        super(modMgr, parent);

    }


	override function getPos( visualDiff:Float, timeDiff:Float, beat:Float, pos:Vector3, data:Int, player:Int, obj:FlxSprite, field:NoteField){
		var origin:Vector3 = new Vector3(modMgr.getBaseX(data, player, field.field.keyCount), FlxG.height* 0.5);
        if(daOrigin!=null)origin=daOrigin;

        var diff = pos.subtract(origin);
		var out = VectorHelpers.rotateV3(diff, (getValue(player) + getSubmodValue('${prefix}${data}rotateX', player)) * FlxAngle.TO_RAD,
			(getSubmodValue('${prefix}rotateY', player) + getSubmodValue('${prefix}${data}rotateY', player)) * FlxAngle.TO_RAD,
			(getSubmodValue('${prefix}rotateZ', player) + getSubmodValue('${prefix}${data}rotateZ', player)) * FlxAngle.TO_RAD);
        return origin.add(out);
    }

    override function getSubmods(){
		var shid:Array<String> = ['rotateX', 'rotateY', 'rotateZ'];

		var submods:Array<String> = [
			for (d in 0...4)
			{
				for (s in shid)
					'$prefix$d$s';
			}
		];

		submods.push('${prefix}rotateY');
		submods.push('${prefix}rotateZ');
		return submods;
    }
}
