package;

import lime.app.Event;
/* hud.ratingFC = ratingFC;
hud.grade = ratingName;
hud.ratingPercent = ratingPercent;
hud.misses = songMisses;
hud.combo = combo;
hud.comboBreaks = comboBreaks;
hud.judgements.set("miss", songMisses);
hud.judgements.set("cb", comboBreaks);
hud.totalNotesHit = totalNotesHit;
hud.totalPlayed = totalPlayed;
hud.score = songScore; */


// Might use this some day idk lol
class Stats {
	public var changedEvent:Event<(String, Dynamic) -> Void> = new Event<(String, Dynamic)->Void>();
	function changedCallback(n:String, v:Dynamic)
		changedEvent.dispatch(n, v);
	
	public var gradeSet:Array<Array<Dynamic>> = [];

    public var score(default, set):Int = 0;
	public var nps(default, set):Int = 0;
	public var npsPeak(default, set):Int = 0;
    public var totalPlayed(default, set):Float = 0;
	public var totalNotesHit(default, set):Float = 0;
    public var clearType(default, set):String = '';
    public var grade(default, set):String = '';
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
    function set_score(val:Int){
        if(score != val){
            changedCallback("score", val);
            return score = val;
        }
        return val;
    }
	function set_nps(val:Int){
		if (nps != val)
		{
			changedCallback("nps", val);
			return nps = val;
		}
		return val;
	}
	function set_npsPeak(val:Int)
	{
		if (npsPeak != val)
		{
			changedCallback("npsPeak", val);
			return npsPeak = val;
		}
		return val;
	}
	function set_totalPlayed(val:Float)
	{
		if (totalPlayed != val){
            changedCallback("totalPlayed", val);
            return totalPlayed = val;
        }
		return val;
	}
	function set_totalNotesHit(val:Float)
	{
		if (totalNotesHit != val){
            changedCallback("totalNotesHit", val);
            return totalNotesHit = val;
        }
		return val;
	}
	function set_clearType(val:String)
	{
		if (clearType != val){
            changedCallback("clearType", val);
            return clearType = val;
        }
		return val;
	}
	function set_grade(val:String)
	{
		if (grade != val){
            changedCallback("grade", val);
            return grade = val;
        }
		return val;
	}
	function set_combo(val:Int)
	{
		if (combo != val){
            changedCallback("combo", val);
            return combo = val;
        }
		return val;
	}
	function set_cbCombo(val:Int)
	{
		if (cbCombo != val)
		{
			changedCallback("cbCombo", val);
			return cbCombo = val;
		}
		return val;
	}
	function set_ratingPercent(val:Float)
	{
		if (ratingPercent != val){
            changedCallback("ratingPercent", val);
            return ratingPercent = val;
        }
		return val;
	}

	public var useFlags:Bool = ClientPrefs.gradeSet == 'Etterna';
    @:isVar
    public var comboBreaks(get, set):Int = 0;
    function get_comboBreaks()return judgements.get("cb");
	function set_comboBreaks(val:Int){judgements.set("cb", val); return val;}
	@:isVar
	public var misses(get, set):Int = 0;
	function get_misses()return judgements.get("miss");
	function set_misses(val:Int){judgements.set("miss", val);return val;}

	public function new(?gradeSet:Array<Array<Dynamic>>)
	{
		if (gradeSet == null)
			gradeSet = Highscore.grades.get(ClientPrefs.gradeSet);

        this.gradeSet = gradeSet;

		updateVariables();
    }

    public function getGrade():String
    {
		if (totalPlayed < 1)
            return '?';
        
		if (ratingPercent >= 1)
			return gradeSet[0][0]; // Uses first string
		else
		{
			for (grade in gradeSet)
			{
				if (ratingPercent >= grade[1])
					return grade[0];	
			}
		}
		
		return '?';
    }

	public function getClearType():String
	{
		var clear = 'Clear';

		if (comboBreaks <= 0)
		{
			var goods = judgements.get("good");
			var sicks = judgements.get("sick");
			var epics = judgements.get("epic");

			if (totalPlayed == 0)
			{
				clear = 'No Play'; // Havent played anything yet
				return clear;
			}

			if (goods > 0)
			{
				if (goods < 10 && goods > 0)
					clear = 'SDC'; // Single Digit Goods
				else
					clear = 'CFC'; // Good Full Combo
			}
			else if (sicks > 0)
			{
				if (sicks < 10 && sicks > 0)
					clear = 'SDA'; // Single Digit Sicks
				else
					clear = 'AFC'; // Sick Full Combo
			}
			else if (epics > 0)
				clear = "KFC";
			
			if (useFlags)
			{
				if (goods == 1)
					clear = 'BF'; // Black Flag (SFC missed by 1 good)
				else if (sicks == 1)
					clear = 'WF'; // White Flag (EFC missed by 1 sick)
			}
		}
		else
		{
			if (useFlags && comboBreaks == 1)
				clear = 'MF'; // Miss Flag (Any FC missed by 1 CB)
			else if (comboBreaks < 10 && score >= 0)
				clear = "SDCB"; // Single Digit Combo Break
			else if (score < 0 || comboBreaks >= 10 && ratingPercent <= 0)
				clear = "Fail"; // Fail
		}

		return clear;
	}


    public function updateVariables()
    {
		ratingPercent = totalNotesHit / totalPlayed;
        grade = getGrade();
		clearType = getClearType();
		// trace(score, grade, clearType);
    }
}