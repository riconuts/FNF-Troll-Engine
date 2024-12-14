package funkin.objects.hud;

import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.tweens.FlxTween;

import funkin.objects.playfields.PlayField;
import funkin.data.JudgmentManager.JudgmentData;

class PsychHUD extends CommonHUD 
{
	public var judgeTexts = new Map<String, FlxText>();
	public var judgeNames = new Map<String, FlxText>();
	
	public var scoreTxt:FlxText;
	public var hitbar:Hitbar;

	var hitbarTween:FlxTween;
	var scoreTxtTween:FlxTween;

	public var separator:String = ' • ';

	// cached because dont wanna be doing that shit every update cycle lmao
	// even though it probably doesnt matter since it caches it the first time
	// i feel like this is probably faster than going through map.get each time
	var scoreString = Paths.getString("score");
	var hiscoreString = Paths.getString("highscore");
	var ratingString = Paths.getString("rating");
	var cbString = Paths.getString("cbplural");
	var npsString = Paths.getString("nps");
	var botplayString = Paths.getString("botplayMark");

	var songHighscore:Int;
	var songWifeHighscore:Float;

	var showJudgeCounter:Bool;
	
	override public function new(iP1:String, iP2:String, songName:String, stats:Stats)
	{
		super(iP1, iP2, songName, stats);

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
		for (text in judgeTexts){
			remove(text);
			text.destroy();
		}
		judgeTexts.clear();

		for (text in judgeNames){
			remove(text);
			text.destroy();
		}
		judgeNames.clear();
	}

	function generateJudgementDisplays()
	{
		#if tgt
		final textBorderSpacing = 6;
		final textLineSpacing = 25;
		final textSize = 24;
		final textBorderSize = 1.25;
		final nameFont = "calibrib.ttf";
		final numbFont = "calibri.ttf";
		#else
		final textBorderSpacing = 6;
		final textLineSpacing = 22;
		final textSize = 20;
		final textBorderSize = 1.5;
		final nameFont = "vcr.ttf";
		final numbFont = "vcr.ttf";
		#end

		var textWidth = ClientPrefs.judgeCounter == 'Shortened' ? 150 : 200;
		var textPosX = ClientPrefs.hudPosition == 'Right' ? (FlxG.width - textBorderSpacing - textWidth) : textBorderSpacing;
		var textPosY = (FlxG.height - displayedJudges.length * textLineSpacing) * 0.5;

		for (idx in 0...displayedJudges.length)
		{
			var judgment = displayedJudges[idx];

			var text = new FlxText(textPosX, textPosY + idx*textLineSpacing, textWidth, displayNames.get(judgment));
			text.setFormat(Paths.font(nameFont), textSize, judgeColours.get(judgment), LEFT);
			text.setBorderStyle(OUTLINE, 0xFF000000, textBorderSize);
			text.scrollFactor.set();
			add(text);

			var numb = new FlxText(textPosX, text.y, textWidth, "0");
			numb.setFormat(Paths.font(numbFont), textSize, 0xFFFFFFFF, RIGHT);
			numb.setBorderStyle(OUTLINE, 0xFF000000, textBorderSize);
			numb.scrollFactor.set();
			add(numb);

			judgeTexts.set(judgment, numb);
			judgeNames.set(judgment, text);
		}
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

	inline function getScoreText(){	
		var text:String = '${isHighscore ? hiscoreString : scoreString}: $shownScore';
		if (!showJudgeCounter) text += separator + '$cbString: $comboBreaks';
		text += separator + '$ratingString: ${getGradeText()}';

		if (ClientPrefs.npsDisplay)
			text += separator + ('$npsString: $nps / $npsPeak');

		return text;
	}

	inline function getGradeText(){
		if (grade == "?")
			return grade;

		final ratFC = ratingFC;
		final comboName = stats.accuracySystem == WIFE3 && ratFC == stats.gfc ? stats.fc : ratFC;
		final ratPerc = Highscore.floorDecimal(ratingPercent * 100, 2);

		return '$ratPerc%'+separator+'$grade [$comboName]';
	}

	override function update(elapsed:Float)
	{
		if (isUpdating)
			scoreTxt.text = PlayState.instance.cpuControlled ? botplayString : getScoreText();
		
		for (k => v in judgements){
			if (judgeTexts.exists(k))
				judgeTexts.get(k).text = Std.string(v);
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

			var judgeName = judgeNames.get(judge.internalName);
			var judgeTxt = judgeTexts.get(judge.internalName);
			if (judgeName != null)
			{
				FlxTween.cancelTweensOf(judgeName.scale);
				judgeName.scale.set(1.075, 1.075);
				FlxTween.tween(judgeName.scale, {x: 1, y: 1}, 0.2);
			}
			if (judgeTxt != null)
			{
				FlxTween.cancelTweensOf(judgeTxt.scale);
				judgeTxt.scale.set(1.075, 1.075);
				FlxTween.tween(judgeTxt.scale, {x: 1, y: 1}, 0.2);
			}

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
				var judgeName = judgeNames.get('miss');
				var judgeTxt = judgeTexts.get('miss');
				if (judgeName != null)
				{
					FlxTween.cancelTweensOf(judgeName.scale);
					judgeName.scale.set(1.075, 1.075);
					FlxTween.tween(judgeName.scale, {x: 1, y: 1}, 0.2);
				}
				if (judgeTxt != null)
				{
					FlxTween.cancelTweensOf(judgeTxt.scale);
					judgeTxt.scale.set(1.075, 1.075);
					FlxTween.tween(judgeTxt.scale, {x: 1, y: 1}, 0.2);

					judgeTxt.text = Std.string(val);
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