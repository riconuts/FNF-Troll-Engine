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
	private inline static final _internalJackLimit:Float = 192 / 16;
	public inline static final ROWS_PER_BEAT:Int = 48;
	public inline static final ROWS_PER_MEASURE:Int = ROWS_PER_BEAT * 4;

	////
	public static var bpm:Float = 100;
	public static var bpmChangeMap:Array<BPMChangeEvent> = [];
	public static var songPosition:Float = 0;
	public static var offset:Float = 0;
	public static var tracks:Array<FlxSound> = [];
	public static var pitch:Float = 1.0;

	public static var safeZoneOffset:Float = ClientPrefs.hitWindow;
	public static var visualPosition:Float = 0;
	public static var lastSongPos:Float;

	/** Whether the song is currently playing. Use startSong and pauseSong to change this **/
	public static var playing(default, null):Bool = false;
	/** real time at which the song started playing **/
	private static var songStartTimestamp:Float = 0;
	/** elapsed playback time before the song was paused **/ 
	private static var songStartOffset:Float = 0;
	
	public static function startSong(offset:Float = 0)
	{
		Conductor.songStartTimestamp = Main.getTime();
		Conductor.songStartOffset = offset;
		Conductor.playing = true;
		Conductor.songPosition = offset;

		resyncTracks();
	}

	public static function resyncTracks() {
		Conductor.songPosition = getAccPosition();
		for (snd in tracks) {
			snd.stop();
			snd.pitch = pitch;
			snd.play(true, getAccPosition());
		}
	}

	public static function pauseSong() 
	{
		if (!Conductor.playing)
			return;

		Conductor.songPosition = getAccPosition();
		Conductor.playing = false;

		for (snd in tracks) {
			snd.stop();
		}
	}

	public static function resumeSong()
	{
		if (Conductor.playing)
			return;

		startSong(Conductor.songPosition);
	}

	public static function changePitch(pitch:Float)
	{
		var wasPlaying:Bool = Conductor.playing;
		Conductor.pauseSong();

		Conductor.pitch = pitch;
		for (track in tracks)
			track.pitch = pitch;

		if (wasPlaying)
			Conductor.resumeSong();
	}
	
	public static var useAccPosition:Bool = false;
	public static function getAccPosition():Float {
		if (playing && useAccPosition)
			return songStartOffset + (Main.getTime() - songStartTimestamp) * pitch;
		else
			return Conductor.songPosition;
	}

	public static function cleanup() {
		for (snd in tracks)
			snd.stop();

		Conductor.songStartTimestamp = 0;
		Conductor.songStartOffset = 0;

		Conductor.songPosition = 0;
		Conductor.playing = false;
		Conductor.bpmChangeMap = [];
		Conductor.tracks = [];
	}

	////
	public static var crochet:Float = (60 / bpm) * 1000; // beat length in milliseconds
	public static var stepCrochet:Float = crochet / 4; // step length in milliseconds

	public static var curDecStep:Float = 0;
	public static var curDecBeat:Float = 0;
	public static var curStep:Int = 0;
	public static var curBeat:Int = 0;

	public static var jackLimit(get, default):Float = -1;
	@:noCompletion static function get_jackLimit()
		return (jackLimit < 0) ? (jackLimit = Conductor.stepCrochet / _internalJackLimit) : jackLimit;

	////
	@:noCompletion public static var crotchet(get, set):Float;
	@:noCompletion static inline function get_crotchet() return crochet;
	@:noCompletion static inline function set_crotchet(v:Float) return crochet = v;
	
	@:noCompletion @:isVar public static var stepCrotchet(get, set):Float;
	@:noCompletion static inline function get_stepCrotchet() return stepCrochet;
	@:noCompletion static inline function set_stepCrotchet(v:Float) return stepCrochet = v;

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

	/** From MILLISECONDS actually **/ 
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

	public static function updateSteps() {
		var lastChange = Conductor.getBPMFromSeconds(Conductor.songPosition);
		var shit = ((Conductor.songPosition - ClientPrefs.noteOffset) - lastChange.songTime) / lastChange.stepCrochet;
		
		curDecStep = lastChange.stepTime + shit;
		curStep = lastChange.stepTime + Math.floor(shit);
		
		curDecBeat = curDecStep / 4;
		curBeat = Math.floor(curStep / 4);
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
	public inline static function calculateCrochet(bpm:Float):Float {
		return 60000 / bpm; // (60/bpm) * 1000;
	}

	/** Step duration in milliseconds */
	public inline static function calculateStepCrochet(bpm:Float):Float {
		return 15000 / bpm; // calculateCrochet(bpm) / 4;
	}

	public inline static function sectionBeats(section:SwagSection):Float {
		return section.sectionBeats ?? 4.0;
	}

	public inline static function sectionSteps(section:SwagSection):Float {
		return sectionBeats(section) * 4;
	}
}
