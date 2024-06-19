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

	// public var value:Float = 1;
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

		updateHealthBarPos();

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
		isOpponentMode = PlayState.instance == null ? false : PlayState.instance.playOpponent;

		super(
			healthBarBG.x + 5, healthBarBG.y + 5,
			RIGHT_TO_LEFT,
			Std.int(healthBarBG.width - 10), Std.int(healthBarBG.height - 10),
			null, null,
			0, 2
		);
		
		value = 1;

		//
		iconP2.setPosition(
			healthBarPos - 75 - iconOffset * 2,
			y + (height - iconP2.height) / 2
		);
		iconP1.setPosition(
			healthBarPos - iconOffset,
			y + (height - iconP1.height) / 2
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

	private var healthBarPos:Float;
	private function updateHealthBarPos()
	{
		healthBarPos = x + width * (flipX ? value * 0.5 : 1 - value * 0.5) ;
	}

	override function set_value(val:Float){
		var val = isOpponentMode ? max-val : val;

		iconP1.animation.curAnim.curFrame = val < 0.4 ? 1 : 0; // 20% ?
		iconP2.animation.curAnim.curFrame = val > 1.6 ? 1 : 0; // 80% ?

		super.set_value(val);

		updateHealthBarPos();

		return value;
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
			leftIcon.x = healthBarPos - scaleOff - iconOffset * 2;
			rightIcon.x = healthBarPos + scaleOff - 75 - iconOffset;
		}
		else
		{
			leftIcon.x = healthBarPos - 75 - iconOffset * 2;
			rightIcon.x = healthBarPos - iconOffset;
		}

		super.update(elapsed);
	}
}
