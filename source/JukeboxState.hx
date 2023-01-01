package;

import flixel.addons.display.shapes.FlxShapeBox;
import FreeplayState;
import sowy.*;
import flixel.system.FlxSound;

class JukeboxState extends MusicBeatState
{
	static var voices = new FlxSound();
	var hasVoices:Bool = false; // does the song have voices?
	var voicesEnabled(default, set):Bool = false; // mute the voices or not?
	function set_voicesEnabled(sowy) 
	{
		voicesEnabled = sowy;
		voices.volume = sowy ? 1 : 0;
		return sowy;
	}

	var outline:FlxShapeBox;
	var image:FlxSprite;

	var options:Array<JukeboxSongText> = [];
	var curOption:JukeboxSongText;
	var curSelected:Int = 0;

    override function create()
	{
		////
		image = new FlxSprite(0, 50).makeGraphic(194, 194);
		image.scale.set(2, 2);
		image.updateHitbox();
		image.screenCenter(X);
		image.antialiasing = true;
		image.x += FlxG.width / 5 * 1;

		outline = new FlxShapeBox(
			image.x - 16, 
			image.y - 16, 
			image.width + 32, 
			image.height + 32,
			{
				thickness: 8,
				color: 0xFFFFFF00
			},
			0xFF000000
		);


		add(outline);
		add(image);

		//// Load the songs!!!
		addSong(new JukeboxSongData()).text = "Menu Theme";

		for (i in CoolUtil.coolTextFile(Paths.txt('freeplaySonglist')))
		{
			if (i != null && i.length > 0){
				var song:Array<String> = i.split(":");

				addSong(new JukeboxSongData(song[0]));
			}
		}

		#if MODS_ALLOWED
		for (mod in Paths.getModDirectories())
		{
			Paths.currentModDirectory = mod;

			for (i in CoolUtil.coolTextFile(Paths.modsTxt('freeplaySonglist')))
			{
				if (i != null && i.length > 0){
					var song:Array<String> = i.split(":");
					addSong(new JukeboxSongData(song[0], mod));
				}
			}
		}
		Paths.currentModDirectory = '';
		#end

        super.create();

		curOption = options[0];
		changeSelection();

		FlxG.autoPause = false;

		#if !FLX_NO_MOUSE
		FlxG.mouse.visible = true;
		#end
    }

	var div:FlxSprite;

	public function addSong(songData:JukeboxSongData):JukeboxSongText
	{
		var button = new JukeboxSongText(songData);
		button.setPosition(10, 48 * options.push(button));		
		button.alpha = 0.5;
		button.ID = options.length - 1;

		add(button);

		return button;
	}

	function goBack()
	{
		hasVoices = false;

		voices.volume = 0;
		voices.pause();
		voices.destroy();

		MusicBeatState.switchState(new GalleryMenuState());
	}

	/* lol fuck it dont sync shit
	function resyncVoices(){
		voices.pause();
		
		for (track in tracks)
			track.pause();

		FlxG.sound.music.play();
		Conductor.songPosition = FlxG.sound.music.time;
		voices.time = Conductor.songPosition;
		voices.play();
		
		for (track in tracks){
			track.time = Conductor.songPosition;
			track.play();
		}
	}

	override function beatHit() 
	{
		if (
			Math.abs(FlxG.sound.music.time - Conductor.songPosition) > 20
			|| 
			(hasVoices && Math.abs(voices.time - Conductor.songPosition) > 20)
		){
			resyncVoices();
		}

		super.beatHit();
	}
	*/

	var totalElapsed = 0.0;
    override function update(e:Float)
	{
		////
		Conductor.songPosition = FlxG.sound.music.time;//+= FlxG.elapsed * 1000;

		//// Keys, controls, actions and whatever.

		if (hasVoices && FlxG.keys.justPressed.M)
			voicesEnabled = !voicesEnabled;

        if (controls.BACK)
            goBack();

		if (controls.UI_UP_P)
			changeSelection(-1);

		if (controls.UI_DOWN_P)
			changeSelection(1);

		#if !FLX_NO_MOUSE
		if (FlxG.mouse.wheel != 0)
			changeSelection(FlxG.mouse.wheel);
		#end

		if (controls.ACCEPT)
			playSong();

        super.update(e);
    }

	function changeSelection(sowy:Int = 0)
	{
		curSelected += sowy;

		if (curSelected >= options.length)
			curSelected = 0;
		else if (curSelected < 0)
			curSelected = options.length - 1;

		curOption.alpha = 0.5;

		for (option in options)
			if (option.ID == curSelected)
				curOption = option;
		
		curOption.alpha = 1;
	}

	function playMenuTheme(){
		hasVoices = false;
		voices.pause();
		
		MusicBeatState.playMenuMusic();
	}

    public function playSong()
    {
		var songData = curOption.songData;
		var songName = songData.name;

		if (songName == null)
			return playMenuTheme();

		////
		Paths.currentModDirectory = songData.dir;

		songName = Paths.formatToSongPath(songName);

		//// Load assets
		var songJSON = Song.loadFromJson(songName, songName);
		var loadList = [
			{
				path: '${Paths.formatToSongPath(songName)}/Inst',
				type: 'SONG'
			},
			{
				path: 'songs/${Paths.formatToSongPath(songName)}',
				type: 'IMAGE'
			}
		];

		if (songJSON.needsVoices){
			hasVoices = true;
			loadList.push({
				path: '${Paths.formatToSongPath(songName)}/Voices',
				type: 'SONG'
			});
		}
		else{
			hasVoices = false;
		}

		Cache.loadWithList(loadList);
		
		//// Play the song!!!
		image.loadGraphic(FreeplayState.songImage(songName));

		Conductor.changeBPM(songJSON.bpm);
		Conductor.songPosition = 0;

		FlxG.sound.playMusic(Paths.inst(songName), 1, true);
		voices.pause();
		
		if (hasVoices)
			voices.loadEmbedded(Paths.voices(songName), true, false).play(FlxG.sound.music.time);
		
		voices.volume = hasVoices && voicesEnabled ? 1 : 0;

		// TODO: bpm changes, extra tracks (lol why do they exist)
	}
}

class JukeboxSongText extends flixel.text.FlxText
{
	public var songData:JukeboxSongData;

	public function new(SongData:JukeboxSongData)
	{
		songData = SongData;

		super(0, 0, 0, songData.name, 64);
		setFormat(Paths.font("calibrib.ttf"), 48, 0xFFFFFF00, LEFT);
	}
}

class JukeboxSongData{
    public var name:Null<String> = null;
	public var dir:String;

	public function new(Name:Null<String> = null, Directory:String = "")
	{
		name = Name;
		dir = Directory;
	}
}