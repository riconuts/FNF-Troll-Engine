package funkin;

#if !macro
import funkin.input.Controls.KeyboardScheme;
import flixel.util.FlxSave;
import flixel.input.keyboard.FlxKey;

#if discord_rpc
import funkin.api.Discord.DiscordClient;
#end

#end

enum OptionType
{
	Toggle;
	Dropdown;
	Number;
	Button;
}

typedef OptionData =
{
	display:String,
	desc:String,
	type:OptionType,
	?value:Dynamic,
	data:Map<String, Dynamic>,
}

#if !macro
@:build(funkin.macros.OptionMacro.build())
#end
class ClientPrefs
{
	#if !USE_EPIC_JUDGEMENT
	public static inline final useEpics:Bool = false;
	public static inline final epicWindow:Float = -1;
	#end

	#if !MULTICORE_LOADING
	public static inline final multicoreLoading:Bool = false;
	#end

	/*	
		* You can force the value of an option by declaring it outside of the option definitions
		* This will also remove it from the options menu.

		* For example:
		// public static inline final directionalCam = false;
		// public static inline final ghostTapping = false;
	*/

	static var defaultOptionDefinitions = getOptionDefinitions();
	inline public static function getOptionDefinitions():Map<String, OptionData>
	{
		return [
			// gameplay
			"controllerMode" => {
				display: "Controller Mode",
				desc: "When toggled, lets you play the game with a controller instead.",
				type: Toggle,
				value: false,
				data: []
			},
			"ghostTapping" => {
				display: "Ghost Tapping",
				desc: "When toggled, you won't get penalised for inputs which don't hit notes.",
				type: Toggle,
				value: true,
				data: []
			},
			"directionalCam" => {
				display: "Directional Camera",
				desc: "When toggled, the camera will move with the focused character's animations",
				type: Toggle,
				value: false,
				data: []
			},
			"bread" => {
				display: "Garlic Bread",
				desc: "Garlic Bread. You're welcome, Wolfy.",
				type: Toggle,
				value: false,
				data: []
			},
			"judgePreset" => {
				display: "Judgement Preset",
				desc: "Preset for the judgement windows.",
				type: Dropdown,
				value: "Standard",
                // V-Slice could be named PBOT1??
				data: [
					"requiresRestart" => true,
					"options" => ["Psych", "V-Slice", "Week 7", "Standard", "ITG", "Custom"]
				]
			},
			"judgeDiff" => {
				display: "Judge Difficulty",
				desc: "Stepmania difficulties for judgements. Lower numbers means looser hit windows, while higher numbers means tighter hit windows.\n For best results, use the Standard judgement preset.",
				type: Dropdown,
				value: "J4",
				data: [
					"requiresRestart" => true,
					"options" => ["J1","J2","J3","J4","J5","J6","J7","J8","JUSTICE"]
				]
			},
			"noteOffset" => {
				display: "Offset",
				desc: "How much to offset notes, song events, etc.",
				type: Number,
				value: 0,
				data: [
					"requiresRestart" => true,
					"min" => -1000, 
					"max" => 1000, 
					"step" => 1,
					"suffix" => "ms" 
				]
			},
			"ratingOffset" => {
				display: "Judgements Offset",
				desc: "How much to offset hit windows.",
				type: Number,
				value: 0,
				data: [
					"requiresRestart" => true,
					"min" => -100, 
					"max" => 100, 
					"step" => 1,
					"suffix" => "ms"
				]
			},
			"hitsoundVolume" => {
				display: "Hitsound Volume",
				desc: "The volume of hitsounds.",
				type: Number,
				value: 0,
				data: [
					"suffix" => "%",
					"min" => 0,
					"max" => 100,
					"step" => 1,
					"type" => "percent" // saved value is value / 100
				]
			},
			"missVolume" => {
				display: "Miss Volume",
				desc: "The volume of miss sounds.",
				type: Number,
				value: 1,
				data: [
					"suffix" => "%",
					"min" => 0,
					"max" => 100,
					"step" => 1,
					"type" => "percent" // saved value is value / 100
				]
			},
			"songVolume" => {
				display: "Music Volume",
				desc: "The volume of music.",
				type: Number,
				value: 1,
				data: [
					"suffix" => "%",
					"min" => 0,
					"max" => 100,
					"step" => 1,
					"type" => "percent" // saved value is value / 100
				]
			},
			"masterVolume" => {
				display: "Master Volume",
				desc: "The volume of the game.",
				type: Number,
				value: 1,
				data: [
					"suffix" => "%",
					"min" => 0,
					"max" => 100,
					"step" => 1,
					"type" => "percent" // saved value is value / 100
				]
			},
			"sfxVolume" => {
				display: "SFX Volume",
				desc: "The volume of the sound effects.",
				type: Number,
				value: 1,
				data: [
					"suffix" => "%",
					"min" => 0,
					"max" => 100,
					"step" => 1,
					"type" => "percent" // saved value is value / 100
				]
			},

			"flashing" => {
				display: "Flashing Lights",
				desc: "When toggled, flashing lights will be shown ingame.",
				type: Toggle,
				value: true,
				data: []
			},
			"camShakeP" => {
				display: "Camera Shaking",
				desc: "A multiplier to camera shake intensity.",
				type: Number,
				value: 1,
				data: [
					"suffix" => "%",
					"min" => 0,
					"max" => 100,
					"step" => 5,
					"type" => "percent" // saved value is value / 100
				]
			},
			"camZoomP" => {
				display: "Camera Zooming",
				desc: "A multiplier to camera zoom intensity.",
				type: Number,
				value: 1,
				data: [
					"suffix" => "%",
					"min" => 0,
					"max" => 100,
					"step" => 5,
					"type" => "percent" // saved value is value / 100
				]
			},
			// UI
			"timeBarType" => {
				display: "Time Bar",
				desc: "How to display the time bar",
				type: Dropdown,
				value: "Time Left",
				data: ["options" => ["Time Left", "Time Elapsed", "Percentage", "Song Name", "Disabled"]]
			},
			"hudOpacity" => {
				display: "HUD Opacity",
				desc: "How visible the HUD should be. 100% is fully visible and 0% is invisible.",
				type: Number,
				value: 1,
				data: [
					"suffix" => "%",
					"min" => 0,
					"max" => 100,
					"step" => 1,
					"type" => "percent" // saved value is value / 100
				]
			},
			"judgeOpacity" => {
				display: "Judgement Opacity",
				desc: "How visible the judgement, combo and timing displays should be. 100% is fully visible and 0% is invisible.",
				type: Number,
				value: 1,
				data: [
					"suffix" => "%",
					"min" => 0,
					"max" => 100,
					"step" => 1,
					"type" => "percent"
				]
			},
			"hpOpacity" => {
				display: "Health Bar Opacity",
				desc: "How visible the health bar should be. 100% is fully visible and 0% is invisible.",
				type: Number,
				value: 1,
				data: [
					"suffix" => "%",
					"min" => 0,
					"max" => 100,
					"step" => 1,
					"type" => "percent" // saved value is value / 100
				]
			},
			"timeOpacity" => {
				display: "Time Bar Opacity",
				desc: "How visible the time bar should be. 100% is fully visible and 0% is invisible.",
				type: Number,
				value: 1,
				data: [
					"suffix" => "%",
					"min" => 0,
					"max" => 100,
					"step" => 1,
					"type" => "percent" // saved value is value / 100
				]
			},
			"stageOpacity" => {
				display: "Stage Darkness",
				desc: "Darkens the stage by the specified amount. 100% is entirely dark, 0% is entirely bright.",
				type: Number,
				value: 0,
				data: [
					"suffix" => "%",
					"min" => 0,
					"max" => 100,
					"step" => 1,
					"type" => "percent" // saved value is value / 100
				]
			},
			"simpleJudge" => {
				display: "Alt Judgements",
				desc: "Makes judgements pop in alot simpler and displays only one at a time.",
				value: false,
				type: Toggle,
				data: []
			},
			"scoreZoom" => {
				display: "Zoom On Hit",
				desc: "When toggled, the HUD zooms when you hit a note.",
				type: Toggle,
				value: true,
				data: []
			},
			"customizeHUD" => {
				display: "Customize HUD Placements",
				desc: "Lets you customize where judgements and combo are displayed.",
				type: Button,
				data: []
			},
			"noteOpacity" => {
				display: "Note Opacity",
				desc: "How visible the notes and receptors should be. 100% is fully visible and 0% is invisible.",
				type: Number,
				value: 1,
				data: [
					"suffix" => "%",
					"min" => 0,
					"max" => 100,
					"step" => 1,
					"type" => "percent" // saved value is value / 100
				]
			},
			"holdSubdivs" => {
				display: "Hold Subdivisions",
				desc: "How many times each hold note should be subdivided. Higher numbers means more lag, but smoother holds.",
				type: Number,
				value: 2,
				data: [
					"min" => 1,
					"max" => 6,
					"step" => 1
				]
			},
			"optimizeHolds" => {
				display: "Optimize Holds",
				desc: "When toggled, hold notes will be less accurate, but they'll use less calls and thus less lag.",
				type: Toggle,
				value: true,
				data: []
			},
			"downScroll" => {
				display: "Downscroll",
				desc: "When toggled, notes will move from top to bottom instead of bottom to top.",
				type: Toggle,
				value: false,
				data: []
			},
			"midScroll" => {
				display: "Middlescroll",
				desc: "When toggled, notes will be centered.",
				type: Toggle,
				value: false,
				data: [#if !tgt "recommendsRestart" => true #end]
			},
			"wife3" => {
				display: "Wife3",
				desc: "When toggled, accuracy will be millisecond-based, using Etterna's Wife3 system, instead of judgement-based.",
				type: Toggle,
				value: false,
				data: ["requiresRestart" => true]
			},
			"showWifeScore" => {
				display: "Accuracy Score Display",
				desc: "When toggled, the score will be displayed as the internal accuracy score, instead of the normal judgement-based scoring.\nOnly really useful on Wife3.",
				type: Toggle,
				value: false,
				data: []
			},
			"noteSplashes" => {
				display: "Note Splashes",
				desc: "When toggled, hitting top judgements will cause particles to spawn.",
				type: Toggle,
				value: true,
				data: []
			},
			"noteSkin" => {
				display: "Note Colours",
				desc: "Changes how notes get their colours. Column bases it on direction, Quants bases it on beat.",
				type: Dropdown,
				value: "Column",
				data: ["requiresRestart" => true, "options" => ["Column", "Quants"]]
			},
			"coloredCombos" => {
				display: "Colored Combos",
				desc: "When toggled, combo numbers are colored based on the FC.", // Sorry I'm bad at descriptions. < its fine lol
				type: Toggle,
				value: false,
				data: []
			},
			"worldCombos" => {
				display: "World Combos",
				desc: "When toggled, combo sprites are placed on the stage instead of the HUD."
				+ '\nDoesn'+"'"+'t work with "Alt Judgements" enabled.',
				type: Toggle,
				value: false,
				data: []
			},
			"showMS" => {
				display: "Show Timing",
				desc: "When toggled, upon hitting a note it will show the millisecond timing.",
				type: Toggle,
				value: false,
				data: []
			},
			"hitbar" => {
				display: "Show Error Bar",
				desc: "When toggled, a bar will be shown that marks note hit timings.", // TODO rewrite this desc
				type: Toggle,
				value: false,
				data: []
			},
			"npsDisplay" => {
				display: "NPS Display",
				desc: "When toggled, the amount of notes you hit per second is displayed in the HUD.",
				type: Toggle,
				value: false,
				data: []
			},
			"gradeSet" => {
				display: "Grade Set",
				desc: "What set of grades to use to rank performance ingame. Does not affect scores",
				type: Dropdown,
				value: "Psych",
				data: [
					"options" => {
						var arr:Array<String> = [for (key in funkin.data.Highscore.grades.keys()) key];
						arr.reverse(); // for some reason keys() returns the map.. backwards
						arr;
					}
				]
			},
			"etternaHUD" => {
				display: "HUD Style",
				desc: "Changes how the HUD looks.",
				type: Dropdown,
				value: "Default",
				data: [
					"recommendsRestart" => true,
					"options" => ["Default", "Advanced", "Kade"]
				]
			},

			"judgeCounter" => {
				display: "Judgement Counter",
				desc: "How to display the judgement counters.",
				type: Dropdown,
				value: "Off",
				data: [
					"recommendsRestart" => true,
					"options" => ["Off", "Shortened", "Full"]
				]
			},
			"hudPosition" => {
				display: "HUD Position",
				desc: "Where to position HUD elements.",
				type: Dropdown,
				value: "Left",
				data: [
					"recommendsRestart" => true, 
					"options" => ["Left", "Right"]
				]
			},
			//// judgement-related (gameplay)
			"useEpics" => {
				display: "Use Epics",
				desc: "When toggled, epics will be used as the highest judgement.",
				type: Toggle,
				value: false,
				data: ["requiresRestart" => true]
			},
			"epicWindow" => {
				display: "Epic Window",
				desc: "The hit window to hit an Epic judgement.",
				type: Number,
				value: 22,
				data: ["requiresRestart" => true, "suffix" => "ms", "min" => 0, "max" => 200, "step" => 0.1]
			},
			"sickWindow" => {
				display: "Sick Window",
				desc: "The hit window to hit a Sick judgement.",
				type: Number,
				value: 45,
				data: ["requiresRestart" => true, "suffix" => "ms", "min" => 0, "max" => 200, "step" => 0.1]
			},
			"goodWindow" => {
				display: "Good Window",
				desc: "The hit window to hit a Good judgement.",
				type: Number,
				value: 90,
				data: ["requiresRestart" => true, "suffix" => "ms", "min" => 0, "max" => 200, "step" => 0.1]
			},
			"badWindow" => {
				display: "Bad Window",
				desc: "The hit window to hit a Bad judgement.",
				type: Number,
				value: 135,
				data: ["requiresRestart" => true, "suffix" => "ms", "min" => 0, "max" => 200, "step" => 0.1]
			},
			"hitWindow" => {
				display: "Max Hit Window",
				desc: "The hit window to hit notes at all",
				type: Number,
				value: 180,
				data: ["requiresRestart" => true, "suffix" => "ms", "min" => 0, "max" => 200, "step" => 0.1]
			},

			////
			"drawDistanceModifier" => {
				display: "Draw Distance Multiplier",
				desc: "Changes how close or far a note must be before it starts being drawn.",
				type: Number,
				value: 1,
				data: ["suffix" => "x", "min" => 0.5, "max" => 2, "step" => 0.1]
			},
			"customizeColours" => {
				display: "Customize Colors",
				desc: "Lets you change the colours of your notes.",
				type: Button,
				data: []
			},
			// video
			"shaders" => {
				display: "Shaders",
				desc: "Changes which shaders can load.",
				type: Dropdown,
				value: "All",
				data: [
					"recommendsRestart" => true,
					"options" => ["All", "Minimal", "None"]
				]
			},
			"showFPS" => {
				display: "Show FPS",
				desc: "When toggled, an FPS counter is showed in the top left.",
				type: Toggle,
				value: true,
				data: []
			},
			"framerate" => {
				display: "Max Framerate",
				desc: "The highest framerate the game can hit.",
				type: Number,
				value: #if !macro FlxG.stage!=null ? FlxG.stage.application.window.displayMode.refreshRate : #end 60,
				data: ["suffix" => " FPS", "min" => 30, "max" => 240, "step" => 1,]
			},
			"lowQuality" => {
				display: "Low Quality",
				desc: "When toggled, many assets won't be loaded to try to reduce strain on lower-end PCs.",
				type: Toggle,
				value: false,
				data: ["recommendsRestart" => true]
			},
			"globalAntialiasing" => {
				display: "Antialiasing",
				desc: "When toggled, sprites are able to be antialiased.",
				type: Toggle,
				value: true,
				data: []
			},
			"multicoreLoading" => {
				display: "Multicore Loading",
				desc: "When toggled, multiple threads will be used for asset loading when possible.\nMay cause crashes, but speeds up load times.",
				type: Toggle,
				value: false,
				data: []
			},
			"modcharts" => {
				display: "Modcharts",
				desc: "When toggled, modcharts will be used on some songs.\nWARNING: Disabling modcharts on modcharted songs will disable scoring!",
				type: Toggle,
				value: true,
				data: ["requiresRestart" => true]
			},
			#if tgt
			"ruin" => {
				display: "Ruin The Mod",
				desc: "Makes the mod really good! improves the mod alot!! the name is a joke guys it makes the mod REALLY REALLY good its not blammed lights i swear",
				type: Toggle,
				value: false,
				data: ["recommendsRestart" => true]
			},
			#end
			"customizeKeybinds" => {
				display: "Customize Key Bindings",
				desc: "Lets you change your controls. Pretty straight forward, huh?",
				type: Button,
				data: []
			},

			//
			"discordRPC" => {
				display: "Discord Rich Presence",
				desc: "Toggles Discord Rich Presence.",
				type: Toggle,
				value: true,
				data: []
			},
			
			// updating
			"downloadBetas" => {
				display: "Download Betas",
				desc: "Lets the engine's auto-updater prompt you to update to beta versions of the engine when available.\nNOTE: While on a beta build, this will always be on, regardless of this option.",
				type: Toggle,
				value: false,
				data: []
			},
			"checkForUpdates" => {
				display: "Check for Updates",
				desc: "Lets the engine's auto-updater check for engine updates and prompt you to update when available.",
				type: Toggle,
				value: true,
				data: []
			}
			
		];
	}

	#if !macro
	public static var gameplaySettings:Map<String, Dynamic> = [
		'scrollspeed' => 1.0,
		'scrolltype' => 'multiplicative',
		// anyone reading this, amod is multiplicative speed mod, cmod is constant speed mod, and xmod is bpm based speed mod.
		// an amod example would be chartSpeed * multiplier
		// cmod would just be constantSpeed = chartSpeed
		// and xmod basically works by basing the speed on the bpm.
		// iirc (beatsPerSecond * (conductorToNoteDifference / 1000)) * noteSize (110 or something like that depending on it, prolly just use note.height)
		// bps is calculated by bpm / 60
		// oh yeah and you'd have to actually convert the difference to seconds which I already do, because this is based on beats and stuff. but it should work
		// just fine. but I wont implement it because I don't know how you handle sustains and other stuff like that.
		// oh yeah when you calculate the bps divide it by the songSpeed or rate because it wont scroll correctly when speeds exist.
		'songspeed' => 1.0,
		'healthgain' => 1.0,
		'healthloss' => 1.0,
		'instakill' => false,
		'practice' => false,
		'perfect' => false,
		'instaRespawn' => false,
		'botplay' => false,
		'opponentplay' => false
	];

	inline public static function getGameplaySetting(name:String, defaultValue:Dynamic):Dynamic
	{
		return (gameplaySettings.exists(name) ? gameplaySettings.get(name) : defaultValue);
	}

	public static var quantHSV:Array<Array<Int>> = [
		[0, 0, 0], // 4th
		[-100, 0, 0], // 8th
		[-80, -20, 0], // 12th
		[120, 0, 0], // 16th
		[-120, -70, -35], // 20th
		[-80, -20, 0], // 24th
		[50, -10, 0], // 32nd
		[-80, -20, 0], // 48th
		[160, -15, 0], // 64th
		[-120, -70, -35], // 96th
		[-120, -70, -35] // 192nd
	];

	//
	public static var arrowHSV:Array<Array<Int>> = [[0, 0, 0], [0, 0, 0], [0, 0, 0], [0, 0, 0]];
	/**
		[0] and [1] for ratings.
		[2] and [3] for combo numbers.
		[4] and [5] for miliseconds.
	**/
	public static var comboOffset:Array<Int> = [
		-60, 60, 
		-260, -80,
		 0, 0
	];

    public static var locale:String = 'en';

	// I'd like to rewrite the whole Controls.hx thing tbh
	// I think its shitty and can stand a rewrite but w/e
	// later
	public static var keyBinds:Map<String, Array<FlxKey>> = [
		'note_left' => [A, LEFT],
		'note_down' => [S, DOWN],
		'note_up' => [W, UP],
		'note_right' => [D, RIGHT],
		'dodge' => [SPACE],
		'ui_left' => [A, LEFT],
		'ui_down' => [S, DOWN],
		'ui_up' => [W, UP],
		'ui_right' => [D, RIGHT],
		'accept' => [SPACE, ENTER],
		'back' => [ESCAPE, BACKSPACE],
		'pause' => [ENTER, ESCAPE],
		'reset' => [R, NONE],
		'volume_mute' => [ZERO, NONE],
		'volume_up' => [NUMPADPLUS, PLUS],
		'volume_down' => [NUMPADMINUS, MINUS],
		'fullscreen' => [F11, NONE],
		'debug_1' => [SEVEN, NONE],
		'debug_2' => [EIGHT, NONE],
		'botplay' => [F6, NONE]
	];
	public static var defaultKeys:Map<String, Array<FlxKey>> = null;

	public static function loadDefaultKeys()
	{
		defaultKeys = keyBinds.copy();
		// trace(defaultKeys);
	}

	static var optionSave:FlxSave = new FlxSave();

	static var manualLoads = ["gameplaySettings", "quantHSV", "arrowHSV", "comboOffset"];

	public static function initialize(){
		defaultOptionDefinitions.get("framerate").value = FlxG.stage.application.window.displayMode.refreshRate;
		#if MULTILANGUAGE
		locale = openfl.system.Capabilities.language;
		#end

		optionSave.bind("options_v2");
		loadDefaultKeys();
    }
	

	public static function save(?definitions:Map<String, OptionData>)
	{
		if (definitions != null)
		{
			for (key => val in definitions){
				if (val.type == Number && val.data.exists("type") && val.data.get("type") == 'percent')
					Reflect.setField(optionSave.data, key, val.value / 100);
				else
					Reflect.setField(optionSave.data, key, val.value);

			}
		}
		else
			for (name in options)
				Reflect.setField(optionSave.data, name, Reflect.field(ClientPrefs, name));

		
		// some dumb hardcoded saves
		for (name in manualLoads)
			Reflect.setField(optionSave.data, name, Reflect.field(ClientPrefs, name));

		optionSave.flush();

		saveBinds();
	}

	public static function saveBinds(){
		var save:FlxSave = new FlxSave();
		save.bind('controls_v2'); // Placing this in a separate save so that it can be manually deleted without removing your Score and stuff
		save.data.customControls = keyBinds;
		save.close();
	}

	public static function loadBinds()
	{
		var save:FlxSave = new FlxSave();
		save.bind('controls_v2');
		if (save != null && save.data.customControls != null)
		{
			var loadedControls:Map<String, Array<FlxKey>> = save.data.customControls;
			for (control => keys in loadedControls)
				keyBinds.set(control, keys);

			reloadControls();
		}
		save.destroy();
	}

	public static function load()
	{
		for (name in options){
			if (Reflect.field(optionSave.data, name)!=null)
				Reflect.setField(ClientPrefs, name, Reflect.field(optionSave.data, name));
			else
				Reflect.setField(ClientPrefs, name, ClientPrefs.defaultOptionDefinitions.get(name).value);
		}

		if (optionSave.data.gameplaySettings != null)
		{
			var savedMap:Map<String, Dynamic> = optionSave.data.gameplaySettings;
			for (name => value in savedMap)
			{
				gameplaySettings.set(name, value);
			}
		}

		// some dumb hardcoded saves
		loadBinds();

		for (name in manualLoads)
			if (Reflect.field(optionSave.data, name) != null)
				Reflect.setField(ClientPrefs, name, Reflect.field(optionSave.data, name));

		if (Main.fpsVar != null)
			Main.fpsVar.visible = ClientPrefs.showFPS;

		if (Main.bread != null)
			Main.bread.visible = ClientPrefs.bread;

		FlxSprite.defaultAntialiasing = ClientPrefs.globalAntialiasing;
		FlxG.stage.quality = ClientPrefs.globalAntialiasing ? openfl.display.StageQuality.BEST : openfl.display.StageQuality.LOW; // does nothing!!!!

		#if discord_rpc
		discordRPC ? DiscordClient.start() : DiscordClient.shutdown();	
		#end

		if (framerate > FlxG.drawFramerate)
		{
			FlxG.updateFramerate = Math.floor(framerate);
			FlxG.drawFramerate = Math.floor(framerate);
		}
		else
		{
			FlxG.drawFramerate = Math.floor(framerate);
			FlxG.updateFramerate = Math.floor(framerate);
		}

		Main.downloadBetas = Main.beta || ClientPrefs.downloadBetas;

	}

	public static function reloadControls()
	{
		funkin.input.PlayerSettings.player1.controls.setKeyboardScheme(KeyboardScheme.Solo);

		StartupState.muteKeys = copyKey(keyBinds.get('volume_mute'));
		StartupState.volumeDownKeys = copyKey(keyBinds.get('volume_down'));
		StartupState.volumeUpKeys = copyKey(keyBinds.get('volume_up'));
		StartupState.fullscreenKeys = copyKey(keyBinds.get("fullscreen"));
	}

	public static function copyKey(arrayToCopy:Array<FlxKey>):Array<FlxKey>
	{
		var copiedArray:Array<FlxKey> = arrayToCopy.copy();
		var i:Int = 0;
		var len:Int = copiedArray.length;

		while (i < len)
		{
			if (copiedArray[i] == NONE)
			{
				copiedArray.remove(NONE);
				--i;
			}
			i++;
			len = copiedArray.length;
		}
		return copiedArray;
	}
	#end
}