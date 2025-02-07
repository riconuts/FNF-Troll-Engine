package flixel.graphics.tile;

import openfl.display.Sprite;
import flixel.FlxCamera;
import flixel.graphics.frames.FlxFrame;
import flixel.graphics.tile.FlxDrawBaseItem.FlxDrawItemType;
import flixel.math.FlxMatrix;
import flixel.math.FlxPoint;
import flixel.math.FlxRect;
import flixel.system.FlxAssets.FlxShader;
import flixel.util.FlxColor;
import openfl.display.Graphics;
import openfl.display.ShaderParameter;
import openfl.display.TriangleCulling;
import openfl.geom.ColorTransform;

import funkin.objects.shaders.NoteColorSwap;

typedef DrawData<T> = #if (flash || openfl >= "4.0.0") openfl.Vector<T> #else Array<T> #end;

/**
 * @author Zaphod
 */
class FlxDrawTrianglesItem extends FlxDrawBaseItem<FlxDrawTrianglesItem>
{
	static var point:FlxPoint = FlxPoint.get();
	static var rect:FlxRect = FlxRect.get();

	#if !flash
	public var shader:FlxShader;
	var alphas:Array<Float>;
	var colorMultipliers:Array<Float>;
	var colorOffsets:Array<Float>;

	var hsvShifts:Array<Float>;
	var daAlphas:Array<Float>;
	var flashes:Array<Float>;
	var flashColors:Array<Float>;
	#end

	public var vertices:DrawData<Float> = new DrawData<Float>();
	public var indices:DrawData<Int> = new DrawData<Int>();
	public var uvtData:DrawData<Float> = new DrawData<Float>();
	public var colors:DrawData<Int> = new DrawData<Int>();

	public var verticesPosition:Int = 0;
	public var indicesPosition:Int = 0;
	public var colorsPosition:Int = 0;

	var bounds:FlxRect = FlxRect.get();

	public function new()
	{
		super();
		type = FlxDrawItemType.TRIANGLES;
		#if !flash
		alphas = [];

		hsvShifts = [];
		daAlphas = [];
		flashes = [];
		flashColors = [];
		#end
	}

	override public function render(sprite:Sprite, ?antialiasing:Bool = true, ?debugLayer:Sprite):Void
	{
		if (!FlxG.renderTile)
			return;

		if (numTriangles <= 0)
			return;

		#if !flash
		var shader = shader != null ? shader : graphics.shader;
		shader.bitmap.input = graphics.bitmap;
		shader.bitmap.filter = (antialiasing || this.antialiasing) ? LINEAR : NEAREST;
		shader.bitmap.wrap = REPEAT; // in order to prevent breaking tiling behaviour in classes that use drawTriangles
		shader.alpha.value = alphas;

		if (colored || hasColorOffsets)
		{
			shader.colorMultiplier.value = colorMultipliers;
			shader.colorOffset.value = colorOffsets;
		}

		if (shader is NoteColorSwapShader)
		{
			var swapShader:NoteColorSwapShader = cast shader;
			swapShader.hsvShift.value = hsvShifts;
			swapShader.daAlpha.value = daAlphas;
			swapShader.flash.value = flashes;
			swapShader.flashColor.value = flashColors;
		}

		setParameterValue(shader.hasTransform, true);
		setParameterValue(shader.hasColorTransform, colored || hasColorOffsets);

		#if (openfl > "8.7.0")
		sprite.graphics.overrideBlendMode(blend);
		#end

		sprite.graphics.beginShaderFill(shader);
		#else
		sprite.graphics.beginBitmapFill(graphics.bitmap, null, true, (antialiasing || this.antialiasing));
		#end

		sprite.graphics.drawTriangles(vertices, indices, uvtData, TriangleCulling.NONE);
		sprite.graphics.endFill();

		#if FLX_DEBUG
		if (FlxG.debugger.drawDebug && debugLayer != null)
		{
			var gfx:Graphics = debugLayer.graphics;
			gfx.lineStyle(1, FlxColor.BLUE, 0.5);
			gfx.drawTriangles(vertices, indices, uvtData);
		}
		#end

		super.render(sprite, antialiasing, debugLayer);
	}

