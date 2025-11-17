package funkin.states;

import funkin.states.options.OptionsSubstate;
import flixel.addons.transition.FlxTransitionableState;
import flixel.text.FlxText;
import funkin.data.Song;
import funkin.data.BaseSong;
import funkin.data.Highscore;
import funkin.states.options.OptionsState;
import funkin.states.editors.MasterEditorMenu;

#if DISCORD_ALLOWED
import funkin.api.Discord.DiscordClient;
#end

using StringTools;

/**
	Barebones menu that shows a list of every available song and chart
	Not meant to be a Freeplay menu!!! Just here as a placeholder and song select menu for quick testing
**/
class SongSelectState extends MusicBeatSubstate
{	
	public var songs:Array<BaseSong> = null;
	
	var songTexts:Array<FlxText> = [];
	var folderTexts:Array<FlxText> = [];

	public var curSelected(default, set):Int = 0;
	var curTextIdx:Int = -1;

	public static function getEverySong():Array<BaseSong>
	{
		var songMeta:Array<BaseSong> = [];

		var folder = 'assets/songs/';
		Paths.iterateDirectory(folder, function(name:String){
			trace(name);
			if (Paths.isDirectory(folder + name))
				songMeta.push(new Song(name));
		});

		#if MODS_ALLOWED
		for (modDir in Paths.getModDirectories()){
			var folder = Paths.mods('$modDir/songs/');
			Paths.iterateDirectory(folder, function(name:String){
				if (Paths.isDirectory(folder + name))
					songMeta.push(new Song(name, modDir));
			});
		}
		#end

		return songMeta;
	}

	var cam:FlxCamera = null;

	override public function create() 
	{
		FlxTransitionableState.skipNextTransIn = true;
		FlxTransitionableState.skipNextTransOut = true;
		this.persistentDraw = false;
		this.persistentUpdate = false;
		super.create();

		#if DISCORD_ALLOWED
		DiscordClient.changePresence({details: "In the Menus"});
		#end
		////
		
		/*
		var bg = new FlxSprite(Paths.image("menuDesat"));
		bg.blend = INVERT;
		bg.setColorTransform(-1.75, -1.75, -1.75, 0.4, Std.int(255 + bg.color.red / 3), Std.int(255 + bg.color.green / 3), Std.int(255 + bg.color.blue / 3), 0);
		bg.screenCenter();
		add(bg);
		*/

		////
		if (_parentState == null) {
			if (FlxG.sound.music == null){
				MusicBeatState.playMenuMusic(1);
			}else{
				FlxG.sound.music.fadeIn(1.0, FlxG.sound.music.volume);
			}
		}else {
			cam = new FlxCamera();
			cam.bgColor = 0;
			FlxG.cameras.add(cam, false);
			this.camera = cam;
			if (this._bgSprite != null)
				this._bgSprite._cameras = this._cameras;
		}

		songs ??= getEverySong();

		var hPadding = 64;
		var vPadding = 64;
		var spacing = 4; // space between texts
		var width = (FlxG.width - hPadding - hPadding);
		var height = (FlxG.height - vPadding - vPadding);
		var textSize = 16;

		var ySpace = (textSize+spacing);
		var width = Math.ceil(width / 2);
		var txts = Math.floor(height / ySpace);

		for (i in 0...txts)
		{
			var text = new FlxText(
				hPadding, 
				vPadding + (ySpace * i), 
				width, 
				"" + i,
				textSize
			);
			text.wordWrap = false;
			text.antialiasing = false;
			songTexts.push(text);
			add(text);

			var text = new FlxText(
				hPadding + width, 
				vPadding + (ySpace * i), 
				width, 
				"" + i,
				textSize
			);
			text.wordWrap = false;
			text.antialiasing = false;
			folderTexts.push(text);
			add(text);
		}

		curSelected = curSelected;

		var versionTxt = new FlxText(0, 0, 0, Main.Version.displayedVersion, 12);
		versionTxt.setPosition(FlxG.width - 2 - versionTxt.width, FlxG.height - 2 - versionTxt.height);
		versionTxt.alpha = 0.6;
		versionTxt.antialiasing = false;
		add(versionTxt);
	}

	var xSecsHolding = 0.0;
	var ySecsHolding = 0.0; 

	override public function update(e)
	{
		var speed = 1;

		if (controls.UI_UP || controls.UI_DOWN){
			if (controls.UI_DOWN_P){
				curSelected += speed;
				ySecsHolding = 0;
			}
			if (controls.UI_UP_P){
				curSelected -= speed;
				ySecsHolding = 0;
			}

			var checkLastHold:Int = Math.floor((ySecsHolding - 0.5) * 10);
			ySecsHolding += e;
			var checkNewHold:Int = Math.floor((ySecsHolding - 0.5) * 10);

			if(ySecsHolding > 0.35 && checkNewHold - checkLastHold > 0)
				curSelected += (checkNewHold - checkLastHold) * (controls.UI_UP ? -1 : 1) * speed;
		}

		if (FlxG.keys.pressed.CONTROL)
		{
			openSubState(new GameplayChangersSubstate());
		}

		if (FlxG.keys.justPressed.SIX)
		{
			var ss = new OptionsSubstate();
			ss.goBack = (_) -> ss.close();
			openSubState(ss);
		}

		if (controls.ACCEPT) 
		{
			var charts = songs[curSelected].getCharts();
			if (charts.length > 0) {
				trace(charts);
				var ss = new ChartSelectSubstate(songs[curSelected], charts, onSelectChart);
				ss.cameras = cameras;
				openSubState(ss);
			}else {
				trace("no charts!");
				songTexts[curTextIdx].color = 0xFFFF0000;
			}
		}

		if (controls.BACK) 
		{
			goBack();
		}

		super.update(e);
	}

