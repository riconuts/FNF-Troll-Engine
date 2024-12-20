package funkin.states;

import funkin.data.PauseMenuOption;
import funkin.input.Controls;
import funkin.states.options.OptionsSubstate;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxCamera;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
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
			if (ClientPrefs.countUnpause) {
				var gameCnt = PlayState.instance==null ? null : PlayState.instance.curCountdown;
				if (gameCnt != null && !gameCnt.finished) // don't make a new countdown if there's already one in progress lol
					return this.close();
				
				for (obj in members) 
					obj.visible = false;

				menu.inputsActive = false;

				var c = new Countdown(this); // https://tenor.com/view/letter-c-darwin-tawog-the-amazing-world-of-gumball-dance-gif-17949158
				c.onComplete = this.close;
				c.start(0.5);

			}else {
				this.close(); // close immediately
			} 
		});

		newOpt("Restart Song", ()->{
			if (FlxG.keys.pressed.SHIFT) {
				Paths.clearStoredMemory();
				Paths.clearUnusedMemory();
			}
			PlayState.instance.restartSong();
		});

		if (!PlayState.isStoryMode) {
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

				PlayState.instance.optionsChanged(changedOptions);
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
			if (PlayState.chartingMode) {
				newOpt("Leave charting mode", ()->{
					var songName:String = PlayState.SONG.song;
					var jsonName:String;
		
					if (PlayState.difficultyName == "")
						jsonName = songName; 
					else
						jsonName = songName + '-' + PlayState.difficultyName;
		
					PlayState.SONG = funkin.data.Song.loadFromJson(jsonName, songName);
					PlayState.chartingMode = false;
					PlayState.instance.restartSong();
				});	
			}

			////
			if (PlayState.instance.startedOnTime > 0) {
				newOpt('Restart on last start time', ()->{
					close();
					PlayState.instance.skipToTime(PlayState.instance.startedOnTime);
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
			newOpt('End song', ()->{
				close();
				PlayState.instance.finishSong(true);
			});
	
			////
			inline function getBotplayTxt()
				return 'Botplay ${PlayState.instance.cpuControlled ? "ON" : "OFF"}';
			
			var opt = newOpt('Toggle botplay'); 
			opt.displayName = getBotplayTxt();
			opt.onAccept = ()->{
				PlayState.instance.cpuControlled = !PlayState.instance.cpuControlled;
				opt.text.changeText(getBotplayTxt());
			};
		}

		newOpt('Exit to menu', PlayState.gotoMenus);
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

		bg = new FlxSprite(FlxG.width / 2 - 1, FlxG.height / 2 -1).makeGraphic(2, 2);
		bg.scale.set(FlxG.width, FlxG.height);
		bg.scrollFactor.set();
		bg.color = 0xFF000000;
		bg.alpha = 0.0;
		add(bg);

		FlxTween.tween(bg, {alpha: 0.6}, 0.4, {ease: FlxEase.quartInOut});

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
		////
		var game = PlayState.instance;
		var metadata = game.metadata;
		var songInfo:Array<String> = [];

		function pushInfo(str:String) {
			for (string in str.split('\n'))
				songInfo.push(string);
		}

		songInfo.push(game.displayedSong);

		if (metadata != null){
			if (metadata.artist != null && metadata.artist.length > 0)		
				pushInfo("Artist: " + metadata.artist);

			if(metadata.charter != null && metadata.charter.length > 0)
				pushInfo("Chart: " + metadata.charter);

			if(metadata.modcharter != null && metadata.modcharter.length > 0)
				pushInfo("Modchart: " + metadata.modcharter);
		}

		if (PlayState.SONG != null && PlayState.SONG.info != null)
			for (extraInfo in PlayState.SONG.info)
				pushInfo(extraInfo);
		
		if (metadata != null && metadata.extraInfo!=null){
			for(extraInfo in metadata.extraInfo)
				pushInfo(extraInfo);
		}

		songInfo.push("Difficulty: " + game.displayedDifficulty.toUpperCase());		
		songInfo.push("Failed: " + PlayState.deathCounter); // i'd say blueballed but not every character blueballs + you straight up die in die batsards
		// removed the practice clause cus its just nice to have the counter lol

		////
		allTexts = [];
		var fieldX:Float = 20;
		var fieldWidth:Float = FlxG.width - 40;

		for (i => str in songInfo){
			var obj = new FlxText(fieldX, 15+32*i, fieldWidth, str, 32);
			obj.setFormat(Paths.font('vcr.ttf'), 32, 0xFFFFFFFF, RIGHT);
			obj.scrollFactor.set();
			obj.updateHitbox();
			obj.alpha = 0;

			allTexts.push(obj);
			add(obj);

			FlxTween.tween(obj, {alpha: 1, y: obj.y + 5}, 0.4, {ease: FlxEase.quartInOut, startDelay: 0.3 * (i+1)});
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
			
			var loopTimePath = new haxe.io.Path(Paths.soundPath("music", songName));
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
	public var songLength:Float = PlayState.instance.songLength;

	private var controls:Controls;
	private var holdTime:Float = 0.0;

	public function new() {
		super();
	}

	override function select() {
		@:privateAccess
		this.controls = PauseSubState.instance.controls;
		this.songLength = PlayState.instance.songLength;

		updateSkipTimeText();
	}

	override function accept() {
		PauseSubState.instance.close();
		PlayState.instance.skipToTime(curTime);
	}

	override function unselect() {
		text.changeText(this.displayName);
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
		text.changeText(str);
	}

	static inline function formatTime(msTime:Float, showMS:Bool = false)
		return FlxStringUtil.formatTime(Math.max(0, Math.floor(msTime / 1000)), showMS);
}