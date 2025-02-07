package flixel.graphics.tile;

import openfl.display.Sprite;
import flixel.FlxCamera;
import flixel.graphics.frames.FlxFrame;
import flixel.graphics.tile.FlxDrawBaseItem.FlxDrawItemType;
import flixel.math.FlxMatrix;
import flixel.system.FlxAssets.FlxShader;
import openfl.Vector;
import openfl.display.ShaderParameter;
import openfl.geom.ColorTransform;

import funkin.objects.shaders.NoteColorSwap;

class FlxDrawQuadsItem extends FlxDrawBaseItem<FlxDrawQuadsItem>
{
	static inline var VERTICES_PER_QUAD = #if (openfl >= "8.5.0") 4 #else 6 #end;

	public var shader:FlxShader;

	var rects:Vector<Float>;
	var transforms:Vector<Float>;
	var alphas:Array<Float>;
	var colorMultipliers:Array<Float>;
	var colorOffsets:Array<Float>;

	var hsvShifts:Array<Float>;
	var daAlphas:Array<Float>;
	var flashes:Array<Float>;
	var flashColors:Array<Float>;

	public function new()
	{
		super();
		type = FlxDrawItemType.TILES;
		rects = new Vector<Float>();
		transforms = new Vector<Float>();
		alphas = [];

		hsvShifts = [];
		daAlphas = [];
		flashes = [];
		flashColors = [];
	}

	override public function reset():Void
	{
		super.reset();
		rects.length = 0;
		transforms.length = 0;
		alphas.splice(0, alphas.length);

		hsvShifts.splice(0, hsvShifts.length);
		daAlphas.splice(0, daAlphas.length);
		flashes.splice(0, flashes.length);
		flashColors.splice(0, flashColors.length);

		if (colorMultipliers != null)
			colorMultipliers.splice(0, colorMultipliers.length);
		if (colorOffsets != null)
			colorOffsets.splice(0, colorOffsets.length);
	}

	override public function dispose():Void
	{
		super.dispose();
		rects = null;
		transforms = null;
		alphas = null;
		colorMultipliers = null;
		colorOffsets = null;

		hsvShifts = null;
		daAlphas = null;
		flashes = null;
		flashColors = null;
	}

	override public function addQuad(frame:FlxFrame, matrix:FlxMatrix, ?transform:ColorTransform, ?colorSwap:NoteColorSwap):Void
	{
		var rect = frame.frame;
		rects.push(rect.x);
		rects.push(rect.y);
		rects.push(rect.width);
		rects.push(rect.height);

		transforms.push(matrix.a);
		transforms.push(matrix.b);
		transforms.push(matrix.c);
		transforms.push(matrix.d);
		transforms.push(matrix.tx);
		transforms.push(matrix.ty);

		var alphaMultiplier = transform != null ? transform.alphaMultiplier : 1.0;
		for (i in 0...VERTICES_PER_QUAD)
			alphas.push(alphaMultiplier);

		if (colorSwap != null)
		{
			for (i in 0...VERTICES_PER_QUAD)
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

			for (i in 0...VERTICES_PER_QUAD)
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

	#if !flash
	override public function render(sprite:Sprite, ?antialiasing:Bool = true, ?debugLayer:Sprite):Void
	{
		if (rects.length == 0)
			return;

		var shader = shader != null ? shader : graphics.shader;
		if (shader == null) // bitch
			return;

		shader.bitmap.input = graphics.bitmap;
		shader.bitmap.filter = (antialiasing || this.antialiasing) ? LINEAR : NEAREST;
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
		sprite.graphics.drawQuads(rects, null, transforms);

		super.render(sprite, antialiasing, debugLayer);
	}

	inline function setParameterValue(parameter:ShaderParameter<Bool>, value:Bool):Void
	{
		if (parameter.value == null)
			parameter.value = [];
		parameter.value[0] = value;
	}
	#end
}