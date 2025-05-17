package funkin.objects.hud;

import math.CoolMath;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.tweens.*;
import funkin.objects.hud.JudgementCounter;
import funkin.data.JudgmentManager.JudgmentData;
import funkin.objects.playfields.*;

using funkin.data.FlxTextFormatData;

class AdvancedHUD extends CommonHUD
{
	public var gradeTxt:FlxText;
	public var scoreTxt:FlxText;
	public var ratingTxt:FlxText;
	public var fcTxt:FlxText;
	public var npsTxt:FlxText;
	public var pcTxt:FlxText;
	public var hitbar:Hitbar;
	
	public var hudY:Float = (FlxG.height / 2) + 50;

	var peakCombo:Int = 0;
	var songHighscore:Int = 0;
	var songWifeHighscore:Float = 0;
	var songHighRating:Float = 0;
	public var hudPosition(default, null):String = ClientPrefs.hudPosition;
	private var cpuControlled(get, never):Bool;
	inline function get_cpuControlled() return PlayState.instance.cpuControlled;

	var npsString:String = Paths.getString("nps");
	var peakString:String = Paths.getString("peak");
	var pcString:String = Paths.getString("peakcombo");
	var botplayString = Paths.getString("botplayMark");

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
		textLineSpacing: 24,
		textSize: 22,
		textBorderSize: 1.25,
		nameFont: "quanticob.ttf",
		numbFont: "quantico.ttf"
		#end
	}
	var judgeCounters:JudgementCounters;

	var textStyle:FlxTextFormatData = {
		#if tgt
		font: "calibri.ttf",
		#else
		font: "quantico.ttf",
		#end
		borderStyle: FlxTextBorderStyle.OUTLINE,
		borderColor: FlxColor.BLACK,
		borderSize: 1.25,
	};

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
				hudY,
				displayNames,
				judgeColours,
				counterOptions,
				displayedJudges
			);
		} else {
			judgeCounters = new JudgementCounters(
				hudPosition == 'Right' ? (FlxG.width - counterOptions.textBorderSpacing - 200) : counterOptions.textBorderSpacing,
				hudY,
				displayNames,
				judgeColours,
				counterOptions,
				["cb"]
			);
		}
		add(judgeCounters);


		repositionHud();
	}

	function repositionHud(){
		var offset = judgeCounters.height / 2;

		scoreTxt.y = hudY - offset - 90;
		ratingTxt.y = hudY - offset - 60;
		fcTxt.y = hudY - offset - 30;
		npsTxt.y = hudY + offset;
		pcTxt.y = hudY + offset + 25;

		if (!npsTxt.visible) 
			pcTxt.y -= 25;
		
	}

	override public function new(songName:String, stats:Stats)
	{
		super(songName, stats);

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
		#if tgt
		var tWidth = 200;
		var scoreSize = 40;
		var ratingSize = 32;
		var fcSize = 32;
		var gradeSize = 46;
		var npsSize = 26;
		var pcSize = 26; 
		#else
		var tWidth = 200;
		var scoreSize = 32;
		var ratingSize = 28;
		var fcSize = 28;
		var gradeSize = 38;
		var npsSize = 20;
		var pcSize = 20;
		#end

		scoreTxt = new FlxText(0, 0, tWidth, "0", scoreSize);
		scoreTxt.applyFormat(textStyle);
		scoreTxt.alignment = CENTER;
		scoreTxt.screenCenter(Y);
		scoreTxt.x += 20 - 15;
		scoreTxt.scrollFactor.set();
		add(scoreTxt);

		ratingTxt = new FlxText(0, 0, tWidth, "100%", ratingSize);
		ratingTxt.applyFormat(textStyle);
		ratingTxt.alignment = CENTER;
		ratingTxt.screenCenter(Y);
		ratingTxt.x += 20 - 15;
		ratingTxt.scrollFactor.set();
		add(ratingTxt);

		fcTxt = new FlxText(0, 0, tWidth, "Clear", fcSize);
		fcTxt.applyFormat(textStyle);
		fcTxt.alignment = CENTER;
		fcTxt.screenCenter(Y);
		fcTxt.x += 20 - 15;
		fcTxt.scrollFactor.set();
		add(fcTxt);

		gradeTxt = new FlxText(20, 0, FlxG.width - 40, "C", gradeSize);
		gradeTxt.applyFormat(textStyle);
		gradeTxt.alignment = (hudPosition == 'Right') ? RIGHT : LEFT;
		gradeTxt.color = 0xFFFFD800;
		@:privateAccess gradeTxt.regenGraphic();
		gradeTxt.y = FlxG.height - gradeTxt.height;
		gradeTxt.scrollFactor.set();
		add(gradeTxt);


		npsTxt = new FlxText(0, 0, tWidth, '$npsString: 0 ($peakString: 0)', npsSize);
		npsTxt.applyFormat(textStyle);
		npsTxt.alignment = CENTER;
		npsTxt.wordWrap = false; // vcr font spaces are huuge compared to calibri so fuck it just clip it
		npsTxt.screenCenter(Y);
		npsTxt.scrollFactor.set();
		npsTxt.visible = ClientPrefs.npsDisplay;
		add(npsTxt);
		
		pcTxt = new FlxText(0, 0, tWidth, '$pcString: 0', pcSize);
		pcTxt.applyFormat(textStyle);
		pcTxt.alignment = CENTER;
		pcTxt.screenCenter(Y);
		pcTxt.x += 20 - 15;
		pcTxt.scrollFactor.set();
		add(pcTxt);

		generateJudgementDisplays();

		if (hudPosition == 'Right'){
			for(obj in members){
				if(obj != judgeCounters)
					obj.x = FlxG.width - obj.width - obj.x;
			}
		}


		repositionHud();
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

		

		
		npsTxt.visible = ClientPrefs.npsDisplay;
		
		hitbar.visible = ClientPrefs.hitbar;
		if (changed.contains('judgeCounter') || changed.contains('npsDisplay')) 
			repositionHud();

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
		
		ratingTxt.text = (grade=="?") ? "0%" : (CoolMath.floorDecimal(ratingPercent * 100, 2) + "%");
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