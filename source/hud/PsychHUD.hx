package hud;

import JudgmentManager.JudgmentData;
import flixel.util.FlxColor;
import playfields.*;

import flixel.tweens.FlxTween;
import flixel.text.FlxText;

class PsychHUD extends BaseHUD 
{
	public var judgeTexts:Map<String, FlxText> = [];
	public var judgeNames:Map<String, FlxText> = [];
	
	public var scoreTxt:FlxText;
	public var hitbar:Hitbar;

	var hitbarTween:FlxTween;
	var scoreTxtTween:FlxTween;

	var songHighscore:Int = 0;
	var songWifeHighscore:Float = 0;
	override public function new(iP1:String, iP2:String, songName:String, stats:Stats)
	{
		super(iP1, iP2, songName, stats);

		stats.changedEvent.add(statChanged);

		add(healthBarBG);
		add(healthBar);
		add(iconP1);
		add(iconP2);
		
		songHighscore = Highscore.getScore(songName);
		songWifeHighscore = Highscore.getNotesHit(songName);

		scoreTxt = new FlxText(0, healthBarBG.y + 48, FlxG.width, "", 20);
		scoreTxt.setFormat(Paths.font("calibri.ttf"), 20, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		scoreTxt.scrollFactor.set();
		scoreTxt.borderSize = 1.25;
		scoreTxt.visible = scoreTxt.alpha > 0;

		if (ClientPrefs.judgeCounter != 'Off')
		{
			var textWidth = ClientPrefs.judgeCounter == 'Shortened' ? 150 : 200;
			var textPosX = ClientPrefs.hudPosition == 'Right' ? (FlxG.width - 5 - textWidth) : 5;
			var textPosY = (FlxG.height - displayedJudges.length*25) * 0.5;

			for (idx in 0...displayedJudges.length)
			{
				var judgment = displayedJudges[idx];

				var text = new FlxText(textPosX, textPosY + idx*25, textWidth, displayNames.get(judgment), 20);
				text.setFormat(Paths.font("calibrib.ttf"), 24, judgeColours.get(judgment), LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
				text.scrollFactor.set();
				text.borderSize = 1.25;
				add(text);

				var numb = new FlxText(textPosX, text.y, textWidth, "0", 20);
				numb.setFormat(Paths.font("calibri.ttf"), 24, FlxColor.WHITE, RIGHT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
				numb.scrollFactor.set();
				numb.borderSize = 1.25;
				add(numb);

				judgeTexts.set(judgment, numb);
				judgeNames.set(judgment, text);
			}
		}

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
	}

	override function update(elapsed:Float){
		var shownScore:String = Std.string(score);
		var isHighscore:Bool = false;
		if (ClientPrefs.showWifeScore){
			shownScore = Std.string(Math.floor(stats.totalNotesHit * 100));
			isHighscore = songWifeHighscore != 0 && stats.totalNotesHit > songWifeHighscore;
		}else
			isHighscore = songHighscore != 0 && score > songHighscore;
		

		scoreTxt.text = (isHighscore ? 'Hi-score: ' : 'Score: ')
			+ '$shownScore | Combo Breaks: $comboBreaks | Rating: '
			+ (grade != '?' ? Highscore.floorDecimal(ratingPercent * 100, 2)
				+ '% / ${grade} [${(ratingFC == 'CFC' && ClientPrefs.wife3) ? "FC" : ratingFC}]' : grade);
		if (ClientPrefs.npsDisplay)
			scoreTxt.text += ' | NPS: ${nps} / ${npsPeak}';

		for (k in judgements.keys())
		{
			if (judgeTexts.exists(k))
				judgeTexts.get(k).text = Std.string(judgements.get(k));
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