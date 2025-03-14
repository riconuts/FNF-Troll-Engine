package funkin.data;

import funkin.data.JudgmentManager.Judgment;
import funkin.data.JudgmentManager.PBot;
import funkin.data.JudgmentManager.Wife3;
import funkin.data.JudgmentManager.JudgmentData;
import funkin.data.Highscore.ScoreRecord;
import lime.app.Event;

enum abstract AccuracySystem(String) from String to String
{
	var SIMPLE = "Simple";
	var JUDGEMENT = "Judgement";
	var WIFE3 = "Wife3";
	var PBOT = "PBot";
}

typedef NoteHitInfo = {
	var strumTime:Float;
	var judgment:Judgment;
	@:optional var hitDiff:Float;
}

class Stats {
	public var changedEvent = new Event<(String, Dynamic) -> Void>();
	inline function changedCallback(n:String, v:Dynamic)
		changedEvent.dispatch(n, v);
	
	public final accuracySystem:AccuracySystem;

	public var gradeSet:Array<Array<Dynamic>> = [["?", Math.NEGATIVE_INFINITY]];
	public var useFlags:Bool = false;
	
	public var score(default, set):Int = 0;
	public var nps(default, set):Int = 0;
	public var npsPeak(default, set):Int = 0;
	public var totalPlayed(default, set):Float = 0;
	public var totalNotesHit(default, set):Float = 0;
	public var clearType(default, set):String = '';
	public var grade(default, set):String = '?';

	public var noteDiffs:Array<Float> = [];
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
	public var combo(default, set):Int = 0;
	public var cbCombo(default, set):Int = 0;
	public var ratingPercent(default, set):Float = 0;
	function set_score(val:Int) {
		if (score != val) {
			changedCallback("score", val);
			return score = val;
		}
		return val;
	}
	function set_nps(val:Int) {
		if (nps != val) {
			changedCallback("nps", val);
			return nps = val;
		}
		return val;
	}
	function set_npsPeak(val:Int) {
		if (npsPeak != val) {
			changedCallback("npsPeak", val);
			return npsPeak = val;
		}
		return val;
	}
	function set_totalPlayed(val:Float) {
		if (totalPlayed != val) {
			changedCallback("totalPlayed", val);
			return totalPlayed = val;
		}
		return val;
	}
	function set_totalNotesHit(val:Float) {
		if (totalNotesHit != val) {
			changedCallback("totalNotesHit", val);
			return totalNotesHit = val;
		}
		return val;
	}
	function set_clearType(val:String) {
		if (clearType != val) {
			changedCallback("clearType", val);
			return clearType = val;
		}
		return val;
	}
	function set_grade(val:String) {
		if (grade != val) {
			changedCallback("grade", val);
			return grade = val;
		}
		return val;
	}
	function set_combo(val:Int) {
		if (combo != val) {
			changedCallback("combo", val);
			return combo = val;
		}
		return val;
	}
	function set_cbCombo(val:Int) {
		if (cbCombo != val) {
			changedCallback("cbCombo", val);
			return cbCombo = val;
		}
		return val;
	}
	function set_ratingPercent(val:Float) {
		if (ratingPercent != val) {
			changedCallback("ratingPercent", val);
			return ratingPercent = val;
		}
		return val;
	}

	@:isVar
	public var comboBreaks(get, set):Int = 0;
	function get_comboBreaks():Int return judgements.get("cb");
	function set_comboBreaks(val:Int):Int {
		comboBreaks = val;
		judgements.set("cb", val); 
		return val;
	}
	@:isVar
	public var misses(get, set):Int = 0;
	function get_misses():Int return judgements.get("miss");
	function set_misses(val:Int):Int {
		misses = val;
		judgements.set("miss", val);
		return val;
	}

	public function new(accuracySystem:AccuracySystem = SIMPLE, ?gradeSet:Array<Array<Dynamic>>) {
		this.accuracySystem = accuracySystem;
		if (gradeSet != null) this.gradeSet = gradeSet;
		updateVariables();
	}

	public function getGrade():String
	{
		if (totalPlayed < 1)
			return '?';
		
		for (grade in gradeSet) {
			if (ratingPercent >= grade[1])
				return grade[0];	
		}
		
		return '?';
	}

	//// Clear Strings
	public var sdg = Paths.getString("sdt3"); // Single Digit Goods
	public var sds = Paths.getString("sdt4"); // Single Digit Sicks

	public var gfc = Paths.getString("t3fc"); // Good Full Combo
	public var sfc = Paths.getString("t4fc"); // Sick Full Combo
	public var efc = Paths.getString("t5fc"); // Epic Full Combo
	public var fc = Paths.getString("fc"); // Full Combo

	public var bf = Paths.getString("blackflag"); // Black Flag (SFC missed by 1 good)
	public var wf = Paths.getString("whiteflag"); // White Flag (EFC missed by 1 sick)
	public var mf = Paths.getString("missflag"); // Miss Flag (Any FC missed by 1 CB)

	public var sdcb = Paths.getString("sdcb"); // Single Digit Combo Breaks
	public var fail = Paths.getString("fail");
	public var clear = Paths.getString("clear");
	public var noplay = Paths.getString("noplay");

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
			var bads = judgements.get("bad");
			var goods = judgements.get("good");
			var sicks = judgements.get("sick");
			var epics = judgements.get("epic");
			
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
			comboBreaks: judgements.get("cb"), // since we cant detect the combo breaks from here
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

			default: // accuracy depends on the judgement
				totalNotesHit += data.accuracy * 0.01;

				if (data.countAsHit != false)
					totalPlayed++;
		}
	}
}