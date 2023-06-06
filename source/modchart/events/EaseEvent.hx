// @author Nebula_Zorua
package modchart.events;

import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
class EaseEvent extends BaseEvent
{
	public var easeFunc:EaseFunction;
	public var callback:(EaseEvent, Float, Float) -> Void;
	public var endStep:Float = 0;
	public var progress:Float = 0;
    public var value:Float = 0;
    public var length:Float = 0;

	public function new(step:Float, endStep:Float, easeFunc:EaseFunction, callback:(EaseEvent, Float, Float) -> Void, modMgr:ModManager)
	{
		super(step, modMgr);
		this.callback = callback;
		this.easeFunc = easeFunc;
        this.endStep = endStep;

		length = endStep - step;
	}


	function ease(e:EaseFunction, t:Float, b:Float, c:Float, d:Float)
	{ // elapsed, begin, change (ending-beginning), duration
		var time = t / d;
		return c * e(time) + b;
	}

	override function run(curStep:Float)
	{
		if (curStep <= endStep)
		{
			var passed = curStep - executionStep;
			progress = passed / (endStep - executionStep);
            
			value = ease(easeFunc, passed, 0, 1, length);
			callback(this, value, curStep);
		}
		else
			finished = true;

		if (finished)
			progress = 1;
	}
}