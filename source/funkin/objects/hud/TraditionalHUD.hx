package funkin.objects.hud;

import math.CoolMath;
import funkin.objects.hud.JudgementCounter.JudgementCounters;
import funkin.objects.hud.JudgementCounter.JudgeCounterSettings;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.tweens.FlxTween;

import funkin.objects.playfields.PlayField;
import funkin.data.JudgmentManager.JudgmentData;

typedef PsychHUD = TraditionalHUD;

class TraditionalHUD extends CommonHUD 
{	
	public var scoreTxt:FlxText;
	public var hitbar:Hitbar;

	var hitbarTween:FlxTween;
	var scoreTxtTween:FlxTween;

	public var separator:String = ' • ';
	// cached because dont wanna be doing that shit every update cycle lmao
	// even though it probably doesnt matter since it caches it the first time
	// i feel like this is probably faster than going through map.get each time
	var scoreString = Paths.getString("score", "Score");
	var hiscoreString = Paths.getString("highscore", "Hi-Score");
	var ratingString = Paths.getString("rating", "Rating");
	var rankString = Paths.getString("rank", "Rank");
	var cbString = Paths.getString("cbplural", "Combo Breaks");
	var npsString = Paths.getString("nps", "NPS");
	var botplayString = Paths.getString("botplayMark", "[BOTPLAY]");

	var songHighscore:Int;
	var songWifeHighscore:Float;

	var showJudgeCounter:Bool;
	
	override public function new(songName:String, stats:Stats)
	{
		super(songName, stats);

		stats.changedEvent.add(statChanged);
		
		var songRecord = Highscore.getRecord(this.songName, PlayState.difficultyName);
		songHighscore = songRecord.score;
		songWifeHighscore = songRecord.accuracyScore;

		showJudgeCounter = ClientPrefs.judgeCounter != "Off";
		////
		scoreTxt = new FlxText(0, healthBarBG.y + 48, FlxG.width, "", 20);
		scoreTxt.antialiasing = true;
		scoreTxt.scrollFactor.set();

		#if tgt
		scoreTxt.setFormat(Paths.font("calibri.ttf"), 20, FlxColor.WHITE, CENTER);
		scoreTxt.setBorderStyle(OUTLINE, FlxColor.BLACK, 1.25);
		#else
		scoreTxt.setFormat(Paths.font('vcr.ttf'), 18, FlxColor.WHITE, CENTER);
		scoreTxt.setBorderStyle(OUTLINE, FlxColor.BLACK, 1.5);
		#end
		
		////
		hitbar = new Hitbar();
		if (hitbar.visible = ClientPrefs.hitbar) {
			hitbar.screenCenter(XY);
			hitbar.y += (ClientPrefs.downScroll) ? -230 : 330;
		}

		////
		add(healthBarBG);
		add(healthBar);
		add(iconP1);
		add(iconP2);
		add(hitbar);
		add(scoreTxt);

		if (showJudgeCounter) 
			generateJudgementDisplays();
	}

	function clearJudgementDisplays()
	{
		if (judgeCounters == null)
			return;
		remove(judgeCounters);
		judgeCounters.destroy();
		judgeCounters = null;
	}

	// Maybe we should move this into CommonHUD??
	var counterOptions:JudgeCounterSettings = {
		#if tgt
		textBorderSpacing: 6,
		textLineSpacing: 25,
		textSize: 24,
		textBorderSize: 1.25,
		nameFont: "calibrib.ttf",
		numbFont: "calibri.ttf"
		#else
		textBorderSpacing: 6,
		textLineSpacing: 22,
		textSize: 20,
		textBorderSize: 1.5,
		nameFont: "vcr.ttf",
		numbFont: "vcr.ttf"
		#end
	}
	var judgeCounters:JudgementCounters;

	function generateJudgementDisplays()
	{
		var textWidth = ClientPrefs.judgeCounter == 'Shortened' ? 150 : 200;
		counterOptions.length = ClientPrefs.judgeCounter;
		judgeCounters = new JudgementCounters(
			ClientPrefs.hudPosition == 'Right' ? (FlxG.width - counterOptions.textBorderSpacing - textWidth) : counterOptions.textBorderSpacing,
			FlxG.height * 0.5,
			displayNames,
			judgeColours,
			counterOptions,
			displayedJudges
		);
		add(judgeCounters);
	}

