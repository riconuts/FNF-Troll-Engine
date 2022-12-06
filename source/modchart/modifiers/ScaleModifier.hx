package modchart.modifiers;

import flixel.math.FlxPoint;
import modchart.Modifier.ModifierOrder;
import math.Vector3;

class ScaleModifier extends NoteModifier {
	override function getName()return 'mini';
	override function getOrder()return PRE_REVERSE;
	inline function lerp(a:Float, b:Float, c:Float)
	{
		return a + (b - a) * c;
	}
	function getScale(sprite:Dynamic, scale:FlxPoint, data:Int, player:Int)
	{
		var y = scale.y;
		scale.x *= 1 - getValue(player);
		scale.y *= 1 - getValue(player);
		var miniX = getSubmodValue("miniX", player) + getSubmodValue('mini${data}X', player);
		var miniY = getSubmodValue("miniY", player) + getSubmodValue('mini${data}Y', player);

		scale.x *= 1 - miniX;
		scale.y *= 1 - miniY;
		var angle = 0;

		var stretch = getSubmodValue("stretch", player) + getSubmodValue('stretch${data}', player);
		var squish = getSubmodValue("squish", player) + getSubmodValue('squish${data}', player);

		var stretchX = lerp(1, 0.5, stretch);
		var stretchY = lerp(1, 2, stretch);

		var squishX = lerp(1, 2, squish);
		var squishY = lerp(1, 0.5, squish);

		scale.x *= (Math.sin(angle * Math.PI / 180) * squishY) + (Math.cos(angle * Math.PI / 180) * squishX);
		scale.x *= (Math.sin(angle * Math.PI / 180) * stretchY) + (Math.cos(angle * Math.PI / 180) * stretchX);

		scale.y *= (Math.cos(angle * Math.PI / 180) * stretchY) + (Math.sin(angle * Math.PI / 180) * stretchX);
		scale.y *= (Math.cos(angle * Math.PI / 180) * squishY) + (Math.sin(angle * Math.PI / 180) * squishX);
		if ((sprite is Note) && sprite.isSustainNote)
			scale.y = y;

		return scale;
	}
	
	override function shouldExecute(player:Int, val:Float)
		return true;

	override function ignorePos()
		return true;

	override function ignoreUpdateReceptor()
		return false;

	override function ignoreUpdateNote()
		return false;

	override function updateNote(beat:Float, note:Note, pos:Vector3, player:Int)
	{
		var scale = getScale(note, FlxPoint.weak(note.defScale.x, note.defScale.y), note.noteData, player);
		if(note.isSustainNote)scale.y = note.defScale.y;
		
		note.scale.copyFrom(scale);
		scale.putWeak();
	}

	override function updateReceptor(beat:Float, receptor:StrumNote, pos:Vector3, player:Int)
	{
		var scale = getScale(receptor, FlxPoint.weak(receptor.defScale.x, receptor.defScale.y), receptor.noteData, player);
		receptor.scale.copyFrom(scale);
		scale.putWeak();
	}

	override function getSubmods()
	{
		var subMods:Array<String> = ["squish", "stretch", "miniX", "miniY"];

		var receptors = modMgr.receptors[0];
		var kNum = receptors.length;
		for (i in 0...4)
		{
			subMods.push('mini${i}X');
			subMods.push('mini${i}Y');
			subMods.push('squish${i}');
			subMods.push('stretch${i}');
		}
		return subMods;
	}

}