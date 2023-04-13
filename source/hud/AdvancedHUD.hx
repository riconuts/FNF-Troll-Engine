package hud;

import flixel.math.FlxMath;
import flixel.tweens.FlxEase;
import flixel.util.FlxStringUtil;
import flixel.ui.FlxBar;
import flixel.util.FlxColor;
import Conductor.Rating;
import flixel.tweens.FlxTween;
import flixel.text.FlxText;

class AdvancedHUD extends BaseHUD
{
	public var judgeTexts:Map<String, FlxText> = [];
	public var judgeNames:Map<String, FlxText> = [];
	public var gradeTxt:FlxText;
	public var scoreTxt:FlxText;
	public var ratingTxt:FlxText;
	public var fcTxt:FlxText;
	public var hitbar:Hitbar;
	public var timeBar:FlxBar;
	public var timeTxt:FlxText;
	public var botplaySine:Float = 0;
	public var botplayTxt:FlxText;

	private var timeBarBG:AttachedSprite;

	var songHighscore:Int = 0;
	public var hudPosition(default, null):String = ClientPrefs.hudPosition;
	override public function new(iP1:String, iP2:String, songName:String)
	{
		super(iP1, iP2, songName);
		displayedJudges.push("cb");
		
		songHighscore = Highscore.getScore(songName);

		scoreTxt = new FlxText(0, 0, 170, "", 20);
		scoreTxt.setFormat(Paths.font("calibri.ttf"), 40, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		scoreTxt.screenCenter(Y);
		scoreTxt.y -= 120;
		scoreTxt.x += 20 - 15;
		scoreTxt.scrollFactor.set();
		scoreTxt.borderSize = 1;
		add(scoreTxt);

		ratingTxt = new FlxText(0, 0, 170, "100%", 20);
		ratingTxt.setFormat(Paths.font("calibri.ttf"), 32, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		ratingTxt.screenCenter(Y);
		ratingTxt.y -= 90;
		ratingTxt.x += 20 - 15;
		ratingTxt.scrollFactor.set();
		ratingTxt.borderSize = 1;
		add(ratingTxt);

		fcTxt = new FlxText(0, 0, 170, "Clear", 20);
		fcTxt.setFormat(Paths.font("calibri.ttf"), 32, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		fcTxt.screenCenter(Y);
		fcTxt.y -= 60;
		fcTxt.x += 20 - 15;
		fcTxt.scrollFactor.set();
		fcTxt.borderSize = 1;
		add(fcTxt);

		gradeTxt = new FlxText(0, 0, 0, "C", 20);
		gradeTxt.setFormat(Paths.font("calibri.ttf"), 46, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		gradeTxt.x = 20;
		gradeTxt.color = 0xFFD800;
		gradeTxt.y = FlxG.height - gradeTxt.height;
		gradeTxt.scrollFactor.set();
		gradeTxt.borderSize = 1;
		add(gradeTxt);

		var idx:Int = 0;
		if (ClientPrefs.judgeCounter != 'Off'){
			// maybe this'd benefit from a JudgeCounter object idk
			for (judgment in displayedJudges){
				var text = new FlxText(0, 0, 170, displayNames.get(judgment), 20);
				text.setFormat(Paths.font("calibrib.ttf"), 28, judgeColours.get(judgment), LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
				text.screenCenter(Y);
				text.y -= 35 - (25 * idx);
				text.x += 20 - 15;
				text.scrollFactor.set();
				text.borderSize = 1;
				add(text);
				var numb = new FlxText(0, 0, 170, "0", 20);
				numb.setFormat(Paths.font("calibri.ttf"), 28, FlxColor.WHITE, RIGHT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
				numb.screenCenter(Y);
				numb.y -= 35 - (25 * idx);
				numb.x += 25 - 15;
				numb.scrollFactor.set();
				numb.borderSize = 1;
				add(numb);
				judgeTexts.set(judgment, numb);
				judgeNames.set(judgment, text);
				idx++;
			}
		}else{
			var text = new FlxText(0, 0, 170, "Misses", 20);
			text.setFormat(Paths.font("calibrib.ttf"), 28, 0xBDBDBD, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			text.screenCenter(Y);
			text.y -= 35;
			text.x += 20 - 15;
			text.scrollFactor.set();
			text.borderSize = 1;
			add(text);
			var numb = new FlxText(0, 0, 170, "0", 20);
			numb.setFormat(Paths.font("calibri.ttf"), 28, FlxColor.WHITE, RIGHT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			numb.screenCenter(Y);
			numb.y -= 35;
			numb.x += 25 - 15;
			numb.scrollFactor.set();
			numb.borderSize = 1;
			add(numb);
			judgeTexts.set('miss', numb);
			judgeNames.set('miss', text);
		}

		if (hudPosition == 'Right'){
			for(obj in members)
				obj.x = FlxG.width - obj.width - obj.x;
		}

		// prob gonna do my own time bar too lol but for now idc
		timeTxt = new FlxText(PlayState.STRUM_X + (FlxG.width * 0.5) - 248, (ClientPrefs.downScroll ? FlxG.height - 44 : 19), 400, "", 32);
		timeTxt.setFormat(Paths.font("calibri.ttf"), 32, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		timeTxt.scrollFactor.set();
		timeTxt.alpha = 0;
		timeTxt.borderSize = 2;
		timeTxt.visible = updateTime;

		if (ClientPrefs.timeBarType == 'Song Name')
		{
			timeTxt.text = songName;
			timeTxt.size = 24;
			timeTxt.y += 3;
		}

		timeBarBG = new AttachedSprite('timeBar');
		timeBarBG.x = timeTxt.x;
		timeBarBG.y = timeTxt.y + (timeTxt.height * 0.25);
		timeBarBG.scrollFactor.set();
		timeBarBG.alpha = 0;
		timeBarBG.visible = updateTime;
		timeBarBG.color = FlxColor.BLACK;
		timeBarBG.xAdd = -5;
		timeBarBG.yAdd = -5;
		add(timeBarBG);

		timeBar = new FlxBar(timeBarBG.x + 5, timeBarBG.y + 5, LEFT_TO_RIGHT, Std.int(timeBarBG.width - 10), Std.int(timeBarBG.height - 10), this,
			'songPercent', 0, 1);
		timeBar.scrollFactor.set();
		timeBar.createFilledBar(0xFF000000, 0xFFFFFFFF);
		timeBar.numDivisions = 800; // How much lag this causes?? Should i tone it down to idk, 400 or 200?
		timeBar.alpha = 0;
		timeBar.visible = updateTime;

		add(timeBar);
		add(timeTxt);
		timeBarBG.sprTracker = timeBar;

		//
		botplayTxt = new FlxText(400, timeBarBG.y + (ClientPrefs.downScroll ? -78 : 55), FlxG.width - 800, "[BUTTPLUG]", 32);
		botplayTxt.setFormat(Paths.font("calibri.ttf"), 32, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		botplayTxt.scrollFactor.set();
		botplayTxt.borderSize = 1.25;
		botplayTxt.visible = false;
		add(botplayTxt);

		if (ClientPrefs.hitbar)
		{
			hitbar = new Hitbar();
			hitbar.screenCenter(XY);
			if (ClientPrefs.downScroll)
			{
				hitbar.y -= 220;
				hitbar.averageIndicator.flipY = false;
				hitbar.averageIndicator.y = hitbar.y - (hitbar.averageIndicator.width + 5);
			}
			else
				hitbar.y += 340;

			add(hitbar);
		}
	}

	override public function songStarted()
	{
		FlxTween.tween(timeBar, {alpha: ClientPrefs.timeOpacity * alpha}, 0.5, {ease: FlxEase.circOut});
		FlxTween.tween(timeTxt, {alpha: ClientPrefs.timeOpacity * alpha}, 0.5, {ease: FlxEase.circOut});
	}

	override public function songEnding()
	{
		timeBarBG.visible = false;
		timeBar.visible = false;
		timeTxt.visible = false;
	}

	function colorLerp(clr1:FlxColor, clr2:FlxColor, alpha:Float){
		return FlxColor.fromRGBFloat(
			FlxMath.lerp(clr1.redFloat, clr2.redFloat, alpha),
			FlxMath.lerp(clr1.greenFloat, clr2.greenFloat, alpha),
			FlxMath.lerp(clr1.blueFloat, clr2.blueFloat, alpha),
			FlxMath.lerp(clr1.alphaFloat, clr2.alphaFloat, alpha)
		);
	}
	
	override function set_grade(v:String){
		if(grade != v){
			grade = v;
			FlxTween.cancelTweensOf(gradeTxt.scale);
			gradeTxt.scale.set(1.2, 1.2);
			FlxTween.tween(gradeTxt.scale, {x: 1, y: 1}, 0.2, {ease: FlxEase.circOut});
		}

		return grade;
	}

	override function recalculateRating(){
		var gradeColor = FlxColor.WHITE;
		if(grade!='?'){
			if (ratingPercent < 0)
				gradeColor = judgeColours.get("miss");
			else if (ratingPercent >= 0.9)
				gradeColor = colorLerp(judgeColours.get("good"), 0xFFD800, (ratingPercent - 0.9) / 0.1);
			
			else if (ratingPercent >= 0.6)
				gradeColor = colorLerp(FlxColor.WHITE, judgeColours.get("good"), (ratingPercent - 0.6) / 0.3);
			else
				gradeColor = colorLerp(judgeColours.get("miss"), FlxColor.WHITE, (ratingPercent) / 0.6);
		}
		

		gradeTxt.color = gradeColor;

	}
	override function update(elapsed:Float)
	{
/* 		scoreTxt.text = (songHighscore != 0 && score > songHighscore ? 'Hi-score: ' : 'Score: ')
			+ '$score | Misses: $misses | Rating: '
			+ (grade != '?' ? Highscore.floorDecimal(ratingPercent * 100, 2) + '% / ${grade} [$ratingFC]' : grade); */

		var displayedScore = Std.string(score);
		if (displayedScore.length > 7)
			displayedScore = '999999999';
		gradeTxt.text = grade;
		if (hudPosition == 'Right')gradeTxt.x = FlxG.width - gradeTxt.width - 20;

		scoreTxt.text = displayedScore;
		scoreTxt.color = (songHighscore != 0 && score > songHighscore) ? 0xFFD800 : 0xFFFFFF;

		ratingTxt.text = (grade != "?"?(Highscore.floorDecimal(ratingPercent * 100, 2) + "%"):"0%");
		fcTxt.text = ratingFC;
		fcTxt.color = switch (ratingFC){
			case 'KFC':
				judgeColours.get("epic");
			case 'AFC':	
				judgeColours.get("sick");
			case 'CFC':
				judgeColours.get("good");
			case 'FC':
				0xFFFFFFFF;
			case 'Fail':
				judgeColours.get("miss");
			default:
				0xFFA3A3A3;
		}
		
		for(k in judgements.keys()){
			if (judgeTexts.exists(k))
				judgeTexts.get(k).text = Std.string(judgements.get(k));
		}
		super.update(elapsed);

		if (FlxG.state == PlayState.instance)
			botplayTxt.visible = PlayState.instance.cpuControlled;

		if (botplayTxt.visible)
		{
			botplaySine += 180 * elapsed;
			botplayTxt.alpha = 1 - Math.sin((Math.PI * botplaySine) / 180);
		}

		var songCalc:Float = (songLength - time);
		if (ClientPrefs.timeBarType == 'Time Elapsed')
			songCalc = time;

		var secondsTotal:Int = Math.floor(songCalc / 1000);
		if (secondsTotal < 0)
			secondsTotal = 0;

		if (ClientPrefs.timeBarType != 'Song Name')
			timeTxt.text = FlxStringUtil.formatTime(secondsTotal, false);
	}

	override function set_misses(val:Int){
		if(misses!=val){
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
			}
			judgeTxt.text = Std.string(val);
		}
		return misses;
	}

	override function set_comboBreaks(val:Int)
	{
		if (comboBreaks != val)
		{
			comboBreaks = val;
			var judgeName = judgeNames.get('cb');
			var judgeTxt = judgeTexts.get('cb');
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
			judgeTxt.text = Std.string(val);
		}
		return comboBreaks;
	}

	override function set_ratingPercent(val:Float)
	{
		if (ratingPercent!=val){
			ratingPercent = val;
			FlxTween.cancelTweensOf(ratingTxt.scale);
			ratingTxt.scale.set(1.075, 1.075);
			FlxTween.tween(ratingTxt.scale, {x: 1, y: 1}, 0.2);
		}
		return ratingPercent;
	}

	
	override function noteJudged(judge:Rating, ?note:Note, ?field:PlayField)
	{
		var hitTime = note.strumTime - Conductor.songPosition + ClientPrefs.ratingOffset;

		if (ClientPrefs.hitbar)
			hitbar.addHit(hitTime);
		if (ClientPrefs.scoreZoom)
		{
			FlxTween.cancelTweensOf(scoreTxt.scale);
			scoreTxt.scale.set(1.075, 1.075);
			FlxTween.tween(scoreTxt.scale, {x: 1, y: 1}, 0.2);

			var judgeName = judgeNames.get(judge.name);
			var judgeTxt = judgeTexts.get(judge.name);
			if(judgeName!=null){
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

		}
	}

	override public function beatHit(beat:Int)
	{
		if (hitbar != null)
			hitbar.beatHit();

		super.beatHit(beat);
	}
}