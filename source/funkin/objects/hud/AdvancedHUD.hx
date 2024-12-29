package funkin.objects.hud;

import funkin.objects.hud.JudgementCounter;
import funkin.objects.hud.JudgementCounter.JudgeCounterSettings;
import funkin.data.JudgmentManager.JudgmentData;
import flixel.util.FlxColor;
import funkin.objects.playfields.*;
import flixel.math.FlxMath;
import flixel.tweens.*;
import flixel.text.FlxText;

class AdvancedHUD extends CommonHUD
{
	public var gradeTxt:FlxText;
	public var scoreTxt:FlxText;
	public var ratingTxt:FlxText;
	public var fcTxt:FlxText;
	public var npsTxt:FlxText;
	public var pcTxt:FlxText;
	public var hitbar:Hitbar;

	var peakCombo:Int = 0;
	var songHighscore:Int = 0;
	var songWifeHighscore:Float = 0;
	var songHighRating:Float = 0;
	var npsIdx:Int = 0;
	public var hudPosition(default, null):String = ClientPrefs.hudPosition;
	private var cpuControlled(get, never):Bool;
	inline function get_cpuControlled() return PlayState.instance.cpuControlled;

	var npsString:String = Paths.getString("nps");
	var peakString:String = Paths.getString("peak");
	var pcString:String = Paths.getString("peakcombo");
	var botplayString = Paths.getString("botplayMark");

	// Maybe we should move this into CommonHUD??
	var counterOptions:JudgeCounterSettings = {
		textBorderSpacing: 5,
		textLineSpacing: 25,
		textSize: 24,
		textBorderSize: 1.25,
		nameFont: "calibrib.ttf",
		numbFont: "calibri.ttf"
	}
	var judgeCounters:JudgementCounters;

	function regenJudgeDisplay()
	{
		remove(judgeCounters);
		judgeCounters.destroy();
		judgeCounters = null;
		generateJudgementDisplays();
	}

	function generateJudgementDisplays()
	{
		var textWidth = 200;
		counterOptions.length = FULL;
		if (ClientPrefs.judgeCounter != 'Off') {
			judgeCounters = new JudgementCounters(
				hudPosition == 'Right' ? (FlxG.width - counterOptions.textBorderSpacing - textWidth) : counterOptions.textBorderSpacing,
				FlxG.height + 100, // TODO: Alter the math so this can be FlxG.height * 0.5, since that'd make more sense	for users
				displayNames,
				judgeColours,
				counterOptions,
				displayedJudges
			);
		} else {
			judgeCounters = new JudgementCounters(
				hudPosition == 'Right' ? (FlxG.width - counterOptions.textBorderSpacing - 200) : counterOptions.textBorderSpacing,
				FlxG.height + 100, // TODO: Alter the math so this can be FlxG.height * 0.5, since that'd make more sense	for users
				displayNames,
				judgeColours,
				counterOptions,
				["miss"]
			);
		}
		add(judgeCounters);

		npsIdx = judgeCounters.len;
		if (npsTxt != null){
			npsTxt.screenCenter(Y);
			npsTxt.y -= 5 - (25 * npsIdx);
		}
	}

