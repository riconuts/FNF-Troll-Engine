package funkin.states;

import funkin.data.Song;
import funkin.data.Song.SongMetadata;
import funkin.data.WeekData;

class FreeplayState extends MusicBeatState
{
	var menu:AlphabetMenu;
	var songMeta:Array<SongMetadata> = [];

	override public function create()
	{
		var bg = new FlxSprite(Paths.image('menuBGBlue'));
		bg.screenCenter();
		add(bg);

		menu = new AlphabetMenu();
		menu.controls = controls;
		menu.callbacks.onAccept = (selectedIdx)->{
			menu.controls = null;
			Song.playSong(songMeta[selectedIdx]);	
		};
		add(menu);
		
		for (week in WeekData.reloadWeekFiles())
		{
			for (songName in week.songs){
				menu.addTextOption(songName).ID = songMeta.length;
				songMeta.push({songName: songName, folder: week.directory});
				trace("add", songName, week.directory);
			}
		}

		super.create();
	}
	
	override public function update(elapsed:Float)
	{
		if (controls.BACK){
			menu.controls = null;
			MusicBeatState.switchState(new funkin.states.MainMenuState());
		}

		super.update(elapsed);
	}
}