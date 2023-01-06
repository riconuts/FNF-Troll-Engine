package;

import flixel.util.FlxTimer;
import flixel.system.FlxSound;
import sys.FileSystem;
import flixel.tweens.FlxTween;
import flixel.text.FlxText;
import flixel.text.FlxText.FlxTextBorderStyle;
import flixel.util.FlxColor;
import flixel.addons.display.shapes.FlxShapeBox;
import flash.ui.Mouse;
import flash.ui.MouseCursor;
import flixel.FlxG;
import openfl.utils.AssetType;

using StringTools;
typedef JukeboxSongData = {
    var songName:String;
    var coverArt:String;
    var songDirectory:String;
    @:optional var chapterDir:String;
}
class JukeboxState extends MusicBeatState {
    var songData:Array<JukeboxSongData> = [];
    var outline:FlxShapeBox;
    var image:FlxSprite;
    var defImage:FlxSprite;
    var back:FlxSprite;
    var play:FlxSprite;
    var forw:FlxSprite;
	var songName:FlxText;
    
    inline function addSong(songName:String, songDir:String, ?chapter:String, ?coverArt:String)songData.push({songName: songName,songDirectory: songDir,chapterDir: chapter==null?"":chapter,coverArt: coverArt==null?'songs/$songDir':coverArt});
    // TODO: add bpm
    static var idx:Int = 0;
    public static var playIdx:Int = 0;

	override function create()
	{
        // menuTheme songDir is hard-coded to goto the playMenuMusic func
		addSong("Main Menu", "menuTheme", null, '');
		addSong("Game Over (TGT Mix)", Paths.getPath('music/gameOver.${Paths.SOUND_EXT}', SOUND), null, '');
		addSong("Breakfast (TGT Mix)", Paths.getPath('music/breakfast.${Paths.SOUND_EXT}', SOUND), null, '');
		defImage = new FlxSprite(0, 50).loadGraphic(Paths.image("jukebox/defImage"));
		defImage.antialiasing = false;

		
		image = new FlxSprite(0, 50).loadGraphic(Paths.image("jukebox/defImage"));
		image.antialiasing = false;
		outline = new FlxShapeBox(0, 33, 420, 420, {
			thickness: 8,
			color: 0xFFFFFF00
		}, 0x000000);
		outline.screenCenter(X);

		defImage.x = outline.x + 16;
        defImage.y = outline.y + 16;
		for (i in CoolUtil.coolTextFile(Paths.txt('freeplaySonglist')))
		{
			var song:String = i.split(":")[0];
			var songLowercase:String = Paths.formatToSongPath(song);
			addSong(song, songLowercase, '');
		}

		#if MODS_ALLOWED
		for (mod in Paths.getModDirectories())
		{
			Paths.currentModDirectory = mod;

			for (i in CoolUtil.coolTextFile(Paths.modsTxt('freeplaySonglist')))
			{
				var song:String = i.split(":")[0];
				var songLowercase:String = Paths.formatToSongPath(song);
                addSong(song, songLowercase, mod);
            }
        }
		Paths.currentModDirectory = '';
        #end
        // TODO: order the songs so its story > side stories > remixes

		back = new FlxSprite(0, 500).loadGraphic(Paths.image("jukebox/controls"), true, 60, 60);
        back.animation.add("back", [0], 0, true);
        back.animation.play("back", true);

		play = new FlxSprite(0 , 500).loadGraphic(Paths.image("jukebox/controls"), true, 60, 60);
		play.animation.add("play", [1], 0, true);
		play.animation.add("pause", [2], 0, true);
		play.animation.play("play", true);

        forw = new FlxSprite(0, 500).loadGraphic(Paths.image("jukebox/controls"), true, 60, 60);
		forw.animation.add("fw", [0], 0, true);
		forw.animation.play("fw", true);
		forw.flipX = true;

		songName = new FlxText(0, 475, FlxG.width, "", 32, true);
		songName.setFormat(Paths.font("calibrib.ttf"), 32, FlxColor.YELLOW, FlxTextAlign.CENTER, FlxTextBorderStyle.NONE, FlxColor.YELLOW);
		songName.scrollFactor.set(1, 1);

		songName.screenCenter(X);
		

        play.screenCenter(X);
        forw.screenCenter(X);
        back.screenCenter(X);
        back.x -= 60;
        forw.x += 60;

		add(songName);
		add(forw);
        add(back);
        add(play);
        add(outline);
		add(defImage);
        add(image);

		changeSong(idx);
        super.create();
		FlxG.autoPause = false;
    }

