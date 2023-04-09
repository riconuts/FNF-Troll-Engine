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

	override function isRenderMod()
		return true;

	// TODO: seperate into modifyNoteVert and modifyReceptorVert?

	override function modifyVert(beat:Float, vert:Vector3, idx:Int, sprite:FlxSprite, pos:Vector3, player:Int, data:Int):Vector3
	{
		if(!(sprite is NoteObject))return vert;

		var obj:NoteObject = cast sprite;
		var scale = getScale(obj, FlxPoint.weak(1, 1), obj.noteData, player);
		if ((sprite is Note)){
			var note:Note = cast sprite;
			if (note.isSustainNote)
				scale.y = 1;
		}
		vert.x *= scale.x;
		vert.y *= scale.y;
		scale.putWeak();
		return vert;
	}

/* 	override function ignoreUpdateReceptor()
		return false;

	override function ignoreUpdateNote()
		return false;

	override function updateNote(beat:Float, note:Note, player:Int)
	{
		var scale = getScale(note, FlxPoint.weak(note.defScale.x, note.defScale.y), note.noteData, player);
		if(note.isSustainNote)scale.y = note.defScale.y;
		
		note.scale.copyFrom(scale);
		scale.putWeak();
	}

	override function updateReceptor(beat:Float, receptor:StrumNote, player:Int)
	{
		var scale = getScale(receptor, FlxPoint.weak(receptor.defScale.x, receptor.defScale.y), receptor.noteData, player);
		receptor.scale.copyFrom(scale);
		scale.putWeak();
	} */

	override function getSubmods()
	{
		var subMods:Array<String> = ["squish", "stretch", "miniX", "miniY"];

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