package funkin.objects.hud;

import flixel.util.FlxStringUtil;
import flixel.ui.FlxBar;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import funkin.states.PlayState;

/**
	Joke. Taken from Kade Engine 1.6
**/
class KadeHUD extends BaseHUD
{
	var healthBar:FNFHealthBar;
	var healthBarBG:FlxSprite;

	var iconP1:HealthIcon;
	var iconP2:HealthIcon;

	var scoreTxt:FlxText;
	var originalX:Float;

	var timeBarBG:FlxSprite;
	var timeBar:FlxBar;
	var timeTxt:FlxText;

	var watermark:FlxText;

	var songHighscore:Int = 0;
	var songWifeHighscore:Float = 0.0;

	var scoreString = Paths.getString("score");
	var hiscoreString = Paths.getString("highscore");
	var ratingString = Paths.getString("rating");
	var cbString = Paths.getString("cbplural");
	var npsString = Paths.getString("nps");

	var engineStringLong = 'Troll Engine ${Main.displayedVersion}';
	var engineStringShort = 'TE ${Main.displayedVersion}';

	override function set_displayedHealth(value:Float)
	{
		healthBar.value = value;
		displayedHealth = value;
		return value;
	}

	public function new(iP1:String, iP2:String, songName:String, stats:Stats)
	{
		super(iP1, iP2, songName, stats);

		songHighscore = Highscore.getScore(songName);
		songWifeHighscore = Highscore.getNotesHit(songName);

		//// Health bar
		healthBar = new FNFHealthBar(iP1, iP2);
		healthBarBG = healthBar.healthBarBG;
		iconP1 = healthBar.iconP1;
		iconP2 = healthBar.iconP2;

		////
		watermark = new FlxText(
			4, 
			(ClientPrefs.downScroll) ? (FlxG.height * 0.9 + 45) : (healthBarBG.y + 50), 
			0,
			'',
			16
		);
		watermark.setFormat(Paths.font("vcr.ttf"), 16, 0xFFFFFFFF, RIGHT, FlxTextBorderStyle.OUTLINE, 0xFF000000);
		watermark.scrollFactor.set();
		add(watermark);
		
		scoreTxt = new FlxText(FlxG.width / 2 - 235, healthBarBG.y + 50, 0, "", 20);
		scoreTxt.screenCenter(X);
		originalX = scoreTxt.x;
		scoreTxt.scrollFactor.set();
		scoreTxt.setFormat(Paths.font("vcr.ttf"), 16, 0xFFFFFFFF, FlxTextAlign.CENTER, FlxTextBorderStyle.OUTLINE, 0xFF000000);
		add(scoreTxt);

		////
		timeBarBG = new FlxSprite(0, (ClientPrefs.downScroll) ? (FlxG.height * 0.9 + 45) : 10, healthBarBG.graphic);
		timeBarBG.color = 0xFF000000;
		timeBarBG.screenCenter(X);
		timeBarBG.scrollFactor.set();
		add(timeBarBG);

		timeBar = new FlxBar(timeBarBG.x + 4, timeBarBG.y + 4, LEFT_TO_RIGHT, Std.int(timeBarBG.width - 8), Std.int(timeBarBG.height - 8), null, null, 0, 1);
		timeBar.scrollFactor.set();
		timeBar.createFilledBar(FlxColor.GRAY, FlxColor.LIME);
		timeBar.numDivisions = timeBar.barWidth;
		add(timeBar);

		timeTxt = new FlxText(timeBarBG.x + (timeBarBG.width / 2) - (songName.length * 5), timeBarBG.y, 0, songName, 16);
		timeTxt.y = (ClientPrefs.downScroll) ? (timeBarBG.y - 3) : timeBarBG.y;
		timeTxt.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, RIGHT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		timeTxt.scrollFactor.set();
		add(timeTxt);
	
		
		add(healthBarBG);
		add(healthBar);
		add(iconP1);
		add(iconP2);

		// fuck it
		changedOptions([]);
	}

