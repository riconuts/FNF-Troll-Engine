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

class ColumnRotateModifier extends NoteModifier { // this'll be rotateX in ModManager
	override function getName()
		return 'columnrotater';

	override function getOrder()
		return Modifier.ModifierOrder.LAST - 10;

	inline function lerp(a:Float,b:Float,c:Float){
		return a+(b-a)*c;
	}
	
	private var origin = new Vector3(); 
	override function getPos( visualDiff:Float, timeDiff:Float, beat:Float, pos:Vector3, data:Int, player:Int, obj:FlxSprite, field:NoteField){
		origin.x = field.field.getBaseX(data);
		origin.y = FlxG.height * 0.5;

		pos.decrementBy(origin); // diff

		VectorHelpers.rotateV3(pos, // out
			getSubmodValue('${data}rotateX', player) * FlxAngle.TO_RAD, 
			getSubmodValue('${data}rotateY',player)* FlxAngle.TO_RAD, 
			getSubmodValue('${data}rotateZ',player)* FlxAngle.TO_RAD, 
		pos);
		
		pos.incrementBy(origin);
		return pos;
	}

	override function getSubmods(){
		var shid:Array<String>=['rotateX','rotateY','rotateZ'];

		var submods:Array<String> = [
			for (d in 0...PlayState.keyCount)
			{
				for(s in shid)
					'$d$s';
			}
		];

		return submods;
	}
}
