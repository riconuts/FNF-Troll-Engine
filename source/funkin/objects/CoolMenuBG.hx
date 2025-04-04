package funkin.objects;

import flixel.util.FlxColor;
import openfl.geom.ColorTransform;
import funkin.objects.shaders.AdjustColor;
import flixel.util.FlxGradient;
import flixel.addons.display.FlxBackdrop;
import flixel.group.FlxSpriteGroup;
import flixel.system.FlxAssets.FlxGraphicAsset;
import flixel.graphics.FlxGraphic;
import openfl.display.BitmapData;

// TODO: Condense this into one sprite with a shader
class CoolMenuBG extends FlxSpriteGroup
{
	private var gradient:FlxSprite;
	private var backdrop:FlxBackdrop;
	private var bg:FlxSprite;

	override function set_color(color:Int):Int {
		backdrop.color = color;
		bg.color = color;
		return this.color = color;
	}

	public function new(simpleGraphic:FlxGraphicAsset, color:FlxColor = 0xFFFFFFFF) {
		super();
		this.scrollFactor.set();

		var colorTransform = new ColorTransform(-1, -1, -1, 1,
			Std.int(255 + color.red / 3),
			Std.int(255 + color.green / 3),
			Std.int(255 + color.blue / 3),
			0
		);

		bg = new FlxSprite(0, 0, simpleGraphic);
		var bitmap = bg.updateFramePixels();
		if (bitmap != null) {
			bg.makeGraphic(bitmap.width, bitmap.height, 0x00000000, false, 'CoolBG_bg_$color');
			bg.graphic.bitmap.draw(bitmap, null, colorTransform, INVERT, null, true);
			bg.blend = MULTIPLY;
		}

		var grid = new BitmapData(2, 2);
		grid.setPixel32(0, 0, 0xFFC0C0C0);
		grid.setPixel32(1, 1, 0xFFC0C0C0);

		var grid = FlxGraphic.fromBitmapData(grid, false, 'CoolBG_grid');

		backdrop = new FlxBackdrop(grid);
		backdrop.scrollFactor.set();
		backdrop.scale.x = backdrop.scale.y = FlxG.height / 3;
		backdrop.updateHitbox();
		backdrop.y -= backdrop.height / 2;
		backdrop.velocity.set(30, 30);
		backdrop.antialiasing = true;
		backdrop.color = color;
		backdrop.alpha = 0.5;
		backdrop.blend = ADD;

		gradient = FlxGradient.createGradientFlxSprite(FlxG.width, FlxG.height, [0xFFFFFFFF, 0xFF000000]);
		gradient.scrollFactor.set();

		bg.setGraphicSize(0, FlxG.height);
		bg.updateHitbox();
		bg.screenCenter();

		if (FlxG.height < FlxG.width)
			bg.scale.x = bg.scale.y = (FlxG.height * 1.05) / bg.frameHeight;
		else
			bg.scale.x = bg.scale.y = (FlxG.width * 1.05) / bg.frameWidth;

		add(gradient);
		add(backdrop);
		add(bg);
	}
}