	override function changedOptions(changed){
		super.changedOptions(changed);

		////
		healthBar.y = (ClientPrefs.downScroll) ? 50 : (FlxG.height * 0.9);
		healthBar.iconP1.y = healthBar.y - 75;
		healthBar.iconP2.y = healthBar.y - 75;
		healthBar.update(0);

		scoreTxt.y = (healthBarBG.y + 50);

		watermark.y = (ClientPrefs.downScroll) ? (FlxG.height * 0.9 + 45) : (healthBarBG.y + 50);
		
		timeBarBG.y = (ClientPrefs.downScroll) ? (FlxG.height * 0.9 + 45) : 10;
		timeBar.y = (timeBarBG.y + 4);
		timeTxt.y = (ClientPrefs.downScroll) ? (timeBarBG.y - 3) : timeBarBG.y;

		////
		updateTime = (ClientPrefs.timeBarType != 'Disabled' && ClientPrefs.timeOpacity > 0);

		timeBarBG.exists = updateTime;
		timeBar.exists = updateTime;
		timeTxt.exists = updateTime;

		if (ClientPrefs.timeBarType == "Song Name"){
			timeTxt.text = songName;
			watermark.text = engineStringLong;

			if (watermark.x + watermark.width >= healthBarBG.x)
				watermark.text = engineStringShort;
		}else{
			timeTxt.text = "";
			watermark.text = '$songName | $engineStringLong';

			if (watermark.x + watermark.width >= healthBarBG.x)
				watermark.text = '$songName | $engineStringShort';
		}

		timeTxt.x = timeBarBG.x + (timeBarBG.width / 2) - (timeTxt.text.length * 5);

		updateTimeBarAlpha();
	}

	function updateTimeBarAlpha()
	{
		var timeBarAlpha = ClientPrefs.timeOpacity * alpha;// * tweenProg;

		timeBarBG.alpha = timeBarAlpha;
		timeBar.alpha = timeBarAlpha;
		timeTxt.alpha = timeBarAlpha;
	}

	override function reloadHealthBarColors(dadColor:FlxColor, bfColor:FlxColor)
	{
		if (healthBar != null)
		{
			PlayState.instance.playOpponent ? healthBar.createFilledBar(0xFF66FF33, 0xFFFF0000) : healthBar.createFilledBar(0xFFFF0000, 0xFF66FF33);
			healthBar.updateBar();
		}
	}

	override function beatHit(beat:Int)
	{
		healthBar.iconScale = 1.2;
	}

	override function update(elapsed:Float)
	{
		if (FlxG.keys.justPressed.NINE)
			iconP1.swapOldIcon();

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

		var lengthInPx = scoreTxt.textField.length * scoreTxt.frameHeight; // bad way but does more or less a better job
		scoreTxt.x = (originalX - (lengthInPx / 2)) + 335;

		////
		if (updateTime)
		{
			var curTime:Float = Conductor.songPosition - ClientPrefs.noteOffset;
			if (curTime < 0)
				curTime = 0;

			songPercent = (curTime / songLength);
			time = curTime;

			var timeCalc:Null<Float> = null;

			switch (ClientPrefs.timeBarType)
			{
				case "Percentage":
					timeTxt.text = Math.floor(songPercent * 100) + "%";
				case "Time Left":
					timeCalc = (songLength - time);
				case "Time Elapsed":
					timeCalc = time;
			}

			if (timeCalc != null)
			{
				if (timeCalc <= 0)
					timeTxt.text = "0:00"
				else
					timeTxt.text = FlxStringUtil.formatTime(timeCalc / FlxG.timeScale / 1000, false);
			}

			timeBar.value = songPercent;
			timeTxt.x = timeBarBG.x + (timeBarBG.width / 2) - (timeTxt.text.length * 5); // kade engine try to center text challenge
		}

		super.update(elapsed);
	}
}