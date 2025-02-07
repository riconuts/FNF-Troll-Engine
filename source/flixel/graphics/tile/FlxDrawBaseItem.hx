package flixel.graphics.tile;

import openfl.display.Sprite;
import flixel.FlxCamera;
import flixel.graphics.frames.FlxFrame;
import flixel.math.FlxMatrix;
import openfl.display.BlendMode;
import openfl.geom.ColorTransform;
import funkin.objects.shaders.NoteColorSwap;

/**
 * @author Zaphod
 */
class FlxDrawBaseItem<T>
{
	/**
	 * Tracks the total number of draw calls made each frame.
	 */
	public static var drawCalls:Int = 0;

	public static function blendToInt(blend:BlendMode):Int
	{
		return 0; // no blend mode support in drawQuads()
	}

	public var nextTyped:T;

	public var next:FlxDrawBaseItem<T>;

	public var graphics:FlxGraphic;
	public var antialiasing:Bool = false;
	public var colored:Bool = false;
	public var hasColorOffsets:Bool = false;
	public var blending:Int = 0;
	public var blend:BlendMode;

	public var type:FlxDrawItemType;

	public var numVertices(get, never):Int;

	public var numTriangles(get, never):Int;

	public function new() {}

	public function reset():Void
	{
		graphics = null;
		antialiasing = false;
		nextTyped = null;
		next = null;
	}

	public function dispose():Void
	{
		graphics = null;
		next = null;
		type = null;
		nextTyped = null;
	}

	public function renderCamera(camera:FlxCamera):Void
	{
		render(camera.canvas, camera.antialiasing#if FLX_DEBUG , camera.debugLayer #end);
	}

	public function render(sprite:Sprite, ?antialiasing:Bool = true, ?debugLayer:Sprite):Void
	{
		drawCalls++;
	}

	public function addQuad(frame:FlxFrame, matrix:FlxMatrix, ?transform:ColorTransform, ?colorSwap:NoteColorSwap):Void {}

	function get_numVertices():Int
	{
		return 0;
	}

	function get_numTriangles():Int
	{
		return 0;
	}
}

enum FlxDrawItemType
{
	TILES;
	TRIANGLES;
}