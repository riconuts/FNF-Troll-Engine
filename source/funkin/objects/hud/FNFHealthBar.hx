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

	/** Use this to change the alpha of the bar **/
	public var real_alpha(default, set):Float = 1.0; 
	function set_real_alpha(value:Float){
		set_alpha(value * ClientPrefs.hpOpacity);
		return real_alpha = value; 
	}

	@:noCompletion override function set_alpha(val) {
		iconP1.alpha = val;
		iconP2.alpha = val;
		healthBarBG.alpha = val;
		return super.set_alpha(val);
	}

	@:noCompletion override function set_cameras(newCameras) {
		healthBarBG.cameras = newCameras;
		iconP2.cameras = newCameras;
		iconP1.cameras = newCameras;
		return super.set_cameras(newCameras);
	}

	public function new(bfHealthIcon = "face", dadHealthIcon = "face")
	{
		isOpponentMode = PlayState.instance == null ? false : PlayState.instance.playOpponent;

		////		
		healthBarBG = new FlxSprite();
		healthBarBG.scrollFactor.set();
		healthBarBG.antialiasing = false;
		
		var graphic = Paths.image('healthBar');
		if (graphic != null) healthBarBG.loadGraphic(graphic);
		else healthBarBG.makeGraphic(600, 18, 0xFF000000);
		healthBarBG.updateHitbox();

		//
		iconP1 = new HealthIcon(bfHealthIcon, true);
		iconP2 = new HealthIcon(dadHealthIcon, false);
		leftIcon = iconP2;
		rightIcon = iconP1;
            
		//
		super(
			0, 0,
			RIGHT_TO_LEFT,
			Std.int(healthBarBG.width - 10), Std.int(healthBarBG.height - 10),
			null, null,
			0, 2
		);
		
		cameras = cameras;
		antialiasing = false;
		scrollFactor.set();
		value = 1;
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
		var perc = val / max;

		if (perc < 0.2) {
			iconP1.animation.play('losing');
			iconP2.animation.play('winning');
		}
		else if (perc > 0.8) {
			iconP1.animation.play('winning');
			iconP2.animation.play('losing');
		}
		else {
			iconP1.animation.play('idle');
			iconP2.animation.play('idle');
		}

		super.set_value(val);
		updateHealthBarPos();

		return value;
	}

	override function draw() {
		if (alpha == 0)
			return;

		healthBarBG.draw();
		super.draw();
		iconP1.draw();
		iconP2.draw();
	}

	override function update(elapsed:Float)
	{
		if (FlxG.keys.justPressed.NINE)
			(isOpponentMode ? iconP2 : iconP1).swapOldIcon();

		healthBarBG.update(elapsed);
		super.update(elapsed);
		iconP1.update(elapsed);
		iconP2.update(elapsed);	

		healthBarBG.setPosition(x - 5, y - 5);

		if (iconScale != 1)
			iconScale = FlxMath.lerp(1, iconScale, Math.exp(-elapsed * 9));

		var scaleOff = 75 * iconScale;
		leftIcon.x = healthBarPos - scaleOff - iconOffset * 2;
		rightIcon.x = healthBarPos + scaleOff - 75 - iconOffset;
	}
}
