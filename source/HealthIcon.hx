package;

import flixel.FlxSprite;

using StringTools;

class HealthIcon extends FlxSprite
{
	public var sprTracker:FlxSprite;
	private var isOldIcon:Bool = false;
	private var isPlayer:Bool = false;
	private var char:String = '';

	public function new(char:String = 'bf', isPlayer:Bool = false)
	{
		super();

		this.isPlayer = isPlayer;
		antialiasing = ClientPrefs.globalAntialiasing;

		changeIcon(char);

		scrollFactor.set();
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (sprTracker != null)
			setPosition(sprTracker.x + sprTracker.width + 10, sprTracker.y - 30);
	}

	function changeIconGraphic(gr){
		loadGraphic(gr); //Load stupidly first for getting the file size
		loadGraphic(gr, true, Math.floor(width * 0.5), Math.floor(height)); //Then load it fr
		iconOffsets[0] = (width - 150) * 0.5;
		iconOffsets[1] = (width - 150) * 0.5;
		updateHitbox();

		animation.add(char, [0, 1], 0, false, isPlayer);
		animation.play(char);
	}

	public function swapOldIcon() 
	{
		var oldIcon = Paths.image('icons/$char-old');
		if(oldIcon == null)
			oldIcon = Paths.image('icons/char-$char-old'); // psych compat

		if (!isOldIcon && oldIcon != null){
			changeIconGraphic(oldIcon);
			
			isOldIcon = true;
		}else if (isOldIcon){
			// shitty workaround
			var ugh = char;
			char = "";
			changeIcon(ugh);

			isOldIcon = false;
		}
	}

	private var iconOffsets:Array<Float> = [0, 0];
	public function changeIcon(char:String) {
		if(this.char != char) {
			var file:Dynamic = Paths.image('icons/$char');

			if(file == null)
				file = Paths.image('icons/icon-$char'); // psych compat
			

			if(file == null) 
				file = Paths.image('icons/face'); // Prevents crash from missing icon

			changeIconGraphic(file);
			this.char = char;

			// antialiasing = ClientPrefs.globalAntialiasing && !char.endsWith("-pixel");
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
