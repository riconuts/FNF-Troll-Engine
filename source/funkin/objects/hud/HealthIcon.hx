package funkin.objects.hud;

import flixel.graphics.frames.FlxAtlasFrames;
import flixel.graphics.FlxGraphic;
import flixel.FlxSprite;

using StringTools;

class HealthIcon extends FlxSprite
{	
	private var char:String = '';
	private var isOldIcon:Bool = false;
	private var iconOffsets:Array<Float> = [0, 0];

	public function new(char:String = 'face', isPlayer:Bool = false)
	{
		super();

		this.flipX = isPlayer;
		scrollFactor.set();

		changeIcon(char);
	}

	public function getCharacter():String
		return char;

	private function setupGraphic(pngPath:String)
	{
		var graphic:FlxGraphic = Paths.getGraphic(pngPath, true);
		loadGraphic(graphic, true, graphic.height, graphic.height, false, pngPath);

		animation.add('idle', [0], 0, false);
		animation.add('losing', [1], 0, false);
		animation.add('winning', [2], 0, false);

		CoolUtil.cloneSpriteAnimation(this, 'idle', 'losing');
		CoolUtil.cloneSpriteAnimation(this, 'idle', 'winning');
		animation.play('idle');

		updateOffsets();
	}

	private function setupSparrowAtlas(pngPath:String, xmlPath:String)
	{
		frames = FlxAtlasFrames.fromSparrow(pngPath, Paths.getContent(xmlPath));

		animation.addByPrefix('idle', 'idle0', 24, true);
		animation.addByPrefix('losing', 'losing0', 24, true);
		animation.addByPrefix('winning', 'winning0', 24, true);

		CoolUtil.cloneSpriteAnimation(this, 'idle', 'losing');
		CoolUtil.cloneSpriteAnimation(this, 'idle', 'winning');
		animation.play('idle');

		updateOffsets();
	}

	private function updateOffsets() {
		super.updateHitbox();
		iconOffsets[0] = (frameWidth - 150) * 0.5;
		iconOffsets[1] = (frameHeight - 150) * 0.5;
		offset.set(iconOffsets[0], iconOffsets[1]);
	}

	override function updateHitbox() {
		super.updateHitbox();
		offset.x = iconOffsets[0];
		offset.y = iconOffsets[1];
	}

	private function setIconImage(pngPath:String) {
		var xmlPath = pngPath.substr(0, -4) + '.xml';
		Paths.exists(xmlPath) ? setupSparrowAtlas(pngPath, xmlPath) : setupGraphic(pngPath);
	}

	public function changeIcon(char:String) {
		var pngPath = getIconImage(char);

		if (pngPath == null)
			pngPath = getIconImage('face');

		this.char = char;
		this.antialiasing = false;
		this.useDefaultAntialiasing = !char.endsWith("-pixel");
		setIconImage(pngPath);
	}

	public function swapOldIcon() {
		if (!isOldIcon) {
			var oldPng = getIconImage('$char-old');
			if (oldPng != null) {
				setIconImage(oldPng);
				this.isOldIcon = true;
			}
		}else {
			setIconImage(getIconImage(char));
			this.isOldIcon = false;
		}
	}

	////
	public static function getIconImage(char:String):Null<String> {
		/*
		var pngPath:String = Paths.imagePath('characters/icons/$char'); // i'd like to use this some day lol

		if (!Paths.exists(pngPath))
			pngPath = Paths.imagePath('icons/$char');
		*/
		var pngPath:String = Paths.imagePath('icons/$char'); 

		#if ALLOW_DEPRECATION
		if (!Paths.exists(pngPath))
			pngPath = Paths.imagePath('icons/icon-$char'); // base game compat
		#end

		return Paths.exists(pngPath) ? pngPath : null;
	}
}