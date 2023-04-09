package modchart.modifiers;
import flixel.math.FlxAngle;
import flixel.FlxSprite;
import ui.*;
import modchart.*;
import flixel.math.FlxPoint;
import math.Vector3;
import flixel.math.FlxMath;
import flixel.FlxG;
using StringTools;
import math.*;
// NOTE: THIS SHOULDNT HAVE ITS PERCENTAGE MODIFIED
// THIS IS JUST HERE TO ALLOW OTHER MODIFIERS TO HAVE PERSPECTIVE

// did my research
// i now know what a frustrum is lmao
// stuff ill forget after tonight

// its the next day and yea i forgot already LOL
// something somethng clipping idk

// either way
// perspective projection woo

class PerspectiveModifier extends NoteModifier {
  override function getName()return 'perspectiveDONTUSE';
	override function getOrder()
		return Modifier.ModifierOrder.LAST + 1000; // should ALWAYS go last
  override function shouldExecute(player:Int, val:Float)return true;

	override function isRenderMod()
		return true;

	override function getSubmods()
	{
		var subMods:Array<String> = ["fieldRoll", "fieldYaw", "fieldPitch", "fieldX", "fieldY", "fieldZ"];

		return subMods;
	}

	override function getPos( visualDiff:Float, timeDiff:Float, beat:Float, pos:Vector3, data:Int, player:Int, obj:FlxSprite)
	{
 		var origin = new Vector3(FlxG.width / 2, FlxG.height / 2); // vertex origin
		var fieldPos = new Vector3(-getSubmodPercent("fieldX", player) / 100,
			-getSubmodPercent("fieldY", player) / 100,
			1280
			+ getSubmodPercent("fieldZ", player) / 100); // playfield pos
			
		
		
		var originMod = pos.subtract(origin); // moves the vertex to the appropriate position on screen based on origin
		var rotated = VectorHelpers.rotateV3(originMod, getSubmodValue("fieldPitch", player) * FlxAngle.TO_RAD, getSubmodValue("fieldYaw", player) * FlxAngle.TO_RAD,
			getSubmodValue("fieldRoll", player) * FlxAngle.TO_RAD); // rotate the vertex properly
		var projected = VectorHelpers.getVector(rotated.subtract(fieldPos)); // perpsective projection
		return projected.add(origin); // puts the vertex back to default pos 
	}

	override function modifyVert(beat:Float, vert:Vector3, idx:Int, sprite:FlxSprite, pos:Vector3, player:Int, data:Int):Vector3
	{
		if((sprite is Note)){
			var shit:Note = cast sprite;
			if(shit.isSustainNote)return vert;
		}
		var origin = new Vector3(FlxG.width/2, FlxG.height/2); // vertex origin
		var fieldPos = new Vector3(-getSubmodPercent("fieldX", player) / 100, -getSubmodPercent("fieldY", player) / 100, 1280 + getSubmodPercent("fieldZ", player) / 100); // playfield pos
		var originMod = vert.add(pos).subtract(origin); // moves the vertex to the appropriate position on screen based on origin
		var rotated = VectorHelpers.rotateV3(originMod, getSubmodValue("fieldPitch", player) * FlxAngle.TO_RAD, getSubmodValue("fieldYaw", player) * FlxAngle.TO_RAD, getSubmodValue("fieldRoll", player) * FlxAngle.TO_RAD); // rotate the vertex properly
		var projected = VectorHelpers.getVector(rotated.subtract(fieldPos)); // perpsective projection
		var nuVert = projected.subtract(pos).add(origin); // puts the vertex back to default pos
		return nuVert; 
		
  }
  

}
