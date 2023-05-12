package;

import options.GameplaySettingsSubState;
import newoptions.OptionsSubstate;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.addons.transition.FlxTransitionableState;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.system.FlxSound;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxStringUtil;

class PauseSubState extends MusicBeatSubstate
{
	var grpMenuShit:FlxTypedGroup<Alphabet>;

	var menuItems:Array<String> = [];
	var menuItemsOG:Array<String> = ['Resume', 'Restart Song', 'Options', 'Exit to menu'];
	var curSelected:Int = 0;

	var pauseMusic:FlxSound;
	var skipTimeText:FlxText;
	var skipTimeTracker:Alphabet;
	var curTime:Float = Math.max(0, Conductor.songPosition);
	//var botplayText:FlxText;

	public static var songName:String = '';

	public function new(x:Float, y:Float)
	{
		super();
		
		persistentUpdate = true;

		var cam:FlxCamera = FlxG.cameras.list[FlxG.cameras.list.length - 1];
		this.camera = cam;

		if (!PlayState.isStoryMode){
			menuItemsOG.insert(3, "Change Modifiers");
		}

		if(#if debug true || #end PlayState.chartingMode)
		{
			var shit:Int = 2;

			if (PlayState.chartingMode){
				menuItemsOG.insert(shit, 'Leave Charting Mode');
				shit++;
			}

			var num:Int = 0;

			//if(!PlayState.instance.startingSong)
			//{
				num = 1;
				menuItemsOG.insert(shit, 'Skip Time');
			//}

			menuItemsOG.insert(shit + num, 'End Song');
			// menuItemsOG.insert(shit + num, 'Toggle Practice Mode');
			menuItemsOG.insert(shit + num, 'Toggle Botplay');
		}
		menuItems = menuItemsOG;


		pauseMusic = new FlxSound();
		if(songName != null) 
			pauseMusic.loadEmbedded(Paths.music(songName), true, true);
		else if (songName != 'None')
			pauseMusic.loadEmbedded(Paths.music(Paths.formatToSongPath('Breakfast')), true, true);
		
		pauseMusic.volume = 0;
		pauseMusic.play(false, FlxG.random.int(0, Std.int(pauseMusic.length* 0.5)));

		FlxG.sound.list.add(pauseMusic);

		var bg:FlxSprite = new FlxSprite().makeGraphic(cam.width, cam.height, FlxColor.BLACK);
		bg.alpha = 0;
		bg.screenCenter(XY);
		bg.scrollFactor.set();
		add(bg);

		////
		var songInfo:Array<String> = [];
		var metadata = PlayState.instance.metadata;

		function pushInfo(str:String) {
			for (string in str.split('\n'))
				songInfo.push(string);
		}

		if (PlayState.SONG != null && PlayState.SONG.song != null){
			var songCredit = PlayState.SONG.song;
			if (metadata != null)
				songCredit += " - " + metadata.artist;
			pushInfo(songCredit);
		}

		if (metadata != null){
			if(metadata.charter != null)
				pushInfo("Charted by " + metadata.charter);

			if(metadata.modcharter != null)
				pushInfo("Modcharted by " + metadata.modcharter);
		}

		if (PlayState.SONG != null && PlayState.SONG.info != null)
			for (extraInfo in PlayState.SONG.info)
				pushInfo(extraInfo);
		
		if (metadata != null && metadata.extraInfo!=null){
			for(extraInfo in metadata.extraInfo)
				pushInfo(extraInfo);
		}
		
		// removed the practice clause cus its just nice to have the counter lol
		songInfo.push("Failed: " + PlayState.deathCounter); // i'd say blueballed but not every character blueballs + you straight up die in die batsards

		////
		var allTexts:Array<FlxText> = [];
		var prevText:FlxText = null;

		for (daText in songInfo){
			prevText = new FlxText(20, prevText == null ? 15 : (prevText.y + 36), 0, daText, 32);
			prevText.setFormat(Paths.font('vcr.ttf'), 32, 0xFFFFFFFF, RIGHT);
			prevText.scrollFactor.set();
			prevText.updateHitbox();
			prevText.alpha = 0;	

			prevText.x = cam.width - (prevText.width + 20);

			allTexts.push(prevText);
			add(prevText);
		}

		if (PlayState.chartingMode){
			var chartingText:FlxText = new FlxText(cam.width, 0, 0, "CHARTING MODE", 32);
			chartingText.setFormat(Paths.font('vcr.ttf'), 32);
			chartingText.scrollFactor.set();
			chartingText.updateHitbox();

			chartingText.setPosition(
				cam.width - (chartingText.width + 20),
				cam.height - (chartingText.height + 20)
			);

			add(chartingText);

			chartingText.alpha = 0;
			FlxTween.tween(chartingText, {alpha: 1}, 0.4, {ease: FlxEase.quartInOut});
		}

		FlxTween.tween(bg, {alpha: 0.6}, 0.4, {ease: FlxEase.quartInOut});
		//FlxTween.tween(pauseMusic, {volume: 0.5}, 5, {ease: FlxEase.linear});
		for (id in 0...allTexts.length)
		{
			var daText = allTexts[id];

			daText.y -= 5;
			FlxTween.tween(daText, {alpha: 1, y: daText.y + 5}, 0.4, {ease: FlxEase.quartInOut, startDelay: 0.3 * (id+1)});
		}

		grpMenuShit = new FlxTypedGroup<Alphabet>();
		add(grpMenuShit);

		regenMenu();
		cameras = [cam];

		PlayState.instance.callOnScripts('paused');
	}

	var holdTime:Float = 0;
	override function update(elapsed:Float)
	{
		if (pauseMusic.volume < 0.5)
			pauseMusic.volume += 0.01 * elapsed; 

		super.update(elapsed);
		updateSkipTextStuff();

		if(subState == null){
			var upP = controls.UI_UP_P;
			var downP = controls.UI_DOWN_P;
			var accepted = controls.ACCEPT;

			if (upP)
				changeSelection(-1);

			if (downP)
				changeSelection(1);

			var daSelected:String = menuItems[curSelected];
			switch (daSelected)
			{
				case 'Skip Time':
					var speed = FlxG.keys.pressed.SHIFT ? 10 : 1;

					if (controls.UI_LEFT_P)
					{
						FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
						curTime -= 1000 * speed;
						holdTime = 0;
					}
					if (controls.UI_RIGHT_P)
					{
						FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
						curTime += 1000 * speed;
						holdTime = 0;
					}

					if(controls.UI_LEFT || controls.UI_RIGHT)
					{
						holdTime += elapsed;

						if(holdTime > 0.5)
							curTime += 45000 * elapsed * (controls.UI_LEFT ? -1 : 1) * speed;

						if (curTime >= FlxG.sound.music.length) 
							curTime -= FlxG.sound.music.length;
						else if (curTime < 0)
							curTime += FlxG.sound.music.length;

						updateSkipTimeText();
					}
			}

			if (accepted)
			{
				switch (daSelected)
				{
					case 'Change Modifiers':
						this.persistentDraw = false;						
						this.openSubState(new GameplayChangersSubstate());						

					case 'Options':
						var daSubstate = new OptionsSubstate();
						this.persistentDraw = true;

						daSubstate.goBack = (function(changedOptions:Array<String>)
						{
	 						var canResume:Bool = true;

							for(opt in changedOptions){
								if (OptionsSubstate.requiresRestart.contains(opt)){
									canResume = false;
									break;
								}
							}
							
							PlayState.instance.optionsChanged(changedOptions);

							closeSubState();
	 						if (!canResume)
							{ 
								if (changedOptions.length > 0)
								{
									menuItems.remove("Resume");
									menuItems.remove("Skip Time");
									regenMenu();
								}
							}
							for(camera in daSubstate.camerasToRemove)
								FlxG.cameras.remove(camera);

							var cam:FlxCamera = FlxG.cameras.list[FlxG.cameras.list.length - 1];

							cameras = [cam];

						}); 
						openSubState(daSubstate);
					case "Resume":
						close();
					case "Restart Song":

						if (FlxG.keys.pressed.SHIFT){					
							PlayState.SONG = Song.loadFromJson(PlayState.SONG.song, PlayState.SONG.song);

							Paths.clearStoredMemory();
							Paths.clearUnusedMemory();

							MusicBeatState.resetState();
						}else
							restartSong();
					case "Leave Charting Mode":

						restartSong();
						PlayState.chartingMode = false;
					case 'Skip Time':
						if(curTime < Conductor.songPosition)
						{
							PlayState.startOnTime = curTime;
							restartSong(true);
						}
						else
						{
							if (curTime != Conductor.songPosition)
							{
								PlayState.instance.clearNotesBefore(curTime);
								PlayState.instance.setSongTime(curTime);
							}
							close();
						}
					case "End Song":

						close();
						PlayState.instance.finishSong(true);
					case 'Toggle Botplay':
						PlayState.instance.cpuControlled = !PlayState.instance.cpuControlled;
	/* 					PlayState.instance.botplayTxt.visible = PlayState.instance.cpuControlled;
						PlayState.instance.botplayTxt.alpha = 1;
						PlayState.instance.botplaySine = 0; */
					case "Exit to menu":

						PlayState.deathCounter = 0;
						PlayState.seenCutscene = false;
						if(PlayState.isStoryMode) {
							MusicBeatState.switchState(new StoryMenuState());
						} else {
							MusicBeatState.switchState(new FreeplayState());
						}
						PlayState.cancelMusicFadeTween();

						MusicBeatState.playMenuMusic(true);
						
						PlayState.chartingMode = false;
				}
			}
		}
	}

	public static function restartSong(noTrans:Bool = false)
	{
		PlayState.instance.paused = true; // For lua
		FlxG.sound.music.volume = 0;
		PlayState.instance.vocals.volume = 0;

		if(noTrans)
		{
			FlxTransitionableState.skipNextTransOut = true;
			FlxG.resetState();
		}
		else
		{
			MusicBeatState.resetState();
		}
	}

	override function destroy()
	{
		pauseMusic.destroy();

		super.destroy();
	}

	function changeSelection(change:Int = 0):Void
	{
		curSelected += change;

		FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);

		if (curSelected < 0)
			curSelected = menuItems.length - 1;
		if (curSelected >= menuItems.length)
			curSelected = 0;

		var bullShit:Int = 0;

		for (item in grpMenuShit.members)
		{
			item.targetY = bullShit - curSelected;
			bullShit++;

			item.alpha = 0.6;
			// item.setGraphicSize(Std.int(item.width * 0.8));

			if (item.targetY == 0)
			{
				item.alpha = 1;
				// item.setGraphicSize(Std.int(item.width));

				if(item == skipTimeTracker)
				{
					curTime = Math.max(0, Conductor.songPosition);
					updateSkipTimeText();
				}
			}
		}
	}

