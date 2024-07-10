package funkin.states;

import funkin.data.Highscore;
import flixel.math.FlxMath;
import funkin.states.SongSelectState.SongChartSelec;
import funkin.data.Song;
import funkin.data.Song.SongMetadata;
import funkin.data.WeekData;

import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.text.FlxText;
import flixel.group.FlxGroup.FlxTypedGroup;

class FreeplayState extends MusicBeatState
{
	var menu = new AlphabetMenu();
	var songMeta:Array<SongMetadata> = [];

	var bgGrp = new FlxTypedGroup<FlxSprite>();
	var bg:FlxSprite;

	var targetHighscore:Float = 0;
	var lerpHighscore:Float = 0;

	var scoreBG:FlxSprite;
	var scoreText:FlxText;
	var diffText:FlxText;

	static var lastSelected:Int = 0;
	var selectedSongData:SongMetadata;
	
	static var curDiffName:String = "normal";
	static var curDiffIdx:Int = 1;

	override public function create()
	{
		for (week in WeekData.reloadWeekFiles())
		{
			Paths.currentModDirectory = week.directory;

			for (songName in week.songs){
				var metadata:SongMetadata = {songName: songName, folder: week.directory};
				if (metadata.charts.length == 0){
					trace('${week.directory}: $songName doesn\'t have any available charts!');
					continue;
				}
				
				menu.addTextOption(songName).ID = songMeta.length;
				songMeta.push(metadata);
			}
		}

		////
		add(bgGrp);

		add(menu);
		menu.controls = controls;
		menu.callbacks.onAccept = (selectedIdx)->{
			menu.controls = null;
			Song.playSong(songMeta[selectedIdx], curDiffName);	
		};
		menu.callbacks.onSelect = (selectedIdx)->{
			onSelectSong(songMeta[selectedIdx]);
		}

		////
		var textBG = CoolUtil.blankSprite(FlxG.width, 26, 0xFF999999);
		textBG.y = FlxG.height - 26;
		textBG.blend = MULTIPLY;
		add(textBG);

		var text:FlxText = new FlxText(textBG.x, textBG.y + 4, FlxG.width, Paths.getString("freeplayhint"));
		text.setFormat(Paths.font("vcr.ttf"), 16, 0xFFFFFFFF, RIGHT);
		text.scrollFactor.set();
		add(text);

		////
		scoreText = new FlxText(FlxG.width * 0.7, 5, 0, 'PERSONAL BEST: 0', 32);
		scoreText.setFormat(Paths.font("vcr.ttf"), 32, 0xFFFFFFFF, RIGHT);

		scoreBG = CoolUtil.blankSprite(FlxG.width * 0.3, 66, 0xFF999999);
		scoreBG.setPosition(scoreText.x - 6, 0);
		scoreBG.blend = MULTIPLY;
		add(scoreBG);

		diffText = new FlxText(scoreText.x, scoreText.y + 36, 0, "", 24);
		diffText.font = scoreText.font;
		add(diffText);

		add(scoreText);

		////
		menu.curSelected = lastSelected;

		super.create();
	}

	function onSelectSong(data:SongMetadata)
	{	
		selectedSongData = data;
		Paths.currentModDirectory = data.folder;

		updateDifficulty();

		var record = Highscore.getRecord(data.songName);
		targetHighscore = record.score;

		var modBgGraphic = Paths.image('menuBGBlue');
		if (bg == null || modBgGraphic != bg.graphic)
			fadeToBg(modBgGraphic);
	}

	private function positionHighscore() {
		scoreText.x = FlxG.width - scoreText.width - 6;
		scoreBG.scale.x = FlxG.width - scoreText.x + 6;
		scoreBG.x = FlxG.width - (scoreBG.scale.x / 2);
		diffText.x = Std.int(scoreBG.x + (scoreBG.width / 2));
		diffText.x -= diffText.width / 2;
	}

	function changeDifficulty(val:Int = 0, ?isAbs:Bool)
	{
		var charts = selectedSongData.charts;
		if (charts.length == 0) return;

		if (isAbs)
			curDiffIdx = val;
		else
			curDiffIdx = FlxMath.wrap(curDiffIdx + val, 0, charts.length - 1);

		curDiffName = charts[curDiffIdx];
		diffText.text = curDiffName.toUpperCase(); //Paths.getString('freeplayDiff_$curDiffName');
	}

	function updateDifficulty(){
		var charts = selectedSongData.charts;

		if (charts.length == 0){
			diffText.text = "null"; // fuck it
			return;
		}

		if (!charts.contains(curDiffName)){
			var idx = charts.indexOf("normal");
			if (idx == -1)
				idx = charts.indexOf("hard");
			if (idx == -1)
				idx = FlxMath.maxInt(0, curDiffIdx);

			changeDifficulty(idx, true);
		}else{
			diffText.text = curDiffName.toUpperCase(); //Paths.getString('freeplayDiff_$curDiffName');
		}
	}

	function fadeToBg(graphic){
		var prevBg = bg;

		if (bgGrp.length < 6){
			bg = bgGrp.recycle(FlxSprite);
		}else{ /// fixed size flxgroups are wack
			bg =  bgGrp.members[0];
			FlxTween.cancelTweensOf(bg);
			bg.alpha = 1.0;
			bg.revive();
		};
		bg.loadGraphic(graphic);
		bg.screenCenter();
		
		if (prevBg == null)
			return;

		bg.alpha = 0.0;
		FlxTween.tween(bg, {alpha: 1.0}, 0.4, {
			ease: FlxEase.sineInOut,
			onComplete: (_) -> prevBg.kill()
		});
		
		bgGrp.remove(bg, true);
		bgGrp.add(bg);
	}
	
	override public function update(elapsed:Float)
	{
		if (controls.UI_LEFT_P){
			changeDifficulty(-1);
		}
		if (controls.UI_RIGHT_P){
			changeDifficulty(1);
		}

		if (controls.BACK){
			menu.controls = null;
			MusicBeatState.switchState(new funkin.states.MainMenuState());	
			
		}else if (controls.RESET){
			openSubState(new funkin.states.ResetScoreSubState(selectedSongData.songName, false));
			
		}else if (FlxG.keys.justPressed.CONTROL){
			openSubState(new funkin.states.GameplayChangersSubstate());

		}

		lerpHighscore = CoolUtil.coolLerp(lerpHighscore, targetHighscore, elapsed * 12);
		scoreText.text = 'PERSONAL BEST: ${Math.round(lerpHighscore)}';

		super.update(elapsed);
	}

	override public function destroy()
	{
		lastSelected = menu.curSelected;
		
		super.destroy();
	}
}