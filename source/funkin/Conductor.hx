// conductor we have a problem conductor we have a problem conductor we have a problem conductor we have a problem conductor we have a problem conductor we have a problem conductor we have a problem conductor we have a problem conductor we have a problem conductor we have a problem conductor we have a problem conductor we have a problem conductor we have a problem conductor we have a problem conductor we have a problem conductor we have a problem conductor we have a problem conductor we have a problem conductor we have a problem conductor we have a problem conductor we have a problem conductor we have a problem conductor we have a problem conductor we have a problem conductor we have a problem conductor we have a problem conductor we have a problem conductor we have a problem conductor we have a problem conductor we have a problem conductor we have a problem conductor we have a problem conductor we have a problem conductor we have a problem conductor we have a problem conductor we have a problem conductor we have a problem conductor we have a problem conductor we have a problem conductor we have a problem conductor we have a problem conductor we have a problem conductor we have a problem conductor we have a problem conductor we have a problem conductor we have a problem
package funkin;

import funkin.data.Section.SwagSection;
import funkin.data.JudgmentManager.Judgment;
import funkin.data.Song.SwagSong;

typedef BPMChangeEvent =
{
	var stepTime:Int;
	var songTime:Float;
	var bpm:Float;
	@:optional var stepCrochet:Float;
}

class Conductor
{
	public static var judgeScales:Map<String, Float> = [
		// since APPARENTLY Map<Float, String> is bad
		"J1" => 1.50,
		"J2" => 1.33,
		"J3" => 1.16,
		"J4" => 1.0,
		"J5" => 0.84,
		"J6" => 0.66,
		"J7" => 0.5,
		"J8" => 0.33,
		"JUSTICE" => 0.2
	];

	public static var ROWS_PER_BEAT:Int = 48;
	// its 48 in ITG but idk because FNF doesnt work w/ note rows
	public static var ROWS_PER_MEASURE:Int = ROWS_PER_BEAT*4;

	public static var MAX_NOTE_ROW = 1 << 30; // from Stepmania

	public inline static function beatToRow(beat:Float):Int
		return Math.round(beat * ROWS_PER_BEAT);

	public inline static function rowToBeat(row:Int):Float
		return row / ROWS_PER_BEAT;

	public inline static function secsToRow(sex:Float):Int
		return Math.round(getBeat(sex) * ROWS_PER_BEAT);
    

	public static var bpm:Float = 100;
	public static var crochet:Float = ((60 / bpm) * 1000); // beats in milliseconds
	public static var stepCrochet:Float = crochet / 4; // steps in milliseconds
	public static var songPosition:Float = 0;
	public static var visualPosition:Float = 0;
	public static var lastSongPos:Float;
	public static var offset:Float = 0;

	//public static var safeFrames:Int = 10;
	public static var safeZoneOffset:Float = ClientPrefs.hitWindow; //(ClientPrefs.safeFrames / 60) * 1000; // is calculated in create(), is safeFrames in milliseconds

	public static var bpmChangeMap:Array<BPMChangeEvent> = [];

	public function new() {}

	public static function judgeNote(diff:Float=0):Judgment // die
	{
		var jm = funkin.states.PlayState.instance.judgeManager;
		for (judge in jm.hittableJudgments)
		{
			if (diff <= jm.getWindow(judge))
				return judge;
		}
		return UNJUDGED;
	}

	inline public static function beatToNoteRow(beat:Float):Int{
		return Math.round(beat*Conductor.ROWS_PER_BEAT);
	}

	inline public static function noteRowToBeat(row:Float):Float{
		return row/Conductor.ROWS_PER_BEAT;
	}

	public static function timeSinceLastBPMChange(time:Float):Float{
		var lastChange = getBPMFromSeconds(time);
		return time-lastChange.songTime;
	}

	public static function getBeatSinceChange(time:Float):Float{
		var lastBPMChange = getBPMFromSeconds(time);
		return (time-lastBPMChange.songTime) / (lastBPMChange.stepCrochet*4);
	}

