package funkin;

import haxe.io.Bytes;
import haxe.io.Path;

import math.CoolMath;

import flixel.math.FlxPoint;
import flixel.util.FlxColor;
import flixel.tweens.FlxEase;
import flixel.util.typeLimit.OneOfTwo;

#if sys
import sys.io.File;
import sys.FileSystem;
#end
#if linc_filedialogs
import filedialogs.FileDialogs;
#else
import lime.ui.FileDialog;
import openfl.net.FileFilter;
#end

using StringTools;

class CoolUtil {
	// TIRED OF WRITING THIS FUCKING SHIT
	public static function updateIndex(curIdx:Int, val:Int, length:Int) {
		curIdx += val;

		if (curIdx < 0)
			curIdx += length;
		else if (curIdx >= length)
			curIdx %= length;

		return curIdx;
	}

	public static function updateDifficultyIndex(curDiffIdx:Int, curDiffId:String, newDiffIds:Array<String>) {
		var idx = newDiffIds.indexOf(curDiffId);
		if (idx != -1)
			return idx;

		idx = newDiffIds.indexOf("normal");
		if (idx != -1)
			return idx;

		idx = newDiffIds.indexOf("hard");
		if (idx != -1)
			return idx;
		
		return curDiffIdx < 0 ? 0 : curDiffIdx;
	}

	public static function prettyInteger(num:Int):String {
		var buf = new StringBuf();

		if (num < 0) {
			num = -num;
			buf.add('-');
		}

		var str = Std.string(num);
		var h = str.length - 1;
		var i = 1;

		buf.add(str.charAt(0));
		while (i < str.length) {
			if (h % 3 == 0) buf.add(',');
			buf.add(str.charAt(i));
			h--; i++;
		}

		return buf.toString();
	}

	public static function structureToMap(st:Dynamic):Map<String, Dynamic> {
		return [
			for (k in Reflect.fields(st)){
				k => Reflect.field(st, k);
			}
		];
	}

	public static function alphabeticalSort(a:String, b:String):Int {
		// https://haxe.motion-twin.narkive.com/BxeZgKeh/sort-an-array-string-alphabetically
		a = a.toLowerCase();
		b = b.toLowerCase();
		if (a < b) return -1;
		if (a > b) return 1;
		return 0;	
	}

