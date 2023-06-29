package hud;

import playfields.PlayField;
import JudgmentManager.JudgmentData;
import scripts.FunkinHScript;

class HScriptedHUD extends BaseHUD {
	private var script:FunkinHScript;
	override public function new(iP1:String, iP2:String, songName:String, stats:Stats, script:FunkinHScript)
	{
		super(iP1, iP2, songName, stats);
		this.script = script;
		script.set("this", this);

		script.call("createHUD", [iP1, iP2, songName]);
	}

	override public function songStarted()
	{
		script.call("songStarted");
	}

	override public function songEnding()
	{
		script.call("songEnding");
	}

	override function changedOptions(changed:Array<String>)
	{
		super.changedOptions(changed);
		script.call("changedOptions", [changed]);
	}

	override function update(elapsed:Float)
	{
		script.call("update", [elapsed]);
		super.update(elapsed);
		script.call("postUpdate", [elapsed]);
	}

	override public function beatHit(beat:Int)
	{
		super.beatHit(beat);
		script.call("beatHit", [beat]);
	}

	override public function stepHit(step:Int)
	{
		super.stepHit(step);
		script.call("stepHit", [step]);
	}

	override public function recalculateRating()
		script.call("recalculateRating", []);

	override function set_songLength(value:Float){
		script.call("set_songLength", [value]);
		return songLength = value;
	}
	override function set_time(value:Float){
		script.call("set_time", [value]);
		return time = value;
	}
	override function set_songName(value:String){
		script.call("set_songName", [value]);
		return songName = value;
	}
	override function set_score(value:Float){
		script.call("set_score", [value]);
		return score = value;
	}
	override function set_misses(value:Int){
		script.call("set_misses", [value]);
		return misses = value;
	}
	override function set_grade(value:String){
		script.call("set_grade", [value]);
		return grade = value;
	}
	override function set_ratingFC(value:String){
		script.call("set_ratingFC", [value]);
		return ratingFC = value;
	}
	override function set_totalNotesHit(value:Float){
		script.call("set_totalNotesHit", [value]);
		return totalNotesHit = value;
	}
	override function set_totalPlayed(value:Float){
		script.call("set_totalPlayed", [value]);
		return totalPlayed = value;
	}
	override function set_ratingPercent(value:Float){
		script.call("set_ratingPercent", [value]);
		return ratingPercent = value;
	}
	override function set_songPercent(value:Float){
		script.call("set_songPercent", [value]);
		return songPercent = value;
	}
	override function set_comboBreaks(value:Int){
		script.call("set_comboBreaks", [value]);
		return comboBreaks = value;
	}
	override function set_nps(value:Int){
		script.call("set_nps", [value]);
		return nps = value;
	}
	override function set_npsPeak(value:Int){
		script.call("set_npsPeak", [value]);
		return npsPeak = value;
	}
	override function set_combo(value:Int){
		script.call("set_combo", [value]);
		return combo = value;
	}

	override public function noteJudged(judge:JudgmentData, ?note:Note, ?field:PlayField)
	{
		super.noteJudged(judge, note, field);
		script.call("noteJudged", [judge, note, field]);
	}

	// easier constructors

	public static function fromString(iP1:String, iP2:String, songName:String, stats:Stats, scriptSource:String):HScriptedHUD
	{
		return new HScriptedHUD(iP1, iP2, songName, stats, FunkinHScript.fromString(scriptSource, "HScriptedHUD"));
	}

	public static function fromFile(iP1:String, iP2:String, songName:String, stats:Stats, fileName:String):Null<HScriptedHUD>
	{
		var fileName:String = '$fileName.hscript';
		for (file in [#if MODS_ALLOWED Paths.modFolders(fileName), #end Paths.getPreloadPath(fileName)])
		{
			if (!Paths.exists(file))
				continue;

			return new HScriptedHUD(iP1, iP2, songName, stats, FunkinHScript.fromFile(file));
		}

		trace('HUD script: $fileName not found!');
		return null;
	}

	public static function fromName(iP1:String, iP2:String, songName:String, stats:Stats, scriptName:String):Null<HScriptedHUD>
	{
		var fileName:String = 'scripts/$scriptName.hscript';
		for (file in [#if MODS_ALLOWED Paths.modFolders(fileName), #end Paths.getPreloadPath(fileName)])
		{
			if (!Paths.exists(file))
				continue;

			return new HScriptedHUD(
				iP1, 
				iP2, 
				songName, 
				stats,
				FunkinHScript.fromFile(file)
			);
		}

		trace('HUD script: $scriptName not found!');
		return null;
	}
}