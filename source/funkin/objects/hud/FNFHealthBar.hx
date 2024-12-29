package funkin.objects.hud;

import flixel.math.FlxMath;
import flixel.ui.FlxBar;

// TODO: think abt this
class FNFHealthBar extends FlxBar{
	public var healthBarBG:FlxSprite;

	public var iconP1:HealthIcon;
	public var iconP2:HealthIcon;

	var leftIcon:HealthIcon;
	var rightIcon:HealthIcon;

	public var iconOffset:Int = 26;

	public var isOpponentMode:Bool = false; // going insane

	override function set_flipX(value:Bool){
		iconP1.flipX = value;
		iconP2.flipX = value;

		// aughhh
		if (value){
			leftIcon = iconP1;
			rightIcon = iconP2;
		}else{
			leftIcon = iconP2;
			rightIcon = iconP1;
		}

		updateIconPos();

		return super.set_flipX(value);
	}

	override function set_visible(value:Bool){
		healthBarBG.visible = value;
		iconP1.visible = value;
		iconP2.visible = value;

		return super.set_visible(value);
	}

	override function set_alpha(value:Float)
	{
		healthBarBG.alpha = value;
		iconP1.alpha = value;
		iconP2.alpha = value;

		return super.set_alpha(value);
	}

	/** Use this to change the alpha of the bar **/
	public var real_alpha(default, set):Float = 1.0; 
	function set_real_alpha(value:Float){
		set_alpha(value * ClientPrefs.hpOpacity);
		return real_alpha = value; 
	}

	public function new(bfHealthIcon = "face", dadHealthIcon = "face")
	{
		//
		var graphic = Paths.image('healthBar');

		healthBarBG = new FlxSprite(0, FlxG.height * (ClientPrefs.downScroll ? 0.11 : 0.89));
		(graphic==null) ? healthBarBG.makeGraphic(600, 18, 0xFF000000) : healthBarBG.loadGraphic(graphic);	
		healthBarBG.screenCenter(X);
		healthBarBG.scrollFactor.set();
		healthBarBG.antialiasing = false;

		//
		iconP1 = new HealthIcon(bfHealthIcon, true);
		iconP2 = new HealthIcon(dadHealthIcon, false);
		leftIcon = iconP2;
		rightIcon = iconP1;
			
		//
		var maxHealth:Float = 2.0;
		var curHealth:Float = 1.0;
		var minHealth:Float = 0.0;

		if (PlayState.instance != null) {
			isOpponentMode = PlayState.instance.playOpponent;
			maxHealth = PlayState.instance.maxHealth;
			curHealth = PlayState.instance.health;
		}

		super(
			healthBarBG.x + 5, healthBarBG.y + 5,
			isOpponentMode ? LEFT_TO_RIGHT : RIGHT_TO_LEFT, // changing this later on breaks the bar visually idk why
			Std.int(healthBarBG.width - 10), Std.int(healthBarBG.height - 10),
			null, null,
			minHealth, maxHealth
		);
		
		value = curHealth;

		//
		iconP2.setPosition(
			iconPosX - 75 - iconOffset * 2,
			iconPosY - iconP2.height * 0.5
		);
		iconP1.setPosition(
			iconPosX - iconOffset,
			iconPosY - iconP1.height * 0.5
		);

		//
		antialiasing = false;
		scrollFactor.set();
		real_alpha = 1.0;
		visible = alpha > 0;
	}

	public var iconScale(default, set) = 1.0;
	function set_iconScale(value:Float){
		iconP1.scale.set(value, value);
		iconP2.scale.set(value, value);

		iconP1.updateHitbox();
		iconP2.updateHitbox();

		return iconScale = value;
	}

	private var iconPosX:Float;
	private var iconPosY:Float;
	private function updateIconPos()
	{
		switch (fillDirection) {
			case LEFT_TO_RIGHT:
				iconPosX = x + width * (flipX ? (100 - percent) : percent) / 100;
				iconPosY = y + height * 0.5;

			case RIGHT_TO_LEFT:
				iconPosX = x + width * (flipX ? percent : (100 - percent)) / 100;
				iconPosY = y + height * 0.5;

			default:
			/* // TODO: vertical healthbars would b cool
			case TOP_TO_BOTTOM:
				iconPosX = x + width * 0.5;
				iconPosY = y + height * (flipY ? (100 - percent) : percent) / 100;

			case BOTTOM_TO_TOP:
				iconPosX = x + width * 0.5;
				iconPosY = y + height * (flipY ? percent : (100 - percent)) / 100;

			default: // idk lol
				iconPosX = x + width * 0.5;
				iconPosY = y + height * 0.5;
			*/
		}
	}

	override function updateBar() {
		super.updateBar();
		updateIconPos();

		var percent = isOpponentMode ? 100 - percent : percent;
		iconP1.animation.curAnim.curFrame = percent < 20 ? 1 : 0;
		iconP2.animation.curAnim.curFrame = percent > 80 ? 1 : 0;
	}

	override function update(elapsed:Float)
	{
		if (!visible){
			super.update(elapsed);
			return;
		}

		healthBarBG.setPosition(x - 5, y - 5);

		if (iconScale != 1){
			iconScale = FlxMath.lerp(1, iconScale, Math.exp(-elapsed * 9));

			var scaleOff = 75 * iconScale;
			leftIcon.x = iconPosX - scaleOff - iconOffset * 2;
			rightIcon.x = iconPosX + scaleOff - 75 - iconOffset;
		}
		else
		{
			leftIcon.x = iconPosX - 75 - iconOffset * 2;
			rightIcon.x = iconPosX - iconOffset;
		}

		super.update(elapsed);
	}
}
