package funkin.modchart.events;
// @author Nebula_Zorua


class ModEvent extends BaseEvent {
	public var modName:String;
	public var endVal:Float;
	public var player:Int;

	private var mod:Modifier;

	public function new(step:Float, modName:String, target:Float, player:Int = -1, modMgr:ModManager)
	{
		super(step, modMgr);
		this.modName = modName;
		this.player = player;
		endVal = target;
	}

	override function addedToTimeline()
		this.mod = manager.get(modName);
}