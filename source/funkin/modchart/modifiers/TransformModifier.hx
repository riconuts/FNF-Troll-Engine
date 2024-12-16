package funkin.modchart.modifiers;

class TransformModifier extends NoteModifier { // this'll be transformX in ModManager
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
		
		pos.x += (getSubmodValue("moveX", player) + getSubmodValue('move${data}X', player)) * Note.swagWidth;
		pos.y += (getSubmodValue("moveY", player) + getSubmodValue('move${data}Y', player)) * Note.swagWidth;
		pos.z += (getSubmodValue("moveZ", player) + getSubmodValue('move${data}Z', player)) * Note.swagWidth;

		return pos;
	}

	override function getSubmods(){
		var subMods:Array<String> = ["transformY", "transformZ", "transformX-a", "transformY-a", "transformZ-a", "moveX", "moveY", "moveZ"];

		for(i in 0...PlayState.keyCount){
			subMods.push('transform${i}X');
			subMods.push('transform${i}Y');
			subMods.push('transform${i}Z');
			subMods.push('transform${i}X-a');
			subMods.push('transform${i}Y-a');
			subMods.push('transform${i}Z-a');

			subMods.push('move${i}X');
			subMods.push('move${i}Y');
			subMods.push('move${i}Z');
		}
		return subMods;
	}
}