	override public function reset():Void
	{
		super.reset();
		#if (flash || openfl >= "4.0.0")
		vertices.length = 0;
		indices.length = 0;
		uvtData.length = 0;
		colors.length = 0;
		#else
		vertices.splice(0, vertices.length);
		indices.splice(0, indices.length);
		uvtData.splice(0, uvtData.length);
		colors.splice(0, colors.length);
		#end

		verticesPosition = 0;
		indicesPosition = 0;
		colorsPosition = 0;
		#if !flash
		alphas.splice(0, alphas.length);

		hsvShifts.splice(0, hsvShifts.length);
		daAlphas.splice(0, daAlphas.length);
		flashes.splice(0, flashes.length);
		flashColors.splice(0, flashColors.length);

		if (colorMultipliers != null)
			colorMultipliers.splice(0, colorMultipliers.length);
		if (colorOffsets != null)
			colorOffsets.splice(0, colorOffsets.length);
		#end
	}

	override public function dispose():Void
	{
		super.dispose();

		vertices = null;
		indices = null;
		uvtData = null;
		colors = null;
		bounds = null;
		#if !flash
		alphas = null;
		colorMultipliers = null;
		colorOffsets = null;

		hsvShifts = null;
		daAlphas = null;
		flashes = null;
		flashColors = null;
		#end
	}

