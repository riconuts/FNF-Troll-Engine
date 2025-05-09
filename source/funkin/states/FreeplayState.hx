package funkin.states;

import flixel.util.FlxColor;
import funkin.objects.hud.HealthIcon;

import funkin.data.Song;
import funkin.data.BaseSong;
import funkin.data.Highscore;

import flixel.text.FlxText;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;

using StringTools;
using funkin.CoolerStringTools;

@:injectMoreFunctions([
	"onSelectSong",
	"onAccept",
	"refreshScore",
	"changeDifficulty",
	"positionHighscore"
])
class FreeplayState extends MusicBeatState
{
	public static var comingFromPlayState:Bool = false;

	var menu = new FreeplayMenu();
	var songData:Array<BaseSong> = [];

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

	var selectedSongData:BaseSong;
	var selectedSongCharts:Array<String>;
	
	var hintText:FlxText;

	public static function getFreeplaySongs():Array<BaseSong> {
		var list:Array<BaseSong> = [];
		for (directory => metadata in Paths.getContentMetadata())
		{
			var songIdList:Array<String> = [];

			inline function sowy(song:String) {
				var songId:String = Paths.formatToSongPath(song);
				if (!songIdList.contains(songId))
					songIdList.push(songId);
			}

			// metadata file week songs
			for (week in metadata.weeks) {
				if (week.hideFreeplay != true && week.songs != null) {
					for (song in week.songs)
						sowy(song);
				}
			}

			// metadata file freeplay songs
			if (metadata.freeplaySongs != null) {
				for (song in metadata.freeplaySongs)
					sowy(song.name);
			}

			//
			for (songId in songIdList) {
				list.push(new Song(songId, directory));
			}
		}
		return list;
	} 
	
	override public function create()
	{
		#if DISCORD_ALLOWED
		funkin.api.Discord.DiscordClient.changePresence('In the menus');
		#end

		songData = getFreeplaySongs();
		for (song in songData)
			menu.addSong(song);

		////
		add(bgGrp);

		add(menu);
		menu.controls = controls;
		menu.callbacks.onSelect = (selectedIdx, _) -> onSelectSong(songData[selectedIdx]);
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
		persistentUpdate = true;
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
				PlayState.loadPlaylist([selectedSongData], curDiffStr);
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

		PlayState.isStoryMode = false;

		if (FlxG.keys.pressed.SHIFT)
			LoadingState.loadAndSwitchState(new funkin.states.editors.ChartingState());
		else
			LoadingState.loadAndSwitchState(new PlayState());
	}

	function playSelectedSongMusic() {
		// load song json and play inst
		if (songLoaded != selectedSong){
			songLoaded = selectedSong;
			PlayState.loadPlaylist([selectedSongData], curDiffStr);
			
			if (PlayState.SONG != null){
				Conductor.changeBPM(PlayState.SONG.bpm);
				var instAsset = Paths.track(PlayState.SONG.song, PlayState.SONG.tracks.inst[0]);
				FlxG.sound.playMusic(instAsset, 0.6);
			}
		}
	}

	var shouldRestoreControl:Bool = false;
	inline function stun(){
		shouldRestoreControl = true;
		menu.controls = null;
	}

	override public function update(elapsed:Float)
	{
		super.update(elapsed);
		updateInput(elapsed);
	}

