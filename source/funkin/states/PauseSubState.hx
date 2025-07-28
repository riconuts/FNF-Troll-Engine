package funkin.states;

import funkin.data.MusicData;
import funkin.data.Song;
import funkin.data.PauseMenuOption;
import funkin.input.Controls;
import funkin.objects.hud.Countdown;
import funkin.states.options.OptionsSubstate;
import funkin.states.PlayState.instance as game;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxCamera;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxStringUtil;

class PauseSubState extends MusicBeatSubstate
{
	public static var instance:PauseSubState = null;
	public static var songName:Null<String> = null;

	public var bg:FlxSprite;
	public var menu:AlphabetMenu;

	private var menuOptions:Array<PauseMenuOption>;
	private var optionsMap:Map<String, PauseMenuOption>;
	private var curOption:PauseMenuOption = null; 

	private var allTexts:Array<FlxText>;

	public function newOption(name:String, ?onAccept:Void->Void) {
		var opt = new PauseMenuOption();
		opt.name = Paths.formatToSongPath(name);
		opt.displayName = Paths.getString('pauseoption_${opt.name}', name);
		opt.onAccept = onAccept;
		return opt;
	}

	public function pushOption(opt) {
		optionsMap.set(opt.name, opt);
		menuOptions.push(opt);
		return opt;
	}
	
	public function insertOption(idx:Int, opt) {
		optionsMap.set(opt.name, opt);
		menuOptions.insert(idx, opt);
		return opt;
	}

	public function indexOfOption(name:String):Int {
		name = Paths.formatToSongPath(name);
		return menuOptions.indexOf(optionsMap.get(name));
	}

	public function removeOption(name:String):Bool {
		name = Paths.formatToSongPath(name);

		if (optionsMap.exists(name)) {
			menuOptions.remove(optionsMap.get(name));
			optionsMap.remove(name);
			return true;
		}

		return false;
	}

	private function getOptions() {
		menuOptions = [];
		optionsMap = [];

		inline function newOpt(name:String , ?onAccept) {
			var opt = this.newOption(name, onAccept);
			return this.pushOption(opt);
		}

		newOpt("Resume", ()->{
			if (!ClientPrefs.countUnpause) {
				this.close();
				return;
			}

			if (game?.curCountdown?.finished == false) { // don't make a new countdown if there's already one in progress lol
				this.close();
				return;
			}
			
			for (obj in members) 
				obj.visible = false;

			menu.inputsActive = false;

			var c = new Countdown(game); // https://tenor.com/view/letter-c-darwin-tawog-the-amazing-world-of-gumball-dance-gif-17949158
			if (game != null) game.initCountdown(c);
			c.onComplete = this.close;
			c.cameras = this.cameras;
			c.start(0.5);
			add(c);
		});

		newOpt("Restart Song", ()->{
			if (FlxG.keys.pressed.SHIFT) {
				Paths.clearStoredMemory();
				Paths.clearUnusedMemory();
			}
			game.restartSong();
		});

		if (!PlayState.isStoryMode) {
			var songDifficulties = PlayState.song?.getCharts();
			if (songDifficulties != null && songDifficulties.length > 1) {
				newOpt("Change Difficulty", function(){
					function playChart(chartId:String){
						trace(chartId);
						PlayState.difficultyName = chartId;
						PlayState.SONG = PlayState.song.getSwagSong(chartId);
						MusicBeatState.switchState(new PlayState());
					}
					
					// lol not making a class for it
					var ss = new FlxSubState(FlxColor.fromRGBFloat(0.0, 0.0, 0.0, 0.6));

					var menu = new AlphabetMenu();
					menu.controls = controls;
					menu.cameras = cameras;
					ss.add(menu);

					for (chartId in songDifficulties) 
						menu.addTextOption(chartId, {onAccept: playChart.bind(chartId)});

					ss.add(new FlxSignalHolder(
						FlxG.signals.postUpdate, 
						function() {
							if (controls.BACK) {
								FlxG.sound.play(Paths.sound("cancelMenu"), 0.4);
								ss.close();
							}
						}
					));

					this.persistentUpdate = this.persistentDraw = false;
					this.openSubState(ss);

					//// ffffffffuuuuuuuuuuuuu
					@:privateAccess
					ss._bgSprite.cameras = cameras;

					menu.inputsActive = false;
					FlxG.signals.postUpdate.addOnce(()->{
						menu.inputsActive = true;
					});
				});
			}

			newOpt("Change Modifiers", ()->{
				this.persistentDraw = false;
				this.openSubState(new GameplayChangersSubstate());
			});
		}

		newOpt("Options", ()->{
			this.persistentDraw = false;
			var daSubstate = new OptionsSubstate();
			daSubstate.goBack = function(changedOptions:Array<String>) {
				var canResume:Bool = true;

				for (opt in changedOptions) {
					if (OptionsSubstate.requiresRestart.exists(opt)) {
						canResume = false;
						break;
					}
				}

				game.optionsChanged(changedOptions);
				FlxG.mouse.visible = false;

				closeSubState();
				if (!canResume && changedOptions.length > 0){
					removeOption("Resume");
					removeOption("Skip To");
					regenMenu();
				}

				for (camera in daSubstate.camerasToRemove)
					FlxG.cameras.remove(camera);
			};
			openSubState(daSubstate);
		});

		if (#if debug true #else PlayState.chartingMode #end) {
			////
			if (game.startedOnTime > 0) {
				newOpt('Restart on last start time', ()->{
					close();
					game.skipToTime(game.startedOnTime);
				});
			}

			////
			{
				var name = 'Skip to';
				var opt = new SkipTimeOption();
				opt.name = Paths.formatToSongPath(name);
				opt.displayName = Paths.getString('pauseoption_${opt.name}', name);
				pushOption(opt);
			}
	
			////
			inline function getBotplayTxt()
				return 'Botplay ${game.cpuControlled ? "ON" : "OFF"}';
			
			var opt = newOpt('Toggle botplay'); 
			opt.displayName = getBotplayTxt();
			opt.onAccept = ()->{
				game.cpuControlled = !game.cpuControlled;
				opt.text.set_text(getBotplayTxt());
			};
		}

		newOpt('Exit to menu', PlayState.gotoMenus);
	}

