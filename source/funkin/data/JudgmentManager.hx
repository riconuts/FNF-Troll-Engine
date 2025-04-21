package funkin.data;

import funkin.objects.notes.Note;

/**
 * Defines how a judgment interacts w/ the combo count
 */
enum abstract ComboBehaviour(Int) from Int to Int
{
	/** doesnt increment or break your combo */
	var IGNORE = 0;
	/** increments your combo by 1 */
	var INCREMENT = 1;
	/** breaks your combo */
	var BREAK = -1;
}

/**
 * Defines how a judgment behaves (hit window, score, etc)
 */
typedef JudgmentData = {
	internalName:String, // internal name of the judge
	displayName:String, // how this judge is displayed in UI, etc
	window:Float, // hit window to hit this judge
	score:Int, // score you gain when hitting this judge
	accuracy:Float, // how much accuracy is added by this judge. unused by wife3
	health:Float, // % of health to add/remove
	noteSplash:Bool, // whether this judge should cause a note splash
	// var frame:Int; // where in the judgment sheet this judgment lies

	?wifePoints:Float, // if this isn't null, then Wife3 wont do any calculations and will instead just add these to the wife score/accuracy
	?pbotPoints:Float, // if this isn't null, then PBOT wont do any calculations and will instead just add these to the pbot score/accuracy
	?hideJudge:Bool, // if this is true then this judge wont show a judgment image
	?comboBehaviour:ComboBehaviour, // how this judge affects your combo (IGNORE, INCREMENT or BREAK). Defaults to INCREMENT
	?badJudgment:Bool, // used for mines, etc. makes it so the window isnt scaled by the judge difficulty. defaults to false
	?countAsHit:Bool // False for stuff like hold drops

}

/**
 * Ease of access to default judgments
 */
enum abstract Judgment(String) from String to String // this just makes it easier
{
	var UNJUDGED = 'unjudged'; // yet to be hit
	var TIER1 = 'tier1'; // shit
	var TIER2 = 'tier2'; // bad
	var TIER3 = 'tier3'; // good
	var TIER4 = 'tier4'; // sick
	var TIER5 = 'tier5'; // epic
	var MISS = 'miss'; // miss
	var DROPPED_HOLD = 'holdDrop'; // miss but when a hold is attached
	var DAMAGELESS_MISS = 'customMiss'; // miss but this doesnt cause damage
	var HIT_MINE = 'mine'; // mine
	var MISS_MINE = 'missMine'; // hitCausesMiss mine. a mine but with health being derived from the note's .missHealth
	var CUSTOM_MINE = 'customMine'; // mine, but with no health loss
}

/**
 * Handles judgments and everything related to them (judge windows, etc).
 * I hate how Psych does judges with its Rating classes so I decided to rewrite it lol
 */
