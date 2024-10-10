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
    static inline var _internalJackLimit:Float = 192 / 16;
    @:isVar
	public static var jackLimit(get, default):Float = -1;
	static function get_jackLimit(){
        if(jackLimit < 0)
			jackLimit = Conductor.stepCrochet / _internalJackLimit;

        return jackLimit;
    }
	public inline static final ROWS_PER_BEAT:Int = 48;
	public inline static final ROWS_PER_MEASURE:Int = ROWS_PER_BEAT * 4;
    
    @:isVar
    public static var stepCrotchet(get, set):Float = 0;
    static function get_stepCrotchet()
        return stepCrochet;

	static function set_stepCrotchet(v:Float)
		return stepCrochet = v;

	@:isVar
	public static var crotchet(get, set):Float = 0;

	static function get_crotchet()
		return crochet;

	static function set_crotchet(v:Float)
		return crochet = v;

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

	public inline static function getStep(time:Float){
		var lastChange = getBPMFromSeconds(time);
		return lastChange.stepTime + (time - lastChange.songTime) / lastChange.stepCrochet;
	}

	public inline static function getStepRounded(time:Float):Int
		return Math.floor(getStep(time));
	

	public inline static function getBeat(time:Float)
		return getStep(time) * 0.25;
	

	public inline static function getBeatRounded(time:Float):Int
		return Math.floor(getStepRounded(time) * 0.25);
	

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
		Conductor.jackLimit = -1;
		bpm = newBpm;

		crochet = calculateCrochet(bpm);
		stepCrochet = crochet / 4;
	}
}
