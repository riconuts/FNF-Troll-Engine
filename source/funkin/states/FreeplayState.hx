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
	public static var comingFromPlayState:Bool = false;

	var menu = new AlphabetMenu();
	var songMeta:Array<SongMetadata> = [];

	var bgGrp = new FlxTypedGroup<FlxSprite>();
	var bg:FlxSprite;

	var targetHighscore:Float = 0.0;
	var lerpHighscore:Float = 0.0;

	var targetRating:Float = 0.0;
	var lerpRating:Float = 0.0;

	var scoreBG:FlxSprite;
	var scoreText:FlxText;
	var diffText:FlxText;

	static var lastSelected:Int = 0;
	static var curDiffStr:String = "normal";
	static var curDiffIdx:Int = 1;

	var selectedSongData:SongMetadata;
	var selectedSongCharts:Array<String>;
	
	var hintText:FlxText;
	
	override public function create()
	{
		#if DISCORD_ALLOWED
		funkin.api.Discord.DiscordClient.changePresence('In the menus');
		#end

		for (week in WeekData.reloadWeekFiles(true))
		{
			Paths.currentModDirectory = week.directory;

			if (week.songs == null)
				continue;

			for (songName in week.songs){
				var metadata:SongMetadata = {songName: songName, folder: week.directory, difficulties: week.difficulties != null ? week.difficulties : []};
				
				/*
				if (metadata.charts.length == 0){
					trace('${week.directory}: $songName doesn\'t have any available charts!');
					continue;
				}
				*/
				
				menu.addTextOption(songName).ID = songMeta.length;
				songMeta.push(metadata);
			}
		}

		////
		add(bgGrp);

		add(menu);
		menu.controls = controls;
		menu.callbacks.onSelect = (selectedIdx, _) -> onSelectSong(songMeta[selectedIdx]);
		menu.callbacks.onAccept = (_, _) -> onAccept();

		////
		var hintBG = CoolUtil.blankSprite(FlxG.width, 26, 0xFF999999);
		hintBG.y = FlxG.height - 26;
		hintBG.blend = MULTIPLY;
		add(hintBG);

		hintText = new FlxText(hintBG.x, hintBG.y + 4, FlxG.width, Paths.getString("freeplayhint"));
		hintText.setFormat(Paths.font("vcr.ttf"), 16, 0xFFFFFFFF, RIGHT);
		hintText.scrollFactor.set();
		add(hintText);

		////
		scoreText = new FlxText(FlxG.width * 0.7, 5, 0, 'PERSONAL BEST: 0', 32);
		scoreText.setFormat(Paths.font("vcr.ttf"), 32, 0xFFFFFFFF, RIGHT);

		scoreBG = CoolUtil.blankSprite(FlxG.width * 0.3, 66, 0xFF999999);
		scoreBG.setPosition(scoreText.x - 6, 0);
		scoreBG.blend = MULTIPLY;
		add(scoreBG);

		diffText = new FlxText(scoreText.x, scoreText.y + 36, 100, "", 24);
		diffText.alignment = CENTER;
		diffText.font = scoreText.font;
		add(diffText);

		add(scoreText);

		////
		menu.curSelected = lastSelected;
		if (comingFromPlayState) playSelectedSongMusic();

		super.create();
		comingFromPlayState = false;
	}

	function reloadFont(){
		scoreText.font = Paths.font("vcr.ttf");
		hintText.font = scoreText.font;
		diffText.font = scoreText.font;
	}

	var songLoaded:String = null;
	var selectedSong:String = null;
	function onAccept() {
		var proceed:Bool = false;
		
		if (selectedSongCharts.length == 0)
			proceed = false;
		else{
			proceed = songLoaded == selectedSong && PlayState.SONG != null;
		
			if (!proceed) {
				Song.loadSong(selectedSongData, curDiffStr, curDiffIdx);
				proceed = PlayState.SONG != null;
			}
		}

		if (!proceed) {
			FlxG.sound.play(Paths.sound('cancelMenu'));
			return;
		}

		menu.controls = null;

		if (FlxG.sound.music != null)
			FlxG.sound.music.fadeOut(0.16);

		if (FlxG.keys.pressed.SHIFT)
			LoadingState.loadAndSwitchState(new funkin.states.editors.ChartingState());
		else
			LoadingState.loadAndSwitchState(new PlayState());
	}

	function playSelectedSongMusic() {
		// load song json and play inst
		if (songLoaded != selectedSong){
			songLoaded = selectedSong;
			Song.loadSong(selectedSongData, curDiffStr, curDiffIdx);
			
			if (PlayState.SONG != null){
				var instAsset = Paths.inst(PlayState.SONG.song); 
				FlxG.sound.playMusic(instAsset);
			}
		}
	}

	// disable menu class controls for one update cycle Dx 
	var stunned:Bool = false;
	inline function stun(){
		stunned = true;
		menu.controls = null;
	}

	override public function update(elapsed:Float)
	{
		if (stunned){
			stunned = false;
			menu.controls = controls;
		}

		if (controls.UI_LEFT_P){
			changeDifficulty(-1);
		}
		if (controls.UI_RIGHT_P){
			changeDifficulty(1);
		}

		if (FlxG.keys.justPressed.SPACE){
			stun();
			playSelectedSongMusic();

		}else if (controls.BACK){
			menu.controls = null;
			FlxG.sound.play(Paths.sound('cancelMenu'));
			MusicBeatState.switchState(new funkin.states.MainMenuState());	
			
		}else if (controls.RESET){
			var songName:String = selectedSongData.songName;
			var _dStrId:String = 'difficultyName_$curDiffStr';
			
			var diffName:String = Paths.getString(_dStrId, curDiffStr);
			var displayName:String = '$songName ($diffName)'; // maybe don't specify the difficulty if it's the only available one

			openSubState(new ResetScoreSubState(
				songName, 
				curDiffStr.toLowerCase() == 'normal' ? '' : curDiffStr, 
				false, 
				displayName
			));
			this.subStateClosed.addOnce((_) -> refreshScore());
			
		}else if (FlxG.keys.justPressed.CONTROL){
			openSubState(new GameplayChangersSubstate());
			this.subStateClosed.addOnce((_) -> refreshScore());
		}

		super.update(elapsed);
	}

	function onSelectSong(data:SongMetadata)
	{	
		selectedSongData = data;
		selectedSongCharts = data.charts;
		Paths.currentModDirectory = data.folder;

		changeDifficulty(getNewDiffIdx(), true);

		var modBgGraphic = Paths.image('menuBGBlue');
		reloadFont();
		if (bg == null || modBgGraphic != bg.graphic)
			fadeToBg(modBgGraphic);
	}

	function refreshScore()
	{
		var data = selectedSongData;
		var record = Highscore.getRecord(data.songName, curDiffStr.toLowerCase() == 'normal' ? '' : curDiffStr);
		targetRating = Highscore.getRatingRecord(record) * 100;
		targetHighscore = record.score;
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

	function changeDifficulty(val:Int = 0, ?isAbs:Bool)
	{
		var charts = selectedSongCharts;

		switch (charts.length){
			case 0:
				diffText.text = "NO CHARTS AVAILABLE"; // fuck it

			case 1:
				curDiffStr = charts[0];
				diffText.text = curDiffStr.toUpperCase();

			default:
				curDiffIdx = isAbs ? val : FlxMath.wrap(curDiffIdx + val, 0, charts.length - 1);
				curDiffStr = charts[curDiffIdx];
				diffText.text = "< " + curDiffStr.toUpperCase() + " >";
		}

		selectedSong = '$selectedSongData-$curDiffStr';
		refreshScore();
	}

	function getNewDiffIdx() {
		var idx = selectedSongCharts.indexOf(curDiffStr);
		if (idx != -1)
			return idx;

		idx = selectedSongCharts.indexOf("normal");
		if (idx != -1)
			return idx;

		idx = selectedSongCharts.indexOf("hard");
		if (idx != -1)
			return idx;
		
		return FlxMath.maxInt(0, curDiffIdx);
	}

	override function draw()
	{
		lerpHighscore = CoolUtil.coolLerp(lerpHighscore, targetHighscore, FlxG.elapsed * 12);
		lerpRating = CoolUtil.coolLerp(lerpRating, targetRating, FlxG.elapsed * 8);

		var score = Math.round(lerpHighscore);
		var rating = formatRating(lerpRating);

		scoreText.text = 'PERSONAL BEST: $score ($rating%)';
		positionHighscore();

		super.draw();
	}

	private static function formatRating(val:Float):String
	{
		var str = Std.string(Math.floor(val * 100.0) / 100.0);
		var dot = str.indexOf('.');

		if (dot == -1)
			return str + '.00';

		dot += 3;
		while (str.length < dot)
			str += '0';

		return str;
	}

	private function positionHighscore() {
		var bgWidth = scoreText.width + 6;

		scoreBG.x = FlxG.width - bgWidth; 
		scoreBG.scale.x = bgWidth;
		scoreBG.updateHitbox();

		diffText.x = scoreText.x = scoreBG.x + 3;

		diffText.fieldWidth = bgWidth;
	}

	override public function destroy()
	{
		lastSelected = menu.curSelected;
		
		super.destroy();
	}
}