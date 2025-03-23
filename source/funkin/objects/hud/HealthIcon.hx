package funkin.objects.hud;

import flixel.graphics.frames.FlxFrame;
import flixel.graphics.FlxGraphic;
import flixel.FlxSprite;

using StringTools;

// Should we incluide this?? Should we just have it as part of base HealthIcon if icon has an xml??
/* class SparrowHealthIcon extends HealthIcon
{
	public static final IDLE_PREFIX = 'idle';
	public static final LOSING_PREFIX = 'losing';
	public static final WINNING_PREFIX = 'winning';
	override function swapOldIcon()
		trace("TODO");

	// I am just trusting the user on this one that the icon is formatted correctly lol
	// Maybe the prefix constants should be in the health icon instead???
	
	override function changeIcon(char:String){
		frames = Paths.getSparrowAtlas('icons/$char');
		animation.addByPrefix("idle", IDLE_PREFIX, 24);
		animation.addByPrefix("losing", LOSING_PREFIX, 24);
		final animFrames:Array<FlxFrame> = new Array<FlxFrame>();
		animation.findByPrefix(animFrames, WINNING_PREFIX);
		if (animFrames.length > 0)
			animation.addByPrefix("winning", WINNING_PREFIX, 24);
		else
			animation.addByPrefix("winning", IDLE_PREFIX, 24);
	}
} */
class HealthIcon extends FlxSprite
{
	public var autoUpdatesAnims:Bool = true;

	public var sprTracker:FlxObject;
	private var isOldIcon:Bool = false;
	private var isPlayer:Bool = false;
	private var char:String = '';

	public var relativePercent(default, set):Float = 0;

	function set_relativePercent(percent:Float){
		if (autoUpdatesAnims)
			updateState(percent);
		
		return relativePercent = percent;
	}

	public var losingPercent:Float = 20;
	public var winningPercent:Float = 80;

	// Done to allow more customization by simply extending HealthIcon
	// Can also be used by scripts to do stuff w/ health icons
	// I.e adding transitions between animations
	
	public function getAnimation(relativePercent:Float){
		if (relativePercent <= losingPercent)
			return 'losing';
		else if(relativePercent >= winningPercent)
			return 'winning';

		return 'idle';

	}
	
	public function updateState(relativePercent:Float){
		animation.play(getAnimation(relativePercent), true);
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
		//trace(iconOffsets[0], iconOffsets[1]);

		animation.add("idle", [0], 0, false, isPlayer);
		animation.add("losing", [1], 0, false, isPlayer);
		animation.add("winning", [0], 0, false, isPlayer);

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