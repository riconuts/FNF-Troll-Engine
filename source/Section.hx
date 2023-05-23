package;

typedef SwagSection =
{
	var sectionNotes:Array<Array<Dynamic>>;
	//var lengthInSteps:Int;
	var typeOfSection:Int;
	var mustHitSection:Bool;
	var gfSection:Bool;
	var bpm:Float;
	var changeBPM:Bool;
	var altAnim:Bool;
	var sectionBeats:Float;
}

class Section
{
	public var sectionNotes:Array<Dynamic> = [];

	public var sectionBeats:Float = 4; // duct tape
	//public var lengthInSteps:Int = 16;
	public var gfSection:Bool = false;
	public var typeOfSection:Int = 0;
	public var mustHitSection:Bool = true;

	/**
	 *	Copies the first section into the second section!
	 */
	public static var COPYCAT:Int = 0;

	public function new(sectionBeats:Int = 4)
	{
		this.sectionBeats = sectionBeats;
	}
}
