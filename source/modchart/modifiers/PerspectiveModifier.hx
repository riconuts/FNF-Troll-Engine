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

  var fov = Math.PI/2;
  var near = 0;
  var far = 2;

  function FastTan(rad:Float) // thanks schmoovin
  {
    return FlxMath.fastSin(rad) / FlxMath.fastCos(rad);
  }

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

	public function getVector(pos:Vector3):Vector3{
		var oX = pos.x;
		var oY = pos.y;

		var aspect = 1;

		var shit = pos.z / 1280;
		if(shit>0)shit=0;

		var ta = FastTan(fov/2);
		var x = oX * aspect/ta;
		var y = oY/ta;
		var a = (near+far)/(near-far);
		var b = 2*near*far/(near-far);
		var z = (a*shit+b);
		var returnedVector = new Vector3(x/z,y/z,z);

		return returnedVector;
	}

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
			+ getSubmodPercent("fieldZ", player)); // playfield pos
			
		
		
		var originMod = pos.subtract(origin); // moves the vertex to the appropriate position on screen based on origin
		var rotated = rotateV3(originMod, getSubmodValue("fieldPitch", player) * FlxAngle.TO_RAD, getSubmodValue("fieldYaw", player) * FlxAngle.TO_RAD,
			getSubmodValue("fieldRoll", player) * FlxAngle.TO_RAD); // rotate the vertex properly
		var projected = getVector(rotated.subtract(fieldPos)); // perpsective projection
		return projected.add(origin); // puts the vertex back to default pos 
	}

	override function modifyVert(beat:Float, vert:Vector3, idx:Int, sprite:FlxSprite, pos:Vector3, player:Int, data:Int):Vector3
	{
		var origin = new Vector3(FlxG.width/2, FlxG.height/2); // vertex origin
		var fieldPos = new Vector3(-getSubmodPercent("fieldX", player) / 100, -getSubmodPercent("fieldY", player) / 100, 1280 + getSubmodPercent("fieldZ", player)); // playfield pos
		var originMod = vert.add(pos).subtract(origin); // moves the vertex to the appropriate position on screen based on origin
		var rotated = rotateV3(originMod, getSubmodValue("fieldPitch", player) * FlxAngle.TO_RAD, getSubmodValue("fieldYaw", player) * FlxAngle.TO_RAD, getSubmodValue("fieldRoll", player) * FlxAngle.TO_RAD); // rotate the vertex properly
		var projected = getVector(rotated.subtract(fieldPos)); // perpsective projection
		var nuVert = projected.subtract(pos).add(origin); // puts the vertex back to default pos
		return nuVert; 
		
  }
  

}
