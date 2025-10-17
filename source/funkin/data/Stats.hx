package funkin.data;

import funkin.data.JudgmentManager.Judgment;
import funkin.data.JudgmentManager.PBot;
import funkin.data.JudgmentManager.Wife3;
import funkin.data.JudgmentManager.JudgmentData;
import funkin.data.Highscore.ScoreRecord;
import lime.app.Event;

enum abstract AccuracySystem(String) from String to String
{
	/** Simple accuracy system, averaging hits (100%) and combo breaks (-100%) **/
	var SIMPLE = "Simple";
	/** Judgement based accuracy **/
	var JUDGEMENT = "Judgement";
	/** Millisecond-based accuracy using Etterna's Wife3 algorithm **/
	var WIFE3 = "Wife3";
	/** Millisecond-based accuracy using V-Slice's PBOT1 algorithm**/
	var PBOT = "PBot";
}

typedef NoteHitInfo = {
	var strumTime:Float;
	var judgment:Judgment;
	@:optional var hitDiff:Float;
}

class Stats {
	public final accuracySystem:AccuracySystem;

	/** 
		Grade set to be used in grade calculation.  
		Format: Array of Arrays, each inner array is `[gradeName:String, minPercent:Float]`  
		Example: `[["A", 0.9], ["B", 0.8], ["C", 0.7], ["D", 0.6], ["F", 0.0]] ` 
	**/
	public var gradeSet:Array<Array<Dynamic>>;

	/** Whether to use flags (black, white, miss) in clear type calculation **/
	public var useFlags:Bool = false;

	////
	
	/** Total score **/
	public var score(default, set):Int = 0;

	/** Current note hits per second **/
	public var nps(default, set):Int = 0;

	/** Maximum note hits per second **/
	public var npsPeak(default, set):Int = 0;

	/** Current amount of consecutive note hits **/
	public var combo(default, set):Int = 0;

	/** Maximum note hit combo achieved **/
	public var maxCombo(default, set):Int = 0;

	/** Current amount of consecutive combo breaks **/
	public var cbCombo(default, set):Int = 0;

	/** Calculated rating **/
	public var ratingPercent(default, set):Float = 0;

	/** Clear type based on your judgements **/
	public var clearType(default, set):String = '';

	/** Grade based on your rating percent **/
	public var grade(default, set):String = '?';

	public var totalPlayed(default, set):Float = 0;
	public var totalNotesHit(default, set):Float = 0;

	/** 
		Event that's dispatched when a stat changes  
		This event is not called for judgement changes (i.e sicks, misses, combo breaks, etc)
	**/
	public var changedEvent = new Event<(String, Dynamic) -> Void>();

	/** Array of note hit differences in milliseconds **/
	public var noteDiffs:Array<Float> = [];
	/** Array of note hit results (hit time, judgement, hit difference), in order **/
	public var judged:Array<NoteHitInfo> = [];

	public var judgements:Map<String, Int> = [
		"epic" => 0,
		"sick" => 0,
		"good" => 0,
		"bad" => 0,
		"shit" => 0,
		"miss" => 0,
		"cb" => 0
	];

	/** Shortcut for `judgements["epic"]` **/
	public var epics(get, set):Int;
	/** Shortcut for `judgements["sick"]` **/
	public var sicks(get, set):Int;
	/** Shortcut for `judgements["good"]` **/
	public var goods(get, set):Int;
	/** Shortcut for `judgements["bads"]` **/
	public var bads(get, set):Int;
	/** Shortcut for `judgements["shit"]` **/
	public var shits(get, set):Int;
	/** Shortcut for `judgements["cb"]` **/
	public var comboBreaks(get, set):Int;
	/** Shortcut for `judgements["miss"]` **/
	public var misses(get, set):Int;

	public function new(accuracySystem:AccuracySystem = SIMPLE, gradeSet:String) {
		this.accuracySystem = accuracySystem;
		setGradeSet(gradeSet);
	}

