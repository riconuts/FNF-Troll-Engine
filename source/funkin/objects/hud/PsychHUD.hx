package funkin.objects.hud;

import funkin.data.JudgmentManager.JudgmentData;
import flixel.util.FlxColor;
import funkin.objects.playfields.*;

import flixel.tweens.FlxTween;
import flixel.text.FlxText;

class PsychHUD extends CommonHUD 
{
	public var judgeTexts:Map<String, FlxText> = [];
	public var judgeNames:Map<String, FlxText> = [];
	
	public var scoreTxt:FlxText;
	public var hitbar:Hitbar;

	var hitbarTween:FlxTween;
	var scoreTxtTween:FlxTween;

	var songHighscore:Int = 0;
	var songWifeHighscore:Float = 0;
	var scoreString = Paths.getString("score");
	var hiscoreString = Paths.getString("highscore");
	var ratingString = Paths.getString("rating");
	var cbString = Paths.getString("cbplural");
	var npsString = Paths.getString("nps");
	var botplayString = Paths.getString("botplayMark");

	override public function new(iP1:String, iP2:String, songName:String, stats:Stats)
	{
		super(iP1, iP2, songName, stats);

        // cached because dont wanna be doing that shit every update cycle lmao
        // even though it probably doesnt matter since it caches it the first time
        // i feel like this is probably faster than going through map.get each time

		stats.changedEvent.add(statChanged);

		add(healthBarBG);
		add(healthBar);
		add(iconP1);
		add(iconP2);
		
		songHighscore = Highscore.getScore(songName);
		songWifeHighscore = Highscore.getNotesHit(songName);

		scoreTxt = new FlxText(0, healthBarBG.y + 48, FlxG.width, "", 20);
		#if tgt
		scoreTxt.setFormat(Paths.font("calibri.ttf"), 20, FlxColor.WHITE, CENTER);
		scoreTxt.setBorderStyle(OUTLINE, FlxColor.BLACK, 1.25);
		#else
		scoreTxt.setFormat(Paths.font('vcr.ttf'), 18, FlxColor.WHITE, CENTER);
		scoreTxt.setBorderStyle(OUTLINE, FlxColor.BLACK, 1.5);
		#end

		scoreTxt.antialiasing = true;
		scoreTxt.scrollFactor.set();
		scoreTxt.visible = scoreTxt.alpha > 0;

		if (ClientPrefs.judgeCounter != 'Off')
			generateJudgementDisplays();
		
		//
		hitbar = new Hitbar();
		hitbar.alpha = alpha;
		hitbar.visible = ClientPrefs.hitbar;
		add(hitbar);
		if (ClientPrefs.hitbar)
		{
			hitbar.screenCenter(XY);
			if (ClientPrefs.downScroll)
				hitbar.y -= 230;
			else
				hitbar.y += 330;
		}

		add(scoreTxt);
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

		hitbar.visible = ClientPrefs.hitbar;

		if (ClientPrefs.hitbar)
		{
			hitbar.screenCenter(XY);
			if (ClientPrefs.downScroll)
			{
				hitbar.y -= 220;
				hitbar.averageIndicator.flipY = false;
				hitbar.averageIndicator.y = hitbar.y - (hitbar.averageIndicator.width + 5);
			}
			else
				hitbar.y += 340;
		}

		var regenJudgeDisplays:Bool = false;
		for (optionName in changed){
			if (optionName == "judgeCounter" || optionName == "hudPosition"){
				regenJudgeDisplays = true; 
				break;
			}
		}

		if (regenJudgeDisplays)
		{
			clearJudgementDisplays();

			if (ClientPrefs.judgeCounter != 'Off')
				generateJudgementDisplays();
		}
	}

	inline function getGradeText(){
		if (grade == "?")
			return grade;

		final ratFC = ratingFC;
		final comboName = ClientPrefs.wife3 && ratFC == stats.cfc ? stats.fc : ratFC;
		final ratPerc = Highscore.floorDecimal(ratingPercent * 100, 2);

		return '$ratPerc% / $grade [$comboName]';
	}

	override function update(elapsed:Float)
	{
		var shownScore:String;
		var isHighscore:Bool;
		
		if (ClientPrefs.showWifeScore) {
			shownScore = Std.string(Math.floor(totalNotesHit * 100));
			isHighscore = songWifeHighscore != 0 && totalNotesHit > songWifeHighscore;
		} else {
			shownScore = Std.string(score);
			isHighscore = songHighscore != 0 && score > songHighscore;
		}

		scoreTxt.text = PlayState.instance.cpuControlled ? botplayString : {
			final separator = ' • ';
			
			var text = 
				'${isHighscore ? hiscoreString : scoreString}: $shownScore' +
				separator + 
				'$cbString: $comboBreaks' + 
				separator + 
				'$ratingString: ${getGradeText()}'
			;

			if (ClientPrefs.npsDisplay)
				text += separator + ('$npsString: $nps / $npsPeak');

			text;
		}
		
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
		}
	}

	override public function beatHit(beat:Int){
		if (hitbar != null)
			hitbar.beatHit();

		super.beatHit(beat);
	}
}