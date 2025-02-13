package funkin.modchart.events;
// @author Nebula_Zorua


import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;

class ModEaseEvent extends ModEvent {
	public var endStep:Float = 0;
	public var startVal:Null<Float>;
	public var easeFunc:EaseFunction;
	public var length:Float = 0;
	public function new(step:Float, endStep:Float, modName:String, target:Float, easeFunc:EaseFunction, player:Int = 0, modMgr:ModManager, ?startVal:Float) {
		super(step, modName, target, player, modMgr);
		this.endStep = endStep; 
		this.easeFunc = easeFunc;
		this.startVal=startVal;
		
		#if debug
		if(mod==null)trace(modName + " is null!");
		#end
		length = endStep - step;
	}

	function ease(e:EaseFunction, t:Float, b:Float, c:Float, d:Float)
	{ // elapsed, begin, change (ending-beginning), duration
		var time = t / d;
		return c * e(time) + b;
	}

	override function run(curStep:Float)
	{
		if (mod == null && !finished){
			trace("no mod! mod name is wrong (" + modName +")");
			finished = true;
			return;
		}
		if (curStep < endStep)
		{
			if (this.startVal == null)
				this.startVal = mod.getValue(player);
			

			var passed = curStep - executionStep;
			var change = endVal - startVal;
			//mod.setValue(ease(easeFunc, passed, startVal, change, length), player);
			manager.setValue(modName, ease(easeFunc, passed, startVal, change, length), player);
		}
		else if (curStep >= endStep)
		{
			finished = true;
			manager.setValue(modName, endVal, player); // expoInOut doesnt end at the correct value WHAT
		}
	}
}