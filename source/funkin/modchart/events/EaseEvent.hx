package funkin.modchart.events;
// @author Nebula_Zorua

import flixel.tweens.FlxEase.EaseFunction;

class EaseEvent extends BaseEvent
{
	public var endStep:Float;
	public var easeFunc:EaseFunction;
	public var callback:(EaseEvent, Float, Float) -> Void;

	/** Ease length in steps **/
	public var length:Float;

	/** Ease progress percentage [0.0, 1.0] **/
	public var progress:Float = 0;

	public var value:Float = 0;

	public function new(step:Float, endStep:Float, easeFunc:EaseFunction, callback:(EaseEvent, Float, Float) -> Void, modMgr:ModManager)
	{
		super(step, modMgr);
		this.callback = callback;
		this.easeFunc = easeFunc;
		this.endStep = endStep;

		length = endStep - step;
	}

	override function run(curStep:Float)
	{
		if (curStep <= endStep)
		{
			progress = (curStep - executionStep) / length;
			value = easeFunc(progress);
			callback(this, value, curStep);
		}
		else{
			finished = true;
			progress = 1.0;
			callback(this, 1.0, curStep);
		}
	}
}