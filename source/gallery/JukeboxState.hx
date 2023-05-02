package gallery;

import flixel.addons.display.FlxBackdrop;
import flixel.util.FlxTimer;
import flixel.system.FlxSound;
import sys.FileSystem;
import flixel.tweens.FlxTween;
import flixel.text.FlxText;
import flixel.text.FlxText.FlxTextBorderStyle;
import flixel.util.FlxColor;
import flixel.addons.display.shapes.FlxShapeBox;
import openfl.ui.Mouse;
import openfl.ui.MouseCursor;
import flixel.FlxG;
#if desktop
import Discord;
#end

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

	var songName:FlxText;

	var back:FlxSprite;
	var play:FlxSprite;
	var forw:FlxSprite;

	var mute:FlxSprite;
	
	inline function addSong(songName:String, songDir:String, ?chapter:String, ?coverArt:String)
		songData.push({
			songName: songName,
			songDirectory: songDir,
			chapterDir: chapter==null ? "" : chapter,
			coverArt: coverArt==null ? 'songs/$songDir' : coverArt
		});
	// TODO: add bpm
	static var idx:Int = 0;
	public static var playIdx:Int = 0;

	static var muteVocals(default, set) = false;
	static function set_muteVocals(mute:Bool){
		muteVocals = mute;

		if (MusicBeatState.menuVox != null){
			if(MusicBeatState.menuVox.fadeTween!=null)
				MusicBeatState.menuVox.fadeTween.cancel();
			
			if (mute)
				MusicBeatState.menuVox.fadeOut(0.25, 0);
			else
				MusicBeatState.menuVox.volume = 1;
		}
		
		return mute;
	}

	function addSonglists(?modDir:String)
	{
		var modDir:String = modDir==null?'':modDir;
		var getTxt:Dynamic = modDir==''?Paths.txt:Paths.modsTxt;
		Paths.currentModDirectory = modDir;

		//var added:Array<String> = [];

		for (i in CoolUtil.coolTextFile(getTxt('jukeboxSonglist')))
		{
			var splitted = i.split(":");
			//added.push(splitted[1]);
			addSong(splitted[0], splitted[1], modDir, splitted[2]);
		}

		for (i in CoolUtil.coolTextFile(getTxt('freeplaySonglist')))
		{
			var song:String = i.split(":")[0];
			var songLowercase:String = Paths.formatToSongPath(song);
			//if (!added.contains(songLowercase))
			addSong(song, songLowercase, modDir);
		}
	}

	override function create()
	{
		persistentUpdate = true;
		persistentDraw = true;

		var bg = new FlxBackdrop();
		bg.frames = Paths.getSparrowAtlas("jukebox/space");
		bg.animation.addByPrefix("space", "space", 50, true);
		bg.animation.play("space");
		bg.screenCenter();
		add(bg);

		if (FlxG.width > FlxG.height)
			add(new FlxSprite().makeGraphic(FlxG.height, FlxG.height, 0xFF000000).screenCenter(X));
		else
			add(new FlxSprite().makeGraphic(FlxG.width, FlxG.width, 0xFF000000).screenCenter(Y));

		//// Song stuff

		defImage = new FlxSprite(0, 50).loadGraphic(Paths.image("jukebox/defImage"));
		defImage.antialiasing = false;
		
		image = new FlxSprite(0, 50).loadGraphic(Paths.image("jukebox/defImage"));
		image.antialiasing = false;
		outline = new FlxShapeBox(0, 33, 420, 420, {
			thickness: 8,
			color: 0xFFF4CC34
		}, 0x000000);
		outline.screenCenter(X);

		defImage.x = outline.x + 16;
		defImage.y = outline.y + 16;

		//// Add songs
		addSong("Main Menu (TGT Mix)", "menuTheme", null, ''); // menuTheme songDir is hard-coded to goto the playMenuMusic func
		addSong("Game Over (TGT Mix)", 'gameOver', null, '');
		addSong("Breakfast (TGT Mix)", 'breakfast', null, '');
		addSonglists();

		#if MODS_ALLOWED
		for (mod in Paths.getModDirectories())
			addSonglists(mod);
		#end
		Paths.currentModDirectory = '';

		// TODO: order the songs so its story > side stories > remixes
		// naah don't do that

		back = new FlxSprite(0, 560).loadGraphic(Paths.image("jukebox/controls"), true, 60, 60);
		back.color = 0xFFF4CC34;
		back.animation.add("back", [0], 0, true);
		back.animation.play("back", true);

		play = new FlxSprite(0 , 560).loadGraphic(Paths.image("jukebox/controls"), true, 60, 60);
		play.color = 0xFFF4CC34;
		play.animation.add("play", [1], 0, true);
		play.animation.add("pause", [2], 0, true);
		play.animation.play("play", true);

		forw = new FlxSprite(0, 560).loadGraphic(Paths.image("jukebox/controls"), true, 60, 60);
		forw.color = 0xFFF4CC34;
		forw.animation.add("fw", [0], 0, true);
		forw.animation.play("fw", true);
		forw.flipX = true;

		mute = new FlxSprite(0 , 560).loadGraphic(Paths.image("jukebox/controls"), true, 60, 60);
		mute.color = 0xFFF4CC34;
		mute.animation.add("mute", [3], 0, true);
		mute.animation.add("unmute", [4], 0, true);
		mute.animation.play(muteVocals ? "unmute" : "mute", true);
		
		play.screenCenter(X);
		forw.screenCenter(X);
		back.screenCenter(X);
		back.x -= 60;
		forw.x += 60;

		mute.x = forw.x + 120;

		songName = new FlxText(0, 520, FlxG.width, "", 32, true);
		songName.setFormat(Paths.font("calibrib.ttf"), 32, 0xFFF4CC34, FlxTextAlign.CENTER, FlxTextBorderStyle.NONE, 0xFFF4CC34);
		songName.scrollFactor.set(1, 1);

		songName.screenCenter(X);
		
		add(outline);
		add(defImage);
		add(image);

		add(songName);
		add(forw);
		add(back);
		add(play);
		add(mute);

		changeSong(idx);
		super.create();

		var cornerLeftText = new sowy.TGTTextButton(15, 720, 0, "← BACK", 32, goBack);
		cornerLeftText.label.setFormat(Paths.font("calibri.ttf"), 32, 0xFFF4CC34, FlxTextAlign.RIGHT, FlxTextBorderStyle.NONE, 0xFFF4CC34);
		cornerLeftText.y -= cornerLeftText.height + 15;
		add(cornerLeftText);

		FlxG.autoPause = false;
		FlxG.mouse.visible = true;

		updateDiscord();
	}

	inline function updateDiscord(){
		#if desktop
		if (FlxG.sound.music.playing)
			DiscordClient.changePresence('Listening to: ${songData[playIdx].songName}', null);
		else
			DiscordClient.changePresence('In the Menus', null);
		#end
	}

	function goBack() {
		FlxG.sound.play(Paths.sound('cancelMenu'));
		MusicBeatState.switchState(new GalleryMenuState());
	}

	override function update(elapsed:Float){
		super.update(elapsed);

		if(FlxG.mouse.overlaps(forw) || FlxG.mouse.overlaps(back) || FlxG.mouse.overlaps(play) || FlxG.mouse.overlaps(mute))
			Mouse.cursor = BUTTON;
		else
			Mouse.cursor = ARROW;

		var forward = FlxG.mouse.overlaps(forw) && FlxG.mouse.justPressed || FlxG.keys.justPressed.RIGHT;
		var bakward = FlxG.mouse.overlaps(back) && FlxG.mouse.justPressed || FlxG.keys.justPressed.LEFT;
		var resSong = FlxG.mouse.overlaps(play) && FlxG.mouse.justPressed || FlxG.keys.justPressed.SPACE;

		if (FlxG.mouse.overlaps(mute) && FlxG.mouse.justPressed || FlxG.keys.justPressed.M){
			muteVocals = !muteVocals;
			mute.animation.play(muteVocals ? "unmute" : "mute", true);
		}

		if (controls.BACK)
			goBack();

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

						updateDiscord();
					}
					else{
						FlxG.sound.music.resume();
						if (MusicBeatState.menuVox != null)
							MusicBeatState.menuVox.resume();

						updateDiscord();
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
						if (MusicBeatState.menuVox != null && !muteVocals)
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
	}

	function playDaSong(?daIdx:Int){
		if(daIdx==null)daIdx=playIdx;
		playIdx = daIdx;

		var daData = songData[daIdx];
		var song = daData.songDirectory;
		var folder = daData.chapterDir;

		Paths.currentModDirectory = folder==null ? '' : folder; 

		trace(daData);

		Mouse.cursor = __WAIT_ARROW;
		if (song == 'menuTheme')
			MusicBeatState.playMenuMusic(true);
		else
		{
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

						MusicBeatState.menuVox.volume = muteVocals ? 0 : 1;

						FlxG.sound.list.add(MusicBeatState.menuVox);
					}

					vox = Paths.voices(song);
				}

				if (vox!=null){
					MusicBeatState.menuVox.loadEmbedded(vox, true).volume = muteVocals ? 0 : 1;
				}
				
				
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

				FlxG.sound.playMusic(Paths.music(song));
			}
		}
		Mouse.cursor = ARROW;

		updateDiscord();
	}

	function changeSong(newIdx:Int){
		if(newIdx > songData.length-1) newIdx = 0;
		if(newIdx < 0) newIdx=songData.length-1;
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
		if(data.chapterDir != null) Paths.currentModDirectory = data.chapterDir;
		
		image.loadGraphic(Paths.image(coverArtPath));
		image.setGraphicSize(388, 388);
		image.updateHitbox();
		image.x = outline.x + 16;
		image.y = outline.y + 16;
		Paths.currentModDirectory = '';
	}
}