package hud;

import JudgmentManager.JudgmentData;
import flixel.util.FlxColor;
import PlayState.FNFHealthBar;
import haxe.exceptions.NotImplementedException;

import flixel.group.FlxSpriteGroup;

// bunch of basic stuff to be extended by other HUDs

class BaseHUD extends FlxSpriteGroup {
    // just some ref vars
	static var fullDisplays:Map<String, String> = [
		"epic" => "Killers",
		"sick" => "Awesomes",
		"good" => "Cools",
		"bad" => "Gays",
		"shit" => "Retards",
		"miss" => "Fails",
		"cb" => "Combo Breaks"
	];

	static var shortenedDisplays:Map<String, String> = [
		"epic" => "KL",
		"sick" => "AW",
		"good" => "CL",
		"bad" => "GY",
		"shit" => "RT",
		"miss" => "L",
		"cb" => "CB"
	];

	public var displayNames:Map<String, String> = ClientPrefs.judgeCounter == 'Shortened' ? shortenedDisplays : fullDisplays;

	public var judgeColours:Map<String, FlxColor> = [
		"epic" => 0xFFE367E5,
		"sick" => 0xFF00A2E8,
		"good" => 0xFFB5E61D,
		"bad" => 0xFFC3C3C3,
		"shit" => 0xFF7F7F7F,
		"miss" => 0xFF7F2626,
		"cb" => 0xFF7F265A
	];

	public var displayedJudges:Array<String> = ["epic", "sick", "good", "bad", "shit", "miss"];

    // set by PlayState
    public var time(default, set):Float = 0;
	public var songLength(default, set):Float = 0;
    public var songName(default, set):String = '';
    public var score(default, set):Float = 0;
    public var misses(default, set):Int = 0;
	public var combo(default, set):Int = 0;
    public var grade(default, set):String = '';
    public var ratingFC(default, set):String = 'Clear';
    public var totalNotesHit(default, set):Float = 0;
    public var totalPlayed(default, set):Float = 0;
    public var ratingPercent(default, set):Float = 0;
	public var songPercent(default, set):Float = 0;
	public var comboBreaks(default, set):Int = 0;
	public var nps(default, set):Int = 0;
	public var npsPeak(default, set):Int = 0;
	public var updateTime:Bool = (ClientPrefs.timeBarType != 'Disabled');
    public var judgements:Map<String, Float> = [
        "epic" => 0,
        "sick" => 0,
        "good" => 0,
        "bad" => 0,
        "shit" => 0,
        "miss" => 0

        // maybe add hold judgements? (OK and NG)
    ];

    // just some extra variables lol
	public var healthBar:FNFHealthBar;
    @:isVar
	public var healthBarBG(get, null):FlxSprite;
	public var iconP1:HealthIcon;
    public var iconP2:HealthIcon;

    function get_healthBarBG()return healthBar.healthBarBG;

	public function new(iP1:String, iP2:String, songName:String) {
        super();
		this.songName = songName;
		if (!ClientPrefs.useEpics)
			displayedJudges.remove("epic");

		healthBar = new FNFHealthBar(iP1, iP2);
		iconP1 = healthBar.iconP1;
		iconP2 = healthBar.iconP2;

		add(healthBarBG);
		add(healthBar);
		add(iconP1);
		add(iconP2);
    }

    override public function update(elapsed:Float){
		if (FlxG.keys.justPressed.NINE)
			iconP1.swapOldIcon();

		if (updateTime)
		{
            var curTime:Float = Conductor.songPosition - ClientPrefs.noteOffset;
            if (curTime < 0)
                curTime = 0;
            songPercent = (curTime / songLength);
            time = curTime;
        }
        super.update(elapsed);

    }

    public function beatHit(beat:Int){
		healthBar.iconScale = 1.2;
    }

	public function changedOptions(changed:Array<String>){
		healthBar.healthBarBG.y = FlxG.height * (ClientPrefs.downScroll ? 0.11 : 0.89);
		healthBar.y = healthBarBG.y + 5;
		healthBar.iconP1.y = healthBar.y - 75;
		healthBar.iconP2.y = healthBar.y - 75;
	}
    public function stepHit(step:Int){}
	public function noteJudged(judge:JudgmentData, ?note:Note, ?field:PlayField){}
    public function songStarted(){}
    public function songEnding(){}
	public function recalculateRating(){}

	function set_songLength(value:Float)return songLength = value;
	function set_time(value:Float)return time = value;
	function set_songName(value:String)return songName = value;
	function set_score(value:Float)return score = value;
	function set_misses(value:Int)return misses = value;
	function set_grade(value:String)return grade = value;
	function set_ratingFC(value:String)return ratingFC = value;
	function set_totalNotesHit(value:Float)return totalNotesHit = value;
	function set_totalPlayed(value:Float)return totalPlayed = value;
	function set_ratingPercent(value:Float)return ratingPercent = value;
	function set_songPercent(value:Float)return songPercent = value;
	function set_comboBreaks(value:Int)return comboBreaks = value;
	function set_nps(value:Int)return nps = value;
	function set_npsPeak(value:Int)return npsPeak = value;
	function set_combo(value:Int)return combo = value;
}