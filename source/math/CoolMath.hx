package math;

import flixel.math.FlxMath;
import flixel.math.FlxPoint;

class CoolMath/*Games*/{
	inline public static function coolLerp(current:Float, target:Float, elapsed:Float):Float
		return FlxMath.lerp(target, current, Math.exp(-elapsed));

	inline public static function fastTan(radians:Float):Float
		return FlxMath.fastSin(radians) / FlxMath.fastCos(radians);

	inline public static function square(angle:Float) {
		var fAngle = angle % (Math.PI * 2);

		return fAngle >= Math.PI ? -1.0 : 1.0;
	}

	inline public static function triangle(angle:Float) {
		var fAngle:Float = angle % (Math.PI * 2.0);
		if (fAngle < 0.0)
			fAngle += Math.PI * 2.0;
		
		var result:Float = fAngle / Math.PI;
		
		if (result < 0.5) {
			return 2.0 * result;
		}
		else if (result < 1.5) {
			return -2.0 * result + 2.0;
		}
		else {
			return 2.0 * result - 4.0;
		}
	}

	inline public static function scale(value:Float, clow:Float, chigh:Float, nlow:Float, nhigh:Float):Float
		return (value - clow) * (nhigh - nlow) / (chigh - clow) + nlow;

	inline public static function quantizeAlpha(f:Float, interval:Float):Float
		return Std.int((f+interval/2)/interval) * interval;

	inline public static function quantize(f:Float, snap:Float):Float
		return Math.fround(f * snap) / snap;

	inline public static function snap(f:Float, snap:Float):Float
		return Math.fround(f / snap) * snap;

	inline public static function boundTo(value:Float, min:Float, max:Float):Float
		return Math.max(min, Math.min(max, value));

	inline public static function clamp(n:Float, lower:Float, higher:Float)
		return boundTo(n, lower, higher);

	public static function floorDecimal(value:Float, decimals:Int):Float {
		if (decimals < 1)
			return Math.ffloor(value);

		var tempMult:Float = 1.0;
		for (_ in 0...decimals)
			tempMult *= 10.0;
		
		return Math.ffloor(value * tempMult) / tempMult;
	}

	public static function rotate(x:Float, y:Float, radians:Float, ?point:FlxPoint):FlxPoint {
		var s:Float = Math.sin(radians);
		var c:Float = Math.cos(radians);
		// because HAXE* sucks
		if (Math.abs(s) < 0.001)
			s = 0;

		if (Math.abs(c) < 0.001)
			c = 0;

		var p = point ?? FlxPoint.weak();
		p.set((x * c) - (y * s), (x * s) + (y * c));


		return p;
	}
}