	function set_curSelected(newIdx:Int){
		if (songs.length == 0)
			return curSelected = 0;

		if (newIdx < 0 || newIdx >= songs.length)
			newIdx = newIdx % songs.length;
		if (newIdx < 0)
			newIdx = songs.length + newIdx;

		////
		var listEndIdx = Math.round(newIdx + songTexts.length / 2);
		if (listEndIdx > songs.length) listEndIdx = songs.length;
		
		var listStartIdx = listEndIdx - songTexts.length;
		if (listStartIdx < 0) listStartIdx = 0;

		//trace(listStartIdx, newIdx, listEndIdx, songTexts.length);

		for (i in 0...songTexts.length) {
			var songIdx = listStartIdx + i;
			var song = songs[songIdx];
			var songText = songTexts[i];
			var folderText = folderTexts[i];
			
			songText.text = song.songId;
			folderText.text = song.folder;
			songText.color = folderText.color = (songIdx == newIdx) ? 0xFFFFFF00 : 0xFFFFFFFF;
			if (songIdx == newIdx) curTextIdx = i;
		}

		////
		curSelected = newIdx;
		return curSelected;
	}
	
	dynamic public function onSelectChart(song:BaseSong, chart:String) {
		PlayState.loadPlaylist([song], chart);
		PlayState.isStoryMode = false;

		if (FlxG.keys.pressed.SHIFT)
			LoadingState.loadAndSwitchState(new funkin.states.editors.ChartingState());
		else
			LoadingState.loadAndSwitchState(new PlayState());
	}

	dynamic public function goBack() {
		if (_parentState == null)
			MusicBeatState.switchState(new MasterEditorMenu());
		else
			close();
	}

	override function destroy() {
		super.destroy();
		if (cam != null)
			FlxG.cameras.remove(cam);
	}
}

class ChartSelectSubstate extends MusicBeatSubstate
{
	var song:BaseSong;
	var charts:Array<String>;

	var curSelected:Int = 0;

	var chartTxts:Array<FlxText> = [];
	var scoreTxts:Array<FlxText> = [];

	public var onSelect:(BaseSong, String) -> Void;

	public function new(song:BaseSong, ?charts:Array<String>, ?onSelect:(BaseSong, String) -> Void)
	{
		super();
		this.song = song;
		this.charts = charts ?? song.getCharts();
		this.onSelect = onSelect ?? (_, _) -> close();
	}

	override function create()
	{
		var songTxt = new FlxText(0, 5, FlxG.width, song.songId);
		songTxt.setFormat(null, 20, 0xFFFFFFFF, CENTER);
		add(songTxt);

		var y = songTxt.y + songTxt.height + 20;
		var spacing = 20;
		
		for (idx => chartId in charts) {
			var y = y + idx * spacing;
			var w2 = FlxG.width / 2;

			var text = new FlxText(-10, y, w2, chartId, 16);
			text.alignment = RIGHT;
			chartTxts[idx] = text;
			add(text);

			var scoreTxt = new FlxText(w2 + 10, text.y, w2, Std.string(Highscore.getScore(song.songId, chartId)), 16);
			scoreTxt.alignment = LEFT;
			scoreTxts[idx] = scoreTxt;
			add(scoreTxt);
		}

		changeSel();
	}

	function changeSel(diff:Int = 0)
	{
		chartTxts[curSelected].color = 0xFFFFFFFF;
		curSelected = CoolUtil.updateIndex(curSelected, diff, chartTxts.length);
		chartTxts[curSelected].color = 0xFFFFFF00;
	}

	override public function update(e){
		if (FlxG.keys.justPressed.UP || FlxG.keys.justPressed.W)
			changeSel(-1);
		if (FlxG.keys.justPressed.DOWN || FlxG.keys.justPressed.S)
			changeSel(1);

		if (FlxG.keys.justPressed.R) {
			openSubState(new ResetScoreSubState(
				song.songId,
				charts[curSelected],
				false
			));
			this.subStateClosed.addOnce((_) -> {
				scoreTxts[curSelected].text = Std.string(Highscore.getScore(song.songId, charts[curSelected]));
			});
		}
		else if (FlxG.keys.justPressed.BACKSPACE || FlxG.keys.justPressed.ESCAPE)
			this.close();
		else if (FlxG.keys.justPressed.ENTER) {
			onSelect(song, charts[curSelected]);
		}

		super.update(e);
	} 
}