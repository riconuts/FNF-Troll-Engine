package funkin;

import flixel.tweens.FlxEase;
import flixel.math.FlxPoint;
import flixel.math.FlxMath;

using StringTools;

class CoolUtil
{
	@:noCompletion static var _point:FlxPoint = FlxPoint.get();
	public static function overlapsMouse(object:FlxObject, ?camera:FlxCamera):Bool
	{
		if (camera == null)
			camera = FlxG.camera;

		_point = FlxG.mouse.getPositionInCameraView(camera, _point);
		if (camera.containsPoint(_point))
		{
			_point = FlxG.mouse.getWorldPosition(camera, _point);
			if (object.overlapsPoint(_point, true, camera))
				return true;
		}

		return false;
	}

	inline public static function coolLerp(current:Float, target:Float, elapsed:Float):Float
		return FlxMath.lerp(target, current, Math.exp(-elapsed));

	inline public static function blankSprite(width, height, color){
		var spr = new FlxSprite().makeGraphic(1,1);
		spr.scale.set(width, height);
		spr.updateHitbox();
		spr.color = color;
		return spr;
	}

	public static function makeOutlinedGraphic(Width:Int, Height:Int, Color:Int, LineThickness:Int, OutlineColor:Int)
	{
		var rectangle = flixel.graphics.FlxGraphic.fromRectangle(Width, Height, OutlineColor, true);
		rectangle.bitmap.fillRect(
			new openfl.geom.Rectangle(
				LineThickness, 
				LineThickness, 
				Width-LineThickness*2, 
				Height-LineThickness*2
			),
			Color
		);

		return rectangle;
	};

	inline public static function scale(x:Float, l1:Float, h1:Float, l2:Float, h2:Float):Float
		return ((x - l1) * (h2 - l2) / (h1 - l1) + l2);

	inline public static function clamp(n:Float, l:Float, h:Float)
	{
		if (n > h)
			n = h;
		if (n < l)
			n = l;

		return n;
	}

	public static function rotate(x:Float, y:Float, angle:Float, ?point:FlxPoint):FlxPoint
	{
		var p = point == null ? FlxPoint.weak() : point;
		var sin = FlxMath.fastSin(angle);
		var cos = FlxMath.fastCos(angle);
		return p.set((x * cos) - (y * sin), (x * sin) + (y * cos));
	}

	inline public static function quantizeAlpha(f:Float, interval:Float){
		return Std.int((f+interval/2)/interval)*interval;
	}

	inline public static function quantize(f:Float, snap:Float){
		// changed so this actually works lol
		var m:Float = Math.fround(f * snap);
		return (m / snap);
	}

	inline public static function snap(f:Float, snap:Float)
	{
		// changed so this actually works lol
		var m:Float = Math.fround(f / snap);
		return (m * snap);
	}

	inline public static function boundTo(value:Float, min:Float, max:Float):Float {
		return Math.max(min, Math.min(max, value));
	}

	public static function coolTextFile(path:String):Array<String>
	{
		var rawList = Paths.getContent(path);
		if (rawList == null)
			return [];

		return listFromString(rawList);
	}
	public static function listFromString(string:String):Array<String>
	{
		var daList:Array<String> = [
			for (i in string.trim().split('\n'))
				i.trim()
		];

		return daList;
	}
	public static function dominantColor(sprite:flixel.FlxSprite):Int{
		var countByColor:Map<Int, Int> = [];
		for(col in 0...sprite.frameWidth){
			for(row in 0...sprite.frameHeight){
			  var colorOfThisPixel:Int = sprite.pixels.getPixel32(col, row);
			  if(colorOfThisPixel != 0){
				  if(countByColor.exists(colorOfThisPixel)){
					countByColor[colorOfThisPixel] =  countByColor[colorOfThisPixel] + 1;
				  }else if(countByColor[colorOfThisPixel] != 13520687 - (2*13520687)){
					 countByColor[colorOfThisPixel] = 1;
				  }
			  }
			}
		 }
		var maxCount = 0;
		var maxKey:Int = 0;//after the loop this will store the max color
		countByColor[flixel.util.FlxColor.BLACK] = 0;
			for(key in countByColor.keys()){
			if(countByColor[key] >= maxCount){
				maxCount = countByColor[key];
				maxKey = key;
			}
		}
		return maxKey;
	}

	// could probably use a macro
	public static function getEaseFromString(?name:String):EaseFunction
	{
		return switch(name)
		{
 			case "backIn": FlxEase.backIn;
 			case "backInOut": FlxEase.backInOut;
 			case "backOut": FlxEase.backOut;
 			case "bounceIn": FlxEase.bounceIn;
 			case "bounceInOut": FlxEase.bounceInOut;
 			case "bounceOut": FlxEase.bounceOut;
 			case "circIn": FlxEase.circIn;
 			case "circInOut": FlxEase.circInOut;
 			case "circOut": FlxEase.circOut;
 			case "cubeIn": FlxEase.cubeIn;
 			case "cubeInOut": FlxEase.cubeInOut;
 			case "cubeOut": FlxEase.cubeOut;
 			case "elasticIn": FlxEase.elasticIn;
 			case "elasticInOut": FlxEase.elasticInOut;
 			case "elasticOut": FlxEase.elasticOut;
 			case "expoIn": FlxEase.expoIn;
 			case "expoInOut": FlxEase.expoInOut;
 			case "expoOut": FlxEase.expoOut;
 			case "quadIn": FlxEase.quadIn;
 			case "quadInOut": FlxEase.quadInOut;
 			case "quadOut": FlxEase.quadOut;
 			case "quartIn": FlxEase.quartIn;
 			case "quartInOut": FlxEase.quartInOut;
 			case "quartOut": FlxEase.quartOut;
 			case "quintIn": FlxEase.quintIn;
 			case "quintInOut": FlxEase.quintInOut;
 			case "quintOut": FlxEase.quintOut;
 			case "sineIn": FlxEase.sineIn;
 			case "sineInOut": FlxEase.sineInOut;
 			case "sineOut": FlxEase.sineOut;
 			case "smoothStepIn": FlxEase.smoothStepIn;
 			case "smoothStepInOut": FlxEase.smoothStepInOut;
 			case "smoothStepOut": FlxEase.smoothStepOut;
 			case "smootherStepIn": FlxEase.smootherStepIn;
 			case "smootherStepInOut": FlxEase.smootherStepInOut;
 			case "smootherStepOut": FlxEase.smootherStepOut;

 			case "instant": (t:Float) -> return 1.0;
			default: FlxEase.linear;
		}
	}
	
	public static function floorDecimal(value:Float, decimals:Int):Float
	{
		if (decimals < 1)
			return Math.floor(value);

		var tempMult:Float = 1;
		for (_ in 0...decimals)
			tempMult *= 10;
		
		var newValue:Float = Math.floor(value * tempMult);
		return newValue / tempMult;
	}

	inline public static function numberArray(max:Int, ?min = 0):Array<Int>
	{
		// max+1 because in haxe for loops stop before reaching the max number
		return [for (n in min...max+1){n;}];
	}

	//uhhhh does this even work at all? i'm starting to doubt
	public static function precacheSound(sound:String, ?library:String = null):Void {
		Paths.sound(sound, library);
	}

	public static function precacheMusic(sound:String, ?library:String = null):Void {
		Paths.music(sound, library);
	}

	public static function browserLoad(site:String) {
		#if linux
		Sys.command('/usr/bin/xdg-open', [site]);
		#else
		flixel.FlxG.openURL(site);
		#end
	}
}
