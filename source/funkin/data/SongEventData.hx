package funkin.data;

import haxe.io.Path;

private var defaultEventStuff = [ 
	['Hey!', "Plays the \"Hey!\" animation from Bopeebo,\nValue 1: BF = Only Boyfriend, GF = Only Girlfriend,\nSomething else = Both.\nValue 2: Custom animation duration,\nleave it blank for 0.6s"],
	['Set GF Speed', "Sets GF head bopping speed,\nValue 1: 1 = Normal speed,\n2 = 1/2 speed, 4 = 1/4 speed etc.\nUsed on Fresh during the beatbox parts.\n\nWarning: Value must be integer!"],
	['Add Camera Zoom', "Used on MILF on that one \"hard\" part\nValue 1: Camera zoom add (Default: 0.015)\nValue 2: UI zoom add (Default: 0.03)\nLeave the values blank if you want to use Default."],
	['Play Animation', "Plays an animation on a Character,\nonce the animation is completed,\nthe animation changes to Idle\n\nValue 1: Animation to play.\nValue 2: Character (Dad, BF, GF)"],
	['Camera Follow Pos', "Value 1: X\nValue 2: Y\n\nThe camera won't change the follow point\nafter using this, for getting it back\nto normal, leave both values blank."],
	["Change Focus", "Sets who the camera is focusing on.\nNote that the must hit changing on a section will reset\nthe focus.\nValue 1: Who to focus on (dad, bf)"],
	
	['Stage Event', 'Event whose behaviour defined by the stage.'],
	['Song Event', 'Event whose behaviour defined by the song.'],
	['Set Property', "Value 1: Variable name\nValue 2: New value"],
	
	['Alt Idle Animation', "Sets a specified suffix after the idle animation name.\nYou can use this to trigger 'idle-alt' if you set\nValue 2 to -alt\n\nValue 1: Character to set (Dad, BF or GF)\nValue 2: New suffix (Leave it blank to disable)"],
	['Screen Shake', "Value 1: Camera shake\nValue 2: HUD shake\n\nEvery value works as the following example: \"1, 0.05\".\nThe first number (1) is the duration.\nThe second number (0.05) is the intensity."],
	['Change Character', "Value 1: Character to change (dad, bf, gf)\nValue 2: New character's name"],
	
	['Game Flash', "Value 1: Hexadecimal Color (0xFFFFFFFF is default)\nValue 2: Duration in seconds (0.5 is default)"],

	['Change Scroll Speed', "Value 1: Scroll Speed Multiplier (1 is default)\nValue 2: Time it takes to change fully in seconds."],
	[
		"Constant SV", 
		"Speed changes which don't affect note positions.\n(For example, a speed of 0 stops notes\ninstead of making them go onto the receptors.)\nValue 1: New Speed. Defaults to 1"
		#if EASED_SVs
		+ "\nValue 2: Tween settings\n(Duration and EaseFunc seperated by a / (ex. 1/quadOut))"
		#end
	],
	[
		"Mult SV", 
		"Speed changes which don't affect note positions.\n(For example, a speed of 0 stops notes\ninstead of making them go onto the receptors.)\nValue 1: Speed Multiplier. Defaults to 1"
		#if EASED_SVs
		+ "\nValue 2: Tween settings\n(Duration and EaseFunc seperated by a /(ex. 1/quadOut))"
		#end
	]
];

class SongEventData {
	public static function getEventStuff():Array<Array<String>> {
		var eventStuff = defaultEventStuff.copy();

		var eventsLoaded:Map<String, Bool> = new Map();
		for (directory in Paths.getFolders('events')) {
			Paths.iterateDirectory(directory, function(file:String) {
				var fp = new Path(file);
				if (fp.ext.toLowerCase() != 'txt')
					return;

				var eventName:String = fp.file;
				if (eventsLoaded.exists(eventName))
					return;

				eventsLoaded.set(eventName, true);
				eventStuff.push([eventName, Paths.getContent(Path.join([directory, file]))]);			
			});
		}

		return eventStuff;
	}
}