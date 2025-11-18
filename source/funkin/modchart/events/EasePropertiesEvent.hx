package funkin.modchart.events;
// @author riconuts

import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;

class EasePropertiesEvent extends BaseEvent {
	public var object:Dynamic;

	public var endVals:Dynamic;
	
	public var length:Float;
	
	public var options:TweenOptions;

	private var startVals:Dynamic;
	private var valVars:Array<String> = [];
	private var easeFunc:EaseFunction;

	private var endStep:Float;
	private var initialized:Bool = false;
	private var backward:Bool = false;

	private var running:Bool = false;

	public function new(step:Float, length:Float, object:Dynamic, endVals:Dynamic, options:TweenOptions, modMgr:ModManager) {
		super(step, modMgr);
		this.length = length;
		this.object = object;
		this.endVals = endVals;
		this.options = resolveTweenOptions(options);
	}

	private function resolveTweenOptions(options:TweenOptions) {
		options ??= {};
		options.ease ??= FlxEase.linear;
		options.type ??= ONESHOT;
		options.loopDelay ??= 0.0;
		//options.startDelay ??= 0.0;
		return options;
	}

	// TODO: Use `FlxTween.TweenProperty`s so you can tween "scale.x" n shit like that
	private function setStartValues() {
		if (object == null)
			throw "Cannot tween variables of an object that is null.";

		startVals = {};
		valVars = Reflect.fields(endVals);
		for (fn in valVars) {
			var sV:Null<Float> = Reflect.getProperty(object, fn);
			
			if (sV == null)
				throw 'The object does not have the property "$fn"';

			Reflect.setField(startVals, fn, sV);
		}
	}

	override function run(curStep:Float)
	{
		if (!running) {
			if (startVals == null) {
				if (options.onStart != null)
					options.onStart(this);

				try {					
					setStartValues();
				}catch(e:haxe.Exception) {
					finished = true; // so you can skip over the crash
					throw e;
				}
			}

			running = true;
			easeFunc = options.ease;
			endStep = executionStep + length;
			if (options.type == BACKWARD) backward = true;
		}

		var progress = (curStep - executionStep) / length;
		if (progress > 1.0) progress = 1.0;
		progress = easeFunc(progress);
		if (backward) progress = 1.0 - progress;
		for (fn in valVars) {
			var startVal:Float = Reflect.field(startVals, fn);
			var endVal:Float = Reflect.field(endVals, fn);
			var change:Float = (endVal - startVal);
			var value:Float = startVal + change * progress;
			Reflect.setProperty(object, fn, value);
		}

		if (options.onUpdate != null)
			options.onUpdate(this);
		
		if (curStep >= endStep)
		{
			if (options.onComplete != null)
				options.onComplete(this);

			running = false;

			switch(options.type) {
				case PERSIST:
					ignoreExecution = true;

				case LOOPING:
					executionStep = endStep + options.loopDelay;

				case PINGPONG:
					executionStep = endStep + options.loopDelay;
					backward = !backward;

				case ONESHOT:
					finished = true;

				case BACKWARD:
					finished = true;
			}
		}
	}
}

typedef TweenOptions =
{
	/**
	 * Tween type - bit field of `FlxTween`'s static type constants.
	 */
	@:optional var type:FlxTweenType;

	/**
	 * Optional easer function (see `FlxEase`).
	 */
	@:optional var ease:EaseFunction;

	/**
	 * Optional start callback function.
	 */
	@:optional var onStart:EasePropertiesEvent -> Void;

	/**
	 * Optional update callback function.
	 */
	@:optional var onUpdate:EasePropertiesEvent -> Void;

	/**
	 * Optional complete callback function.
	 */
	@:optional var onComplete:EasePropertiesEvent -> Void;
	
	/**
	 * Steps to wait until starting this tween, `0` by default.
	 */
	/* bruh just add it to the starting step
	@:optional var startDelay:Float;
	*/

	/**
	 * Steps to wait between loops of this tween, `0` by default.
	 */
	@:optional var loopDelay:Float;
}