    override function update(elapsed:Float){
        super.update(elapsed);
        if(FlxG.mouse.overlaps(forw) || FlxG.mouse.overlaps(back) || FlxG.mouse.overlaps(play))
            Mouse.cursor = MouseCursor.BUTTON;
        else
            Mouse.cursor = MouseCursor.AUTO;

		var forward = FlxG.mouse.overlaps(forw) && FlxG.mouse.justPressed || FlxG.keys.justPressed.RIGHT;
		var bakward = FlxG.mouse.overlaps(back) && FlxG.mouse.justPressed || FlxG.keys.justPressed.LEFT;
		var resSong = FlxG.mouse.overlaps(play) && FlxG.mouse.justPressed || FlxG.keys.justPressed.SPACE;
		if (controls.BACK){
			FlxG.autoPause = true;
			MusicBeatState.switchState(new MainMenuState());
        }
		if (forward)
            changeSong(idx+1);

		if (bakward)
            changeSong(idx-1);

		if (resSong){
            if(idx==playIdx){
                if (FlxG.sound.music.fadeTween == null || FlxG.sound.music.fadeTween.finished){
                    if (FlxG.sound.music.playing){
                        FlxG.sound.music.pause();
						if (MusicBeatState.menuVox != null)
							MusicBeatState.menuVox.pause();
                    }
                    else{
                        FlxG.sound.music.resume();
						if (MusicBeatState.menuVox != null)
							MusicBeatState.menuVox.resume();
                    }
                }
            }else{
                playIdx = idx;
                if(!FlxG.sound.music.playing)
					playDaSong(); // its paused so dont bother fading out lol!
                else{
                    if (FlxG.sound.music.fadeTween == null || !FlxG.sound.music.fadeTween.active)
                    {
                        FlxG.sound.music.onComplete = null;
						if (MusicBeatState.menuVox!=null)
							MusicBeatState.menuVox.fadeOut(.25, 0);
                        FlxG.sound.music.fadeOut(.25, 0, function(twn:FlxTween)
                        {
                            playDaSong();
                        });
                    }
                }
            }

        }
				
        play.animation.play(idx==playIdx?(FlxG.sound.music.playing?"pause":"play"):"play");
        FlxG.mouse.visible = true;

    }

    function playDaSong(?daIdx:Int){
        if(daIdx==null)daIdx=playIdx;
		playIdx = daIdx;
		var song = songData[daIdx].songDirectory;
		if (song == 'menuTheme')
			MusicBeatState.playMenuMusic(true);
		else
		{
			if (songData[daIdx].chapterDir != null)
				Paths.currentModDirectory = songData[daIdx].chapterDir;
			else
				Paths.currentModDirectory = '';

			if (FileSystem.exists(Paths.returnSoundPath("songs", '${Paths.formatToSongPath(song)}/Inst'))){
                var vox:Null<Any> = null;
				var inst = Paths.inst(song);

                if (FileSystem.exists(Paths.returnSoundPath("songs", '${Paths.formatToSongPath(song)}/Voices')))
                {
                    if (MusicBeatState.menuVox==null){
                        MusicBeatState.menuVox = new FlxSound();
						MusicBeatState.menuVox.persist = true;
						MusicBeatState.menuVox.looped = true;
						MusicBeatState.menuVox.group = FlxG.sound.music.group;
                        FlxG.sound.list.add(MusicBeatState.menuVox);
                    }
                    //MusicBeatState.menuVox.loadEmbedded(Paths.voices(song));
					vox = Paths.voices(song);
                }

				if (vox!=null)MusicBeatState.menuVox.loadEmbedded(vox);
                
                
                FlxG.sound.playMusic(inst);
                if(MusicBeatState.menuVox!=null)
					MusicBeatState.menuVox.play();

                new FlxTimer().start(0, function(tmr:FlxTimer){ // keep it in sync i hope
                    // honestly if i can learn how audio shit works I could try stitching the 2 audio files together to keep it synced n shit? idk if I could make it sound good tho
					var time = FlxG.sound.music.time;
					FlxG.sound.music.time = time;
                    MusicBeatState.menuVox.time = time;
                });
                
            }else{
				if (MusicBeatState.menuVox != null)
				{
					MusicBeatState.menuVox.stop();
					MusicBeatState.menuVox.destroy();
					MusicBeatState.menuVox = null;
				}
				FlxG.sound.playMusic(song);
            }
		}
    }

    function changeSong(newIdx:Int){
        if(newIdx > songData.length-1)newIdx = 0;
        if(newIdx < 0)newIdx=songData.length-1;
        idx = newIdx;
        loadCoverImage(songData[idx]);
		songName.text = songData[idx].songName;
    }

	function loadCoverImage(data:JukeboxSongData){
        var coverArtPath = data.coverArt;
        if(coverArtPath.trim()==''){
            var songPath = 'songs/${data.songDirectory}';
			if (!Paths.fileExists('images/$songPath.png', IMAGE))
				coverArtPath = 'jukebox/noCoverImage';
            else
			    coverArtPath = songPath;
        }
        if(data.chapterDir!=null)Paths.currentModDirectory = data.chapterDir;
        
		image.loadGraphic(Paths.image(coverArtPath));
        image.setGraphicSize(388, 388);
        image.updateHitbox();
		image.x = outline.x + 16;
		image.y = outline.y + 16;
        Paths.currentModDirectory = '';
    }
}