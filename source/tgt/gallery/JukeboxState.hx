package tgt.gallery;

import flixel.FlxG;

import tgt.TGTMenuShit;
import flixel.addons.display.FlxBackdrop;
import flixel.util.FlxTimer;
import flixel.tweens.FlxTween;
import flixel.text.FlxText;
import flixel.text.FlxText.FlxTextBorderStyle;
import flixel.util.FlxColor;
import flixel.addons.display.shapes.FlxShapeBox;
import openfl.ui.Mouse;
import openfl.ui.MouseCursor;
import lime.app.Application;

#if discord_rpc
import Discord;
#end
#if sys
import sys.FileSystem;
#else
import openfl.Assets;
#end

using StringTools;

typedef JukeboxSongData = {
	var songName:String;
	var coverArt:String;
	var songDirectory:String;
	@:optional var chapterDir:String;
}

class JukeboxState extends MusicBeatState {
	////
	var outline:FlxShapeBox;
	var image:FlxSprite;
	var defImage:FlxSprite;

	var songName:FlxText;
	var songProgressBG:FlxSprite;
	var songProgress:FlxSprite;

	// butts
	var loopButton:FlxSprite;
	var back:FlxSprite;
	var play:FlxSprite;
	var forw:FlxSprite;
	var mute:FlxSprite;
	var buttons:Array<FlxSprite>;
	
	////
	var songData:Array<JukeboxSongData> = [];

	var idx:Int = 0;
	public static var playIdx:Int = 0;

	function updateSongCompleteCallback(){

	}

	var loopSong(default, set):Bool = true;
	function set_loopSong(loop:Bool){
		FlxG.sound.music.onComplete = loop ? (playIdx == 0 ? MusicBeatState.menuLoopFunc : null) : ()->{ // god fucking damnit i hate the menu theme
			var nextSong = playIdx+1;
			
			changeSong(nextSong);
			playDaSong(idx);
		};

		FlxG.sound.music.looped = loop;

		return loopSong = loop;
	}

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

	inline function addSong(songName:String, songDir:String, ?chapter:String, ?coverArt:String)
		songData.push({
			songName: songName,
			songDirectory: songDir,
			chapterDir: chapter==null ? "" : chapter,
			coverArt: coverArt==null ? 'songs/$songDir' : coverArt
		});
	// TODO: add bpm

	function addSonglists(?modDir:String)
	{
		var modDir:String = modDir==null?'':modDir;

		#if MODS_ALLOWED
		function getModTxt(file:String)
			return Paths.mods('$modDir/data/$file.txt');

		var getTxt:Dynamic = modDir == '' ? Paths.txt : getModTxt;
		#else
		var getTxt = Paths.txt;
		#end
		
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
		// should i move these to the jukeboxSonglist
		addSong("Game Over (Chapter 1)", 'gameOver', null, '');
		addSong("Breakfast (Chapter 1)", 'breakfast', null, '');
		addSonglists();

		#if MODS_ALLOWED
		for (mod in Paths.getModDirectories())
			addSonglists(mod);
		#end
		Paths.currentModDirectory = '';

		// TODO: order the songs so its story > side stories > remixes
		// naah don't do that

		////
		loopButton = new FlxSprite(0, 560).loadGraphic(Paths.image("jukebox/controls"), true, 60, 60);
		loopButton.color = TGTMenuShit.YELLOW;
		loopButton.animation.add("playloop", [5], 0, true);
		loopButton.animation.add("playlist", [6], 0, true);
		//loopButton.animation.add("playrandom", [7], 0, true);
		loopButton.animation.play(loopSong ? "playloop" : "playlist", true);

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
		
		forw.screenCenter(X);
		play.screenCenter(X);
		back.screenCenter(X);
		back.x -= 60;
		forw.x += 60;

		loopButton.x = back.x - 120;
		mute.x = forw.x + 120;

		songName = new FlxText(0, 520, FlxG.width, "", 32, true);
		songName.setFormat(Paths.font("calibrib.ttf"), 32, TGTMenuShit.YELLOW, FlxTextAlign.CENTER, FlxTextBorderStyle.NONE, TGTMenuShit.YELLOW);
		songName.scrollFactor.set(1, 1);
		songName.screenCenter(X);

		songProgressBG = new FlxSprite(0, 694).makeGraphic(600, 8);
		songProgressBG.color = 0xFF0B081B; // 0xFF070512
		songProgressBG.screenCenter(X);
		songProgressBG.scrollFactor.set();
		add(songProgressBG);

		songProgress = new FlxSprite(songProgressBG.x, songProgressBG.y).makeGraphic(600, 8);
		songProgress.color = TGTMenuShit.YELLOW;
		songProgress.visible = false;
		songProgress.scrollFactor.set();
		add(songProgress);
		
		add(outline);
		add(defImage);
		add(image);

		add(songName);
		add(forw);
		add(back);
		add(play);
		add(mute);
		add(loopButton);

		buttons = [back, play, forw, mute, loopButton, songProgressBG];

		add(tgt.TGTMenuShit.newBackTextButton(goBack));

		//
		set_loopSong(true);
		changeSong(playIdx);
		super.create();

		FlxG.autoPause = false;
		FlxG.mouse.visible = true;

		/*
		Application.current.window.onFocusIn.add(onFocusIn);
		Application.current.window.onFocusOut.add(onFocusOut);
		*/

		updateDiscord();
	}

