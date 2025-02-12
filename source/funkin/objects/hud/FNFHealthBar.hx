package funkin.objects.hud;

import flixel.math.FlxMath;
import flixel.ui.FlxBar;

// TODO: think abt this
class FNFHealthBar extends FlxBar{
	public var autoPositionIcons:Bool = true;
	
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
			Std.int(healthBarBG.width - 10), Std.int(healthBarBG.height -	 10),
			null, null,
			minHealth, maxHealth
		);

		numDivisions = Std.int(width * 2);
		
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

	public function updateIcons(elapsed:Float){
		if (iconScale != 1) {
			iconScale = FlxMath.lerp(1, iconScale, Math.exp(-elapsed * 9));

			var scaleOff = 75 * iconScale;
			leftIcon.x = iconPosX - scaleOff - iconOffset * 2;
			rightIcon.x = iconPosX + scaleOff - 75 - iconOffset;
		} else {
			leftIcon.x = iconPosX - 75 - iconOffset * 2;
			rightIcon.x = iconPosX - iconOffset;
		}
	}

	override function updateBar() {
		super.updateBar();
		if (autoPositionIcons)
			updateIconPos();

		var p1Percent = isOpponentMode ? 100 - percent : percent;
		var p2Percent = isOpponentMode ? percent : 100 - percent;
		
		// Icon behavioural code should be done via extending HealthIcon or turning off icon.autoUpdatesAnims
		
		iconP1.relativePercent = p1Percent;
		iconP2.relativePercent = p2Percent;
	}

	override function update(elapsed:Float)
	{
		if (!visible){
			super.update(elapsed);
			return;
		}

		healthBarBG.setPosition(x - 5, y - 5);

		updateIcons(elapsed);

		super.update(elapsed);
	}
}


// Old icon behaviour from pre-VSlice
class ShittyBar extends FNFHealthBar {
	public var vSlice:Bool = false; // Uses V-Slice lerping

	public var currentValue(default, set):Float = 1; // For lerping w/ vslice

	function set_currentValue(val:Float){
		currentValue = val;
		updateBar();
		return val;
	}

	public function new(p1:String = "face", p2:String = "face"){
		super(p1, p2);
		iconP1.y = y - (iconP1.height / 2);
		iconP2.y = y - (iconP2.height / 2);
	}

	override function updateFilledBar():Void {
		var val = value;
		if(vSlice)
			val = currentValue;

		_filledBarRect.width = barWidth;
		_filledBarRect.height = barHeight;

		var fraction:Float = (val - min) / range;
		var percent:Float = fraction * _maxPercent;
		var maxScale:Float = (_fillHorizontal) ? barWidth : barHeight;
		var scaleInterval:Float = maxScale / numDivisions;
		var interval:Float = Math.round(Std.int(fraction * maxScale / scaleInterval) * scaleInterval);

		if (_fillHorizontal) {
			_filledBarRect.width = Std.int(interval);
		} else {
			_filledBarRect.height = Std.int(interval);
		}

		if (percent > 0) {
			switch (fillDirection) {
				case LEFT_TO_RIGHT, TOP_TO_BOTTOM:
					//	Already handled above

				case BOTTOM_TO_TOP:
					_filledBarRect.y = barHeight - _filledBarRect.height;
					_filledBarPoint.y = barHeight - _filledBarRect.height;

				case RIGHT_TO_LEFT:
					_filledBarRect.x = barWidth - _filledBarRect.width;
					_filledBarPoint.x = barWidth - _filledBarRect.width;

				case HORIZONTAL_INSIDE_OUT:
					_filledBarRect.x = Std.int((barWidth / 2) - (_filledBarRect.width / 2));
					_filledBarPoint.x = Std.int((barWidth / 2) - (_filledBarRect.width / 2));

				case HORIZONTAL_OUTSIDE_IN:
					_filledBarRect.width = Std.int(maxScale - interval);
					_filledBarPoint.x = Std.int((barWidth - _filledBarRect.width) / 2);

				case VERTICAL_INSIDE_OUT:
					_filledBarRect.y = Std.int((barHeight / 2) - (_filledBarRect.height / 2));
					_filledBarPoint.y = Std.int((barHeight / 2) - (_filledBarRect.height / 2));

				case VERTICAL_OUTSIDE_IN:
					_filledBarRect.height = Std.int(maxScale - interval);
					_filledBarPoint.y = Std.int((barHeight - _filledBarRect.height) / 2);
			}

			if (FlxG.renderBlit) {
				pixels.copyPixels(_filledBar, _filledBarRect, _filledBarPoint, null, null, true);
			} else {
				if (frontFrames != null) {
					_filledFlxRect.copyFromFlash(_filledBarRect).round();
					if (Std.int(percent) > 0) {
						_frontFrame = frontFrames.frame.clipTo(_filledFlxRect, _frontFrame);
					}
				}
			}
		}

		if (FlxG.renderBlit) {
			dirty = true;
		}
	}

	override function update(elapsed:Float){
		if(vSlice)
			currentValue = FlxMath.lerp(currentValue, value, 0.15 * (elapsed * 60));
		

		super.update(elapsed);
	}

	override function updateIcons(elapsed:Float) {
		if (vSlice){
			var frameFix = elapsed * 60;
			iconP1.setGraphicSize(Std.int(FlxMath.lerp(iconP1.width, 150, 0.15 * frameFix)));
			iconP2.setGraphicSize(Std.int(FlxMath.lerp(iconP2.width, 150, 0.15 * frameFix)));
		}else{
			iconP1.setGraphicSize(Std.int(FlxMath.lerp(150, iconP1.width, 0.85)));
			iconP2.setGraphicSize(Std.int(FlxMath.lerp(150, iconP2.width, 0.85)));	
		}

		iconP1.updateHitbox();
		iconP2.updateHitbox();

		iconP1.centerOffsets();
		iconP2.centerOffsets();

		var iconOffset:Int = 26;

		var perc = vSlice ? (currentValue / 2) * 100 : percent;

		var percent = flipX ? 100 - perc : perc;
		
		switch (fillDirection) {
			case RIGHT_TO_LEFT:
				iconP1.x = x + (width * (FlxMath.remapToRange(percent, 0, 100, 100, 0) * 0.01) - iconOffset);
				iconP2.x = x + (width * (FlxMath.remapToRange(percent, 0, 100, 100, 0) * 0.01)) - (iconP2.width - iconOffset);

			case LEFT_TO_RIGHT:
				iconP1.x = x + (width * (percent * 0.01) - iconOffset);
				iconP2.x = x + (width * (percent * 0.01)) - (iconP2.width - iconOffset);
			default:
			
		}

		if(vSlice){
			iconP1.y = y - iconP1.height / 2;
			iconP2.y = y - iconP2.height / 2;
		}else{

		}
	}
}