	override public function new(iP1:String, iP2:String, songName:String, stats:Stats)
	{
		super(iP1, iP2, songName, stats);

		stats.changedEvent.add(statChanged);
		
		add(healthBarBG);
		add(healthBar);
		add(iconP1);
		add(iconP2);
		
		var songRecord = Highscore.getRecord(this.songName, PlayState.difficultyName);
		songHighscore = songRecord.score;
		songWifeHighscore = songRecord.accuracyScore;
		songHighRating = songRecord.rating;

		////
		var tWidth = 200;
		scoreTxt = new FlxText(0, 0, tWidth, "0", 20);
		scoreTxt.setFormat(Paths.font("calibri.ttf"), 40, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		scoreTxt.screenCenter(Y);
		scoreTxt.y -= 120;
		scoreTxt.x += 20 - 15;
		scoreTxt.scrollFactor.set();
		scoreTxt.borderSize = 1.25;
		add(scoreTxt);

		ratingTxt = new FlxText(0, 0, tWidth, "100%", 20);
		ratingTxt.setFormat(Paths.font("calibri.ttf"), 32, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		ratingTxt.screenCenter(Y);
		ratingTxt.y -= 90;
		ratingTxt.x += 20 - 15;
		ratingTxt.scrollFactor.set();
		ratingTxt.borderSize = 1.25;
		add(ratingTxt);

		fcTxt = new FlxText(0, 0, tWidth, "Clear", 20);
		fcTxt.setFormat(Paths.font("calibri.ttf"), 32, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		fcTxt.screenCenter(Y);
		fcTxt.y -= 60;
		fcTxt.x += 20 - 15;
		fcTxt.scrollFactor.set();
		fcTxt.borderSize = 1.25;
		add(fcTxt);

		gradeTxt = new FlxText(20, 0, FlxG.width - 40, "C", 20);
		gradeTxt.setFormat(Paths.font("calibri.ttf"), 46, 0xFFD800, (hudPosition == 'Right') ? RIGHT : LEFT);
		gradeTxt.setBorderStyle(FlxTextBorderStyle.OUTLINE, 0xFF000000, 1.25);
		gradeTxt.y = FlxG.height - gradeTxt.height;
		gradeTxt.scrollFactor.set();
		add(gradeTxt);

		generateJudgementDisplays();

		npsTxt = new FlxText(0, 0, tWidth, '$npsString: 0 ($peakString: 0)', 20);
		npsTxt.setFormat(Paths.font("calibri.ttf"), 26, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		npsTxt.screenCenter(Y);
		npsTxt.y -= 5 - (25 * npsIdx);
		npsTxt.x += 20 - 15;
		npsTxt.scrollFactor.set();
		npsTxt.borderSize = 1.25;
		npsTxt.visible = ClientPrefs.npsDisplay;
		add(npsTxt);
		
		pcTxt = new FlxText(0, 0, tWidth, '$pcString: 0', 20);
		pcTxt.setFormat(Paths.font("calibri.ttf"), 26, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		pcTxt.screenCenter(Y);
		pcTxt.y -= 5 - (25 * (ClientPrefs.npsDisplay ? (npsIdx + 1) : npsIdx));
		pcTxt.x += 20 - 15;
		pcTxt.scrollFactor.set();
		pcTxt.borderSize = 1.25;
		add(pcTxt);

		if (hudPosition == 'Right'){
			for(obj in members){
				if(obj != judgeCounters)
					obj.x = FlxG.width - obj.width - obj.x;
			}
		}

		//
		hitbar = new Hitbar();
		hitbar.alpha = alpha;
		hitbar.visible = ClientPrefs.hitbar;
		add(hitbar);

		if (ClientPrefs.hitbar){
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

	override function recalculateRating(){
		gradeTxt.color = (
			if (cpuControlled || grade == '?'){
				FlxColor.WHITE;

			}else if (ratingPercent < 0){
				judgeColours.get("miss");

			}else if (ratingPercent >= 0.9){
				FlxColor.interpolate(judgeColours.get("good"), 0xFFD800, (ratingPercent - 0.9) / 0.1);
			
			}else if (ratingPercent >= 0.6){
				FlxColor.interpolate(FlxColor.WHITE, judgeColours.get("good"), (ratingPercent - 0.6) / 0.3);

			}else{
				FlxColor.interpolate(judgeColours.get("miss"), FlxColor.WHITE, (ratingPercent) / 0.6);

			}
		);
		refreshFCColour();
	}

	override function changedOptions(changed:Array<String>){
		super.changedOptions(changed);

		if (changed.contains('judgeCounter'))
			regenJudgeDisplay();

		if (changed.contains('judgeCounter') || changed.contains('npsDisplay')){
			pcTxt.screenCenter(Y);
			pcTxt.y -= 5 - (25 * (ClientPrefs.npsDisplay ? npsIdx + 1 : npsIdx));
		}

		npsTxt.visible = ClientPrefs.npsDisplay;

		hitbar.visible = ClientPrefs.hitbar;

		statChanged("totalNotesHit", totalNotesHit);
		statChanged("score", score);

		// ^^ force the displays to update

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

	override function update(elapsed:Float)
	{
		gradeTxt.text = cpuControlled && useSubtleMark ? botplayString : grade;
		
		ratingTxt.text = (grade=="?") ? "0%" : (Highscore.floorDecimal(ratingPercent * 100, 2) + "%");
		fcTxt.text = (ratingFC == stats.gfc && stats.accuracySystem == WIFE3) ? stats.fc : ratingFC;
		
		if (ClientPrefs.npsDisplay)
			npsTxt.text = '$npsString: $nps ($peakString: $npsPeak)';

		if(peakCombo < combo) peakCombo = combo;
		pcTxt.text = '$pcString: $peakCombo';
		
		for (k => v in judgements)
			judgeCounters.setCount(k, v);

		super.update(elapsed);
	}
	
	function refreshFCColour(){
		fcTxt.color =
			{
				var color:FlxColor = 0xFFA3A3A3;

				if (ratingFC == stats.fail)
				{
					color = judgeColours.get("miss");
				}
				else if (comboBreaks == 0)
				{
					if (stats.judgements.get("bad") > 0 || stats.judgements.get("shit") > 0)
						color = 0xFFFFFFFF;
					else if (stats.judgements.get("good") > 0)
					{
						color = judgeColours.get("good");
						if (stats.judgements.get("good") == 1)
							color.saturation *= 0.75;
					}
					else if (stats.judgements.get("sick") > 0)
					{
						color = judgeColours.get("sick");
						if (stats.judgements.get("sick") == 1)
							color.saturation *= 0.75;
					}
					else if (stats.judgements.get("epic") > 0)
					{
						color = judgeColours.get("epic");
					}
				}

				color;
			};
	}

	function statChanged(stat:String, val:Dynamic){
		// Maybe add isUpdating shit to here??
		// Idk though
		switch(stat){
			case 'score':
				if(!ClientPrefs.showWifeScore){
					var displayedScore = Std.string(val);
					if (displayedScore.length > 7)
					{
						if (val < 0)
							displayedScore = '-999999';
						else
							displayedScore = '9999999';
					}

					scoreTxt.text = displayedScore;
					scoreTxt.color = !PlayState.instance.saveScore ? 0x818181 : ((songHighscore != 0 && val > songHighscore) ? 0xFFD800 : 0xFFFFFF);
				}
			case 'totalNotesHit':
				if (ClientPrefs.showWifeScore)
				{
					var disp:Int = Math.floor(val * 100);
					var displayedScore = Std.string(disp);
					if (displayedScore.length > 7)
					{
						if (disp < 0)
							displayedScore = '-999999';
						else
							displayedScore = '9999999';
					}

					scoreTxt.text = displayedScore;
					scoreTxt.color = !PlayState.instance.saveScore ? 0x818181 : ((songWifeHighscore != 0 && val > songWifeHighscore) ? 0xFFD800 : 0xFFFFFF);
				}

				// dont need to check songHighRating != 0 because if songWifeHighscore isnt 0 then the rating prob isnt either
				ratingTxt.color = !PlayState.instance.saveScore ? 0x818181 : ((songWifeHighscore != 0 && val > songWifeHighscore && stats.ratingPercent > songHighRating) ? 0xFFD800 : 0xFFFFFF);
			case 'grade':
				FlxTween.cancelTweensOf(gradeTxt.scale);
				gradeTxt.scale.set(1.2, 1.2);
				FlxTween.tween(gradeTxt.scale, {x: 1, y: 1}, 0.2, {ease: FlxEase.circOut});
			case 'misses':
				judgeCounters.setCount('miss', val);
				if (ClientPrefs.scoreZoom)
					judgeCounters.bump('miss');
			case 'comboBreaks':
				judgeCounters.setCount('cb', val);
				if (ClientPrefs.scoreZoom)
					judgeCounters.bump('cb');
			case 'ratingPercent':
				if (ClientPrefs.scoreZoom)
				{
					FlxTween.cancelTweensOf(ratingTxt.scale);
					ratingTxt.scale.set(1.075, 1.075);
					FlxTween.tween(ratingTxt.scale, {x: 1, y: 1}, 0.2);
				}
				
		}
	}

	
	override function noteJudged(judge:JudgmentData, ?note:Note, ?field:PlayField)
	{
		var hitTime = note.strumTime - Conductor.songPosition + ClientPrefs.ratingOffset;

		if (ClientPrefs.hitbar)
			hitbar.addHit(-hitTime);
		if (ClientPrefs.scoreZoom)
		{
			FlxTween.cancelTweensOf(scoreTxt.scale);
			scoreTxt.scale.set(1.075, 1.075);
			FlxTween.tween(scoreTxt.scale, {x: 1, y: 1}, 0.2);
			judgeCounters.bump(judge.internalName);
		}

		refreshFCColour();
	}

	override public function beatHit(beat:Int)
	{
		if (hitbar != null)
			hitbar.beatHit();

		super.beatHit(beat);
	}
}