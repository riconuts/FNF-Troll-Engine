package modchart.modifiers;

import modchart.Modifier.RenderInfo;
import flixel.math.FlxPoint;
import modchart.Modifier.ModifierOrder;
import math.Vector3;
import playfields.NoteField;

class ScaleModifier extends NoteModifier {
	override function getName()return 'tiny';
	override function getOrder()return PRE_REVERSE;
	inline function lerp(a:Float, b:Float, c:Float)
	{
		return a + (b - a) * c;
	}
	function daScale(sprite:Dynamic, scale:FlxPoint, data:Int, player:Int)
	{
		var y = scale.y;
		scale.x *= 1 - getValue(player);
		scale.y *= 1 - getValue(player);
		var tinyX = getSubmodValue("tinyX", player) + getSubmodValue('tiny${data}X', player);
		var tinyY = getSubmodValue("tinyY", player) + getSubmodValue('tiny${data}Y', player);

		scale.x *= 1 - tinyX;
		scale.y *= 1 - tinyY;
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

	override function getExtraInfo(diff:Float, tDiff:Float, beat:Float, info:RenderInfo, sprite:FlxSprite, player:Int, data:Int):RenderInfo
	{
		if (!(sprite is NoteObject))
			return info;

		var obj:NoteObject = cast sprite;
		var scale = daScale(obj, info.scale, obj.noteData, player);
		if ((sprite is Note))
		{
			var note:Note = cast sprite;
			if (note.isSustainNote)
				scale.y = 1;
		}
		info.scale = scale;
		return info;
	}

	override function getSubmods()
	{
		var subMods:Array<String> = ["squish", "stretch", "tinyX", "tinyY"];

		for (i in 0...4)
		{
			subMods.push('tiny${i}X');
			subMods.push('tiny${i}Y');
			subMods.push('squish${i}');
			subMods.push('stretch${i}');
		}
		return subMods;
	}

}