	public function setGradeSet(name:String) {
		gradeSet = Highscore.grades.get(name) ?? [["?", Math.NEGATIVE_INFINITY]];
		useFlags = name == 'Etterna';
		updateVariables();
	}

	public function getGrade():String
	{
		if (totalPlayed >= 1) {			
			for (grade in gradeSet) {
				if (ratingPercent >= grade[1])
					return grade[0];
			}
		}
		return '?';
	}

	public function getClearType():String
	{
		var type = clear;

		if (comboBreaks > 0) {
			if (useFlags && comboBreaks == 1)
				type = mf; // Miss Flag (Any FC missed by 1 CB)
			else if (comboBreaks < 10 && score >= 0)
				type = sdcb; // Single Digit Combo Break
			else if (score < 0 || comboBreaks >= 10 && ratingPercent <= 0)
				type = fail; // Fail
		}
		else if (totalPlayed > 0) {
			if (bads > 0) {
				type = fc; // Bads don't cause a combo break if epics arent enabled so
			}
			else if (goods > 0) {
				if (useFlags && goods == 1 && sicks > 0)
					type = bf; // Black Flag (SFC missed by 1 good)
				else if (goods < 10)
					type = sdg; // Single Digit Goods
				else	
					type = gfc; // Good Full Combo
			}
			else if (sicks > 0) {
				if (useFlags && sicks == 1 && epics > 0 && ClientPrefs.useEpics)
					type = wf; // White Flag (EFC missed by 1 sick)
				else if (sicks < 10 && ClientPrefs.useEpics)
					type = sds; // Single Digit Sicks
				else
					type = sfc; // Sick Full Combo
			}
			else if (epics > 0) {
				type = efc;
			}
		}
		else {
			type = noplay;
		}

		return type;
	}

	public function getScoreRecord():ScoreRecord {
		return {
			score: score,
			comboBreaks: comboBreaks,
			accuracyScore: totalNotesHit,
			maxAccuracyScore: totalPlayed,
			judges: judgements,
			noteDiffs: noteDiffs,
			npsPeak: npsPeak
		}
	}

	public function updateVariables()
	{
		ratingPercent = totalNotesHit / totalPlayed;
		grade = getGrade();
		clearType = getClearType();
		// trace(score, grade, clearType);
	}

	public function calculateAccuracy(data:JudgmentData, diff:Float, ?incrementPlayed:Bool = true) {
		switch(accuracySystem)
		{
			case SIMPLE: // -1 acc if breaks combo, +1 otherwise
				if(data.comboBehaviour == BREAK)
					totalNotesHit--;
				else
					totalNotesHit++;

				if(data.countAsHit != false)
					totalPlayed++;

			case WIFE3: // Milisecond-based accuracy, using Etterna's Wife3 algorithm
				if (data.wifePoints == null)
					totalNotesHit += Wife3.getAcc(diff);
				else
					totalNotesHit += data.wifePoints;

				if (data.countAsHit != false)
					totalPlayed += 2;

			case PBOT: // Milisecond-based accuracy, using V-Slice's PBOT1 algorithm
				if (data.pbotPoints == null)
					totalNotesHit += PBot.getAcc(Math.abs(diff));
				else
					totalNotesHit += data.pbotPoints;
				
				if (data.countAsHit != false)
					totalPlayed += 5;

			case JUDGEMENT: // Judgment based accuracy
				totalNotesHit += data.accuracy * 0.01;

				if (data.countAsHit != false)
					totalPlayed++;
		}
	}

	//// Clear Strings
	/** Single Digit Goods **/
	public var sdg = Paths.getString("sdt3"); 
	/** Single Digit Sicks **/
	public var sds = Paths.getString("sdt4"); 
	/** Good Full Combo **/
	public var gfc = Paths.getString("t3fc"); 
	/** Sick Full Combo **/
	public var sfc = Paths.getString("t4fc"); 
	/** Epic Full Combo **/
	public var efc = Paths.getString("t5fc");
	/** Full Combo **/
	public var fc = Paths.getString("fc"); 