	function updateInput(elapsed:Float) {
		if (shouldRestoreControl){
			shouldRestoreControl = false;
			menu.controls = controls;
		}

		if (menu.controls == null)
			return;

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
			var songName:String = selectedSongData.getMetadata(curDiffStr).songName;
			var displayName:String = songName;

			if (selectedSongCharts.length > 1) {
				var diffName:String = Paths.getString('difficultyName_$curDiffStr', curDiffStr);
				displayName += ' ($diffName)';
			}

			openSubState(new ResetScoreSubState(
				selectedSongData.songId, 
				curDiffStr, 
				false, 
				displayName
			));
			menu.controls = null;
			this.subStateClosed.addOnce(function(_) {
				refreshScore();
				shouldRestoreControl = true;
			});
			
		}else if (FlxG.keys.justPressed.CONTROL){
			openSubState(new GameplayChangersSubstate());
			menu.controls = null;
			this.subStateClosed.addOnce(function(_) {
				refreshScore();
				shouldRestoreControl = true;
			});
		}
	}

	function onSelectSong(data:BaseSong)
	{	
		Paths.currentModDirectory = data.folder;

		selectedSongData = data;
		selectedSongCharts = data.getCharts();

		changeDifficulty(CoolUtil.updateDifficultyIndex(curDiffIdx, curDiffStr, selectedSongCharts), true);

		var metadata = data.getMetadata(curDiffStr);
		var bgColor:FlxColor; 
		var bgKey:String; 
		
		if (metadata.freeplayBgColor == null && metadata.freeplayBgGraphic == null) {
			bgColor = 0xFFFFFFFF;
			bgKey = 'menuBGBlue';
		}else {
			bgColor = (metadata.freeplayBgColor!=null) ? FlxColor.fromString(metadata.freeplayBgColor) : 0xFFFFFFFF;
			bgKey = metadata.freeplayBgGraphic ?? 'menuDesat';
		}

		reloadFont();
		fadeToBg(Paths.image(bgKey), bgColor);
	}

	function refreshScore()
	{
		var data = selectedSongData;
		var record = Highscore.getRecord(data.songId, curDiffStr);

		targetRating = Highscore.getRatingRecord(record) * 100;
		if(ClientPrefs.showWifeScore)
			targetHighscore = record.accuracyScore * 100;
		else
			targetHighscore = record.score;
	}

	static function makeBgSprite(){
		var spr = new FlxSprite();
		spr.active = false;
		spr.moves = false;
		return spr;
	}

	function fadeToBg(graphic, color:FlxColor) {
		if (bg != null && bg.graphic == graphic && bg.color == color)
			return;

		// HORRIBLE BUT COOL I HOPE

		var prevBg = bg;
		
		if (bgGrp.members.length > 4) {
			bg = bgGrp.members[0];
			bg.exists = true;
			FlxTween.cancelTweensOf(bg);

			var sowy = bgGrp.members[1];
			sowy.alpha = 1.0;
			FlxTween.cancelTweensOf(sowy);
		}else {
			bg = bgGrp.recycle(FlxSprite, makeBgSprite);
		}
		bgGrp.members.remove(bg);
		bgGrp.members.push(bg);
		
		bg.loadGraphic(graphic);
		bg.screenCenter();
		bg.color = color;
		bg.alpha = 1.0;

		if (prevBg != null) {
			bg.alpha = 0.0;
			FlxTween.tween(bg, {alpha: 1.0}, 0.4, {ease: FlxEase.sineInOut});
		}
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

private class FreeplayMenu extends AlphabetMenu
{
	var iconGrp = new FlxTypedGroup<FreeplayIcon>();

	public function addSong(song:BaseSong) {
		var metadata = song.getMetadata();
		var songName:String = metadata.songName;
		var iconId:Null<String> = metadata.freeplayIcon;

		var obj:Alphabet = this.addTextOption(songName);

		if (iconId == null)
			return;

		#if shit_fuckign_worked // wtf why isn't alphabet doing this
		var minX = obj.x;
		var maxX = obj.x;
		var minY = obj.y;
		var maxY = obj.y;
		for (obj in obj.members) {
			minX = Math.min(minX, obj.x);
			maxX = Math.max(maxX, obj.x + obj.width);
			minY = Math.min(minY, obj.y);
			maxY = Math.max(maxY, obj.y + obj.height);
		}
		var width = maxX - minX;
		var height = maxY - minY;
		#else
		var width = obj.width;
		var height = obj.height;
		#end

		////
		var iconSpr = new FreeplayIcon(iconId);
		iconSpr.ID = obj.ID;
		iconSpr.tracking = obj;
		iconSpr.offX = width + 15;
		iconSpr.offY = height / 2 - iconSpr.height / 2;
		iconGrp.add(iconSpr);
	}

	override function update(elapsed:Float) {
		super.update(elapsed);
		iconGrp.update(elapsed);
	}

	override function draw() {
		super.draw();
		iconGrp.draw();
	}
}

private class FreeplayIcon extends HealthIcon
{
	public var tracking:FlxSprite = null;
	public var offX:Float = 0;
	public var offY:Float = 0;

	override public function update(elapsed:Float)
	{
		if (tracking != null){
			x = tracking.x + offX;
			y = tracking.y + offY;
			alpha = tracking.alpha;
		}
		super.update(elapsed);
	}
}