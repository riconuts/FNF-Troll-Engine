package funkin.states;

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

	var updateFunc:Null<Void->Void> = null;

	override public function start(status: TransitionStatus){
		var cam = nextCamera!=null ? nextCamera : (defaultCamera!=null ? defaultCamera : FlxG.cameras.list[FlxG.cameras.list.length-1]);
		cameras = [cam];

		nextCamera = null;
	
		curStatus = status;

		var duration:Float = .48;
		var angle:Int = 90;
		var zoom:Float = FlxMath.bound(cam.zoom,0.001);
		var width:Int = Math.ceil(cam.width/zoom);
		var height:Int = Math.ceil(cam.height/ zoom);
		var yStart = -height;
		var yEnd = height;

		//trace('transitioning $status');
		switch(status){
			case IN:
				updateFunc = function() gradientFill.y = gradient.y - gradient.height;
			case OUT:
				angle = 270;
				updateFunc = function() gradientFill.y = gradient.y + gradient.height;
				duration = 0.6;
			default:
				//trace("bruh");
		}

		gradient = FlxGradient.createGradientFlxSprite(width, height, [FlxColor.BLACK, FlxColor.TRANSPARENT], 1, angle);
		gradient.scrollFactor.set();
		gradient.screenCenter(X);
		gradient.y = yStart;

		gradientFill = new FlxSprite().makeGraphic(width,height,FlxColor.BLACK);
		gradientFill.scrollFactor.set();
		gradientFill.screenCenter(X);
		updateFunc();

		add(gradientFill);
		add(gradient);

		FlxTween.tween(gradient, {y: yEnd}, duration, {
			onComplete: function(t:FlxTween){
				//trace("done");
				delayThenFinish();
			}
		});
	}

	public override function update(elapsed:Float)
	{
		if (updateFunc != null) 
			updateFunc();

		super.update(elapsed);
	}

	function delayThenFinish():Void{
		new FlxTimer().start(_finalDelayTime, onFinish); // force one last render call before exiting
	}

	function onFinish(f:FlxTimer):Void
	{
		if (finishCallback != null){
			finishCallback();
			finishCallback = null;
		}
	}

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
}