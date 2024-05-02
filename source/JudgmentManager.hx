package;

import scripts.FunkinHScript;
import PlayState.Wife3;
import flixel.util.FlxColor;

/**
 * Defines how a judgment interacts w/ the combo count
 */
@:enum abstract ComboBehaviour(Int) from Int to Int
{
    var IGNORE = 0; // doesnt increment or break your combo
    var INCREMENT = 1; // increments your combo by 1
    var BREAK = -1; // breaks your combo
}

/**
 * Defines how a judgment behaves (hit window, score, etc)
 */
typedef JudgmentData = {
    var internalName:String; // internal name of the judge
    var displayName:String; // how this judge is displayed in UI, etc
    var window:Float; // hit window to hit this judge
    var score:Int; // score you gain when hitting this judge
    var accuracy:Float; // how much accuracy is added by this judge. unused by wife3
    var health:Float; // % of health to add/remove
	var noteSplash:Bool; // whether this judge should cause a note splash
    // var frame:Int; // where in the judgment sheet this judgment lies

	@:optional var wifePoints:Float; // if this isn't null, then Wife3 wont do any calculations and will instead just add these to the wife score/accuracy
    @:optional var hideJudge:Bool; // if this is true then this judge wont show a judgment image
    @:optional var comboBehaviour:ComboBehaviour; // how this judge affects your combo (IGNORE, INCREMENT or BREAK). Defaults to INCREMENT
    @:optional var badJudgment:Bool; // used for mines, etc. makes it so the window isnt scaled by the judge difficulty. defaults to false

}

/**
 * Ease of access to default judgments
 */
@:enum abstract Judgment(String) from String to String // this just makes it easier
{
	var UNJUDGED = 'none'; // unjudged
	var TIER1 = 'tier1'; // shit / retard
	var TIER2 = 'tier2'; // bad / gay
	var TIER3 = 'tier3'; // good / cool
	var TIER4 = 'tier4'; // sick / awesome
	var TIER5 = 'tier5'; // epic / killer
	var MISS = 'miss'; // miss / fail
	var DROPPED_HOLD = 'holdDrop';
    var DAMAGELESS_MISS = 'customMiss'; // miss / fail but this doesnt cause damage
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
            displayName: "Killer",
			window: ClientPrefs.epicWindow,
            score: 500,
            accuracy: 100,
            health: 1.15, // maybe change to 1, to match V-Slice?
			noteSplash: true,
        },
		#end
        TIER4 => {
            internalName: "sick",
            displayName: "Awesome",
			window: ClientPrefs.sickWindow,
            score: 350,
            accuracy: 90,
			health: 1.15, // maybe change to 0.75, to match V-Slice?
			noteSplash: true,
        },
        TIER3 => {
            internalName: "good",
            displayName: "Cool",
			window: ClientPrefs.goodWindow,
            score: 100,
            accuracy: 10,
            health: 0, // maybe change to 0.375 to match V-Slice?
			noteSplash: false,
        },
        TIER2 => {
            internalName: "bad",
            displayName: "Gay",
			window: ClientPrefs.badWindow,
            score: 0,
            accuracy: -75,
            health: -1.15, // I think we could make this less punishing, just to be closer to V-Slice, but I think shit should stay where it is
			comboBehaviour: BREAK,
			noteSplash: false,
        },
        TIER1 => {
            internalName: "shit",
            displayName: "Retard",
			window: ClientPrefs.hitWindow,
            score: -150,
            accuracy: -220,
            health: -2.375,
			comboBehaviour: BREAK,
			noteSplash: false,
        },
        MISS => {
            internalName: "miss",
			displayName: "Fail",
            window: -1,
            score: -350,
            accuracy: -275,
			wifePoints: Wife3.missWeight,
            health: -5,
			comboBehaviour: BREAK,
			noteSplash: false,
        },
		DROPPED_HOLD => {
			internalName: "miss",
			displayName: "Fail",
			window: -1,
			score: -350,
			accuracy: -225,
			wifePoints: Wife3.holdDropWeight,
			health: -2.5,
			comboBehaviour: BREAK,
			noteSplash: false,
		},
		DAMAGELESS_MISS => {
			internalName: "miss",
			displayName: "Fail",
			window: -1,
			score: -350,
			wifePoints: Wife3.missWeight,
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
            health: 0,
            badJudgment: true,
			comboBehaviour: IGNORE,
			noteSplash: false,
			hideJudge: true
        }
    ];
    public var judgeTimescale:Float = 1; // scales hit windows
	public var hittableJudgments:Array<Judgment> = [#if USE_EPIC_JUDGEMENT TIER5, #end TIER4, TIER3, TIER2, TIER1]; // should be from highest to lowest
    // these are judgments that you can *actually* hit and arent caused by special notes (i.e Mines)

    /**
     * Returns the hit window for a judgment, with the judgeTimescale taken into account
     * @param judgment The judgment to get the hit window for
     */
    inline public function getWindow(judgment:Judgment){
		var d:JudgmentData = judgmentData.get(judgment);
		return d.window * ((d.badJudgment && judgeTimescale<1)?1:judgeTimescale);
    }
    
	/**
	 * Returns a judgment for a note.
	 * @param note Note to return a judgment for
	 * @param time The position the note time is compared to for judgment
	 */
	public function judgeNote(note:Note, ?time:Float)
	{
        // might be inefficient? idk might wanna optimize this at some point if so

		if (time==null)time=Conductor.songPosition;

		var diff = Math.abs(note.strumTime - time);

        switch(note.noteType){
            case 'Hurt Note':
                if(diff <= getWindow(HIT_MINE))
                    return HIT_MINE;
            default:
				if (note.noteScript != null && note.noteScript.scriptType == 'hscript')
				{
					var noteScript:FunkinHScript = cast note.noteScript;
					var judge = noteScript.executeFunc("judgeNote", [note, diff], note);
					if (judge != null)
						return judge;
				}

				if (note.hitCausesMiss){
					if (diff <= getWindow(MISS_MINE))
						return MISS_MINE;
                }else{
                    for(judge in hittableJudgments){
                        if(diff <= getWindow(judge))
                            return judge;
                    }
                }

        }
        // did you know if you always return UNJUDGED a note won't be hittable?
        // i thought that was interesting
        return UNJUDGED;
        // (aka fake notes when)
    }

    public var useEpics:Bool;
    public function new(?useEpics:Bool)
    {
        #if USE_EPIC_JUDGEMENT
		if (ClientPrefs.useEpics || useEpics==true){
			this.useEpics = true;
            return;
		}

		hittableJudgments.remove(TIER5);
		#end

		judgmentData.get(TIER4).accuracy = 100;
		judgmentData.get(TIER2).comboBehaviour = INCREMENT;
		this.useEpics = false;
    }
}