package;

import flixel.math.FlxMath;
import math.Vector3;

class VectorHelpers {
	static var near = 0;
	static var far = 2;

	static function FastTan(rad:Float) // thanks schmoovin
	{
		return FlxMath.fastSin(rad) / FlxMath.fastCos(rad);
	}

	// thanks schmoovin'
	public static function rotateV3(vec:Vector3, xA:Float, yA:Float, zA:Float):Vector3
	{
		var rotateZ = CoolUtil.rotate(vec.x, vec.y, zA);
		var offZ = new Vector3(rotateZ.x, rotateZ.y, vec.z);

		var rotateY = CoolUtil.rotate(offZ.x, offZ.z, yA);
		var offY = new Vector3(rotateY.x, offZ.y, rotateY.y);

		var rotateX = CoolUtil.rotate(offY.z, offY.y, xA);
		var offX = new Vector3(offY.x, rotateX.y, rotateX.x);

		rotateZ.putWeak();
		rotateX.putWeak();
		rotateY.putWeak();

		return offX;
	}

	public static function getVector(pos:Vector3):Vector3
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
		var returnedVector = new Vector3(x / z, y / z, z);

		return returnedVector;
	}

}