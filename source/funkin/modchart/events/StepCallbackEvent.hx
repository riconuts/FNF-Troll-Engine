package funkin.modchart.events;
// @author Nebula_Zorua


class StepCallbackEvent extends CallbackEvent {
	public var endStep:Float = 0;
	public var progress:Float = 0;
	public function new(step:Float, endStep:Float, callback:(CallbackEvent, Float) -> Void, modMgr:ModManager)
	{
		super(step, callback, modMgr);
		this.endStep = endStep;
	}
	override function run(curStep:Float){
		
		if(curStep<=endStep){
			progress = (curStep - executionStep) / (endStep - executionStep);
			try{
				callback(this, curStep);
			}catch(e:haxe.Exception){
				trace("Modchart function error: " + e.toString());
				finished = true;
			}
		}else
			finished = true;

		if (finished)
			progress = 1;
	}
}