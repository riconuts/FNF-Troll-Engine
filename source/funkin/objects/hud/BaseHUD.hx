package funkin.objects.hud;

import flixel.text.FlxText;
import flixel.ui.FlxBar;
import flixel.util.FlxColor;

import flixel.group.FlxSpriteGroup;

// bunch of basic stuff to be extended by other HUDs

class BaseHUD extends FlxSpriteGroup
{
	public static final _displayedJudges = ["epic", "sick", "good", "bad", "shit", "miss", "cb"];
	public static final _judgeColours:Map<String, FlxColor> = [
		#if tgt
		"epic" 	=> 0xFFE367E5,
		"sick" 	=> 0xFF00A2E8,
		"good" 	=> 0xFFB5E61D,
		"bad" 	=> 0xFFC3C3C3,
		"shit" 	=> 0xFF7F7F7F,
		"miss" 	=> 0xFF880015,
		"cb" 	=> 0xFF7F265A
		#else
		"epic"	=> 0xFFBA78FF,
		"sick"	=> 0xFF97FFFF,
		"good"	=> 0xFF97FF9F,
		"bad"	=> 0xFFC4C4C4,
		"shit"	=> 0xFF828282, 
		"miss"	=> 0xFFCC3D3D,
		"cb"	=> 0xFF7F265A
		#end
	];

	// just some ref vars
	var fullDisplays:Map<String, String> = [
		"epic" 	=> Paths.getString("tier5plural"),
		"sick" 	=> Paths.getString("tier4plural"),
		"good" 	=> Paths.getString("tier3plural"),
		"bad" 	=> Paths.getString("tier2plural"),
		"shit" 	=> Paths.getString("tier1plural"),
		"miss" 	=> Paths.getString("tier0plural"),
		"cb" 	=> Paths.getString("cbplural")
	];

	var shortenedDisplays:Map<String, String> = [
		"epic" 	=> Paths.getString("tier5short"),
		"sick" 	=> Paths.getString("tier4short"),
		"good" 	=> Paths.getString("tier3short"),
		"bad" 	=> Paths.getString("tier2short"),
		"shit" 	=> Paths.getString("tier1short"),
		"miss" 	=> Paths.getString("tier0short"),
		"cb" 	=> Paths.getString("cbshort")
	];

	////
	var stats:Stats;

	public var isUpdating:Bool = true;
	public var updateTime:Bool = false;

	public var timeBar:FlxBar;
	public var timeTxt:FlxText;
	public var timeBarBG:FlxSprite;

	public var displayedSong(get, null):String;

	public var judgeColours:Map<String, FlxColor>;
	public var displayedJudges:Array<String>;
	public var displayNames(get, null):Map<String, String>;
	
	// set by PlayState
	public var time(default, set):Float = 0;
	public var songLength(default, set):Float = 0;
	public var songName(default, set):String = '';
	public var songPercent(default, set):Float = 0;	
	public var displayedHealth(default, set):Float = 0;

	public var score(get, null):Float = 0;
	public var comboBreaks(get, null):Float = 0;
	public var misses(get, null):Int = 0;
	public var combo(get, null):Int = 0;
	public var grade(get, null):String = '';
	public var ratingFC(get, null):String = 'Clear';
	public var totalNotesHit(get, null):Float = 0;
	public var totalPlayed(get, null):Float = 0;
	public var ratingPercent(get, null):Float = 0;
	public var nps(get, null):Int = 0;
	public var npsPeak(get, null):Int = 0;
	public var judgements(get, null):Map<String, Int>;

	public function new(songName:String, stats:Stats)
	{
		super();
		this.songName = songName;
		this.stats = stats;

		this.judgeColours =  _judgeColours.copy();
		this.displayedJudges = _displayedJudges.copy();
		if (!ClientPrefs.useEpics)
			this.displayedJudges.remove("epic");
	}

	// Used for compatibility with Psych scripts
	public function getHealthbar():FNFHealthBar 
		return null; 

	public function songStarted(){}
	public function changedOptions(changed:Array<String>){}
	public function changedCharacter(id:Int, char:Character){}
	public function reloadHealthBarColors(dadColor:FlxColor, bfColor:FlxColor){}
	public function beatHit(beat:Int){}
	public function stepHit(step:Int){}
	public function noteJudged(judge:JudgmentData, ?note:Note, ?field:PlayField){}
	public function recalculateRating(){}
	public function songEnding(){}

	function get_displayedSong() return PlayState.instance.displayedSong;
	function get_score() return stats.score;
	function get_comboBreaks() return stats.comboBreaks;
	function get_misses() return stats.misses;
	function get_combo() return stats.combo;
	function get_grade() return stats.grade;
	function get_ratingFC() return stats.clearType;
	function get_totalNotesHit() return stats.totalNotesHit;
	function get_totalPlayed() return stats.totalPlayed;
	function get_ratingPercent() return stats.ratingPercent;
	function get_nps() return stats.nps;
	function get_npsPeak() return stats.npsPeak;
	function get_judgements() return stats.judgements;
	function get_displayNames() return ClientPrefs.judgeCounter == 'Shortened' ? shortenedDisplays : fullDisplays;

	function set_displayedHealth(value:Float) return displayedHealth = value; // override healthbar shit here lol
	function set_songLength(value:Float) return songLength = value;
	function set_time(value:Float) return time = value;
	function set_songName(value:String) return songName = value;
	function set_songPercent(value:Float) return songPercent = value;
	function set_combo(value:Int) return combo = value;
}