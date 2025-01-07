// conductor we have a problem conductor we have a problem conductor we have a problem conductor we have a problem conductor we have a problem conductor we have a problem conductor we have a problem conductor we have a problem conductor we have a problem conductor we have a problem conductor we have a problem conductor we have a problem conductor we have a problem conductor we have a problem conductor we have a problem conductor we have a problem conductor we have a problem conductor we have a problem conductor we have a problem conductor we have a problem conductor we have a problem conductor we have a problem conductor we have a problem conductor we have a problem conductor we have a problem conductor we have a problem conductor we have a problem conductor we have a problem conductor we have a problem conductor we have a problem conductor we have a problem conductor we have a problem conductor we have a problem conductor we have a problem conductor we have a problem conductor we have a problem conductor we have a problem conductor we have a problem conductor we have a problem conductor we have a problem conductor we have a problem conductor we have a problem conductor we have a problem conductor we have a problem conductor we have a problem conductor we have a problem
package funkin;

import funkin.data.Song.SwagSong;
import funkin.data.Section.SwagSection;

typedef BPMChangeEvent =
{
	var stepTime:Int;
	var songTime:Float;
	var bpm:Float;
	@:optional var stepCrochet:Float;
}

class Conductor
{
	////
	public static var bpm:Float = 100;
	public static var crochet:Float = (60 / bpm) * 1000; // beats in milliseconds
	public static var stepCrochet:Float = crochet / 4; // steps in milliseconds
	public static var songPosition:Float = 0;
	public static var visualPosition:Float = 0;
	public static var lastSongPos:Float;
	public static var offset:Float = 0;
	public static var bpmChangeMap:Array<BPMChangeEvent> = [];

	////
	@:isVar public static var crotchet(get, set):Float = 0;
	@:isVar public static var stepCrotchet(get, set):Float = 0;

	@:noCompletion static function get_crotchet()
		return crochet;
	@:noCompletion static function set_crotchet(v:Float)
		return crochet = v;

	@:noCompletion static function get_stepCrotchet()
		return stepCrochet;
	@:noCompletion static function set_stepCrotchet(v:Float)
		return stepCrochet = v;

	////
	private inline static final _internalJackLimit:Float = 192 / 16;
	public inline static final ROWS_PER_BEAT:Int = 48;
	public inline static final ROWS_PER_MEASURE:Int = ROWS_PER_BEAT * 4;

	public static var safeZoneOffset:Float = ClientPrefs.hitWindow;
	public static var jackLimit(get, default):Float = -1;
	@:noCompletion static function get_jackLimit() {
		if (jackLimit < 0)
			jackLimit = Conductor.stepCrochet / _internalJackLimit;

		return jackLimit;
	}

	////
	public static function mapBPMChanges(song:SwagSong, offset:Float=0) {
		Conductor.bpmChangeMap = [];

		if (song == null)
			return;

		var curBPM:Float = song.bpm;
		var totalSteps:Int = 0;
		var totalPos:Float = 0;

		inline function pushBPMChange(newBPM:Float) {
			var event:BPMChangeEvent = {
				stepTime: totalSteps,
				songTime: totalPos,
				bpm: newBPM,
				stepCrochet: calculateStepCrochet(newBPM)
			};
			bpmChangeMap.push(event);
			curBPM = newBPM;
		}

		var firstSec = song.notes[0];
		if (firstSec == null || !firstSec.changeBPM)
			pushBPMChange(song.bpm);

		for (section in song.notes) {
			if (section.changeBPM)
				pushBPMChange(section.bpm);

			var deltaSteps:Int = Math.round(sectionSteps(section));
			totalSteps += deltaSteps;
			totalPos += (15000 * deltaSteps) / curBPM; // calculateStepCrochet(curBPM) * deltaSteps;
		}
		
		print('new BPM map BUDDY [');
		for (ev in bpmChangeMap)
			print('\t$ev');
		print(']');
	}

	public static function changeBPM(newBpm:Float)
	{
		Conductor.jackLimit = -1;
		Conductor.bpm = newBpm;
		Conductor.crochet = Conductor.calculateCrochet(newBpm);
		Conductor.stepCrochet = Conductor.calculateStepCrochet(newBpm);
	}

	public static function getBPMFromSeconds(time:Float):BPMChangeEvent {
		var lastChange:BPMChangeEvent = {
			stepTime: 0,
			songTime: 0,
			bpm: bpm,
			stepCrochet: Conductor.stepCrochet
		}
		
		for (i in 0...Conductor.bpmChangeMap.length) {
			if (time >= Conductor.bpmChangeMap[i].songTime)
				lastChange = Conductor.bpmChangeMap[i];
			else
				break;
		}

		return lastChange;
	}

	public static function getBPMFromStep(step:Float):BPMChangeEvent {
		var lastChange:BPMChangeEvent = {
			stepTime: 0,
			songTime: 0,
			bpm: bpm,
			stepCrochet: Conductor.stepCrochet
		}

		for (i in 0...Conductor.bpmChangeMap.length) {
			if (step >= Conductor.bpmChangeMap[i].stepTime)
				lastChange = Conductor.bpmChangeMap[i];
			else
				break;
		}

		return lastChange;
	}

	public inline static function getStep(time:Float):Float {
		var lastChange = getBPMFromSeconds(time);
		return lastChange.stepTime + (time - lastChange.songTime) / lastChange.stepCrochet;
	}

	public inline static function getBeat(time:Float)
		return getStep(time) * 0.25;

	public inline static function getStepRounded(time:Float):Int
		return Math.floor(getStep(time));
	
	public inline static function getBeatRounded(time:Float):Int
		return Math.floor(getBeat(time));

	public static function stepToSeconds(step:Float):Float {
		var lastChange = getBPMFromStep(step);
		return lastChange.songTime + ((step - lastChange.stepTime) / (lastChange.bpm / 60) / 4);
	}

	public inline static function stepToMs(step:Float):Float {
		return stepToSeconds(step) * 1000;
	}

	public static function getBeatSinceChange(time:Float):Float {
		var lastBPMChange = getBPMFromSeconds(time);
		return (time-lastBPMChange.songTime) / (lastBPMChange.stepCrochet*4);
	}

	public static function getCrotchetAtTime(time:Float):Float {
		var lastChange = getBPMFromSeconds(time);
		return lastChange.stepCrochet*4;
	}

	////
	/** Beat duration in milliseconds */
	inline public static function calculateCrochet(bpm:Float):Float {
		return 60000 / bpm; // (60/bpm) * 1000;
	}

	/** Step duration in milliseconds */
	inline public static function calculateStepCrochet(bpm:Float):Float {
		return 15000 / bpm; // calculateCrochet(bpm) / 4;
	}

	inline static function sectionBeats(section:SwagSection):Float {
		return section.sectionBeats ?? 4.0;
	}

	inline static function sectionSteps(section:SwagSection):Float {
		return sectionBeats(section) * 4;
	}
}
