package;

import flixel.addons.transition.FlxTransitionSprite.TransitionStatus;
import flixel.addons.transition.TransitionSubstate;
import flixel.math.FlxMath;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxGradient;
import flixel.util.FlxTimer;

class FadeTransitionSubstate extends TransitionSubstate
{
	var _finalDelayTime:Float = 0.0;

	public static var defaultCamera:FlxCamera;
	public static var nextCamera:FlxCamera;

	var curStatus:TransitionStatus;

	var gradient:FlxSprite;
	var gradientFill:FlxSprite;

	public override function destroy():Void
	{
		super.destroy();
		if(gradient!=null)
			gradient.destroy();
		gradient = null;

		if(gradientFill!=null)
			gradientFill.destroy();
		gradientFill = null;

		finishCallback = null;
	}

	function onFinish(f:FlxTimer):Void{
		if (finishCallback != null){
			finishCallback();
			finishCallback = null;
		}
	}

	function delayThenFinish():Void{
		new FlxTimer().start(_finalDelayTime, onFinish); // force one last render call before exiting
	}

	public override function update(elapsed:Float){
		if(gradientFill!=null && gradient!=null){
			switch(curStatus){
				case IN:
					gradientFill.y = gradient.y - gradient.height;
				case OUT:
					gradientFill.y = gradient.y + gradient.height;
				default:
			}
		}
		super.update(elapsed);
	}


	override public function start(status: TransitionStatus){
		var cam = nextCamera!=null ? nextCamera : (defaultCamera!=null ? defaultCamera : FlxG.cameras.list[FlxG.cameras.list.length-1]);
		cameras = [cam];

		nextCamera = null;
		// trace('transitioning $status');

		curStatus = status;
		var yStart:Float = 0;
		var yEnd:Float = 0;
		var duration:Float = .48;
		var angle:Int = 90;
		var zoom:Float = FlxMath.bound(cam.zoom,0.001);
		var width:Int = Math.ceil(cam.width/zoom);
		var height:Int = Math.ceil(cam.height/ zoom);

		yStart = -height;
		yEnd = height;

		switch(status){
			case IN:
			case OUT:
				angle=270;
				duration = .8;
			default:
				//trace("bruh");
		}

		gradient = FlxGradient.createGradientFlxSprite(width, height, [FlxColor.BLACK, FlxColor.TRANSPARENT], 1, angle);
		gradient.scrollFactor.set();
		gradient.screenCenter(X);
		gradient.y = yStart;

		gradientFill = new FlxSprite().makeGraphic(width,height,FlxColor.BLACK);
		gradientFill.screenCenter(X);
		gradientFill.scrollFactor.set();
		add(gradientFill);
		add(gradient);


		FlxTween.tween(gradient,{y: yEnd}, duration,{
		onComplete: function(t:FlxTween){
			//trace("done");
			delayThenFinish();
		}
		});
	}
}