	/*
	function onFocusOut(){
		FlxG.drawFramerate = 1;
		FlxG.updateFramerate = 30;
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
	*/

	inline function updateDiscord(){
		#if discord_rpc
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
		
		set_loopSong(true);
		
		MusicBeatState.switchState(new GalleryMenuState());
	}

	override function update(elapsed:Float){
		if (controls.BACK)
			goBack();

		// im bored
		var mouseOverlaps = null;

		for (butt in buttons){
			if (butt.visible && FlxG.mouse.overlaps(butt)){ 
				mouseOverlaps = butt;
				break;
			}
		}

		Mouse.cursor = mouseOverlaps!=null ? BUTTON : ARROW;

		var justClicked = FlxG.mouse.justReleased;
		var music = FlxG.sound.music;
		
		if (justClicked && mouseOverlaps == (songProgressBG))
		{
			music.pause();
			music.time = music.length * ((FlxG.mouse.screenX-songProgressBG.x)/(songProgressBG.width));
			
			if (MusicBeatState.menuVox != null){
				MusicBeatState.menuVox.pause();
				MusicBeatState.menuVox.time = music.time;
				MusicBeatState.menuVox.play();
			}
			
			music.play();
		}

		if (justClicked && mouseOverlaps == (loopButton) || FlxG.keys.justPressed.L){
			loopSong = !loopSong;
			loopButton.animation.play(loopSong ? "playloop" : "playlist", true);
		}

		if (justClicked && mouseOverlaps == (mute) || FlxG.keys.justPressed.M){
			muteVocals = !muteVocals;
			mute.animation.play(muteVocals ? "unmute" : "mute", true);
		}

		if (justClicked && mouseOverlaps == (forw) || FlxG.keys.justPressed.RIGHT)
			changeSong(idx+1);

		if (justClicked && mouseOverlaps == (back) || FlxG.keys.justPressed.LEFT)
			changeSong(idx-1);

		if (justClicked && mouseOverlaps == (play) || FlxG.keys.justPressed.SPACE){
			if(idx==playIdx){
				if (music.fadeTween == null || music.fadeTween.finished){
					if (music.playing){
						music.pause();
						if (MusicBeatState.menuVox != null)
							MusicBeatState.menuVox.pause();

						updateDiscord();
					}
					else{
						music.resume();
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

		if (playIdx != 0 && (music.playing && (music.fadeTween == null || !music.fadeTween.active))){
			songProgressBG.visible = songProgress.visible = true;
			songProgress.scale.x = music.time / music.length;
			songProgress.updateHitbox();
		}else
			songProgressBG.visible = songProgress.visible = false;

		super.update(elapsed);
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
		if (Assets.exists(path, SOUND)){
			trackedSounds.push(path);
			return Assets.getSound(path, false);
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

		if (song == 'menuTheme'){
			MusicBeatState.menuMusic = null; // clear loop cache jus in case
			MusicBeatState.playMenuMusic(true);
		}else{
			var inst = getSound(Paths.returnSoundPath("songs", '${Paths.formatToSongPath(song)}/Inst'));
			var vox = null;

			if (inst == null) // music folder song
				inst = getSound(Paths.returnSoundPath("music", song));
			else // fnf song
				vox = getSound(Paths.returnSoundPath("songs", '${Paths.formatToSongPath(song)}/Voices'));

			if (vox != null){
				if (MusicBeatState.menuVox==null){
					MusicBeatState.menuVox = new FlxSound();
					MusicBeatState.menuVox.persist = true;
					MusicBeatState.menuVox.looped = true;
					MusicBeatState.menuVox.group = FlxG.sound.music.group;
					MusicBeatState.menuVox.volume = 0;

					FlxG.sound.list.add(MusicBeatState.menuVox);
				}

				MusicBeatState.menuVox.loadEmbedded(vox, true).volume = muteVocals ? 0 : 1;

			}else if (MusicBeatState.menuVox != null){
				MusicBeatState.menuVox.stop();
				MusicBeatState.menuVox.destroy();
				MusicBeatState.menuVox = null;
			}
			
			FlxG.sound.playMusic(inst, 1);
			if(MusicBeatState.menuVox!=null)
				MusicBeatState.menuVox.play();

			new FlxTimer().start(0, function(tmr:FlxTimer){ // keep it in sync i hope
				// honestly if i can learn how audio shit works I could try stitching the 2 audio files together to keep it synced n shit? idk if I could make it sound good tho
				var time = FlxG.sound.music.time;
				FlxG.sound.music.time = time;
				if(MusicBeatState.menuVox!=null)
					MusicBeatState.menuVox.time = time;

				set_loopSong(loopSong);
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
			if (Paths.fileExists('images/$songPath.png', IMAGE))
				coverArtPath = songPath;
			else
				coverArtPath = 'jukebox/noCoverImage';
		}

		if(data.chapterDir != null) Paths.currentModDirectory = data.chapterDir;

		var graphic = Paths.image(coverArtPath);
		if (graphic == null) graphic = Paths.image('jukebox/noCoverImage');

		image.loadGraphic(graphic);
		image.setGraphicSize(388, 388);
		image.updateHitbox();
		image.x = outline.x + 16;
		image.y = outline.y + 16;

		Paths.currentModDirectory = '';
	}
}