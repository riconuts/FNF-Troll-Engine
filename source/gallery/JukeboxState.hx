package gallery;

import lime.app.Application;
import sowy.TGTMenuShit;
import flixel.addons.display.FlxBackdrop;
import flixel.util.FlxTimer;
import flixel.system.FlxSound;
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
#if sys
import sys.FileSystem;
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

	////
	var outline:FlxShapeBox;
	var image:FlxSprite;
	var defImage:FlxSprite;

	var songName:FlxText;
	var songProgress:FlxSprite;

	// butts
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

	var bg:FlxSprite;
	override function create()
	{
		persistentUpdate = true;
		persistentDraw = true;

		bg = new FlxBackdrop();
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
			color: TGTMenuShit.YELLOW
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
		back.color = TGTMenuShit.YELLOW;
		back.animation.add("back", [0], 0, true);
		back.animation.play("back", true);

		play = new FlxSprite(0 , 560).loadGraphic(Paths.image("jukebox/controls"), true, 60, 60);
		play.color = TGTMenuShit.YELLOW;
		play.animation.add("play", [1], 0, true);
		play.animation.add("pause", [2], 0, true);
		play.animation.play("play", true);

		forw = new FlxSprite(0, 560).loadGraphic(Paths.image("jukebox/controls"), true, 60, 60);
		forw.color = TGTMenuShit.YELLOW;
		forw.animation.add("fw", [0], 0, true);
		forw.animation.play("fw", true);
		forw.flipX = true;

		mute = new FlxSprite(0 , 560).loadGraphic(Paths.image("jukebox/controls"), true, 60, 60);
		mute.color = TGTMenuShit.YELLOW;
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
		songName.setFormat(Paths.font("calibrib.ttf"), 32, TGTMenuShit.YELLOW, FlxTextAlign.CENTER, FlxTextBorderStyle.NONE, TGTMenuShit.YELLOW);
		songName.scrollFactor.set(1, 1);
		songName.screenCenter(X);

		/*
		songProgress = new FlxSprite(0, 650).makeGraphic(720, 8);
		songProgress.color = TGTMenuShit.YELLOW;
		songProgress.screenCenter(X);
		songProgress.visible = false;
		add(songProgress);
		*/
		
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

		var cornerLeftText = sowy.TGTMenuShit.newBackTextButton(goBack);
		add(cornerLeftText);

		FlxG.autoPause = false;
		FlxG.mouse.visible = true;

		Application.current.window.onFocusIn.add(onFocusIn);
		Application.current.window.onFocusOut.add(onFocusOut);

		updateDiscord();
	}

	function onFocusOut(){
		FlxG.drawFramerate = 1;
		FlxG.updateFramerate = 1;
		bg.animation.pause();
	}
	function onFocusIn(){
		var frameRate = Math.ceil(ClientPrefs.framerate);
		if (frameRate > FlxG.drawFramerate){
			FlxG.updateFramerate = frameRate;
			FlxG.drawFramerate = frameRate;
		}else{
			FlxG.drawFramerate = frameRate;
			FlxG.updateFramerate = frameRate;
		}
		bg.animation.resume();
	}

	override public function destroy(){
		Application.current.window.onFocusIn.remove(onFocusIn);
		Application.current.window.onFocusOut.remove(onFocusOut);
		super.destroy();
	}

	inline function updateDiscord(){
		#if desktop
		if (FlxG.sound.music.playing)
			DiscordClient.changePresence('Listening to: ${songData[playIdx].songName}', null);
		else
			DiscordClient.changePresence('In the Menus', null);
		#end
	}

	var doingTrans = false;
	function goBack() {
		if (doingTrans) return;
		doingTrans = true;
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

		/*
		if (playIdx != 0 && FlxG.sound.music != null){
			songProgress.visible = true;
			songProgress.scale.x = FlxG.sound.music.time / FlxG.sound.music.length;
			songProgress.updateHitbox();
		}else
			songProgress.visible = false;
		*/
	}

	//// sorry but ram usage rises pretty quickly ;_;
	var trackedSounds:Array<String> = [];
	function clearSounds(){
		for (key in trackedSounds)
			openfl.Assets.cache.clear(key);

		trackedSounds = [];
	}
	function getSound(path):Null<openfl.media.Sound>
	{
		#if (html5 || flash)
		if (Assets.exists(gottenPath, SOUND)){
			trackedSounds.push(path);
			return Assets.getSound(gottenPath, false);
		}
		#else
		if (FileSystem.exists(path)){
			trackedSounds.push(path);
			return openfl.media.Sound.fromFile(path);
		}
		#end
		
		return null;
	}

	function playDaSong(?daIdx:Int){
		Mouse.cursor = __WAIT_ARROW;

		if(daIdx==null)daIdx=playIdx;
		playIdx = daIdx;

		var daData = songData[daIdx];
		var song = daData.songDirectory;
		var folder = daData.chapterDir;

		Paths.currentModDirectory = folder==null ? '' : folder; 

		trace(daData);

		if (FlxG.sound.music != null)
			FlxG.sound.music.stop();
		if (MusicBeatState.menuVox != null)
			MusicBeatState.menuVox.stop();

		clearSounds();

		if (song == 'menuTheme')
			MusicBeatState.playMenuMusic(true);
		else
		{
			var inst = getSound(Paths.returnSoundPath("songs", '${Paths.formatToSongPath(song)}/Inst'));

			if (inst == null){
				inst = getSound(Paths.returnSoundPath("music", song));
			}else{
				var vox = getSound(Paths.returnSoundPath("songs", '${Paths.formatToSongPath(song)}/Voices'));
	
				if (vox != null){
					if (MusicBeatState.menuVox==null){
						MusicBeatState.menuVox = new FlxSound();
						MusicBeatState.menuVox.persist = true;
						MusicBeatState.menuVox.looped = true;
						MusicBeatState.menuVox.group = FlxG.sound.music.group;
	
						MusicBeatState.menuVox.volume = muteVocals ? 0 : 1;
	
						FlxG.sound.list.add(MusicBeatState.menuVox);
					}
	
					MusicBeatState.menuVox.loadEmbedded(vox, true).volume = muteVocals ? 0 : 1;
	
				}else if (MusicBeatState.menuVox != null){
					MusicBeatState.menuVox.stop();
					MusicBeatState.menuVox.destroy();
					MusicBeatState.menuVox = null;
				}
			}
			
			FlxG.sound.playMusic(inst);
			if(MusicBeatState.menuVox!=null)
				MusicBeatState.menuVox.play();

			new FlxTimer().start(0, function(tmr:FlxTimer){ // keep it in sync i hope
				// honestly if i can learn how audio shit works I could try stitching the 2 audio files together to keep it synced n shit? idk if I could make it sound good tho
				var time = FlxG.sound.music.time;
				FlxG.sound.music.time = time;
				if(MusicBeatState.menuVox!=null)
					MusicBeatState.menuVox.time = time;
			});
				
			
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