class JudgmentManager {
	public var judgmentData:Map<Judgment, JudgmentData> = [
		#if USE_EPIC_JUDGEMENT
		TIER5 => {
			internalName: "epic",
			displayName: "Epic",
			window: ClientPrefs.epicWindow,
			score: 500,
			accuracy: 100,
			health: 1.15, // maybe change to 1, to match V-Slice?
			noteSplash: true,
		},
		#end
		TIER4 => {
			internalName: "sick",
			displayName: "Sick",
			window: ClientPrefs.sickWindow,
			score: 350,
			accuracy: 90,
			health: 1.15, // maybe change to 0.75, to match V-Slice?
			noteSplash: true,
		},
		TIER3 => {
			internalName: "good",
			displayName: "Good",
			window: ClientPrefs.goodWindow,
			score: 100,
			accuracy: 10,
			health: 0, // maybe change to 0.375 to match V-Slice?
			noteSplash: false,
		},
		TIER2 => {
			internalName: "bad",
			displayName: "Bad",
			window: ClientPrefs.badWindow,
			score: 0,
			accuracy: -75,
			health: -1.15, // I think we could make this less punishing, just to be closer to V-Slice, but I think shit should stay where it is
			comboBehaviour: BREAK,
			noteSplash: false,
		},
		TIER1 => {
			internalName: "shit",
			displayName: "Shit",
			window: ClientPrefs.hitWindow,
			score: -150,
			accuracy: -220,
			health: -2.375,
			comboBehaviour: BREAK,
			noteSplash: false,
		},
		MISS => {
			internalName: "miss",
			displayName: "Miss",
			window: -1,
			score: -350,
			accuracy: -275,
			wifePoints: Wife3.missWeight,
			pbotPoints: PBot.missWeight,
			health: -5,
			comboBehaviour: BREAK,
			noteSplash: false,
		},
		DROPPED_HOLD => {
			internalName: "miss",
			displayName: "Miss",
			window: -1,
			score: -350,
			accuracy: -175,
			wifePoints: Wife3.holdDropWeight,
			pbotPoints: 0,
			health: -2.5,
			comboBehaviour: BREAK,
			noteSplash: false,
			countAsHit: false
		},
		DAMAGELESS_MISS => {
			internalName: "miss",
			displayName: "Miss",
			window: -1,
			score: -350,
			wifePoints: Wife3.missWeight,
			pbotPoints: PBot.missWeight,
			accuracy: -450,
			health: 0, //-5,
			comboBehaviour: BREAK,
			noteSplash: false,
		},
		HIT_MINE => {
			internalName: "mine",
			displayName: "Mine",
			window: 75, // same as Etterna's mines
			score: -200,
			accuracy: -450,
			wifePoints: Wife3.mineWeight,
			pbotPoints: PBot.mineWeight,
			health: -5,
			badJudgment: true,
			comboBehaviour: IGNORE,
			noteSplash: false,
			hideJudge: true
		},
		MISS_MINE => { // for legacy reasons
			internalName: "miss",
			displayName: "Mine",
			window: 75,
			score: -200,
			accuracy: -450,
			wifePoints: Wife3.mineWeight,
			pbotPoints: PBot.mineWeight,
			health: 0,
			badJudgment: true,
			comboBehaviour: BREAK,
			noteSplash: true,
			hideJudge: true
		},
		CUSTOM_MINE => {
			internalName: "customMine",
			displayName: "Mine",
			window: 75,
			score: 0,
			accuracy: -450,
			wifePoints: Wife3.mineWeight,
			pbotPoints: PBot.mineWeight,
			health: 0,
			badJudgment: true,
			comboBehaviour: IGNORE,
			noteSplash: false,
			hideJudge: true
		}
	];
	// these are judgments that you can *actually* hit and arent caused by special notes (i.e Mines) // should be from highest to lowest
	public var hittableJudgments:Array<Judgment>; 
	public var judgeTimescale:Float = 1; // scales hit windows
	public var useEpics:Bool;

	public function new(?useEpics:Bool)
	{
		#if USE_EPIC_JUDGEMENT
		if (ClientPrefs.useEpics || useEpics==true){
			this.useEpics = true;
			hittableJudgments = [TIER5, TIER4, TIER3, TIER2, TIER1];
			return;
		}
		#end

		this.useEpics = false;
		hittableJudgments = [TIER4, TIER3, TIER2, TIER1];
		judgmentData.get(TIER4).accuracy = 100;
		judgmentData.get(TIER2).comboBehaviour = INCREMENT;
	}

	/**
	 * Returns the hit window for a judgment, with the judgeTimescale taken into account
	 * @param judgment The judgment to get the hit window for
	 */
	inline public function getWindow(judgment:Judgment){
		var d:JudgmentData = judgmentData.get(judgment);
		return d.window * ((d.badJudgment && judgeTimescale<1)?1:judgeTimescale);
	}
	
	/**
	 * Returns a judgment for a time difference.
	 */
	public function judgeTimeDiff(diff:Float) {
		for (judge in hittableJudgments) {
			if (diff <= getWindow(judge))
				return judge;
		}
		return UNJUDGED;
	}

