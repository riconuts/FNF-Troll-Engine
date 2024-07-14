package funkin.states;

import funkin.input.Controls;
import funkin.objects.AttachedFlxText;
import funkin.states.options.OptionsSubstate;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxCamera;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxStringUtil;
import haxe.Constraints.Function;

/*
typedef PauseOptionCallbacks = {
	?onAccept:Function,
	?onSelect:Function,
	?unSelect:Function,
	?onAdded:Function
}
*/

class PauseSubState extends MusicBeatSubstate
{
	public static var songName:Null<String> = null;

	public var menu:AlphabetMenu;
	public var menuItems = ["Resume", "Restart Song", 'Options', "Exit to menu"];
	var menuItemCallbacks:Map<String, AlphabetMenu.OptionCallbacks>;

	private var skipTimeText:Null<SkipTimeText> = null;

	public function new(x:Float, y:Float)
	{
		super();

		var menuItemFunctions:Map<String, Function> = [
			"Resume" => this.close,
			"Restart Song" => () ->
			{
				if (FlxG.keys.pressed.SHIFT)
				{
					Paths.clearStoredMemory();
					Paths.clearUnusedMemory();
				}
				PlayState.instance.restartSong();
			},
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
						if (OptionsSubstate.requiresRestart.exists(opt))
						{
							canResume = false;
							break;
						}
					}

					PlayState.instance.optionsChanged(changedOptions);
					FlxG.mouse.visible = false;

					closeSubState();
					if (!canResume && changedOptions.length > 0){
						menuItems.remove("Resume");
						menuItems.remove("Skip To");
						regenMenu();
					}

					for (camera in daSubstate.camerasToRemove)
						FlxG.cameras.remove(camera);
				};
				openSubState(daSubstate);
			},
			"Leave Charting Mode" => () ->
			{
				var songName:String = PlayState.SONG.song;
				var jsonName:String;

				if (PlayState.difficultyName != "")
					jsonName = songName + '-' + PlayState.difficultyName;
				else
					jsonName = songName; 

				PlayState.SONG = funkin.data.Song.loadFromJson(jsonName, songName);
				PlayState.chartingMode = false;
				PlayState.instance.restartSong();
			},
			'Skip To' => () ->
			{
				var curTime = skipTimeText.curTime;
				if (curTime < Conductor.songPosition)
				{
					PlayState.startOnTime = curTime;
					PlayState.instance.restartSong(true);
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
			"End Song" => () -> {
				close();
				PlayState.instance.finishSong(true);
			},
			'Toggle Botplay' => () -> PlayState.instance.cpuControlled = !PlayState.instance.cpuControlled,
			"Exit to menu" => PlayState.gotoMenus
		];

		menuItemCallbacks = [
			for (k => v in menuItemFunctions)
				k => {onAccept: v}
		];
	}

	var prevTimeScale:Float;
	override public function close(){
		FlxG.timeScale = prevTimeScale;
		
		super.close();
	}

	override public function create()
	{
		super.create();

		prevTimeScale = FlxG.timeScale;
		FlxG.timeScale = 1;

		FlxG.mouse.visible = false;
		persistentUpdate = false;

		var cam:FlxCamera = FlxG.cameras.list[FlxG.cameras.list.length - 1];
		this.cameras = [cam];

		var bg = new FlxSprite(FlxG.width / 2 - 1, FlxG.height / 2 -1).makeGraphic(2, 2);
		bg.scale.set(FlxG.width, FlxG.height);
		bg.scrollFactor.set();
		bg.color = 0xFF000000;
		bg.alpha = 0.0;
		add(bg);

		FlxTween.tween(bg, {alpha: 0.6}, 0.4, {ease: FlxEase.quartInOut});

		menu = new AlphabetMenu();
		menu.controls = controls;
		menu.cameras = cameras;
		add(menu);

		if (!PlayState.isStoryMode){
			menuItems.insert(3, "Change Modifiers");
		}
		if(#if debug true #else PlayState.chartingMode #end)
		{
			var shit:Int = 2;

			if (PlayState.chartingMode){
				menuItems.insert(shit, 'Leave Charting Mode');
				shit++;
			}
			
			menuItems.insert(shit, 'Skip To');
		}

		playMusic();
		regenMenu();
		regenInfo();
	}

	public function regenMenu()
	{
		menu.clear();

		var toAdd = new Map<String, AlphabetMenu.OptionCallbacks>();
		for (text in menuItems)
			toAdd.set(text, menuItemCallbacks.get(text));

		var addedItems = [for (text in menuItems){
			var textStringKey = 'pauseoption_${Paths.formatToSongPath(text)}';
			text => menu.addTextOption(
				Paths.hasString(textStringKey) ? Paths.getString(textStringKey) : text,
				toAdd.get(text)	
			);
		}];

		// fuck this thing
		if (addedItems.exists("Skip To")){
			if (skipTimeText == null){
				skipTimeText = new SkipTimeText();
				skipTimeText.controls = controls;
				add(skipTimeText);
			}

			var skipTimeItem = addedItems.get("Skip To");
			skipTimeText.item = skipTimeItem;
			
			var data = toAdd.get("Skip To");
			data.onSelect = skipTimeText.set_exists.bind(true);
			data.unSelect = skipTimeText.set_exists.bind(false);

		}else if (skipTimeText != null){
			remove(skipTimeText);
			skipTimeText.destroy();
			skipTimeText = null;
		}
	}

	private function regenInfo(){
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

			prevText.x = camera.width - (prevText.width + 20);

			allTexts.push(prevText);
			add(prevText);
		}

		if (PlayState.chartingMode){
			var chartingText:FlxText = new FlxText(camera.width, 0, 0, "CHARTING MODE", 32);
			chartingText.setFormat(Paths.font('vcr.ttf'), 32);
			chartingText.scrollFactor.set();
			chartingText.updateHitbox();

			chartingText.setPosition(
				camera.width - (chartingText.width + 20),
				camera.height - (chartingText.height + 20)
			);

			add(chartingText);

			chartingText.alpha = 0;
			FlxTween.tween(chartingText, {alpha: 1}, 0.4, {ease: FlxEase.quartInOut});
		}

		for (id in 0...allTexts.length)
		{
			var daText = allTexts[id];

			daText.y -= 5;
			FlxTween.tween(daText, {alpha: 1, y: daText.y + 5}, 0.4, {ease: FlxEase.quartInOut, startDelay: 0.3 * (id+1)});
		}
	}

	private var pauseMusic:FlxSound;
	private function playMusic(){
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
	}

	override function destroy(){
		pauseMusic.destroy();
		super.destroy();
	}
}

// lol
private class SkipTimeText extends AttachedFlxText{
	public var controls:Controls;
	public var item(default, set):Alphabet;
	public var curTime:Float = Math.max(0, Conductor.songPosition);

	public function new(){
		super();
		setFormat(Paths.font("vcr.ttf"), 64, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		scrollFactor.set();
		borderSize = 2;
		updateSkipTimeText();
	}

	function set_item(obj:Alphabet){
		sprTracker = obj;
		xAdd = obj.width + 60;
		return item = obj;
	}

	var holdTime:Float = 0.0;

	override function update(elapsed:Float){
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
		
		super.update(elapsed);
	}

	function updateSkipTimeText()
	{
		text = FlxStringUtil.formatTime(Math.max(0, Math.floor(curTime / 1000)), false) + ' / ' + FlxStringUtil.formatTime(Math.max(0, Math.floor(PlayState.instance.songLength / 1000)), false);
	}
}