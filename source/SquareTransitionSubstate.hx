package;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.addons.transition.FlxTransitionSprite.TransitionStatus;
import flixel.addons.transition.TransitionSubstate;
import flixel.math.*;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.addons.display.shapes.FlxShapeBox;
import flixel.util.FlxTimer;

class SquareTransitionSubstate extends TransitionSubstate
{
	public static var startPoint = new FlxPoint();
	public static var startSize = new FlxPoint();
	public static var endPoint = new FlxPoint();
	public static var endSize = new FlxPoint();

	var _finalDelayTime:Float = 0.0;

	public static var defaultCamera:FlxCamera;
	public static var nextCamera:FlxCamera;

	var funkyRectangle:FlxShapeBox;

	public override function destroy():Void
	{
		super.destroy();

		if (funkyRectangle != null)
			funkyRectangle.destroy();
		
		finishCallback = null;
	}

	function onFinish(f:FlxTimer):Void
	{
		if (finishCallback != null)
		{
			finishCallback();
			finishCallback = null;
		}
	}

	function delayThenFinish():Void
	{
		new FlxTimer().start(_finalDelayTime, onFinish); // force one last render call before exiting
	}

	override public function start(status: TransitionStatus){
		var cam = nextCamera != null ? nextCamera : (defaultCamera!=null?defaultCamera:FlxG.cameras.list[FlxG.cameras.list.length - 1]);
		cameras = [cam];

		nextCamera = null;

		funkyRectangle = new FlxShapeBox(startPoint.x, startPoint.y, startSize.x, startSize.y, {thickness: 3, color: FlxColor.fromRGB(255, 242, 0)}, FlxColor.BLACK);
		add(funkyRectangle);

		FlxTween.tween(
			funkyRectangle, 
			{
				x: endPoint.x, 
				y: endPoint.y,
				width: endSize.x,
				height: endSize.y,
				shapeWidth: endSize.x,
				shapeHeight: endSize.y
			}, 
			0.3,
			{
				ease: FlxEase.quadOut,
				onComplete: function(t:FlxTween){delayThenFinish();}
			}
		);
	}
}