	/**
	 * Returns a judgment for a note.
	 * @param note Note to return a judgment for
	 * @param time The position the note time is compared to for judgment
	 */
	public function judgeNote(note:Note, ?hitTime:Float)
	{
		// might be inefficient? idk might wanna optimize this at some point if so

		if (hitTime==null) hitTime = Conductor.getAccPosition();
		var diff:Float = Math.abs(note.strumTime - hitTime);

		switch(note.noteType){
			case 'Hurt Note':
				if (diff <= getWindow(HIT_MINE)) 
					return HIT_MINE;

			default:
				if (note.noteScript != null){
					var judge = note.noteScript.executeFunc("judgeNote", [note, diff], note);
					if (judge != null) return judge;
				}

				if (note.defaultJudgement != null) {
					if (diff <= getWindow(note.defaultJudgement))
						return note.defaultJudgement;

					return UNJUDGED;
				}


				if (note.hitCausesMiss) {
					if (diff <= getWindow(MISS_MINE))
						return MISS_MINE;

					return UNJUDGED;
				}
				
				return judgeTimeDiff(diff);
		}
		// did you know if you always return UNJUDGED a note won't be hittable?
		// i thought that was interesting
		return UNJUDGED;
		// (aka fake notes when)
	}
}

// V-Slice

class PBot
{
	public static inline final version:Float = 1; // increment this if any values for scoring changes
	
	public static var missThreshold:Float = 160.0; // This gets set in PlayState

	static inline final perfectThreshold:Float = 5.0;
	public static var holdScorePerSecond:Float = 250.0;
	public static final missWeight = -10; // PBot is weird and barely penalizes a miss lol
	public static final minWeight = 0;
	public static final perfectWeight:Float = 500; // PBot is out of 500

	// troll-specific
	public static final mineWeight = -500;

	static inline final scoringSlope = 0.080;
	static inline final scoringOffset = 54.99;

	public static function getAcc(noteDiff:Float) {
		// trace(noteDiff, missThreshold);

		// TODO: find a math wizard who can add timescale to this
		
		return (switch (noteDiff) {
			case(_ <= perfectThreshold) => true:
				perfectWeight;
			case(_ > missThreshold) => true:
				missWeight;
			default:
				// Fancy equation.
				var factor:Float = 1.0 - (1.0 / (1.0 + Math.exp(-scoringSlope * (noteDiff - scoringOffset))));

				Std.int(perfectWeight * factor + minWeight);
		}) * 0.01;
	}
}
// Etterna
class Wife3
{
	public static var judgeScales:Map<String, Float> = [
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
	
	public static inline final version:Float = 1; // increment this if any values for scoring changes

	public static final missWeight:Float = -5.5;
	public static final mineWeight:Float = -7;
	public static final holdDropWeight:Float = -4.5;
	
	static inline final a1 = 0.254829592;
	static inline final a2 = -0.284496736;
	static inline final a3 = 1.421413741;
	static inline final a4 = -1.453152027;
	static inline final a5 = 1.061405429;
	static inline final p = 0.3275911;

	public static function werwerwerwerf(x:Float):Float
	{
		var neg = x < 0;
		x = Math.abs(x);
		var t = 1 / (1+p*x);
		var y = 1 - (((((a5*t+a4)*t)+a3)*t+a2)*t+a1)*t*Math.exp(-x*x);
		return neg ? -y : y;
	}

	public static var timeScale:Float = 1;
	public static function getAcc(noteDiff:Float, ?ts:Float):Float { // https://github.com/etternagame/etterna/blob/0a7bd768cffd6f39a3d84d76964097e43011ce33/src/RageUtil/Utils/RageUtil.h
		if(ts==null)ts=timeScale;
		if(ts>1)ts=1;
		var jPow:Float = 0.75;
		var maxPoints:Float = 2.0;
		var ridic:Float = 5 * ts;
		var shit_weight:Float = 200;
		var absDiff = Math.abs(noteDiff);
		var zero:Float = 65 * Math.pow(ts, jPow);
		var dev:Float = 22.7 * Math.pow(ts, jPow);

		if(absDiff<=ridic){
			return maxPoints;
		}else if(absDiff<=zero){
			return maxPoints*werwerwerwerf((zero-absDiff)/dev);
		}else if(absDiff<=shit_weight){
			return (absDiff-zero)*missWeight/(shit_weight-zero);
		}
		return missWeight;
	}
}