	private function getInfo():Array<String> {
		var songInfo:Array<String> = [];

		songInfo.push(game.displayedSong);

		for (info in Song.getMetadataInfo(game.metadata))
			songInfo.push(info);

		songInfo.push("Difficulty: " + game.displayedDifficulty.toUpperCase());		
		
		if (game.practiceMode)
			songInfo.push("PRACTICE MODE");
		else
			songInfo.push("Failed: " + PlayState.deathCounter); // i'd say blueballed but not every character blueballs + you straight up die in die batsards

		return songInfo;
	}

	override public function create()
	{
		instance = this;
		super.create();

		prevTimeScale = FlxG.timeScale;
		FlxG.timeScale = 1;

		FlxG.mouse.visible = false;
		persistentUpdate = false;

		var cam:FlxCamera = FlxG.cameras.list[FlxG.cameras.list.length - 1];
		this.cameras = [cam];

		bg = CoolUtil.blankSprite(FlxG.width, FlxG.height, 0xFF000000);
		bg.scrollFactor.set();
		bg.alpha = 0.0;
		add(bg);

		FlxTween.tween(bg, {alpha: 0.6}, 0.3, {ease: FlxEase.quartInOut});

		menu = new AlphabetMenu();
		menu.callbacks.onSelect = onSelectedOption;
		menu.callbacks.unSelect = unSelectedOption;
		menu.callbacks.onAccept = onAcceptedOption;
		menu.controls = controls;
		menu.cameras = cameras;
		add(menu);

		getOptions();
		regenMenu();
		regenInfo();
		playMusic();
	}

	override public function update(elapsed:Float) {
		if (curOption != null)
			curOption.update(elapsed);
		
		super.update(elapsed);

		if (controls.BACK)
			close();
	}

	public function onSelectedOption(id:Int, obj:Alphabet) {
		curOption = menuOptions[id];
		curOption.text = obj;
		curOption.select();
	}

	public function unSelectedOption(id:Int, obj:Alphabet) {
		if (menuOptions[id] == curOption) curOption = null;
		menuOptions[id].text = obj;
		menuOptions[id].unselect();
	}

	public function onAcceptedOption(id:Int, obj:Alphabet) {
		menuOptions[id].text = obj;
		menuOptions[id].accept();
	}

