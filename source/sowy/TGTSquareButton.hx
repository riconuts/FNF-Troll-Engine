package sowy;

import flixel.tweens.FlxTween.TweenOptions;
import flixel.tweens.*;

class TGTSquareButton extends SowyBaseButton
{
	public function new(?X:Float = 0, ?Y:Float = 0)
	{
		super(X, Y);
	}

	/* ahhhhhh so gay
	var scaleTwn:Null<FlxTween>;
	function cancelTwn() {
		if (scaleTwn != null){
			scaleTwn.cancel();
			scaleTwn.destroy();
		}
	}
	override function onover()
	{
		cancelTwn();
		scaleTwn = FlxTween.tween(this.scale, {x: 1.05, y: 1.05}, 0.1);

		super.onover();
	}
	override function onout()
	{
		cancelTwn();
		scaleTwn = FlxTween.tween(this.scale, {x: 1, y: 1}, 0.1);

		super.onout();
	}
	override function destroy(){
		cancelTwn();
		super.destroy();
	}
	*/

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
		else if (shk == 0){
			var tweenShit:TweenOptions = {
				ease: FlxEase.backOut,
				onComplete: function(twn){
					twn.destroy();
					var twnShit:TweenOptions = {ease: FlxEase.backOut, onComplete: function(t){t.destroy();}};

					if (ClientPrefs.flashing)
						FlxTween.tween(this, {color: 0xFFFFFFFF}, 0.1, twnShit);
					else
						FlxTween.color(this, 0.05, color, 0xFFFFFFFF, twnShit);
				}
			};

			if (ClientPrefs.flashing)
				// this wasn't the proper way to tween between but i like how it looked so im keeping it lol!!
				FlxTween.tween(this, {color: 0xFFFF6666}, 0.1, tweenShit);
			else
				FlxTween.color(this, 0.1, color, 0xFFFF0000, tweenShit);
		}

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