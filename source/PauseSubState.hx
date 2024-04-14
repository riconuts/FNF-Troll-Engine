package;

import options.OptionsSubstate;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxCamera;
import flixel.addons.transition.FlxTransitionableState;
import flixel.group.FlxGroup.FlxTypedGroup;
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
	var menuItemFunctions:Map<String, haxe.Constraints.Function>;
	var curSelected:Int = 0;

	var pauseMusic:FlxSound;
	var skipTimeText:Null<FlxText> = null;
	var skipTimeTracker:Alphabet;
	var curTime:Float = Math.max(0, Conductor.songPosition);
	//var botplayText:FlxText;

	public static var songName:Null<String> = null;

	public function new (x:Float, y:Float)
	{
		super();

		menuItemFunctions = [
			'Change Modifiers' => () ->
			{
				this.persistentDraw = false;
				this.openSubState(new GameplayChangersSubstate());
			},
			'Options' => () ->
			{
				this.persistentDraw = false;
				var daSubstate = new OptionsSubstate();
				daSubstate.goBack = function(changedOptions:Array<String>)
				{
					var canResume:Bool = true;

					for (opt in changedOptions)
					{
						if (OptionsSubstate.requiresRestart.contains(opt))
						{
							canResume = false;
							break;
						}
					}

					PlayState.instance.optionsChanged(changedOptions);

					FlxG.mouse.visible = false;

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

					for (camera in daSubstate.camerasToRemove)
						FlxG.cameras.remove(camera);

					var cam:FlxCamera = FlxG.cameras.list[FlxG.cameras.list.length - 1];

					cameras = [cam];
				};
				openSubState(daSubstate);
			},
			"Resume" => this.close,
			"Restart Song" => () ->
			{
				if (FlxG.keys.pressed.SHIFT)
				{
					Paths.clearStoredMemory();
					Paths.clearUnusedMemory();
				}
				restartSong();
			},
			"Leave Charting Mode" => () ->
			{
				var chartPostfix = PlayState.difficultyName;
				if (chartPostfix != "")
					chartPostfix = '-$chartPostfix';
				PlayState.SONG = Song.loadFromJson(PlayState.SONG.song + chartPostfix, PlayState.SONG.song);
				PlayState.chartingMode = false;
				restartSong();
			},
			'Skip Time' => () ->
			{
				if (curTime < Conductor.songPosition)
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
			},
			"End Song" => () ->
			{
				close();
				PlayState.instance.finishSong(true);
			},
			'Toggle Botplay' => () ->
			{
				PlayState.instance.cpuControlled = !PlayState.instance.cpuControlled;
				/* 	
				PlayState.instance.botplayTxt.visible = PlayState.instance.cpuControlled;
				PlayState.instance.botplayTxt.alpha = 1;
				PlayState.instance.botplaySine = 0; 
				*/
			},
			"Exit to menu" => PlayState.gotoMenus
		];
	}

	var prevTimeScale:Float;
	override public function close(){
		FlxG.timeScale = prevTimeScale;
		
		super.close();
	}

	override public function create()
	{
		prevTimeScale = FlxG.timeScale;
		FlxG.timeScale = 1;

		super.create();
		
		FlxG.mouse.visible = false;
		persistentUpdate = false;

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

		////
		pauseMusic = new FlxSound();
		pauseMusic.context = MUSIC;

		var songName = songName;
		if (songName == null) songName = 'Breakfast';

		if (songName != 'None'){
			songName = Paths.formatToSongPath(songName);
			pauseMusic.loadEmbedded(Paths.music(songName), true, true);
			
			var loopTimePath = new haxe.io.Path(Paths.returnSoundPath("music", songName));
			loopTimePath.file += "-loopTime";
			loopTimePath.ext = "txt";

			var loopTime:Float = Std.parseFloat(Paths.getContent(loopTimePath.toString()));
			if (!Math.isNaN(loopTime))
				pauseMusic.loopTime = loopTime;
			
		}
		
		pauseMusic.volume = 0;
		pauseMusic.play(false, FlxG.random.int(0, Std.int(pauseMusic.length* 0.5)));
		pauseMusic.fadeIn(50, 0, 0.5 );

		FlxG.sound.list.add(pauseMusic);

		////
		var bg = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
		bg.setGraphicSize(FlxG.width, FlxG.height);
		bg.updateHitbox();
		bg.screenCenter();
		bg.scrollFactor.set();
		bg.alpha = 0;
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

			if (metadata != null && metadata.artist != null && metadata.artist.length > 0)
				songCredit += " - " + metadata.artist;
			
			pushInfo(songCredit);
		}

		if (metadata != null){
			if(metadata.charter != null && metadata.charter.length > 0)
				pushInfo("Charted by " + metadata.charter);

			if(metadata.modcharter != null && metadata.modcharter.length > 0)
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
		updateSkipTextStuff();

		if(subState == null){
			var scrollChange:Int = -FlxG.mouse.wheel;

			if (controls.UI_UP_P)
				scrollChange--;

			if (controls.UI_DOWN_P)
				scrollChange++;

			if (scrollChange != 0)
				changeSelection(scrollChange);

			var daSelected:String = menuItems[curSelected];
			switch (daSelected)
			{
				case 'Skip Time':
					var speed = FlxG.keys.pressed.SHIFT ? 10 : 1;

					if (controls.UI_LEFT_P)
					{
						FlxG.sound.play(Paths.sound('scrollMenu'), 0.4 );
						curTime -= 1000 * speed;
						holdTime = 0;
					}
					if (controls.UI_RIGHT_P)
					{
						FlxG.sound.play(Paths.sound('scrollMenu'), 0.4 );
						curTime += 1000 * speed;
						holdTime = 0;
					}

					if(controls.UI_LEFT || controls.UI_RIGHT)
					{
						holdTime += elapsed;

						if(holdTime > 0.5)
							curTime += 45000 * elapsed * (controls.UI_LEFT ? -1 : 1) * speed;

						if (curTime >= PlayState.instance.songLength) 
							curTime -= PlayState.instance.songLength;
						else if (curTime < 0)
							curTime += PlayState.instance.songLength;

						updateSkipTimeText();
					}
			}

			if (controls.ACCEPT && menuItemFunctions.exists(daSelected))
			{
				menuItemFunctions.get(daSelected)();
			}
		}

		super.update(elapsed);
	}

	public static function restartSong(noTrans:Bool = false)
	{
		PlayState.instance.persistentUpdate = false;
		PlayState.instance.paused = true; // For lua
		
		PlayState.instance.inst.volume = 0;
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

		if (change != 0)
			FlxG.sound.play(Paths.sound('scrollMenu'), 0.4 );

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
		if (skipTimeText != null){
			remove(skipTimeText);
			
			skipTimeText.destroy();
			skipTimeText = null;
		}

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
				skipTimeText.setFormat(Paths.font("vcr.ttf"), 64, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
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
		skipTimeText.text = FlxStringUtil.formatTime(Math.max(0, Math.floor(curTime / 1000)), false) + ' / ' + FlxStringUtil.formatTime(Math.max(0, Math.floor(PlayState.instance.songLength / 1000)), false);
	}
}