	public function regenMenu() {
		menu.clear();
		
		for (opt in menuOptions)
			menu.addTextOption(opt.displayName);
	}

	private function regenInfo() {
		allTexts = [];
		
		////
		final fieldPadding:Float = 20;
		final fieldWidth:Float = camera.width - fieldPadding * 2;
		final fieldTweenDuration:Float = 3/9; // 0.333
		final fieldTweenDelay:Float = 2/9; // 0.222

		for (i => str in getInfo()){
			var obj = new FlxText(fieldPadding, 15+32*i, fieldWidth, str, 32);
			obj.setFormat(Paths.font('vcr.ttf'), 32, 0xFFFFFFFF, RIGHT);
			obj.scrollFactor.set();
			obj.updateHitbox();
			obj.alpha = 0;

			allTexts.push(obj);
			add(obj);

			FlxTween.tween(obj, {alpha: 1, y: obj.y + 5}, fieldTweenDuration, {ease: FlxEase.quartInOut, startDelay: fieldTweenDelay * i});
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
			FlxTween.tween(chartingText, {alpha: 1}, 0.3, {ease: FlxEase.quartInOut});
		}
	}

	private var pauseMusic:FlxSound;
	private function playMusic(){
		pauseMusic = null;
		
		var songName:String = songName ?? 'Breakfast';
		if (songName == 'None') return;

		songName = Paths.formatToSongPath(songName);

		var md = MusicData.fromName(songName);
		if (md != null) {
			pauseMusic = md.makeFlxSound();
		}else {
			var sndPath = Paths.soundPath("music", songName);
			if (Paths.exists(sndPath)) {
				var loopTimePath = new haxe.io.Path(sndPath);
				loopTimePath.file += "-loopTime";
				loopTimePath.ext = "txt";

				var loopTime:Null<String> = Paths.getContent(loopTimePath.toString());
				var loopTime:Float = (loopTime == null) ? 0 : Std.parseFloat(loopTime);
				if (Math.isNaN(loopTime)) loopTime = 0;
				
				pauseMusic = new FlxSound();
				pauseMusic.context = MUSIC;
				pauseMusic.loadEmbedded(Paths.returnSound(sndPath));
				pauseMusic.loopTime = loopTime;
				pauseMusic.looped = true;
				FlxG.sound.list.add(pauseMusic);
			}
		}

		if (pauseMusic != null) {
			pauseMusic.volume = 0;
			pauseMusic.play(false, FlxG.random.int(0, Std.int(pauseMusic.length * 0.5)));
			pauseMusic.fadeIn(50, 0, 0.5);
		}else {
			trace('Pause music not found: $songName');
		}
	}

	var prevTimeScale:Float;
	override public function close(){
		FlxG.timeScale = prevTimeScale;
		super.close();
	}

	override function destroy() {
		if (instance == this) instance = null;
		pauseMusic.destroy();
		super.destroy();
	}
}

class SkipTimeOption extends PauseMenuOption
{
	public var curTime:Float = Math.max(0, Conductor.songPosition);
	public var songLength:Float = game.songLength;

	private var controls:Controls;
	private var holdTime:Float = 0.0;

	public function new() {
		super();
	}

	override function select() {
		@:privateAccess
		this.controls = PauseSubState.instance.controls;
		this.songLength = game.songLength;

		updateSkipTimeText();
	}

	override function accept() {
		PauseSubState.instance.close();
		game.skipToTime(curTime);
	}

	override function unselect() {
		text.set_text(this.displayName);
	}

	override function update(elapsed:Float){
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

		if (controls.UI_LEFT || controls.UI_RIGHT)
		{
			holdTime += elapsed;

			if (holdTime > 0.5)
				curTime += 45000 * elapsed * (controls.UI_LEFT ? -1 : 1) * speed;

			if (curTime < 0)
				curTime += songLength;
			else if (curTime >= songLength) 
				curTime -= songLength;
			
			updateSkipTimeText();
		}
	}

	function updateSkipTimeText() {
		var str = this.displayName + ': ' + formatTime(curTime) + ' / ' + formatTime(songLength);
		text.set_text(str);
	}

	static inline function formatTime(msTime:Float, showMS:Bool = false)
		return FlxStringUtil.formatTime(Math.max(0, Math.floor(msTime / 1000)), showMS);
}