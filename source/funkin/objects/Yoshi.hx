package funkin.objects;

import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.math.FlxMath;
import flixel.FlxG;
import funkin.objects.shaders.ColorSwap;

using StringTools;

class Yoshi extends FlxSprite {
	public var xRange:Array<Float> = [0, 0];
	public var savedHeight:Float;

	var idle:Bool = false;
	var nextActionTime:Float;
	var time:Float;
	var right:Bool;
	var hibernating:Bool = false;

	public var colorSwap:ColorSwap;

	public static var walking:FlxSound;
	public static var canSfx:Bool = true;

	public var canWalk:Bool = true;

	public function new(range:Array<Float>, height:Float, thescale:Float = 1) {
		super(FlxG.random.float(range[1] - range[0]), height);

		xRange = range;
		savedHeight = height;
		scale.set(thescale, thescale);

		frames = Paths.getSparrowAtlas('menus/yoshi');
		animation.addByPrefix('walk', 'yoshi walk', 12, true);
		animation.addByPrefix('idle', 'yoshi idle', 12, true);
		animation.play('walk');
		scrollFactor.set(1, 1);

		colorSwap = new ColorSwap();
		shader = colorSwap.shader;

		walking = new FlxSound().loadEmbedded(Paths.sound("hitsingle/tapWalk"));
		walking.looped = true;
		walking.play();
		walking.pause();
		FlxG.sound.list.add(walking);

		setNewActionTime();
	}

	function setNewActionTime() {
		nextActionTime = time + FlxG.random.float(0.5, 1);
	}

	function triggerNextAction() {
		if (hibernating == true) {
			hibernating = false;
			visible = true;
		}

		if (FlxG.random.bool(20))
			right = FlxG.random.bool(50);

		if (idle == false && FlxG.random.bool(60)) {
			idle = true;
		}
		if (idle == true && FlxG.random.bool(50)) {
			idle = false;
		}
		setNewActionTime();
	}

	override function update(elapsed:Float) {
		time += elapsed;

		if (time > nextActionTime) {
			triggerNextAction();
		}

		super.update(elapsed);

		if (canWalk) {
			if (hibernating == false) {
				if (x > (xRange[1] * 0.9)) {
					hibernating = true;
					x -= 50;
					right = false;
				}

				if (x < (xRange[0] * 1.1)) {
					hibernating = true;
					x += 50;
					right = true;
				}

				if (idle == false) {
					// if(animation.curAnim.name != 'walk')
					animation.play('walk');
					canSfx ? walking.resume() : walking.pause();

					if (right == true) {
						x = FlxMath.lerp(x, x + 30, CoolUtil.boundTo(elapsed * 9, 0, 1));
						flipX = false;
					} else {
						x = FlxMath.lerp(x, x - 30, CoolUtil.boundTo(elapsed * 9, 0, 1));
						flipX = true;
					}
				} else {
					// if(animation.curAnim.name != 'idle' && (animation.curAnim.curFrame == 7 || animation.curAnim.curFrame == 15))
					animation.play('idle');
					walking.pause();

					if (right == true) {
						flipX = false;
					} else {
						flipX = true;
					}
				}

				if (x > xRange[1]) {
					right = false;
				}

				if (x < xRange[0]) {
					right = true;
				}
			}
		} else {
			walking.pause();
		}
	}

	public static function pause() {
		walking.pause();
		canSfx = false;
	}

	public static function resume() {
		canSfx = true;
	}
}