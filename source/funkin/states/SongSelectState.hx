package funkin.states;

import flixel.text.FlxText;
import funkin.data.Song;
import funkin.states.options.OptionsState;
import funkin.states.editors.MasterEditorMenu;

#if discord_rpc
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
	var songMeta:Array<SongMetadata>;
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

	public static function getEverySong():Array<SongMetadata>
	{
		var songMeta = [];

		var folder = 'assets/songs/';
		Paths.iterateDirectory(folder, function(name:String){
			trace(name);
			if (Paths.isDirectory(folder + name))
				songMeta.push(new SongMetadata(name));
		});

		#if MODS_ALLOWED
		for (modDir in Paths.getModDirectories()){
			var folder = Paths.mods('$modDir/songs/');
			Paths.iterateDirectory(folder, function(name:String){
				if (FileSystem.isDirectory(folder + name))
					songMeta.push(new SongMetadata(name, modDir));
			});
		}
		#end

		return songMeta;
	}

	override public function create() 
	{
		StartupState.load();

		#if discord_rpc
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
				songMeta[id].songName,
				textSize
			);
			text.wordWrap = false;
			text.antialiasing = false;
			songText.push(text);
			add(text);
		}

		curSel = 0;

		var versionTxt = new FlxText(0, 0, 0, Main.displayedVersion, 12);
		versionTxt.setPosition(FlxG.width - 2 - versionTxt.width, FlxG.height - 2 - versionTxt.height);
		versionTxt.alpha = 0.6;
		versionTxt.antialiasing = false;
		add(versionTxt);

		super.create();
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
			var charts = Song.getCharts(songMeta[curSel]);

			trace(charts);
			
			if (charts.length > 1)
				MusicBeatState.switchState(new SongChartSelec(songMeta[curSel], charts));
			else if (charts.length > 0)
				Song.playSong(songMeta[curSel], charts[0], 0);
			else{
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

class SongChartSelec extends MusicBeatState
{
	var songMeta:SongMetadata;
	var alts:Array<String>;

	var texts:Array<FlxText> = [];

	var curSel = 0;

	function changeSel(diff:Int = 0)
	{
		texts[curSel].color = 0xFFFFFFFF;

		curSel += diff;
		
		if (curSel < 0)
			curSel += alts.length;
		else if (curSel >= alts.length)
			curSel -= alts.length;

		texts[curSel].color = 0xFFFFFF00;
	}

	override function create()
	{
		add(new FlxText(0, 5, FlxG.width, songMeta.songName).setFormat(null, 20, 0xFFFFFFFF, CENTER));

		for (id in 0...alts.length){
			var alt = alts[id];
			var text = new FlxText(20, 20 + id * 20 , (FlxG.width-20) / 2, alt, 16);

			// uhhh we don't save separate highscores for other chart difficulties oops
			// var scoreTxt = new FlxText(text.x + text.width, text.y, text.fieldWidth, Highscore.getScore(songMeta.songName));

			texts[id] = text;

			add(text);
		}

		changeSel();
	}

	override public function update(e){
		if (controls.UI_DOWN_P)
			changeSel(1);
		if (controls.UI_UP_P)
			changeSel(-1);

		if (controls.BACK)
			MusicBeatState.switchState(new FreeplayState());
		else if (controls.ACCEPT){
			var daDiff = alts[curSel];
			Song.playSong(songMeta, (daDiff=="normal") ? null : daDiff, curSel);
		}

		super.update(e);
	} 

	public function new(WHO:SongMetadata, alts) 
	{
		super();
		
		songMeta = WHO;
		this.alts = alts;
	}
}