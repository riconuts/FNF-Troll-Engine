package math;

import flixel.math.FlxMath;
import math.Vector3;
import funkin.CoolUtil;

class VectorHelpers {
	static var near = 0;
	static var far = 2;

	static function FastTan(rad:Float) // thanks schmoovin
	{
		return FlxMath.fastSin(rad) / FlxMath.fastCos(rad);
	}

	// thanks schmoovin'
	public static function rotateV3(vec:Vector3, xA:Float, yA:Float, zA:Float, resultVector:Null<Vector3> = null):Vector3
	{
		var rotateZ = CoolUtil.rotate(vec.x, vec.y, zA);
		var rotateY = CoolUtil.rotate(rotateZ.x, vec.z, yA);
		var rotateX = CoolUtil.rotate(rotateY.y, rotateZ.y, xA);

		if (resultVector == null) {
			resultVector = new Vector3(rotateY.x, rotateX.y, rotateX.x);
		}else {
			resultVector.setTo(rotateY.x, rotateX.y, rotateX.x);
		}		

		rotateZ.putWeak();
		rotateX.putWeak();
		rotateY.putWeak();

		return resultVector;
	}

	public static function project(pos:Vector3, resultVector:Null<Vector3> = null):Vector3
	{
		var oX = pos.x;
		var oY = pos.y;

		var aspect = 1;

		var shit = pos.z / 1280;
		if (shit > 0)
			shit = 0;

		var fov = (Math.PI / 2);
		var ta = FastTan(fov / 2);
		var x = oX * aspect / ta;
		var y = oY / ta;
		var a = (near + far) / (near - far);
		var b = 2 * near * far / (near - far);
		var z = (a * shit + b);

		if (resultVector == null) {
			resultVector = new Vector3(x / z, y / z, z);
		}else {
			resultVector.setTo(x / z, y / z, z);		
		}

		return resultVector;
	}

}