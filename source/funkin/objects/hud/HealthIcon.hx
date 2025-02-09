package funkin.objects.hud;

import flixel.graphics.FlxGraphic;
import flixel.FlxSprite;

using StringTools;

// class HScriptedHealthicon
// maybe some day lol

class HealthIcon extends FlxSprite
{
	public var sprTracker:FlxObject;
	private var isOldIcon:Bool = false;
	private var isPlayer:Bool = false;
	private var char:String = '';

	public function updateState(relativePercent:Float){
		animation.play(relativePercent < 20 ? "losing" : "idle"); // Exists so that you can extend the HealthIcon class and do like animated icons n shit
		// (Maybe could be made easier in cv3 by adding more icon options to the character data)
		// ((Or icon jsons but that sounds dumb but we could do it because could be useful for stuff like icons like Yourself's which has like 6 different icons on it which are all idle))
	}

	public function new(char:String = 'bf', isPlayer:Bool = false)
	{
		super();

		this.isPlayer = isPlayer;

		changeIcon(char);

		scrollFactor.set();
	}

	override function update(elapsed:Float)
	{
		if (sprTracker != null)
			setPosition(sprTracker.x + sprTracker.width + 10, sprTracker.y - 30);
	
		super.update(elapsed);
	}

	function changeIconGraphic(graphic:FlxGraphic)
	{
		loadGraphic(graphic, true, Math.floor(graphic.width * 0.5), Math.floor(graphic.height));
		iconOffsets[0] = (width - 150) * 0.5;
		iconOffsets[1] = (width - 150) * 0.5;
		updateHitbox();
		trace(iconOffsets[0], iconOffsets[1]);

		animation.add("idle", [0], 0, false, isPlayer);
		animation.add("losing", [1], 0, false, isPlayer);

		animation.play('idle');
	}

	public function swapOldIcon() 
	{
		if (!isOldIcon){
			var oldIcon = Paths.image('icons/$char-old');
			
			if(oldIcon == null)
				oldIcon = Paths.image('icons/icon-$char-old'); // base game compat

			if (oldIcon != null){
				changeIconGraphic(oldIcon);
				isOldIcon = true;
				return;
			}
		}

		changeIcon(char);
		isOldIcon = false;
	}

	private var iconOffsets:Array<Float> = [0, 0];
	public function changeIcon(char:String) {
/* 		var file:Null<FlxGraphic> = Paths.image('characters/icons/$char'); // i'd like to use this some day lol

		if (file == null)
			file = Paths.image('icons/$char'); // new psych compat */

		var file:Null<FlxGraphic> = Paths.image('icons/$char'); 

		if(file == null)
			file = Paths.image('icons/icon-$char'); // base game compat
		
		if(file == null) 
			file = Paths.image('icons/face'); // Prevents crash from missing icon

		if (file != null){
			//// TODO: sparrow atlas icons? would make the implementation of extra behaviour (ex: winning icons) way easier
			changeIconGraphic(file);
			this.char = char;
		}

		if (char.endsWith("-pixel")){
			antialiasing = false;
			useDefaultAntialiasing = false;
		}
	}

	override function updateHitbox()
	{
		super.updateHitbox();
		offset.x = iconOffsets[0];
		offset.y = iconOffsets[1];
	}

	public function getCharacter():String {
		return char;
	}
}