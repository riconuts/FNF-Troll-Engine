package funkin.objects.hud;

import flixel.util.FlxColor;
import funkin.objects.playfields.PlayField;
import funkin.data.JudgmentManager.JudgmentData;
import funkin.scripts.FunkinHScript;

class HScriptedHUD extends BaseHUD {
	private var script:FunkinHScript;
	override public function new(songName:String, stats:Stats, script:FunkinHScript)
	{
		this.script = script;
		script.set("this", this);
		script.set("add", add);
		script.set("remove", remove);
		script.set("insert", insert);

		stats.changedEvent.add(statChanged);

		super(songName, stats);
		script.call("createHUD", ['bf', 'dad', songName, stats]);
	}

	override function set_displayedHealth(nV:Float):Float 
	{
		script.call("set_displayedHealth", [nV]);
		return nV;
	}

	override function reloadHealthBarColors(dadColor:FlxColor, bfColor:FlxColor)
		script.call("reloadHealthBarColors", [dadColor, bfColor]);

	override function changedCharacter(id:Int, char:Character)
		script.call("changedCharacter", [id, char]);
	

	function statChanged(stat:String, val:Dynamic)
		script.call("statChanged", [stat, val]);
	

	override public function songStarted()
		script.call("songStarted");
	

	override public function songEnding()
		script.call("songEnding");
	

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
	override function set_songPercent(value:Float){
		script.call("set_songPercent", [value]);
		return songPercent = value;
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
		return new HScriptedHUD(songName, stats, FunkinHScript.fromString(scriptSource, "HScriptedHUD"));
	}

	public static function fromFile(iP1:String, iP2:String, songName:String, stats:Stats, fileName:String):Null<HScriptedHUD>
	{
		var file = Paths.getHScriptPath('$fileName');
		if (file != null)
			return new HScriptedHUD(songName, stats, FunkinHScript.fromFile(file));
		

		trace('HUD script: $fileName not found!');
		return null;
	}

	public static function fromName(iP1:String, iP2:String, songName:String, stats:Stats, scriptName:String):Null<HScriptedHUD>
	{
		var file = Paths.getHScriptPath('huds/$scriptName');
		if (file != null)
			return new HScriptedHUD(
				songName, 
				stats,
				FunkinHScript.fromFile(file)
			);
		

		trace('HUD script: $scriptName not found!');
		return null;
	}
}