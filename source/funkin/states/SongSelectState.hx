package funkin.states;

import flixel.addons.transition.FlxTransitionableState;
import funkin.data.Highscore;
import flixel.text.FlxText;
import funkin.data.Song;
import funkin.states.options.OptionsState;
import funkin.states.editors.MasterEditorMenu;

#if DISCORD_ALLOWED
import funkin.api.Discord.DiscordClient;
#end

#if sys
import sys.io.File;
import sys.FileSystem;
#end

using StringTools;

/**
	Barebones menu that shows a list of every available song and chart
	Not meant to be a Freeplay menu!!! Just here as a placeholder and song select menu for quick testing
**/
class SongSelectState extends MusicBeatState
{	
	var songMeta:Array<Song>;
	var songText:Array<FlxText> = [];
	var curSel(default, set):Int;
	function set_curSel(sowy){
		if (songMeta.length == 0)
			return curSel = 0;

		if (sowy < 0 || sowy >= songMeta.length)
			sowy = sowy % songMeta.length;
		if (sowy < 0)
			sowy = songMeta.length + sowy;
		
		////
		var prevText = songText[curSel];
		if (prevText != null)
			prevText.color = 0xFFFFFFFF;

		var selText = songText[sowy];
		if (selText != null)
			selText.color = 0xFFFFFF00;

		////
		curSel = sowy;
		return curSel;
	}
	

	var verticalLimit:Int;

	public static function getEverySong():Array<Song>
	{
		var songMeta = [];

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

	override public function create() 
	{
		FlxTransitionableState.skipNextTransIn = true;
		FlxTransitionableState.skipNextTransOut = true;
		this.persistentDraw = false;
		super.create();

		#if DISCORD_ALLOWED
		DiscordClient.changePresence("In the Menus", null);
		#end
		FlxG.camera.bgColor = 0xFF000000;
		////
		
		/*
		var bg = new FlxSprite(Paths.image("menuDesat"));
		bg.blend = INVERT;
		bg.setColorTransform(-1.75, -1.75, -1.75, 0.4, Std.int(255 + bg.color.red / 3), Std.int(255 + bg.color.green / 3), Std.int(255 + bg.color.blue / 3), 0);
		bg.screenCenter();
		add(bg);
		*/

		////
		if (FlxG.sound.music == null){
			MusicBeatState.playMenuMusic(1);
		}else{
			FlxG.sound.music.fadeIn(1.0, FlxG.sound.music.volume);
		}

		songMeta = getEverySong();

		var hPadding = 14;
		var vPadding = 24;
		var spacing = 3;
		var textSize = 16;
		var width = 16*textSize;

		var ySpace = (textSize+spacing);

		verticalLimit = Math.floor((FlxG.height - vPadding*2)/ySpace);

		for (id in 0...songMeta.length)
		{
			var text = new FlxText(
				hPadding + (Math.floor(id/verticalLimit) * width), 
				vPadding + (ySpace*(id%verticalLimit)), 
				width, 
				songMeta[id].songId,
				textSize
			);
			text.wordWrap = false;
			text.antialiasing = false;
			songText.push(text);
			add(text);
		}

		curSel = 0;

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
				curSel += speed;
				ySecsHolding = 0;
			}
			if (controls.UI_UP_P){
				curSel -= speed;
				ySecsHolding = 0;
			}

			var checkLastHold:Int = Math.floor((ySecsHolding - 0.5) * 10);
			ySecsHolding += e;
			var checkNewHold:Int = Math.floor((ySecsHolding - 0.5) * 10);

			if(ySecsHolding > 0.35 && checkNewHold - checkLastHold > 0)
				curSel += (checkNewHold - checkLastHold) * (controls.UI_UP ? -1 : 1) * speed;
		}

		if (controls.UI_LEFT || controls.UI_RIGHT){
			if (controls.UI_RIGHT_P){
				curSel += verticalLimit;
				ySecsHolding = 0;
			}
			if (controls.UI_LEFT_P){
				curSel -= verticalLimit;
				ySecsHolding = 0;
			}

			var checkLastHold:Int = Math.floor((ySecsHolding - 0.5) * 10);
			ySecsHolding += e;
			var checkNewHold:Int = Math.floor((ySecsHolding - 0.5) * 10);

			if(ySecsHolding > 0.35 && checkNewHold - checkLastHold > 0)
				curSel += (checkNewHold - checkLastHold) * (controls.UI_LEFT_P ? -1 : 1) * verticalLimit;
		}

		if (FlxG.keys.pressed.CONTROL)
		{
			openSubState(new GameplayChangersSubstate());
		}

		if (controls.ACCEPT){
			var charts = songMeta[curSel].getCharts();
			if (charts.length > 0) {
				trace(charts);
				openSubState(new ChartSelectSubstate(songMeta[curSel], charts));
			}else {
				trace("no charts!");
				songText[curSel].alpha = 0.6;
			}
		}
		else if (controls.BACK)
			MusicBeatState.switchState(new MainMenuState());
		else if (FlxG.keys.justPressed.SEVEN)
			MusicBeatState.switchState(new MasterEditorMenu());
		else if (FlxG.keys.justPressed.SIX)
			MusicBeatState.switchState(new OptionsState());

		super.update(e);
	}
}

class ChartSelectSubstate extends MusicBeatSubstate
{
	var song:Song;
	var charts:Array<String>;

	var curSel:Int = 0;

	var chartTxts:Array<FlxText> = [];
	var scoreTxts:Array<FlxText> = [];

	public function new(song:Song, ?charts:Array<String>) 
	{
		super();
		this.song = song;
		this.charts = charts ?? song.getCharts();
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
		chartTxts[curSel].color = 0xFFFFFFFF;
		curSel = CoolUtil.updateIndex(curSel, diff, chartTxts.length);
		chartTxts[curSel].color = 0xFFFFFF00;
	}

	override public function update(e){
		if (FlxG.keys.justPressed.UP || FlxG.keys.justPressed.W)
			changeSel(-1);
		if (FlxG.keys.justPressed.DOWN || FlxG.keys.justPressed.S)
			changeSel(1);

		if (FlxG.keys.justPressed.R) {
			openSubState(new ResetScoreSubState(
				song.songId,
				charts[curSel],
				false
			));
			this.subStateClosed.addOnce((_) -> {
				scoreTxts[curSel].text = Std.string(Highscore.getScore(song.songId, charts[curSel]));
			});
		}
		else if (FlxG.keys.justPressed.BACKSPACE || FlxG.keys.justPressed.ESCAPE)
			this.close();
		else if (FlxG.keys.justPressed.ENTER) {
			PlayState.loadPlaylist([song], charts[curSel]);

			if (FlxG.keys.pressed.SHIFT)
				LoadingState.loadAndSwitchState(new funkin.states.editors.ChartingState());
			else
				LoadingState.loadAndSwitchState(new PlayState());
		}

		super.update(e);
	} 
}