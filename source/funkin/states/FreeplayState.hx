package funkin.states;

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

	var selectedSongData:SongMetadata;

	public static var lastSelected:Int = 0;

	override public function create()
	{
		for (week in WeekData.reloadWeekFiles())
		{
			Paths.currentModDirectory = week.directory;

			for (songName in week.songs){
				menu.addTextOption(songName).ID = songMeta.length;
				songMeta.push({songName: songName, folder: week.directory});
			}
		}

		////
		add(bgGrp);

		add(menu);
		menu.controls = controls;
		menu.callbacks.onAccept = (selectedIdx)->{
			menu.controls = null;
			Song.playSong(songMeta[selectedIdx]);	
		};
		menu.callbacks.onSelect = (selectedIdx)->{
			onSelectSong(songMeta[selectedIdx]);
		}
		menu.curSelected = lastSelected;

		////

		var textBG = CoolUtil.blankSprite(FlxG.width, 26, 0xFF999999);
		textBG.y = FlxG.height - 26;
		textBG.blend = MULTIPLY;
		add(textBG);

		var text:FlxText = new FlxText(textBG.x, textBG.y + 4, FlxG.width, Paths.getString("freeplayhint"));
		text.setFormat(Paths.font("vcr.ttf"), 16, 0xFFFFFFFF, RIGHT);
		text.scrollFactor.set();
		add(text);

		super.create();
	}

	function onSelectSong(data:SongMetadata)
	{	
		selectedSongData = data;

		Paths.currentModDirectory = data.folder;

		var modBgGraphic = Paths.image('menuBGBlue');
		if (bg == null || modBgGraphic != bg.graphic)
			fadeToBg(modBgGraphic);
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
		if (controls.BACK){
			menu.controls = null;
			MusicBeatState.switchState(new funkin.states.MainMenuState());	
			
		}else if (controls.RESET){
			openSubState(new funkin.states.ResetScoreSubState(selectedSongData.songName, false));
			
		}else if (FlxG.keys.justPressed.CONTROL){
			openSubState(new funkin.states.GameplayChangersSubstate());

		}

		super.update(elapsed);
	}

	override public function destroy()
	{
		lastSelected = menu.curSelected;
		
		super.destroy();
	}
}