	public static function getCrotchetAtTime(time:Float){
		var lastChange = getBPMFromSeconds(time);
		return lastChange.stepCrochet*4;
	}

	public static function getBPMFromSeconds(time:Float){
		var lastChange:BPMChangeEvent = {
			stepTime: 0,
			songTime: 0,
			bpm: bpm,
			stepCrochet: stepCrochet
		}
		for (i in 0...Conductor.bpmChangeMap.length)
		{
			if (time >= Conductor.bpmChangeMap[i].songTime)
				lastChange = Conductor.bpmChangeMap[i];
			else
				break;
		}

		return lastChange;
	}

	public static function getBPMFromStep(step:Float){
		var lastChange:BPMChangeEvent = {
			stepTime: 0,
			songTime: 0,
			bpm: bpm,
			stepCrochet: stepCrochet
		}
		for (i in 0...Conductor.bpmChangeMap.length)
		{
			if (step >= Conductor.bpmChangeMap[i].stepTime)
				lastChange = Conductor.bpmChangeMap[i];
			else
				break;
		}

		return lastChange;
	}

	public static function beatToSeconds(beat:Float): Float{
		var step = beat * 4;
		var lastChange = getBPMFromStep(step);
		return lastChange.songTime + ((step - lastChange.stepTime) / (lastChange.bpm / 60) * 0.25) * 1000; // TODO: make less shit and take BPM into account PROPERLY
	}

	public static function getStep(time:Float){
		var lastChange = getBPMFromSeconds(time);
		return lastChange.stepTime + (time - lastChange.songTime) / lastChange.stepCrochet;
	}

	public static function getStepRounded(time:Float){
		var lastChange = getBPMFromSeconds(time);
		return lastChange.stepTime + Math.floor(time - lastChange.songTime) / lastChange.stepCrochet;
	}

	public static function getBeat(time:Float){
		return getStep(time) * 0.25;
	}

	public static function getBeatRounded(time:Float):Int{
		return Math.floor(getStepRounded(time) * 0.25);
	}

	public static function mapBPMChanges(song:SwagSong, offset:Float=0)
	{
		bpmChangeMap = [];

		var curBPM:Float = song.bpm;
		var totalSteps:Int = -Math.floor(calculateCrochet(curBPM) * 0.25 * offset);
		var totalPos:Float = -offset;

		inline function pushChange(newBPM:Float) {
			var event:BPMChangeEvent = {
				stepTime: totalSteps,
				songTime: totalPos,
				bpm: newBPM,
				stepCrochet: calculateCrochet(newBPM) / 4
			};
			bpmChangeMap.push(event);
			curBPM = newBPM;
		}

		var firstSec = song.notes[0];
		if (firstSec == null || !firstSec.changeBPM)
			pushChange(song.bpm);

		for (section in song.notes) {
			if (section.changeBPM)
				pushChange(section.bpm);

			var deltaSteps:Int = Math.round(sectionBeats(section) * 4);
			totalSteps += deltaSteps;
			totalPos += (15000 * deltaSteps) / curBPM; //((60 / curBPM) * 1000 / 4) * deltaSteps;
		}
		
		trace("new BPM map BUDDY " + bpmChangeMap);
	}

	static function sectionBeats(section:SwagSection):Float
	{
		var beats:Null<Float> = (section==null) ? null : section.sectionBeats;
		return (beats==null) ? 4 : section.sectionBeats;
	}
	
	inline static function getSectionBeats(song:SwagSong, section:Int)
	{
		return sectionBeats(song.notes[section]);
	}

	inline public static function calculateCrochet(bpm:Float){
		return 60000 / bpm; // (60/bpm) * 1000;
	}

	public static function changeBPM(newBpm:Float)
	{
		bpm = newBpm;

		crochet = calculateCrochet(bpm);
		stepCrochet = crochet / 4;
	}
}
