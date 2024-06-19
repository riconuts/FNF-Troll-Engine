package funkin.modchart.modifiers;

import funkin.modchart.Modifier.RenderInfo;
import flixel.math.FlxPoint;
import funkin.modchart.Modifier.ModifierOrder;
import math.Vector3;
import funkin.objects.playfields.NoteField;
import flixel.math.FlxMath;

class ScaleModifier extends NoteModifier {
	override function getName()return 'tiny';
	override function getOrder()return PRE_REVERSE;
	inline function lerp(a:Float, b:Float, c:Float)
	{
		return a + (b - a) * c;
	}
	function daScale(sprite:Dynamic, scale:FlxPoint, data:Int, player:Int)
	{
		var tiny = getValue(player) + getSubmodValue('tiny${data}', player);
		var tinyX = (getSubmodValue("tinyX", player) + getSubmodValue('tiny${data}X', player));
		var tinyY = (getSubmodValue("tinyY", player) + getSubmodValue('tiny${data}Y', player));

		scale.x *= Math.pow(0.5, tinyX) * Math.pow(0.5, tiny);
		scale.y *= Math.pow(0.5, tinyY) * Math.pow(0.5, tiny);

		scale.x *= getSubmodValue("scale", player) 
			* getSubmodValue('scale${data}', player) 
			* getSubmodValue('scaleX', player)
			* getSubmodValue('scale${data}X', player);

		scale.y *= getSubmodValue("scale", player) 
			* getSubmodValue('scale${data}', player) 
			* getSubmodValue('scaleY', player)
			* getSubmodValue('scale${data}Y', player);
		var angle = 0;

		var stretch = getSubmodValue("stretch", player) + getSubmodValue('stretch${data}', player);
		var squish = getSubmodValue("squish", player) + getSubmodValue('squish${data}', player);

		var stretchX = lerp(1, 0.5, stretch);
		var stretchY = lerp(1, 2, stretch);

		var squishX = lerp(1, 2, squish);
		var squishY = lerp(1, 0.5, squish);

		scale.x *= (FlxMath.fastSin(angle * Math.PI / 180) * squishY) + (FlxMath.fastCos(angle * Math.PI / 180) * squishX);
		scale.x *= (FlxMath.fastSin(angle * Math.PI / 180) * stretchY) + (FlxMath.fastCos(angle * Math.PI / 180) * stretchX);

		scale.y *= (FlxMath.fastCos(angle * Math.PI / 180) * stretchY) + (FlxMath.fastSin(angle * Math.PI / 180) * stretchX);
		scale.y *= (FlxMath.fastCos(angle * Math.PI / 180) * squishY) + (FlxMath.fastSin(angle * Math.PI / 180) * squishX);
		
		if ((sprite is Note) && sprite.isSustainNote)
			scale.y = 1.0;

		return scale;
	}
	
	override function shouldExecute(player:Int, val:Float)
		return true;

	override function ignorePos()
		return false;

	// TODO: fix this

/* 	override function getPos(visualDiff:Float, timeDiff:Float, beat:Float, pos:Vector3, data:Int, player:Int, obj:FlxSprite, field:NoteField)
	{
		var tiny = getValue(player) + getSubmodValue('tiny${data}', player);
		var tinyPerc = Math.min(Math.pow(0.5, tiny), 1);
		switch (player)
		{
			case 0:
				pos.x -= FlxG.width * 0.5 - Note.swagWidth * 2 - 100;
			case 1:
				pos.x += FlxG.width * 0.5 - Note.swagWidth * 2 - 100;
		}
		pos.x -= FlxG.width * 0.5;
		pos.x *= tinyPerc;
		pos.x += FlxG.width * 0.5;
		switch (player)
		{
			case 0:
				pos.x += FlxG.width * 0.5 - Note.swagWidth * 2 - 100;
			case 1:
				pos.x -= FlxG.width * 0.5 - Note.swagWidth * 2 - 100;
		} 

		return pos;
	} */


	override function isRenderMod()
		return true;

	override function getExtraInfo(diff:Float, tDiff:Float, beat:Float, info:RenderInfo, sprite:FlxSprite, player:Int, data:Int):RenderInfo
	{
		if (sprite is NoteObject){
			var sprite:NoteObject = cast sprite;
			daScale(sprite, info.scale, sprite.column, player);
		}

		return info;
	}

	override function getSubmods()
	{
		var subMods:Array<String> = ["squish", "stretch", "scale", "scaleX", "scaleY", "tinyX", "tinyY"];

		for (i in 0...4)
		{
			subMods.push('tiny${i}');
			subMods.push('tiny${i}X');
			subMods.push('tiny${i}Y');
			subMods.push('scale${i}');
			subMods.push('scale${i}X');
			subMods.push('scale${i}Y');
			subMods.push('squish${i}');
			subMods.push('stretch${i}');
		}
		return subMods;
	}

}