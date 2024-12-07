package math;

import math.CoolMath;
import math.Vector3;

class VectorHelpers {
	static var near:Float = 0.0;
	static var far:Float = 2.0;

	static var fov = Math.PI / 2;
	static var ta = CoolMath.fastTan(fov / 2);

	public static function project(pos:Vector3, resultVector:Null<Vector3> = null, cameraMaxSize:Float = 1280):Vector3
	{
		if (resultVector == null) 
			resultVector = new Vector3();

		var x = pos.x / ta;
		var y = pos.y / ta;
		var a = (near + far) / (near - far);
		var b = 2.0 * near * far / (near - far);
		var z = (pos.z / cameraMaxSize) * a + b;
		
		resultVector.setTo(x / z, y / z, z);		
		return resultVector;
	}

	// thanks schmoovin'
	public static function rotateV3(vec:Vector3, xA:Float, yA:Float, zA:Float, resultVector:Null<Vector3> = null):Vector3
	{
		var rotateZ = CoolMath.rotate(vec.x, vec.y, zA);
		var rotateY = CoolMath.rotate(rotateZ.x, vec.z, yA);
		var rotateX = CoolMath.rotate(rotateY.y, rotateZ.y, xA);

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
}