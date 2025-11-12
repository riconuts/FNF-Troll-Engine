package funkin.modchart.events;
// @author Nebula_Zorua

import flixel.tweens.FlxEase;

class ModEaseEvent extends ModEvent {
	public var endStep:Float;
	public var startVal:Null<Float>;
	public var easeFunc:EaseFunction;

	/** Ease length in steps **/
	public var length:Float = 0;

	public function new(step:Float, endStep:Float, modName:String, target:Float, easeFunc:EaseFunction, player:Int = 0, modMgr:ModManager, ?startVal:Float) {
		super(step, modName, target, player, modMgr);
		this.endStep = endStep; 
		this.easeFunc = easeFunc;
		this.startVal = startVal;

		length = endStep - step;
	}

	override function run(curStep:Float)
	{
		if (mod == null && !finished){
			trace('no mod! mod name is wrong ($modName)');
			finished = true;
			return;
		}
		if (curStep < endStep)
		{
			if (this.startVal == null)
				this.startVal = mod.getValue(player);
			
			var progress = (curStep - executionStep) / length;
			var change = (endVal - startVal);
			var value = startVal + change * easeFunc(progress);

			//mod.setValue(value, player);
			manager.setValue(modName, value, player);
		}
		else if (curStep >= endStep)
		{
			finished = true;
			manager.setValue(modName, endVal, player); // expoInOut doesnt end at the correct value WHAT
		}
	}
}