	override function changedOptions(changed:Array<String>)
	{
		super.changedOptions(changed);

		scoreTxt.y = healthBarBG.y + 48;
		ClientPrefs.showWifeScore ? onWifeScoreUpdate() : onScoreUpdate();

		if (hitbar.visible = ClientPrefs.hitbar) {
			hitbar.screenCenter(XY);
			if (ClientPrefs.downScroll) {
				hitbar.y -= 220;
				hitbar.averageIndicator.flipY = false;
				hitbar.averageIndicator.y = hitbar.y - (hitbar.averageIndicator.width + 5);
			
			}else
				hitbar.y += 340;
		}

		var regenJudgeDisplays:Bool = false;
		for (optionName in changed){
			if (optionName == "judgeCounter" || optionName == "hudPosition"){
				regenJudgeDisplays = true; 
				break;
			}
		}

		if (regenJudgeDisplays) {
			clearJudgementDisplays();

			showJudgeCounter = ClientPrefs.judgeCounter != 'Off';
			if (showJudgeCounter) generateJudgementDisplays();
		}
	}

	var shownScore:String = "0";	
	var isHighscore:Bool = false;

	function onScoreUpdate(){
		shownScore = Std.string(score);
		isHighscore = songHighscore != 0 && score > songHighscore;
	}
	function onWifeScoreUpdate(){
		shownScore = Std.string(Math.floor(totalNotesHit * 100));
		isHighscore = songWifeHighscore != 0 && totalNotesHit > songWifeHighscore;
	}

	inline function getStatusText():String {
		if (PlayState.instance.cpuControlled && useSubtleMark)
			return botplayString;

		var text:String = getScoreText();

		if (!showJudgeCounter) 
			text += separator + getComboBreaksText();
		
		if (ClientPrefs.npsDisplay)
			text += separator + getNPSText();

		if (grade != "?") {
			text += separator + getRatingText();
			text += separator + getClearTypeText();
		}
		
		text += separator + getGradeText();

		return text;
	}

	inline function getScoreText():String
		return '${isHighscore ? hiscoreString : scoreString}: $shownScore';

	inline function getComboBreaksText():String
		return '$cbString: $comboBreaks';

	inline function getNPSText():String
		return '$npsString: $nps / $npsPeak';

	inline function getRatingText():String
	{
		final ratPerc:Float = CoolMath.floorDecimal(ratingPercent * 100, 2);
		return '$ratingString: $ratPerc%';
	}

	inline function getClearTypeText():String
	{
		var clearType:String = ratingFC;

		if (stats.accuracySystem == WIFE3 && clearType == stats.gfc)
			clearType = stats.fc;
		
		return '[$clearType]';
	}

	inline function getGradeText() {
		return '$rankString: $grade';
	}

	override function update(elapsed:Float)
	{
		if (isUpdating)
			scoreTxt.text = getStatusText();
		
		if (judgeCounters != null) {
			for (k => v in judgements)
				judgeCounters.setCount(k, v);
		}

		super.update(elapsed);
	}

	override function noteJudged(judge:JudgmentData, ?note:Note, ?field:PlayField)
	{
		var hitTime = note.strumTime - Conductor.songPosition + ClientPrefs.ratingOffset;

		if (ClientPrefs.hitbar)
			hitbar.addHit(hitTime);
		
		if (ClientPrefs.scoreZoom)
		{
			if (scoreTxtTween != null)
				scoreTxtTween.cancel();
			if (judgeCounters != null)
				judgeCounters.bump(judge.internalName);

			scoreTxt.scale.x = 1.075;
			scoreTxt.scale.y = 1.075;
			scoreTxtTween = FlxTween.tween(scoreTxt.scale, {x: 1, y: 1}, 0.2, {
				onComplete: function(twn:FlxTween)
				{
					scoreTxtTween = null;
				}
			});
		}
	}

	function statChanged(stat:String, val:Dynamic)
	{
		switch (stat)
		{
			case 'misses':
				misses = val;
				if (judgeCounters != null) {
					judgeCounters.bump('miss');
					judgeCounters.setCount('miss', val);
				}
			
			case 'totalNotesHit':
				if (ClientPrefs.showWifeScore)
					onWifeScoreUpdate();
			
			case 'score':
				if (!ClientPrefs.showWifeScore)
					onScoreUpdate();
		}
	}

	override public function beatHit(beat:Int){
		if (hitbar != null)
			hitbar.beatHit();

		super.beatHit(beat);
	}
}
