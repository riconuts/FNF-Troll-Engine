package funkin.states;

import funkin.input.InputFormatter;
import flixel.util.FlxColor;
import funkin.objects.hud.HealthIcon;

import sys.FileSystem;
import funkin.data.Song;
import funkin.data.BaseSong;
import funkin.data.Level;
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

	var menu:FreeplayMenu;
	var songList:Array<BaseSong>;

	var bgGrp = new FlxTypedGroup<FlxSprite>();
	var bg:FlxSprite;

	var targetHighscore:Float = 0.0;
	var lerpHighscore:Float = 0.0;

	var targetRating:Float = 0.0;
	var lerpRating:Float = 0.0;
	var fcDisplay:String = '';

	var scoreBG:FlxSprite;
	var scoreText:FlxText;
	var diffText:FlxText;

	static var lastSelectedIdx:Int = 0;
	static var lastSelectedChart:String = "normal";

	var curChartId:String = "";
	var curChartIdx:Int = -1;

	var selectedSongData:BaseSong;
	var selectedSongCharts:Array<String>;
	
	var hintBG:FlxSprite;
	var hintText:FlxText;

	public static function getFreeplaySongs():Array<BaseSong> {
		var list:Array<BaseSong> = [];
		for (contentId => metadata in Paths.getContentMetadata())
		{
			var songIdMap:Map<String, Bool> = [];

			inline function sowy(songId:String) {
				// weird old tgt shit
				var splitted:Array<String> = songId.split(":");
				if (splitted.length > 1)
					songId = splitted[0];
				
				if (!songIdMap.exists(songId)) {
					songIdMap.set(songId, true);
					list.push(new Song(songId, contentId));
				}
			}

			//// level songs
			for (level in StoryModeState.scanContentLevels(contentId)) {
				if (!level.isUnlocked())
					continue;
				
				for (song in level.getFreeplaySongs()) {
					songIdMap.set(song.songId, true);
					list.push(song);
				}
			}

			// metadata file freeplay songs
			if (metadata.freeplaySongs != null) {
				for (songId in metadata.freeplaySongs)
					sowy(songId);
			}

			// freeplaySonglist.txt
			var rawList:Null<String> = Paths.getContent(Paths._modPath('data/freeplaySonglist.txt', contentId));
			if (rawList != null) {
				for (songId in CoolUtil.listFromString(rawList))
					sowy(songId);
			}
			
			// default category shit
			// should prob just make a autoAddToFreeplay bool or sum shit idk lol
			if (metadata.defaultCategory != null && metadata.defaultCategory.length > 0){
				var dir = Paths.mods(contentId + "/songs");

				Paths.iterateDirectory(dir, function(file:String) {
					if (FileSystem.isDirectory(haxe.io.Path.join([dir, file]))) {
						sowy(file);
					}
					
				});

			}
		}

		#if USING_MOONCHART
		var time = Sys.time();
		funkin.data.Moonchart.MoonchartContent.scanSongs();
		time = Sys.time() - time;
		var moonchartSongs = funkin.data.Moonchart.MoonchartContent.freeplaySongs;
		print('Moonchart song scan took $time seconds, found ${moonchartSongs.length}');
		for (song in moonchartSongs) {
			list.push(song);
		}
		#end

		return list;
	} 

	public function new(?songList:Array<BaseSong>) {
		this.songList = songList;
		super();
	}
	
	override public function create()
	{
		#if DISCORD_ALLOWED
		funkin.api.Discord.DiscordClient.changePresence({details: "In the Menus"});
		#end

		songList ??= getFreeplaySongs();

		////
		add(bgGrp);

		menu = new FreeplayMenu();
		menu.controls = controls;
		menu.callbacks.onSelect = (selectedIdx, _) -> onSelectSong(menu.songList[selectedIdx]);
		menu.callbacks.onAccept = (_, _) -> onAccept();
		add(menu);

		////
		var hintStr = "";
		hintStr += '[R] ${Paths.getString('action_resetScore') ?? 'action_resetScore'}';
		//InputFormatter.getKeyName(controls.getFirstBind('reset'));
		hintStr += '\n';
		hintStr += '[CTRL] ${Paths.getString('action_openGameplayChangers') ?? 'action_openGameplayChangers'}';
		hintStr += '\n';
		hintStr += '[SPACE] ${Paths.getString('action_listenToSong') ?? 'action_listenToSong'}';

		hintText = new FlxText(16, 16, 0, hintStr);
		hintText.setFormat(Paths.font("vcr.ttf"), 16, 0xFFFFFFFF, LEFT);
		hintText.setBorderStyle(OUTLINE, 0xFF000000, 1);
		hintText.scrollFactor.set();
		hintText.drawFrame();
		hintText.y = FlxG.height - hintText.height - hintText.y;

		hintBG = CoolUtil.blankSprite(hintText.width + 8, hintText.height, 0xFF666666);
		hintBG.setPosition(hintText.x, hintText.y);
		hintBG.setGraphicSize(hintBG.width + 8, hintBG.height + 8);
		hintBG.blend = MULTIPLY;

		add(hintBG);
		add(hintText);

		////
		scoreText = new FlxText(FlxG.width * 0.7, 5, 0);
		scoreText.setFormat(Paths.font("vcr.ttf"), 28, 0xFFFFFFFF, RIGHT);

		scoreBG = CoolUtil.blankSprite(FlxG.width * 0.3, 66, 0xFF666666);
		scoreBG.setPosition(scoreText.x - 6, 0);
		scoreBG.blend = MULTIPLY;
		add(scoreBG);

		diffText = new FlxText(scoreText.x, scoreText.y + 36, 100, "", 22);
		diffText.alignment = CENTER;
		diffText.font = scoreText.font;
		add(diffText);

		add(scoreText);

		////
		menu.setSongList(songList);
		curChartId = FreeplayState.lastSelectedChart;
		menu.curSelected = FreeplayState.lastSelectedIdx;
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
				PlayState.loadPlaylist([selectedSongData], curChartId);
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
			PlayState.loadPlaylist([selectedSongData], curChartId);
			
			if (PlayState.SONG != null){
				Conductor.changeBPM(PlayState.SONG.bpm);
				var instAsset = selectedSongData.getTrackSound(PlayState.SONG.tracks.inst[0]);
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
		updateInput(elapsed);
		super.update(elapsed);
	}

	function updateInput(elapsed:Float) {
		if (shouldRestoreControl){
			shouldRestoreControl = false;
			menu.controls = controls;
		}

		hintBG.exists = hintText.exists = menu.controls != null;

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
			
		}else if (FlxG.keys.justPressed.R){
			openResetScorePrompt();
			
		}else if (FlxG.keys.justPressed.CONTROL){
			openGameplayChangersMenu();
		}
	}

	function openResetScorePrompt() {
		var songName:String = selectedSongData.getMetadata(curChartId).songName;
		var displayName:String = songName;
		persistentUpdate = false;

		if (selectedSongCharts.length > 1) {
			var diffName:String = Paths.getString('difficultyName_$curChartId') ?? curChartId;
			displayName += ' ($diffName)';
		}

		openSubState(new ResetScoreSubState(
			selectedSongData.songId, 
			curChartId, 
			false, 
			displayName
		));
		menu.controls = null;
		this.subStateClosed.addOnce(function(_) {
			refreshScore();
			shouldRestoreControl = true;
		});
	}

	function openGameplayChangersMenu() {
		persistentUpdate = false;
		openSubState(new GameplayChangersSubstate());
		menu.controls = null;
		this.subStateClosed.addOnce(function(_) {
			refreshScore();
			shouldRestoreControl = true;
		});
	}

	function onSelectSong(data:BaseSong)
	{	
		Paths.currentModDirectory = data.folder;

		selectedSongData = data;
		selectedSongCharts = data.getCharts();

		changeDifficulty(CoolUtil.updateDifficultyIndex(curChartIdx, curChartId, selectedSongCharts), true);

		var metadata = data.getMetadata(curChartId);
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
		var record = Highscore.getRecord(data.songId, curChartId);

		targetRating = Highscore.getRatingRecord(record) * 100;
		if(ClientPrefs.showWifeScore)
			targetHighscore = record.accuracyScore * 100;
		else
			targetHighscore = record.score;

		fcDisplay = switch(record.fcMedal) {
			case TIER4: 't5fc';
			case TIER3: 't4fc';
			case TIER2: 't3fc';
			case TIER1: 'fc';
			default: '';
		}
		fcDisplay = fcDisplay.length==0 ? fcDisplay : '${Paths.getString(fcDisplay) ?? fcDisplay}';
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
				curChartId = charts[0];
				diffText.text = (Paths.getString('difficultyName_$curChartId') ?? curChartId).toUpperCase();

			default:
				curChartIdx = isAbs ? val : FlxMath.wrap(curChartIdx + val, 0, charts.length - 1);
				curChartId = charts[curChartIdx];
				diffText.text = "< " + (Paths.getString('difficultyName_$curChartId') ?? curChartId).toUpperCase() + " >";
		}

		selectedSong = '$selectedSongData-$curChartId';
		refreshScore();
	}

	override function draw()
	{
		lerpHighscore = CoolUtil.coolLerp(lerpHighscore, targetHighscore, FlxG.elapsed * 12);
		lerpRating = CoolUtil.coolLerp(lerpRating, targetRating, FlxG.elapsed * 8);

		final score = Math.round(lerpHighscore);
		final rating = formatRating(lerpRating);
		final fcDisplay = (fcDisplay.length==0 ? fcDisplay : ' • [$fcDisplay]');

		scoreText.text = 'PERSONAL BEST • $score • ($rating%)' + fcDisplay;
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
		if (menu != null) {
			lastSelectedIdx = menu.curSelected;
			lastSelectedChart = curChartId;
		}
		
		super.destroy();
	}
}

private class FreeplayMenu extends AlphabetMenu
{
	public var songList(default, null):Array<BaseSong> = [];

	private var iconGrp = new FlxTypedGroup<FreeplayIcon>();

	public function setSongList(songs:Array<BaseSong>) {
		this.clear();
		this.songList = songs;
		for (song in songList)
			addSong(song);
	}

	public function addSong(song:BaseSong) {
		var metadata = song.getMetadata();
		var songName:String = metadata.songName;
		var iconId:Null<String> = metadata.freeplayIcon;

		Paths.currentModDirectory = song.folder;

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
		var iconSpr = iconGrp.getFirstAvailable(FreeplayIcon, true) ?? {
			var obj = new FreeplayIcon(iconId);
			obj.exists = true;
			iconGrp.add(obj);
		};
		
		if (!iconSpr.exists) {
			iconSpr.changeIcon(iconId);
			iconSpr.revive();
		}
		
		iconSpr.ID = obj.ID;
		iconSpr.tracking = obj;
		iconSpr.offX = width + 15;
		iconSpr.offY = height / 2 - iconSpr.height / 2;
	}

	override function onSelect(item:Alphabet) {
		super.onSelect(item);
	}

	override public function clear() {
		iconGrp.killMembers();
		super.clear();
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