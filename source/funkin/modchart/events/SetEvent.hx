package funkin.modchart.events;
// @author Nebula_Zorua


class SetEvent extends ModEvent {
	override function run(curStep:Float)
	{
		//mod.setValue(endVal, player);
		manager.setValue(modName, endVal, player);
		finished = true;
	}
}