	/** Black Flag (SFC missed by 1 good) **/
	public var bf = Paths.getString("blackflag");
	/** White Flag (EFC missed by 1 sick) **/
	public var wf = Paths.getString("whiteflag");
	/** Miss Flag (Any FC missed by 1 CB) **/
	public var mf = Paths.getString("missflag");

	/** Single Digit Combo Breaks **/
	public var sdcb = Paths.getString("sdcb");
	public var fail = Paths.getString("fail");
	public var clear = Paths.getString("clear");
	public var noplay = Paths.getString("noplay");

	////
	inline function changedCallback(n:String, v:Dynamic)
		changedEvent.dispatch(n, v);

	@:noCompletion inline function get_epics():Int return judgements["epic"];
	@:noCompletion inline function get_sicks():Int return judgements["sick"];
	@:noCompletion inline function get_goods():Int return judgements["good"];
	@:noCompletion inline function get_bads():Int return judgements["bad"];
	@:noCompletion inline function get_shits():Int return judgements["shit"];
	@:noCompletion inline function get_comboBreaks():Int return judgements["cb"];
	@:noCompletion inline function get_misses():Int return judgements["miss"];

	@:noCompletion inline function set_epics(val:Int):Int return judgements["epic"] = val;
	@:noCompletion inline function set_sicks(val:Int):Int return judgements["sick"] = val;
	@:noCompletion inline function set_goods(val:Int):Int return judgements["good"] = val;
	@:noCompletion inline function set_bads(val:Int):Int return judgements["bad"] = val;
	@:noCompletion inline function set_shits(val:Int):Int return judgements["shit"] = val;
	@:noCompletion inline function set_comboBreaks(val:Int):Int return judgements["cb"] = val;
	@:noCompletion inline function set_misses(val:Int):Int return judgements["miss"] = val;

	@:noCompletion function set_score(val:Int) {
		if (score != val) {
			changedCallback("score", val);
			return score = val;
		}
		return val;
	}
	@:noCompletion function set_nps(val:Int) {
		if (nps != val) {
			changedCallback("nps", val);
			return nps = val;
		}
		return val;
	}
	@:noCompletion function set_npsPeak(val:Int) {
		if (npsPeak != val) {
			changedCallback("npsPeak", val);
			return npsPeak = val;
		}
		return val;
	}
	@:noCompletion function set_totalPlayed(val:Float) {
		if (totalPlayed != val) {
			changedCallback("totalPlayed", val);
			return totalPlayed = val;
		}
		return val;
	}
	@:noCompletion function set_totalNotesHit(val:Float) {
		if (totalNotesHit != val) {
			changedCallback("totalNotesHit", val);
			return totalNotesHit = val;
		}
		return val;
	}
	@:noCompletion function set_clearType(val:String) {
		if (clearType != val) {
			changedCallback("clearType", val);
			return clearType = val;
		}
		return val;
	}
	@:noCompletion function set_grade(val:String) {
		if (grade != val) {
			changedCallback("grade", val);
			return grade = val;
		}
		return val;
	}
	@:noCompletion function set_combo(val:Int) {
		if (combo != val) {
			changedCallback("combo", val);
			combo = val;
			if (val > maxCombo) maxCombo = val;
			return val;
		}
		return val;
	}
	@:noCompletion function set_maxCombo(val:Int) {
		if (maxCombo != val) {
			changedCallback("maxCombo", val);
			return maxCombo = val;
		}
		return val;
	}
	@:noCompletion function set_cbCombo(val:Int) {
		if (cbCombo != val) {
			changedCallback("cbCombo", val);
			return cbCombo = val;
		}
		return val;
	}
	@:noCompletion function set_ratingPercent(val:Float) {
		if (ratingPercent != val) {
			changedCallback("ratingPercent", val);
			return ratingPercent = val;
		}
		return val;
	}
}