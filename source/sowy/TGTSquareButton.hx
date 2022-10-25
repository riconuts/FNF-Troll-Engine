package sowy;

import flixel.tweens.*;

class TGTSquareButton extends SowyBaseButton
{
	public function new(?X:Float = 0, ?Y:Float = 0)
    {
		super(X, Y);
	}

	override function onover()
	{
		super.onover();
	}

	// fucking lmao
	var shk = 0;
	var twen:FlxTween;
	var its:Float = .05;

	public function shake()
	{
		shk = 0;
		if (twen != null)
		{
			twen.cancel();
			twen.destroy();
		}
		doShake();
	}

	function doShake()
	{
		if (shk >= 4)
		{
			shk = 0;
			return;
		}
		else if (shk == 0)
			FlxTween.tween(this, {color: 0xFF0000}, 0.1, {
				ease: FlxEase.backOut,
				onComplete: function(twn)
				{
					twn.destroy();
					FlxTween.tween(this, {color: 0xFFFFFF}, 0.1, {ease: FlxEase.backOut, onComplete: function(twn)
					{
						twn.destroy();
					}});
				}
			});

		var state:Array<Dynamic> = [
			{x: -width * its, y: height * its},
			{x: width * its, y: -height * its},
			{x: -width * (its / 4), y: height * (its / 4)},
			{x: width * (its / 4), y: -height * (its / 4)},
			{x: 0, y: 0},
		];

		twen = FlxTween.tween(offset, state[shk], 0.05, {
			ease: FlxEase.backOut,
			onComplete: function(twn)
			{
				shk++;
				doShake();
				twn.destroy();
			}
		});
	}
}