	function regenMenu():Void {
		for (i in 0...grpMenuShit.members.length) {
			var obj = grpMenuShit.members[0];
			obj.kill();
			grpMenuShit.remove(obj, true);
			obj.destroy();
		}

		for (i in 0...menuItems.length) {
			var item = new Alphabet(0, 70 * i + 30, menuItems[i], true, false);
			item.isMenuItem = true;
			item.targetY = i;
			grpMenuShit.add(item);

			if(menuItems[i] == 'Skip Time')
			{
				skipTimeText = new FlxText(0, 0, 0, '', 64);
				skipTimeText.setFormat(Paths.font("calibri.ttf"), 64, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
				skipTimeText.scrollFactor.set();
				skipTimeText.borderSize = 2;
				skipTimeTracker = item;
				add(skipTimeText);

				updateSkipTextStuff();
				updateSkipTimeText();
			}
		}
		curSelected = 0;
		changeSelection();
	}

	function updateSkipTextStuff()
	{
		if(skipTimeText == null || skipTimeTracker == null) return;

		skipTimeText.x = skipTimeTracker.x + skipTimeTracker.width + 60;
		skipTimeText.y = skipTimeTracker.y;
		skipTimeText.visible = (skipTimeTracker.alpha >= 1);
	}

	function updateSkipTimeText()
	{
		skipTimeText.text = FlxStringUtil.formatTime(Math.max(0, Math.floor(curTime / 1000)), false) + ' / ' + FlxStringUtil.formatTime(Math.max(0, Math.floor(FlxG.sound.music.length / 1000)), false);
	}
}
