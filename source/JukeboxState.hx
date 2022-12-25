package;

import FreeplayState;
import sowy.*;
import flixel.system.FlxSound;

class JukeboxState extends MusicBeatState
{
	static var voices = new FlxSound();
	var hasVoices:Bool = false; 

	var image:FlxSprite;

	var options:Array<JukeboxSongText> = [];
	var curOption:JukeboxSongText;
	var curSelected:Int = 0;

    override function create(){
		div = new FlxSprite().makeGraphic(6, FlxG.height, 0xFFFFFF00);
		div.screenCenter(X);
		div.x -= FlxG.width / 6;
		add(div);

		image = new FlxSprite().makeGraphic(194, 194);
		image.screenCenter();
		image.x += FlxG.width / 5 * 1;
		add(image);

		//// Load the songs!!!
		addSong(new JukeboxSongData()).text = "Title Screen";

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
					addSong(new JukeboxSongData(song[0]), mod);
				}
			}
		}
		Paths.currentModDirectory = '';
		#end

        super.create();

		curOption = options[0];
		changeSelection();

		/*
		var sowy = new Alphabet(0, 0, "SOWY", true);
		sowy.angularVelocity = 90;
		add(sowy);
		*/

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

		/* frame width is not accurate to what is being displayed or im stupid
		var textLimit = div.x - 20;
		if (button.frameWidth > textLimit){
			button.scale.x = textLimit / button.frameWidth;
			button.updateHitbox();
		}
		*/
		
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

    override function update(e)
	{
		////
		Conductor.songPosition = FlxG.sound.music.time;
		
		if (hasVoices){
			if (Math.abs(voices.time - Conductor.songPosition) > 20){
				voices.pause();
				voices.time = Conductor.songPosition;
				voices.play();
			}

			if (FlxG.keys.justPressed.M)
				voices.volume = voices.volume == 0 ? 1 : 0;
		}

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

    public function playSong()
    {
		var songData = curOption.songData;
		var songName = songData.name;

		Paths.currentModDirectory = songData.dir;

		if (songName == null) 
		{
			hasVoices = false;
			voices.pause();
			
			MusicBeatState.playMenuMusic();
			Conductor.changeBPM(180);
			
			return;
		}	
		
		image.loadGraphic(FreeplayState.songImage(songName));

		FlxG.sound.playMusic(Paths.inst(songName), 1, true);
		
		var prevVol = voices.volume; // fuck 
		voices.loadEmbedded(Paths.voices(songName), true, false).play();
		voices.volume = prevVol;

		hasVoices = true;
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

	public function new(?Name:String, Directory:String = "")
	{
		name = Name;
		dir = Directory;
	}
}