	////
	inline public static function blankSprite(width, height, color=0xFFFFFFFF) {
		var spr = new FlxSprite().makeGraphic(1, 1);
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

	/**
	 * @param spr The sprite on which to clone the animation
	 * @param ogName Name of the animation to be cloned. 
	 * @param cloneName Name of the resulting clone.
	 * @param force Whether to override the resulting animation, if it exists.
	 */
	public static function cloneSpriteAnimation(spr:FlxSprite, ogName:String, cloneName:String, force:Bool=false)
	{
		var daAnim = spr.animation.getByName(ogName);
		if (daAnim!=null && (force==true || !spr.animation.exists(cloneName)))
			spr.animation.add(cloneName, daAnim.frames, daAnim.frameRate, daAnim.looped, daAnim.flipX, daAnim.flipY);
	}

	@:noCompletion static var _point:FlxPoint = new FlxPoint();
	public static function overlapsMouse(object:FlxObject, ?camera:FlxCamera):Bool
	{
		if (camera == null)
			camera = FlxG.camera;

		_point = FlxG.mouse.getPositionInCameraView(camera, _point);
		if (camera.containsPoint(_point)) {
			_point = FlxG.mouse.getWorldPosition(camera, _point);
			if (object.overlapsPoint(_point, true, camera))
				return true;
		}

		return false;
	}

	public static function centerOnObject(obj1:FlxObject, obj2:FlxObject) {
		obj1.x = obj2.x + (obj2.width - obj1.width) / 2;
		obj1.y = obj2.y + (obj2.height - obj2.height) / 2;
		return obj1;
	}

	////
	public static function listFromString(string:String):Array<String>
	{
		string = string.trim();
		if (string.length == 0)
			return [];

		var daList:Array<String> = string.split('\n');
		for (i in 0...daList.length)
			daList[i] = daList[i].trim();
		
		return daList;
	}
	public static function coolTextFile(path:String):Array<String>
	{
		var rawList = Paths.getContent(path);
		if (rawList == null)
			return [];

		return listFromString(rawList);
	}

	public static function dominantColor(sprite:flixel.FlxSprite):Int{
		var countByColor:Map<Int, Int> = [];
		for(col in 0...sprite.frameWidth) {
			for(row in 0...sprite.frameHeight) {
				var colorOfThisPixel:Int = sprite.pixels.getPixel32(col, row);
				if (colorOfThisPixel != 0){
					if (countByColor.exists(colorOfThisPixel)) {
						countByColor[colorOfThisPixel] =  countByColor[colorOfThisPixel] + 1;
					}else if (countByColor[colorOfThisPixel] != 13520687 - (2*13520687)){
						countByColor[colorOfThisPixel] = 1;
					}
				}
			}
		}
		var maxCount = 0;
		var maxKey:Int = 0;//after the loop this will store the max color
		
		countByColor[flixel.util.FlxColor.BLACK] = 0;
		for (key in countByColor.keys()) {
			if (countByColor[key] >= maxCount) {
				maxCount = countByColor[key];
				maxKey = key;
			}
		}
		return maxKey;
	}

	////
	public static function colorFromString(color:String):FlxColor
	{
		var hideChars = ~/[\t\n\r]/;
		var color:String = hideChars.split(color).join('').trim();
		if (color.startsWith('0x')) color = color.substring(color.length - 6);

		var colorNum:Null<FlxColor> = FlxColor.fromString(color);
		if (colorNum == null) colorNum = FlxColor.fromString('#$color');
		return colorNum != null ? colorNum : FlxColor.WHITE;
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

    public static function createMissingDirectories(path:String):String {
		#if sys
		var folders:Array<String> = path.split("/");
		var currentPath:String = "";

		for (folder in folders) {
			currentPath += folder + "/";
			if (!FileSystem.exists(currentPath))
				FileSystem.createDirectory(currentPath);
		}
		#end
		return path;
	}

    public static function safeSaveFile(path:String, content:OneOfTwo<String, Bytes>) {
		#if sys
		try {
			createMissingDirectories(Path.directory(path));
			if(content is Bytes)
                File.saveBytes(path, content);
			else
                File.saveContent(path, content);
		}
        catch(e) {
            final errMsg:String = 'Error while trying to save the file: ${Std.string(e).replace('\n', ' ')}';
			trace(errMsg);
		}
		#end
	}

	public static function getFileBytes(absolutePath:String) {
		var cwd = Sys.getCwd();
		Sys.setCwd('');
		var b = Paths.getBytes(absolutePath);
		Sys.setCwd(cwd);
		return b;
	}

	@:noCompletion
	private static inline function _filefilters(?filters:Array<String>) {
		#if linc_filedialogs
		return filters ?? [];
		#else		
		final goodFilters:Array<String> = [];
		if (filters != null) {
			for (f in filters) {
				var type = new FileFilter(f, f);
				goodFilters.push(StringTools.replace(StringTools.replace(type.extension, "*.", ""), ";", ","));
			}
		}
		return goodFilters.join(";");
		#end
	}

	@:noCompletion
	private static inline function fileDialogPath(?path:String):String {
		#if sys
		if (path == null || path.length == 0)
			return Sys.getCwd();
		if (!Path.isAbsolute(path))
			path = Path.join([Sys.getCwd(), path]);
		
		if (!FileSystem.exists(Path.directory(path)))
			path = Sys.getCwd();
		#if windows else
			path = path.replace('/', '\\');
		#end

		return path;
		#else
		return "";
		#end
	}

	public static function showOpenMultipleDialog(title:String = "Open Files", ?defaultPath:String, ?filters:Array<String>, ?onSelect:(paths:Array<String>)->Void, ?onCancel:Void->Void):Void {
		final filters = _filefilters(filters);
		final defaultPath = fileDialogPath(defaultPath);
		#if linc_filedialogs
		final files:Array<String> = FileDialogs.open_file(title, cast defaultPath, cast filters, Option.Multiselect);
		if (files.length == 0) {
			if (onCancel != null) onCancel();
		}else {
			if (onSelect != null) onSelect(files);
		}
		#else
		final dialog:FileDialog = new FileDialog();
		if (onCancel != null) dialog.onCancel.add(onCancel);
		if (onSelect != null) dialog.onSelectMultiple.add(onSelect);
		dialog.browse(OPEN_MULTIPLE, filter, defaultPath, title);
		Sys.sleep(0.5); // sleep to prevent dialogs sometimes not opening if opened in quick succession
		#end
	}
	
	public static function showOpenDialog(title:String = "Open File", ?defaultPath:String, ?filters:Array<String>, ?onOpen:(bytes:Bytes)->Void, ?onSelect:(path:String)->Void, ?onCancel:Void->Void):Void {
		final filters = _filefilters(filters);
		final defaultPath = fileDialogPath(defaultPath);
		#if linc_filedialogs
		final files:Array<String> = FileDialogs.open_file(title, cast defaultPath, cast filters, Option.None);
		if (onSelect != null) onSelect(files[0]);
		if (files.length == 0) {
			if (onCancel != null) onCancel();
		}else {
			if (onOpen != null) onOpen(getFileBytes(files[0]));
		}
		#else
		final dialog:FileDialog = new FileDialog();
		if (onOpen != null) dialog.onOpen.add(onOpen);
		if (onCancel != null) dialog.onCancel.add(onCancel);
		if (onSelect != null) dialog.onSelect.add(onSelect);
		dialog.browse(OPEN, filter, defaultPath, title);
		Sys.sleep(0.5); // sleep to prevent dialogs sometimes not opening if opened in quick succession
		#end
	}

	public static function showSaveDialog(content:OneOfTwo<String, Bytes>, title:String = "Save File", ?defaultPath:String, ?filters:Array<String>, ?onSave:(path:String)->Void, ?onCancel:Void->Void):Void {
		final filters = _filefilters(filters);
		final defaultPath = fileDialogPath(defaultPath);
		#if linc_filedialogs
		final savePath:String = FileDialogs.save_file(title, cast defaultPath, cast filters);
		if (savePath.length == 0) {
			if (onCancel != null)
				onCancel();
		}else {
			safeSaveFile(savePath, content);
			onSave(savePath);
		}
		#else
		final dialog:FileDialog = new FileDialog();
		dialog.onSelect.add((f) -> safeSaveFile(f, content));
		if (onCancel != null) dialog.onCancel.add(onCancel);
		if (onSelect != null) dialog.onCancel.add(onSelect);
		dialog.browse(SAVE, filter, defaultPath, title);
		Sys.sleep(0.5); // sleep to prevent dialogs sometimes not opening if opened in quick succession
		#end
	}

	////
	inline public static function coolLerp(current:Float, target:Float, elapsed:Float):Float
		return CoolMath.coolLerp(current, target, elapsed);

	inline public static function scale(x:Float, lower1:Float, higher1:Float, lower2:Float, higher2:Float):Float
		return CoolMath.scale(x, lower1, higher1, lower2, higher2);

	inline public static function quantizeAlpha(f:Float, interval:Float):Float
		return CoolMath.quantizeAlpha(f, interval);

	inline public static function quantize(f:Float, snap:Float):Float
		return CoolMath.quantize(f, snap);

	inline public static function snap(f:Float, snap:Float):Float
		return CoolMath.snap(f, snap);

	inline public static function boundTo(value:Float, min:Float, max:Float):Float
		return CoolMath.boundTo(value, min, max);

	inline public static function clamp(n:Float, lower:Float, higher:Float):Float
		return CoolMath.clamp(n, lower, higher);

	inline public static function floorDecimal(value:Float, decimals:Int):Float
		return CoolMath.floorDecimal(value, decimals);

	inline public static function rotate(x:Float, y:Float, rads:Float, ?point:FlxPoint):FlxPoint
		return CoolMath.rotate(x, y, rads, point);
}
