package hud;

import JudgmentManager.JudgmentData;
import flixel.util.FlxColor;
import playfields.*;

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
		scoreTxt.setFormat(Paths.font("calibri.ttf"), 20, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		scoreTxt.borderSize = 1.25;
		#else
		scoreTxt.setFormat(Paths.font("vcr.ttf"), 18, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		scoreTxt.borderSize = 1.15;
		#end
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
		final textBorderSpacing = 6;
		final textLineSpacing = #if tgt 25 #else 22 #end;
		final textSize = #if tgt 24 #else 20 #end;
		final textBorderSize = #if tgt 1.25 #else 1.15 #end;

		var textWidth = ClientPrefs.judgeCounter == 'Shortened' ? 150 : 200;
		var textPosX = ClientPrefs.hudPosition == 'Right' ? (FlxG.width - textBorderSpacing - textWidth) : textBorderSpacing;
		var textPosY = (FlxG.height - displayedJudges.length * textLineSpacing) * 0.5;

		for (idx in 0...displayedJudges.length)
		{
			var judgment = displayedJudges[idx];

			var text = new FlxText(textPosX, textPosY + idx*textLineSpacing, textWidth, displayNames.get(judgment));
			text.setFormat(Paths.font(#if tgt "calibrib.ttf" #else "vcr.ttf" #end), textSize, judgeColours.get(judgment), LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			text.borderSize = textBorderSize;
			text.scrollFactor.set();
			add(text);

			var numb = new FlxText(textPosX, text.y, textWidth, "0");
			numb.setFormat(Paths.font(#if tgt "calibri.ttf" #else "vcr.ttf" #end), textSize, FlxColor.WHITE, RIGHT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			numb.borderSize = textBorderSize;
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

	override function update(elapsed:Float)
	{
		var shownScore:String;
		var isHighscore:Bool;
		if (ClientPrefs.showWifeScore){
			shownScore = Std.string(Math.floor(totalNotesHit * 100));
			isHighscore = songWifeHighscore != 0 && totalNotesHit > songWifeHighscore;
		}else{
			shownScore = Std.string(score);
			isHighscore = songHighscore != 0 && score > songHighscore;
		}

		scoreTxt.text = 
			(isHighscore ? '$hiscoreString: ' : '$scoreString: ') + shownScore +
			' | $cbString: ' + comboBreaks + 
			' | $ratingString: '
			+ (grade == '?' ? grade : Highscore.floorDecimal(ratingPercent * 100, 2)
				+ '% / $grade [${(ratingFC == stats.cfc && ClientPrefs.wife3) ? stats.fc : ratingFC}]');
		if (ClientPrefs.npsDisplay)
			scoreTxt.text += ' | $npsString: ${nps} / ${npsPeak}';

		
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