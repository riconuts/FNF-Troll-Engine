package funkin.states.options;
// fuck you

class QuantNotesSubState extends NotesSubState
{
	public static var defaults:Array<Array<Int>> = [
		[0, -20, 0], // 4th
		[-130, -20, 0], // 8th
		[-80, -20, 0], // 12th
		[128, -30, 0], // 16th
		[-120, -70, -35], // 20th
		[-80, -20, 0], // 24th
		[50, -20, 0], // 32nd
		[-80, -20, 0], // 48th
		[160, -15, 0], // 64th
		[-120, -70, -35], // 96th
		[-120, -70, -35]// 192nd
	];

	public static var quantizations:Array<String> = [
		"4th",
		"8th",
		"12th",
		"16th",
		"20th",
		"24th",
		"32nd",
		"48th",
		"64th",
		"96th",
		"192nd"
	];

	public function new() {
		super();

		valuesArray = ClientPrefs.quantHSV;
		namesArray = quantizations;
		noteFrames = Paths.getSparrowAtlas('QUANTNOTE_assets');
		noteAnimations = ['purple0', 'blue0', 'green0', 'red0'];
	}

	override function resetValue(selected:Int, type:Int) {
		curValue = defaults[selected][type];
		changeValue(selected, type, curValue);
	}
}
