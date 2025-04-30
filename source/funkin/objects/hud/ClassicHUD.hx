package funkin.objects.hud;

import flixel.math.FlxMath;
import flixel.util.FlxColor;
import flixel.text.FlxText;
import flixel.ui.FlxBar;
import funkin.objects.hud.FNFHealthBar.ShittyBar;
import flixel.util.FlxStringUtil;

class ClassicHUD extends CommonHUD {
	var scoreTxt:FlxText;
	var counters = new Map<String, FlxText>();

	override function beatHit(beat:Int)
	{
		healthBar.iconP1.setGraphicSize(Std.int(healthBar.iconP1.width + 30));
		healthBar.iconP2.setGraphicSize(Std.int(healthBar.iconP2.width + 30));

		healthBar.iconP1.updateHitbox();
		healthBar.iconP2.updateHitbox();
	}

	public function new(songName:String, stats:Stats)
	{
		super(songName, stats);
		healthBar.destroy();
		remove(healthBar);
		
		// Maybe this should use a modified one that looks like V-Slice's instead of Week <=7
		// Idk lol

		healthBar = new ShittyBar('bf', 'dad');
		cast (healthBar, ShittyBar).vSlice = true;
		healthBarBG = healthBar.healthBarBG;

		iconP1 = healthBar.iconP1;
		iconP2 = healthBar.iconP2;

		healthBar.healthBarBG.y = FlxG.height * (ClientPrefs.downScroll ? 0.1 : 0.9);
		healthBar.y = healthBarBG.y + 5;
		healthBar.iconP1.y = healthBar.y - 75;
		healthBar.iconP2.y = healthBar.y - 75;

		scoreTxt = new FlxText(healthBarBG.x + healthBarBG.width - 190, healthBarBG.y + (ClientPrefs.downScroll ? -30 : 30), 0, "", 20);
		scoreTxt.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, 'right', FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		scoreTxt.scrollFactor.set();

		healthBar.createFilledBar(0xFFFF0000, 0xFF00FF00);
		healthBar.updateBar();

		for (counterIdx => judge in displayedJudges) {
			var offset = -40 + (counterIdx * 20);

			var txt = new FlxText(4, (FlxG.height / 2) + offset, FlxG.width - 8, "", 20);
			txt.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			txt.scrollFactor.set();
			txt.visible = ClientPrefs.judgeCounter != 'Off';
			add(txt);
			counters.set(judge, txt);
			updateJudgeCounter(judge);
		}

		timeBar.visible = false;
		add(healthBarBG);
		add(healthBar);
		add(iconP1);
		add(iconP2);
		add(scoreTxt);

		remove(timeBar);
		remove(timeBarBG);
		remove(timeTxt);
    }

	private function updateJudgeCounter(id:String) {
		if (counters.exists(id))
			counters.get(id).text = '${displayNames[id]}: ${judgements[id]}';
	}


	override function reloadHealthBarColors(dadColor:FlxColor, bfColor:FlxColor)
	{
		if (healthBar != null)
		{
			healthBar.createFilledBar(0xFFFF0000, 0xFF00FF00);
			healthBar.updateBar();
		}
	}

	var scoreString = Paths.getString("score");

	override function update(elapsed:Float){
		super.update(elapsed);
		for (k => v in judgements)
			updateJudgeCounter(k);

		var shownScore:Float = 0;
		if (ClientPrefs.showWifeScore)
			shownScore = Math.floor(stats.totalNotesHit * 100);
		else
			shownScore = stats.score;

		if (ClientPrefs.botplayMarker != 'Off' && PlayState.instance.cpuControlled)
			scoreTxt.text = 'Botplay Enabled';
		else
			scoreTxt.text = '$scoreString: ${FlxStringUtil.formatMoney(shownScore, false, true)}';

	}

	override function changedOptions(changed:Array<String>)
	{
		super.changedOptions(changed);
		if (changed.contains("judgeCounter")){
			for (id => cnt in counters)
				cnt.visible = ClientPrefs.judgeCounter != 'Off';
		}

		if (changed.contains("downScroll"))
		{
			healthBar.healthBarBG.y = FlxG.height * (ClientPrefs.downScroll ? 0.1 : 0.9);
			healthBar.y = healthBarBG.y + 5;
			healthBar.iconP1.y = healthBar.y - 75;
			healthBar.iconP2.y = healthBar.y - 75;
			scoreTxt.x = healthBarBG.x + healthBarBG.width - 190;
			scoreTxt.y = healthBarBG.y + (ClientPrefs.downScroll ? -30 : 30);
		}
	}


}