	public function addTrianglesColorArray(vertices:DrawData<Float>, indices:DrawData<Int>, uvtData:DrawData<Float>, ?colors:DrawData<Int>,
			?position:FlxPoint, ?cameraBounds:FlxRect #if !flash, ?transforms:Array<ColorTransform>, ?colorSwap:NoteColorSwap #end):Void
	{
		if (position == null)
			position = point.set();

		if (cameraBounds == null)
			cameraBounds = rect.set(0, 0, FlxG.width, FlxG.height);

		var verticesLength:Int = vertices.length;
		var prevVerticesLength:Int = this.vertices.length;
		var numberOfVertices:Int = Std.int(verticesLength / 2);
		var numberOfTriangles:Int = Std.int(indices.length / 3);
		var prevIndicesLength:Int = this.indices.length;
		var prevUVTDataLength:Int = this.uvtData.length;
		var prevColorsLength:Int = this.colors.length;
		var prevNumberOfVertices:Int = this.numVertices;

		var tempX:Float, tempY:Float;
		var i:Int = 0;
		var currentVertexPosition:Int = prevVerticesLength;

		while (i < verticesLength)
		{
			tempX = position.x + vertices[i];
			tempY = position.y + vertices[i + 1];

			this.vertices[currentVertexPosition++] = tempX;
			this.vertices[currentVertexPosition++] = tempY;

			i += 2;
		}

		var uvtDataLength:Int = uvtData.length;
		for (i in 0...uvtDataLength)
		{
			this.uvtData[prevUVTDataLength + i] = uvtData[i];
		}

		var indicesLength:Int = indices.length;
		for (i in 0...indicesLength)
		{
			this.indices[prevIndicesLength + i] = indices[i] + prevNumberOfVertices;
		}

		verticesPosition += verticesLength;
		indicesPosition += indicesLength;

		position.putWeak();
		cameraBounds.putWeak();

		#if !flash
		for (_ in 0...numberOfTriangles)
		{
			var transform = transforms[_];
			alphas.push(transform != null ? transform.alphaMultiplier : 1.0);
			alphas.push(transform != null ? transform.alphaMultiplier : 1.0);
			alphas.push(transform != null ? transform.alphaMultiplier : 1.0);
		}

		if (colorSwap != null)
		{
			for (i in 0...(numberOfTriangles * 3))
			{
				hsvShifts.push(colorSwap.hue);
				hsvShifts.push(colorSwap.saturation);
				hsvShifts.push(colorSwap.brightness);

				daAlphas.push(colorSwap.daAlpha);

				flashes.push(colorSwap.flash);

				flashColors.push(colorSwap.flashR);
				flashColors.push(colorSwap.flashG);
				flashColors.push(colorSwap.flashB);
				flashColors.push(colorSwap.flashA);
			}
		}

		if (colored || hasColorOffsets)
		{
			if (colorMultipliers == null)
				colorMultipliers = [];

			if (colorOffsets == null)
				colorOffsets = [];

			for (_ in 0...numberOfTriangles)
			{
				var transform = transforms[_];
				for (_ in 0...3)
				{
					if (transform != null)
					{
						colorMultipliers.push(transform.redMultiplier);
						colorMultipliers.push(transform.greenMultiplier);
						colorMultipliers.push(transform.blueMultiplier);

						colorOffsets.push(transform.redOffset);
						colorOffsets.push(transform.greenOffset);
						colorOffsets.push(transform.blueOffset);
						colorOffsets.push(transform.alphaOffset);
					}
					else
					{
						colorMultipliers.push(1);
						colorMultipliers.push(1);
						colorMultipliers.push(1);

						colorOffsets.push(0);
						colorOffsets.push(0);
						colorOffsets.push(0);
						colorOffsets.push(0);
					}

					colorMultipliers.push(1);
				}
			}
		}
		#end
	}
    

	public function addTriangles(vertices:DrawData<Float>, indices:DrawData<Int>, uvtData:DrawData<Float>, ?colors:DrawData<Int>, ?position:FlxPoint,
			?cameraBounds:FlxRect #if !flash , ?transform:ColorTransform, ?colorSwap:NoteColorSwap #end):Void
	{
		if (position == null)
			position = point.set();

		if (cameraBounds == null)
			cameraBounds = rect.set(0, 0, FlxG.width, FlxG.height);

		var verticesLength:Int = vertices.length;
		var prevVerticesLength:Int = this.vertices.length;
		var numberOfVertices:Int = Std.int(verticesLength / 2);
		var numberOfTriangles:Int = Std.int(indices.length / 3);
		var prevIndicesLength:Int = this.indices.length;
		var prevUVTDataLength:Int = this.uvtData.length;
		var prevColorsLength:Int = this.colors.length;
		var prevNumberOfVertices:Int = this.numVertices;

		var tempX:Float, tempY:Float;
		var i:Int = 0;
		var currentVertexPosition:Int = prevVerticesLength;

		while (i < verticesLength)
		{
			tempX = position.x + vertices[i];
			tempY = position.y + vertices[i + 1];

			this.vertices[currentVertexPosition++] = tempX;
			this.vertices[currentVertexPosition++] = tempY;

			if (i == 0)
			{
				bounds.set(tempX, tempY, 0, 0);
			}
			else
			{
				inflateBounds(bounds, tempX, tempY);
			}

			i += 2;
		}

		if (!cameraBounds.overlaps(bounds))
		{
			this.vertices.splice(this.vertices.length - verticesLength, verticesLength);
		}
		else
		{
			var uvtDataLength:Int = uvtData.length;
			for (i in 0...uvtDataLength)
			{
				this.uvtData[prevUVTDataLength + i] = uvtData[i];
			}

			var indicesLength:Int = indices.length;
			for (i in 0...indicesLength)
			{
				this.indices[prevIndicesLength + i] = indices[i] + prevNumberOfVertices;
			}

			if (colored)
			{
				for (i in 0...numberOfVertices)
				{
					this.colors[prevColorsLength + i] = colors[i];
				}

				colorsPosition += numberOfVertices;
			}

			verticesPosition += verticesLength;
			indicesPosition += indicesLength;
		}

		position.putWeak();
		cameraBounds.putWeak();

		#if !flash
		for (_ in 0...numberOfTriangles)
		{
			alphas.push(transform != null ? transform.alphaMultiplier : 1.0);
			alphas.push(transform != null ? transform.alphaMultiplier : 1.0);
			alphas.push(transform != null ? transform.alphaMultiplier : 1.0);
		}

		if (colorSwap != null)
		{
			for (i in 0...(numberOfTriangles * 3))
			{
				hsvShifts.push(colorSwap.hue);
				hsvShifts.push(colorSwap.saturation);
				hsvShifts.push(colorSwap.brightness);

				daAlphas.push(colorSwap.daAlpha);

				flashes.push(colorSwap.flash);

				flashColors.push(colorSwap.flashR);
				flashColors.push(colorSwap.flashG);
				flashColors.push(colorSwap.flashB);
				flashColors.push(colorSwap.flashA);
			}
		}

		if (colored || hasColorOffsets)
		{
			if (colorMultipliers == null)
				colorMultipliers = [];

			if (colorOffsets == null)
				colorOffsets = [];

			for (_ in 0...(numberOfTriangles * 3))
			{
				if(transform != null)
				{
					colorMultipliers.push(transform.redMultiplier);
					colorMultipliers.push(transform.greenMultiplier);
					colorMultipliers.push(transform.blueMultiplier);

					colorOffsets.push(transform.redOffset);
					colorOffsets.push(transform.greenOffset);
					colorOffsets.push(transform.blueOffset);
					colorOffsets.push(transform.alphaOffset);
				}
				else
				{
					colorMultipliers.push(1);
					colorMultipliers.push(1);
					colorMultipliers.push(1);
	
					colorOffsets.push(0);
					colorOffsets.push(0);
					colorOffsets.push(0);
					colorOffsets.push(0);
				}

				colorMultipliers.push(1);
			}
		}
		#end
	}

	inline function setParameterValue(parameter:ShaderParameter<Bool>, value:Bool):Void
	{
		if (parameter.value == null)
			parameter.value = [];
		parameter.value[0] = value;
	}

	public static inline function inflateBounds(bounds:FlxRect, x:Float, y:Float):FlxRect
	{
		if (x < bounds.x)
		{
			bounds.width += bounds.x - x;
			bounds.x = x;
		}

		if (y < bounds.y)
		{
			bounds.height += bounds.y - y;
			bounds.y = y;
		}

		if (x > bounds.x + bounds.width)
		{
			bounds.width = x - bounds.x;
		}

		if (y > bounds.y + bounds.height)
		{
			bounds.height = y - bounds.y;
		}

		return bounds;
	}

	override public function addQuad(frame:FlxFrame, matrix:FlxMatrix, ?transform:ColorTransform, ?colorSwap:NoteColorSwap):Void
	{
		var prevVerticesPos:Int = verticesPosition;
		var prevIndicesPos:Int = indicesPosition;
		var prevColorsPos:Int = colorsPosition;
		var prevNumberOfVertices:Int = numVertices;

		var point = FlxPoint.get();
		point.transform(matrix);

		vertices[prevVerticesPos] = point.x;
		vertices[prevVerticesPos + 1] = point.y;

		uvtData[prevVerticesPos] = frame.uv.x;
		uvtData[prevVerticesPos + 1] = frame.uv.y;

		point.set(frame.frame.width, 0);
		point.transform(matrix);

		vertices[prevVerticesPos + 2] = point.x;
		vertices[prevVerticesPos + 3] = point.y;

		uvtData[prevVerticesPos + 2] = frame.uv.width;
		uvtData[prevVerticesPos + 3] = frame.uv.y;

		point.set(frame.frame.width, frame.frame.height);
		point.transform(matrix);

		vertices[prevVerticesPos + 4] = point.x;
		vertices[prevVerticesPos + 5] = point.y;

		uvtData[prevVerticesPos + 4] = frame.uv.width;
		uvtData[prevVerticesPos + 5] = frame.uv.height;

		point.set(0, frame.frame.height);
		point.transform(matrix);

		vertices[prevVerticesPos + 6] = point.x;
		vertices[prevVerticesPos + 7] = point.y;

		point.put();

		uvtData[prevVerticesPos + 6] = frame.uv.x;
		uvtData[prevVerticesPos + 7] = frame.uv.height;

		indices[prevIndicesPos] = prevNumberOfVertices;
		indices[prevIndicesPos + 1] = prevNumberOfVertices + 1;
		indices[prevIndicesPos + 2] = prevNumberOfVertices + 2;
		indices[prevIndicesPos + 3] = prevNumberOfVertices + 2;
		indices[prevIndicesPos + 4] = prevNumberOfVertices + 3;
		indices[prevIndicesPos + 5] = prevNumberOfVertices;

		if (colored)
		{
			var red = 1.0;
			var green = 1.0;
			var blue = 1.0;
			var alpha = 1.0;

			if (transform != null)
			{
				red = transform.redMultiplier;
				green = transform.greenMultiplier;
				blue = transform.blueMultiplier;

				#if !neko
				alpha = transform.alphaMultiplier;
				#end
			}

			var color = FlxColor.fromRGBFloat(red, green, blue, alpha);

			colors[prevColorsPos] = color;
			colors[prevColorsPos + 1] = color;
			colors[prevColorsPos + 2] = color;
			colors[prevColorsPos + 3] = color;

			colorsPosition += 4;
		}

		verticesPosition += 8;
		indicesPosition += 6;

		if (colorSwap != null)
		{
			for (i in 0...6) // 2 triangles times 3 vertices
			{
				hsvShifts.push(colorSwap.hue);
				hsvShifts.push(colorSwap.saturation);
				hsvShifts.push(colorSwap.brightness);

				daAlphas.push(colorSwap.daAlpha);

				flashes.push(colorSwap.flash);

				flashColors.push(colorSwap.flashR);
				flashColors.push(colorSwap.flashG);
				flashColors.push(colorSwap.flashB);
				flashColors.push(colorSwap.flashA);
			}
		}
	}

	override function get_numVertices():Int
	{
		return Std.int(vertices.length / 2);
	}

	override function get_numTriangles():Int
	{
		return Std.int(indices.length / 3);
	}
}
