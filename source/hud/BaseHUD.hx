package hud;

import flixel.tweens.*;
import flixel.util.FlxStringUtil;
import flixel.ui.FlxBar;
import flixel.text.FlxText;
import JudgmentManager.JudgmentData;
import flixel.util.FlxColor;
import PlayState.FNFHealthBar;
import haxe.exceptions.NotImplementedException;
import playfields.*;

import flixel.group.FlxSpriteGroup;

// bunch of basic stuff to be extended by other HUDs

class BaseHUD extends FlxSpriteGroup {
	var stats:Stats;
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
	public var score(get, null):Float = 0;
	function get_score()return stats.score;
	public var comboBreaks(get, null):Float = 0;
	function get_comboBreaks()return stats.comboBreaks;
	public var misses(get, null):Int = 0;
	function get_misses()return stats.misses;
	public var combo(get, null):Int = 0;
	function get_combo()return stats.combo;
	public var grade(get, null):String = '';
	function get_grade()return stats.grade;
	public var ratingFC(get, null):String = 'Clear';
	function get_ratingFC()return stats.clearType;
	public var totalNotesHit(get, null):Float = 0;
	function get_totalNotesHit()return stats.totalNotesHit;
	public var totalPlayed(get, null):Float = 0;
	function get_totalPlayed()return stats.totalPlayed;
	public var ratingPercent(get, null):Float = 0;
	function get_ratingPercent()return stats.ratingPercent;
	public var nps(get, null):Int = 0;
	function get_nps()return stats.nps;
	public var npsPeak(get, null):Int = 0;
	function get_npsPeak()return stats.npsPeak;
	public var songPercent(default, set):Float = 0;
	public var updateTime:Bool = false;
	@:isVar
	public var judgements(get, null):Map<String, Int>;
	function get_judgements()return stats.judgements;

	// just some extra variables lol
	public var healthBar:FNFHealthBar;
	@:isVar
	public var healthBarBG(get, null):FlxSprite;
	public var iconP1:HealthIcon;
	public var iconP2:HealthIcon;

	function get_healthBarBG() return healthBar.healthBarBG;

	public var timeBar:FlxBar;
	public var timeTxt:FlxText;
	private var timeBarBG:AttachedSprite;

	public function new(iP1:String, iP2:String, songName:String, stats:Stats)
	{
		super();
		this.stats = stats;
		this.songName = songName;
		if (!ClientPrefs.useEpics)
			displayedJudges.remove("epic");

		healthBar = new FNFHealthBar(iP1, iP2);
		iconP1 = healthBar.iconP1;
		iconP2 = healthBar.iconP2;

		// prob gonna do my own time bar too lol but for now idc
		timeTxt = new FlxText(PlayState.STRUM_X + (FlxG.width * 0.5) - 248, (ClientPrefs.downScroll ? FlxG.height - 44 : 19), 400, "", 32);
		timeTxt.setFormat(Paths.font("calibri.ttf"), 32, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		timeTxt.scrollFactor.set();
		timeTxt.borderSize = 2;

		timeBarBG = new AttachedSprite('timeBar');
		timeBarBG.x = timeTxt.x;
		timeBarBG.y = timeTxt.y + (timeTxt.height * 0.25);
		timeBarBG.scrollFactor.set();
		timeBarBG.color = FlxColor.BLACK;
		timeBarBG.xAdd = -5;
		timeBarBG.yAdd = -5;
		add(timeBarBG);

		timeBar = new FlxBar(timeBarBG.x + 5, timeBarBG.y + 5, LEFT_TO_RIGHT, Std.int(timeBarBG.width - 10), Std.int(timeBarBG.height - 10), this,
			'songPercent', 0, 1);
		timeBar.scrollFactor.set();
		timeBar.createFilledBar(0xFF000000, 0xFFFFFFFF);
		timeBar.numDivisions = 800; // How much lag this causes?? Should i tone it down to idk, 400 or 200?

		add(timeBar);
		add(timeTxt);
		timeBarBG.sprTracker = timeBar;

		updateTimeBarType();
	}

	function updateTimeBarType(){	
		updateTime = (ClientPrefs.timeBarType != 'Disabled' && ClientPrefs.timeOpacity > 0);

		timeTxt.exists = updateTime;
		timeBarBG.exists = updateTime;
		timeBar.exists = updateTime;

		if (updateTime){
			timeTxt.y = (ClientPrefs.downScroll ? FlxG.height - 44 : 19);
			timeBarBG.y = timeTxt.y + (timeTxt.height * 0.25);
			timeBar.y = timeBarBG.y + 5;
			timeBar.alpha = ClientPrefs.timeOpacity * alpha * tweenProg;
			timeTxt.alpha = ClientPrefs.timeOpacity * alpha * tweenProg;

			if (ClientPrefs.timeBarType == 'Song Name')
			{
				timeTxt.text = songName;
				timeTxt.size = 24;
				timeTxt.y += 3;
			}
			else{
				timeTxt.text = "";
				timeTxt.size = 32;
			}
		}
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

			var timeCalc:Null<Float> = null;

			switch (ClientPrefs.timeBarType){
				case "Percentage":
					timeTxt.text = Math.floor(songPercent * 100) + "%";
				case "Time Left":
					timeCalc = (songLength - time);
				case "Time Elapsed":
					timeCalc = time;
			}

			if (timeCalc != null){
				timeCalc /= FlxG.timeScale;

				var secondsTotal:Int = Math.floor(timeCalc / 1000);
				if (secondsTotal < 0) secondsTotal = 0;

				timeTxt.text = FlxStringUtil.formatTime(secondsTotal, false);
			}
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

		trace(updateTime, ClientPrefs.timeBarType, ClientPrefs.timeOpacity);

		updateTimeBarType();
	}

	var tweenProg:Float = 0;
	public function songStarted(){
		FlxTween.num(0, 1, 0.5, {
			ease: FlxEase.circOut,
			onComplete: function(tw:FlxTween)
			{
				tweenProg = 1;
			}
		}, function(prog:Float)
		{
			tweenProg = prog;
			timeBar.alpha = ClientPrefs.timeOpacity * alpha * tweenProg;
			timeTxt.alpha = ClientPrefs.timeOpacity * alpha * tweenProg;
		});	
	}

	public function songEnding()
	{
		timeBarBG.visible = false;
		timeBar.visible = false;
		timeTxt.visible = false;
	}

	public function stepHit(step:Int){}
	public function noteJudged(judge:JudgmentData, ?note:Note, ?field:PlayField){}
	public function recalculateRating(){}

	function set_songLength(value:Float)return songLength = value;
	function set_time(value:Float)return time = value;
	function set_songName(value:String)return songName = value;
	function set_songPercent(value:Float)return songPercent = value;
	function set_combo(value:Int)return combo = value;
}