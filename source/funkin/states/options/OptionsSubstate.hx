package funkin.states.options;

import funkin.CoolUtil.overlapsMouse as overlaps;
import funkin.states.options.*;
import funkin.ClientPrefs;

import flixel.graphics.FlxGraphic;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.addons.ui.FlxUI9SliceSprite;
import openfl.geom.Rectangle;

using funkin.data.FlxTextFormatData;

#if DISCORD_ALLOWED
import funkin.api.Discord;
#end

typedef Widget = {
	type:OptionType,
	optionData:OptionData,
	locked:Bool,
	data:Map<String, Dynamic>,
}

class OptionsSubstate extends MusicBeatSubstate
{
	// for scripting
	public static final requiresRestart:Map<String, Bool> = [];
	public static final recommendsRestart:Map<String, Bool> = [];

	static var optionOrder:Array<String> = [
		"game",
		"ui",
		"video",
		"controls",
		"misc", 
	];

	static var options:Map<String, Array<Dynamic>> = [
		// maps are annoying and dont preserve order so i have to do this
		"game" => [
			[
				"gameplay", 
				[
					"downScroll",
					"midScroll",
					"ghostTapping", 
					"directionalCam", 
					"noteOffset", 
					"ratingOffset",
				]
			],
			[
				"audio", 
				[
					"masterVolume",
					"songVolume",
					'sfxVolume',
					"hitsoundVolume", 
					"missVolume",
					#if tgt "ruin", #end
				]
			],
			[
				"advanced",
				[
					"accuracyCalc",
					"judgePreset",
					#if USE_EPIC_JUDGEMENT
					"useEpics",
					"epicWindow",
					#end
					"sickWindow",
					"goodWindow",
					"badWindow",
					"hitWindow",
					"judgeDiff", // fuck you pedophile
				]
			]
		],
		"ui" => [
			[
				"notes",
				[
					"noteOpacity",
					"downScroll",
					"midScroll",
					"noteSplashes",
					"noteSkin",
					"customizeColours"
				]
			],
			[
				"hud",
				[
					"timeBarType", 
					"hudOpacity", 
					"hpOpacity", 
					"timeOpacity", 
					"judgeOpacity",
					"stageOpacity", 
					"scoreZoom", 
					"npsDisplay", 
					"hitbar", 
					"showMS", 
					"coloredCombos",
					'worldCombos',
					"simpleJudge",
					"judgeCounter", 
					'hudPosition', 
					"customizeHUD",
				]
			],
			[
				"advanced", 
				[
					"etternaHUD", 
					"gradeSet",
					"showWifeScore"
				]
			]
		],
		"video" => [
			["video", ["shaders", "showFPS"]],
			["display", ["framerate", "bread"]],
			[
				"performance",
				[
					"lowQuality",
					"globalAntialiasing",
					"multicoreLoading",
					"optimizeHolds",
					"holdSubdivs",
					"drawDistanceModifier" // apparently i forgot to add this in the new options thing lmao
				]
			]
		],
		"controls" => [
			[
				"keyboard", ["customizeKeybinds",]
			], 
			[
				"controller", ["controllerMode",] // TODO customize binds for controllers
			]
		],
		
		"misc" => [
			[
				"accessibility",
				[
					"autoPause",
					"countUnpause",
					"modcharts",
					"flashing",
					"camShakeP",
					"camZoomP",
				]
			],
			#if DISCORD_ALLOWED
			["discord", ["discordRPC"]],
			#end
			#if DO_AUTO_UPDATE
			[
				"updating", 
				[
					"checkForUpdates", 
					"downloadBetas"
				]
			],
			#end
		],
	];

	static inline function epicWindowVal(val:Float)
		#if USE_EPIC_JUDGEMENT
		return val;
		#else 
		return -1; 
		#end
	
	static var windowPresets:Map<String, Array<Float>> = [
		"Standard" => [epicWindowVal(22.5), 45, 90, 135, 180],
		"Week 7" => [
			-1,		// epic (-1 to disable)
			33,		// sick
			125,	// good
			150,	// bad
			166		// shit / max hit window
		],
		#if USE_EPIC_JUDGEMENT
		"PBot" => [epicWindowVal(12.5), 45, 90, 135, 160],
		#end
		"V-Slice" => [-1, 45, 90, 135, 160], // pbot1 without epics
		"Psych" => [-1, 45, 90, 135, 166],
		"ITG" => [epicWindowVal(21), 43, 102, 135, 180]
	];

	////

	public static function resetRestartRecomendations()
	{
		requiresRestart.clear();
		recommendsRestart.clear();
	}

	var changed:Array<String> = [];
	var originalValues:Map<String, Dynamic> = [];

	public var goBack:(Array<String>)->Void;
	public function save(){
		ClientPrefs.save(actualOptions);
		funkin.data.Highscore.loadData();
	}
	
	function windowsChanged()
	{
		var windows = ["badWindow", "goodWindow", "sickWindow"];

		#if USE_EPIC_JUDGEMENT if (getToggle("useEpics"))
			windows.push("epicWindow");
		else #end 
			actualOptions.get("sickWindow").data.set("min", 0);

		for (idx in 0...windows.length - 1)
		{
			var w = windows[idx];
			var n = windows[idx + 1];
			actualOptions.get(w).data.set("min", actualOptions.get(n).value);
			actualOptions.get(w).data.set("max", actualOptions.get("hitWindow").value);
			actualOptions.get(n).data.set("max", actualOptions.get("hitWindow").value);
		}
	}

	function checkWindows()
	{
		var didChange:Bool = false;

		#if USE_EPIC_JUDGEMENT
		actualOptions.get("epicWindow").data.set("locked", !getToggle("useEpics"));
		#end

		var compareWindow = [
			#if USE_EPIC_JUDGEMENT
			getToggle("useEpics") ? getNumber("epicWindow") : -1,
			#else
			-1,
			#end
			getNumber("sickWindow"),
			getNumber("goodWindow"),
			getNumber("badWindow"),
			getNumber("hitWindow")
		];

		for (name => windows in windowPresets)
		{	
			var isPreset:Bool = true;

			for (idx in 0...compareWindow.length){
				var preset = CoolUtil.snap(windows[idx], 0.1);
				var custom = CoolUtil.snap(compareWindow[idx], 0.1);
				
				if (preset != custom){
					isPreset = false;
					break;
				}
			}

			if (isPreset){
				changeDropdown("judgePreset", name);
				didChange = true;
				break;
			}
		}
		if (!didChange)
			changeDropdown("judgePreset", "Custom");

		windowsChanged();
	}

	function onDropdownChanged(option:String, oldVal:String, newVal:String)
	{
		switch (option)
		{
			case 'judgePreset':
				if (windowPresets.exists(newVal))
				{
					var windows = windowPresets.get(newVal);

					#if USE_EPIC_JUDGEMENT
					changeToggle("useEpics", windows[0] != -1);
					if (windows[0] != -1)
						changeNumber("epicWindow", windows[0], true);
					#end

					changeNumber("sickWindow", windows[1], true);
					changeNumber("goodWindow", windows[2], true);
					changeNumber("badWindow", windows[3], true);
					changeNumber("hitWindow", windows[4], true);

					windowsChanged();
				}
			default:
				// nothing
		}
	}

	function onToggleChanged(option:String, val:Bool)
	{
		switch (option)
		{
			case 'useEpics':
				checkWindows();
			case 'showFPS':
				if (Main.fpsVar != null)
					Main.fpsVar.visible = val;
			case 'bread':
				if (Main.bread != null)
					Main.bread.visible = val;
			case 'globalAntialiasing':
				FlxSprite.defaultAntialiasing = val;
				FlxG.stage.quality = val ? BEST : LOW; // does nothing!!!!
				
			#if(DO_AUTO_UPDATE || display)
			case 'downloadBetas' | 'checkForUpdates':
				Main.downloadBetas = Main.Version.isBeta || ClientPrefs.downloadBetas;
				if (!Main.Version.isBeta || option == 'checkForUpdates'){
					UpdaterState.getRecentGithubRelease();
					UpdaterState.checkOutOfDate();
				}
			#end
			#if DISCORD_ALLOWED
			case 'discordRPC':
				val ? DiscordClient.start(true) : DiscordClient.shutdown(true);
			#end
			case 'autoPause':
				FlxG.autoPause = val;
			default:
				// nothing
		}
	}

	function onButtonPressed(option:String)
	{
		switch (option)
		{
			case 'customizeHUD':
				if ((_parentState is OptionsState) && !FlxG.keys.pressed.SHIFT)
					LoadingState.loadAndSwitchState(new NoteOffsetState());
				else{
					openSubState(new ComboPositionSubstate(!optState ? 0x0 : Math.floor(0xFF * ClientPrefs.stageOpacity) * 0x1000000));
					
					this.persistentDraw = false;
					this.subStateClosed.addOnce((_) -> this.persistentDraw = true);
				}
			case 'customizeColours':
				var noteState = new NotesSubState();
				openSubState(noteState);

				subStateClosed.addOnce((ss) -> {
					if (ss == noteState /*&& noteState.changedAnything*/)  
						changed.push('customizeColours');
				});

			case 'customizeKeybinds':
				var substate:Dynamic = ClientPrefs.controllerMode ? new ButtonBindsSubstate() : new KeyBindsSubstate();
				var bindsMap:Map<String, Array<Int>> = ClientPrefs.controllerMode ? ClientPrefs.buttonBinds : ClientPrefs.keyBinds;
				
				var currentBinds:Map<String, Array<Int>> = [];
				for (key in bindsMap.keys())
					currentBinds.set(key, bindsMap[key].copy());
					
				substate.changedBind = (action:String, index:Int, newBind:Int) -> {
					var daId = '${action}${index}-bind';
					
					trace(daId, currentBinds.get(action)[index], newBind, currentBinds.get(action)[index] == newBind);
					
					if (currentBinds.get(action)[index] == newBind)
						changed.remove(daId);
					else if (!changed.contains(daId))
						changed.push(daId);
				}

				openSubState(substate);
			default:
				// nothing
		}
	}

	private var previewSound:Null<FlxSound> = null;
	function playPreviewSound(name:String, volume:Float = 1){
		if (previewSound != null) previewSound.stop().destroy();
		previewSound = FlxG.sound.play(Paths.sound(name), volume, false, null, true, ()->{previewSound = null;});
		previewSound.context = MISC;
	}

	private var lastFlixelVolume:Float = CoolUtil.snap(FlxG.sound.volume, 0.1);
	function onNumberChanged(option:String, oldVal:Float, newVal:Float)
	{
		switch (option)
		{
			case 'framerate':
				if (newVal > FlxG.drawFramerate){
					FlxG.updateFramerate = Math.floor(newVal);
					FlxG.drawFramerate = Math.floor(newVal);
				}else{
					FlxG.drawFramerate = Math.floor(newVal);
					FlxG.updateFramerate = Math.floor(newVal);
				}
			case 'epicWindow' | 'sickWindow' | 'goodWindow' | 'badWindow' | 'hitWindow':
				checkWindows();

			case 'masterVolume':
				if (ignoreVolumeChange) return;

				var prevVol = FlxG.sound.volume;
				var newVol = newVal * 0.01;
				var snappedVol = CoolUtil.snap(newVol, 0.1);

				ignoreVolumeChange = true;
				FlxG.sound.volume = newVol;
				ignoreVolumeChange = false;

				if (lastFlixelVolume != snappedVol) {
					lastFlixelVolume = snappedVol;
					FlxG.sound.showSoundTray(snappedVol > prevVol);
				}

			case 'sfxVolume':
				playPreviewSound("scrollMenu", newVal * 0.01);
			case 'missVolume':
				playPreviewSound('missnote${1+Std.random(3)}', newVal * 0.01);
			case 'hitsoundVolume':
				playPreviewSound("hitsound", newVal * 0.01);
		}
	}

	var selected:Int = 0;
	var forceWidgetUpdate:Bool = false;

	var buttons:Array<FlxSprite> = [];
	var currentWidgets:Map<FlxObject, Widget> = [];
	var currentGroup:FlxTypedGroup<FlxObject>;
	var groups:Map<String, FlxTypedGroup<FlxObject>> = [];
	var allWidgets:Map<String, Map<FlxObject, Widget>> = [];
	var actualOptions:Map<String, OptionData> = {
		var definitions = ClientPrefs.getOptionDefinitions();
		[
			for (name in ClientPrefs.options)
				name => definitions.get(name)
		];
	};

	var mainCamera:FlxCamera;
	var optionCamera:FlxCamera;
	var overlayCamera:FlxCamera;
	var cameraPositions:Array<FlxPoint> = [];
	var heights:Array<Float> = [];

	var camFollow = new FlxPoint(0, 0);
	var camFollowPos = new FlxObject(0, 0);

	var openedDropdown:Widget;

	@:noCompletion var _mousePoint:FlxPoint = FlxPoint.get();

	var optionDesc:FlxText;

	public var camerasToRemove:Array<FlxCamera> = [];

	public var transCamera:FlxCamera = new FlxCamera();
	public var optState:Bool = false;
	public function new(state:Bool=false){
		optState=state;
		super();
	}

	var whitePixel = FlxGraphic.fromRectangle(1, 1, 0xFFFFFFFF, false, 'whitePixel');

	var ignoreVolumeChange:Bool = false;
	function onVolumeChange(val:Float) {
		if (ignoreVolumeChange || FlxG.sound.muted)
			return;

		forceWidgetUpdate = true;
		ignoreVolumeChange = true;
		changeNumber("masterVolume", Math.ffloor(val * 100), true);
		ignoreVolumeChange = false;
	}

	var color1 = FlxColor.fromRGB(82, 82, 82);
	var color2 = FlxColor.fromRGB(70, 70, 70);

	override function create()
	{
		//var startTime = Sys.cpuTime();
		// ClientPrefs.load();
		persistentDraw = true;
		persistentUpdate = true;

		mainCamera = new FlxCamera();
		mainCamera.bgColor.alpha = 0;
		optionCamera = new FlxCamera();
		optionCamera.bgColor.alpha = 0;
		overlayCamera = new FlxCamera();
		overlayCamera.bgColor.alpha = 0;
		
		transCamera.bgColor.alpha = 0;
		if(optState){
			FlxG.cameras.reset(mainCamera);
			FlxG.cameras.add(optionCamera, false);
			FlxG.cameras.add(overlayCamera, false);
			FlxG.cameras.add(transCamera, false);
			//FlxG.cameras.setDefaultDrawTarget(mainCamera, true);
			camerasToRemove.push(mainCamera);

		}else{
			//mainCamera = FlxG.cameras.list[FlxG.cameras.list.length - 1];
			var backdrop = new FlxSprite(whitePixel);
			backdrop.scale.set(FlxG.width, FlxG.height);
			backdrop.updateHitbox();
			backdrop.color = 0xFF000000;
			backdrop.alpha = 0.6;
			add(backdrop);

			FlxG.cameras.add(mainCamera, false);
			FlxG.cameras.add(optionCamera, false);
			FlxG.cameras.add(overlayCamera, false);
			FlxG.cameras.add(transCamera, false);
		}

		camerasToRemove.push(optionCamera);
		camerasToRemove.push(overlayCamera);
		camerasToRemove.push(transCamera);

		cameras = [mainCamera];

		////
		var optionMenu = new FlxSprite(80, 80, CoolUtil.makeOutlinedGraphic(
			FlxMath.minInt(920, FlxG.width), 
			FlxG.height-140, 
			color1, 
			2, 
			color2
		));
		if (FlxG.width - 160 < optionMenu.width + 160) optionMenu.x = Math.floor((FlxG.width - optionMenu.width)/2);
		optionMenu.alpha = 0.6;
		add(optionMenu);

		optionCamera.width = Std.int(optionMenu.width);
		optionCamera.height = Std.int(optionMenu.height - 4);
		optionCamera.x = optionMenu.x;
		optionCamera.y = optionMenu.y + 2;

		optionCamera.targetOffset.x = optionCamera.width / 2;
		optionCamera.targetOffset.y = optionCamera.height / 2;

		optionCamera.follow(camFollowPos);

		////
		final backdropGraphic = Paths.image("optionsMenu/backdrop");
		final backdropSlice = [22, 22, 89, 89];
		final tabButtonHeight = 44;

		var lastX:Float = optionMenu.x;
		for (idx in 0...optionOrder.length)
		{
			var tabName = optionOrder[idx];

			var strKey = 'opt_tabName_$tabName';
			var text = new FlxText(0, 0, 0, Paths.getString(strKey, tabName).toUpperCase(), 16);
			text.applyFormat(TextFormats.TAB_NAME);

			var button = new FlxSprite(lastX, optionMenu.y - 3 - tabButtonHeight, whitePixel);
			button.ID = idx;
			button.alpha = 0.75;
			
			button.scale.set(Math.max(86, text.fieldWidth) + 8, tabButtonHeight);
			button.updateHitbox();

			text.setPosition(
				button.x,
				button.y + ((button.height - text.height) / 2)
			);
			text.fieldWidth = button.width;
			text.updateHitbox();

			lastX += button.width + 3;
			add(button);
			add(text);
			buttons.push(button);

			////
			var daY:Float = 0;
			var group = new FlxTypedGroup<FlxObject>();
			var widgets:Map<FlxObject, Widget> = [];
			cameraPositions.push(FlxPoint.get());

			for (data in options.get(tabName))
			{
				var label:String = data[0];

				var text = new FlxText(8, daY, 0, Paths.getString('opt_label_$label'), 16);
				text.applyFormat(TextFormats.OPT_LABEL);
				text.cameras = [optionCamera];
				group.add(text);

				daY += text.height;

				var daOpts:Array<String> = data[1];
				for (opt in daOpts)
				{
					if (!actualOptions.exists(opt))
						continue;

					var data:OptionData = actualOptions.get(opt);

					if (data.data.get("requiresRestart"))
						requiresRestart.set(opt, true);
					if (data.data.get("recommendsRestart"))
						recommendsRestart.set(opt, true);

					data.data.set("optionName", opt);
					data.display = Paths.getString('opt_display_$opt', data.display);
					data.desc = Paths.getString('opt_desc_$opt', data.desc);

					var text = new FlxText(16, daY, 0, data.display);
					text.applyFormat(TextFormats.OPT_NAME);
					text.cameras = [optionCamera];

					var height = Math.max(45, text.height + 12);
					var rect = new Rectangle(text.x - 12, text.y, optionMenu.width - text.x - 8, height);

					text.y += (height - text.height) / 2;
					
					var drop:FlxUI9SliceSprite = new FlxUI9SliceSprite(rect.x, rect.y, backdropGraphic, rect, backdropSlice);
					drop.alpha = 0.95;
					drop.cameras = [optionCamera];
					group.add(drop);
					
					var lock:FlxUI9SliceSprite = new FlxUI9SliceSprite(rect.x, rect.y, backdropGraphic, rect, backdropSlice);
					lock.cameras = [optionCamera];
					lock.alpha = 0.75;

					var widget:Widget = createWidget(opt, drop, text, data);
					widget.data.set("optionBox", drop);
					widget.data.set("lockOverlay", lock);
					if (widget.data.exists("objects")) {
						var objects = widget.data.get("objects");
						for (obj in (objects:FlxTypedGroup<FlxObject>).members) {
							@:privateAccess
							if (obj._cameras == null)
								obj.cameras = [optionCamera];
						}
						group.add(objects);
					}

					widgets.set(text, widget);
					group.add(text);
					group.add(lock);
					daY += height + 3;
				}
			}
			
			daY += 4;
			var height = daY > optionCamera.height ? daY - optionCamera.height : 0;
			heights.push(height);
			groups.set(tabName, group);
			allWidgets.set(tabName, widgets);
		}

		optionDesc = new FlxText(5, FlxG.height - 48, 0);
		optionDesc.applyFormat(TextFormats.OPT_DESC);
		optionDesc.textField.background = true;
		optionDesc.textField.backgroundColor = FlxColor.BLACK;
		optionDesc.cameras = [overlayCamera];
		optionDesc.alpha = 0;
		add(optionDesc);

		prevScreenX = FlxG.mouse.screenX;
		prevScreenY = FlxG.mouse.screenY;

		FlxG.sound.onVolumeChange.add(onVolumeChange);
		onVolumeChange(FlxG.sound.volume);

		checkWindows();
		changeCategory(0, true);

		super.create();
		//trace('OptionState creation took ${Sys.cpuTime() - startTime} seconds.');
	}

	function createWidget(name:String, drop:FlxSprite, text:FlxText, data:OptionData):Widget
	{
		var objects:FlxTypedGroup<FlxObject> = new FlxTypedGroup<FlxObject>();
		var widget:Widget = {
			type: data.type,
			optionData: data,
			locked: false,
			data: ["objects" => objects]
		}

		switch (widget.type)
		{
			case Toggle:
				var checkbox = new Checkbox();
				checkbox.setGraphicSize(36, 36);
				checkbox.updateHitbox();
				var text = new FlxText(0, 0, 0, "off", 16);
				text.applyFormat(TextFormats.OPT_VALUE_TEXT);
				checkbox.toggled = data.value != null ? cast data.value : false;

				if (Reflect.hasField(ClientPrefs, name)){
					checkbox.toggled = Reflect.field(ClientPrefs, name);
					originalValues.set(name, checkbox.toggled);
				}

				widget.data.set("checkbox", checkbox);
				widget.data.set("text", text);
				objects.add(text);
				objects.add(checkbox);

				data.value = (checkbox.toggled);

			case Dropdown:
				var options:Array<String> = data.data.get("options");
				var drops:Array<FlxUI9SliceSprite> = [];
				var optionMap:Map<FlxText, String> = [];
				var dV:String = data.value != null ? cast data.value : options[0];
				if (options.indexOf(dV) == -1)
					dV = options[0];

				var daY:Float = 0;
				var daW:Float = 100;

				var ddCamera = new FlxCamera();
				ddCamera.bgColor = FlxColor.GRAY;
				ddCamera.bgColor.alpha = 204;
				camerasToRemove.push(ddCamera);

				var backdropGraphic = Paths.image("optionsMenu/backdrop");

				for (idx in 0...options.length) {
					var l = options[idx];
					var text = new FlxText(8 + 4, daY + 4, 0, l, 16);
					text.cameras = [ddCamera];
					text.applyFormat(TextFormats.OPT_DROPDOWN_OPTION_TEXT);
					
					var width:Float = Math.max(50, text.width + 8);
					var height:Float = 35;

					text.y += (height - text.height) / 2;
					text.ID = idx;
					
					var backDrop:FlxUI9SliceSprite = new FlxUI9SliceSprite(
						text.x - 4, daY + 4, 
						backdropGraphic,
						new Rectangle(0, 0, width, height), [22, 22, 89, 89]
					);
					backDrop.cameras = [ddCamera];

					objects.add(backDrop);
					objects.add(text);
					drops.push(backDrop);
					optionMap.set(text, l);

					daW = Math.max(daW, width + 16);
					daY += backDrop.height + 2;
				}
				for (obj in drops) {
					obj.resize(daW - 8, obj.height);
					obj.x -= 4;
				}

				var height = Math.min(daY, 35 * 12) + 8;
				ddCamera.height = Std.int(height);
				ddCamera.width = Std.int(daW);

				ddCamera.x = optionCamera.x + drop.x + drop.width + 25; // wow thats alot of math
				ddCamera.y = optionCamera.y + optionCamera.scroll.y + drop.y;
				if (ddCamera.y + ddCamera.height > FlxG.height)
					ddCamera.y = FlxG.height - ddCamera.height; // kick it up so nothing ends up off screen
				ddCamera.alpha = 0;

				var hitbox = new FlxSprite(0, 0, whitePixel);
				hitbox.alpha = 0.1;
				hitbox.scale.set(ddCamera.width, ddCamera.height);
				hitbox.updateHitbox();
				hitbox.scrollFactor.set();
				hitbox.cameras = [ddCamera];
				objects.add(hitbox);

				var arrow:FlxSprite = new FlxSprite(Paths.image("optionsMenu/arrow"));
				arrow.scale.set(0.7, 0.7);
				arrow.updateHitbox();
				objects.add(arrow);

				var label = new FlxText(0, 0, 0, dV, 16);
				label.applyFormat(TextFormats.OPT_VALUE_TEXT);
				objects.add(label);

				var camFollow:FlxPoint = new FlxPoint(0, 0);
				var camFollowPos:FlxObject = new FlxObject(0, 0);
				ddCamera.follow(camFollowPos);
				ddCamera.targetOffset.x = ddCamera.width / 2;
				ddCamera.targetOffset.y = ddCamera.height / 2;
				FlxG.cameras.add(ddCamera, false);

				daY += 4;
				widget.data.set("height", daY > height ? daY - height : 0);
				widget.data.set("camFollow", camFollow);
				widget.data.set("camFollowPos", camFollowPos);
				widget.data.set("optionMap", optionMap);
				widget.data.set("boxes", drops);
				widget.data.set("hitbox", hitbox);
				widget.data.set("arrow", arrow);
				widget.data.set("text", label);
				widget.data.set("camera", ddCamera);
				
				if (Reflect.hasField(ClientPrefs, name)) {
					var val = Reflect.field(ClientPrefs, name);
					originalValues.set(name, val);
					data.value = (val);
					label.text = val;
				}else
					data.value = (dV);

			case Number:
				var box:FlxSprite = new FlxSprite(whitePixel);
				box.color = FlxColor.BLACK;
				box.scale.set(240, 24);
				box.updateHitbox();

				var bar:FlxSprite = new FlxSprite().makeGraphic(240-8, 24-8);
				
				objects.add(box);
				objects.add(bar);

				var text = new FlxText(0, 0, 0, "off", 16);
				text.applyFormat(TextFormats.OPT_VALUE_TEXT);
				objects.add(text);

				var leftAdjust = new WidgetButton();
				leftAdjust.loadGraphic(Paths.image("optionsMenu/adjusters"), true, 27, 25);
				leftAdjust.animation.add("idle", [0], 0, true);
				leftAdjust.animation.play("idle", true);
				leftAdjust.scale.set(0.8, 0.8);
				leftAdjust.updateHitbox();
				leftAdjust.canRepeat = true;
				leftAdjust.repeatTime = 0.05;
				leftAdjust.track = box;
				leftAdjust.trackOffset.x = -leftAdjust.width - 5;

				var rightAdjust = new WidgetButton();
				rightAdjust.loadGraphic(Paths.image("optionsMenu/adjusters"), true, 27, 25);
				rightAdjust.animation.add("idle", [1], 0, true);
				rightAdjust.animation.play("idle", true);
				rightAdjust.scale.set(0.8, 0.8);
				rightAdjust.updateHitbox();
				rightAdjust.canRepeat = true;
				rightAdjust.repeatTime = 0.05;
				rightAdjust.track = box;
				rightAdjust.trackOffset.x = box.width + 5;

				leftAdjust.onPressed = function()
				{
					if (!widget.locked)
						changeNumber(name, -data.data.get("step"));
				}

				rightAdjust.onPressed = function()
				{
					if (!widget.locked)
						changeNumber(name, data.data.get("step"));
				}
				objects.add(leftAdjust);
				objects.add(rightAdjust);

				var val = data.value ? cast data.value : (data.data.get("max") + data.data.get("min")) / 2;

				if (Reflect.hasField(ClientPrefs, name))
				{
					val = Reflect.field(ClientPrefs, name);
					originalValues.set(name, val);
					if (data.data.exists("type"))
					{
						switch (data.data.get("type"))
						{
							case 'percent':
								val *= 100;
							default:
								// nothing
						}
					}
				}

				if (val < data.data.get("min"))
					val = data.data.get("min");
				else if (val > data.data.get("max"))
					val = data.data.get("max");

				data.value = (val);
				widget.data.set("min", data.data.get("min"));
				widget.data.set("max", data.data.get("max"));
				if (!data.data.exists("step"))
					data.data.set("step", (data.data.get("max") - data.data.get("min")) / 100);
				widget.data.set("step", data.data.get("step"));

				widget.data.set("text", text);
				widget.data.set("box", box);
				widget.data.set("bar", bar);
				widget.data.set("leftAdjust", leftAdjust);
				widget.data.set("rightAdjust", rightAdjust);

			case Button:
				// nothing needs to be made lol
		}

		return widget;
	}

	function changeCategory(?val:Int = 0, absolute:Bool = false)
	{
		//selected = FlxMath.wrap(absolute ? val : selected+val, 0, buttons.length-1);
		
		if (absolute)
			selected = val;
		else
			selected += val;

		if (selected >= buttons.length)
			selected = 0;
		else if (selected < 0)
			selected = buttons.length - 1;

		////
		for (idx in 0...buttons.length)
		{
			var butt = buttons[idx];
			butt.color = idx == selected ? color2 + FlxColor.fromRGB(60, 60, 60) : color2;
		}

		camFollow.copyFrom(cameraPositions[selected]);
		camFollowPos.setPosition(camFollow.x, camFollow.y);

		remove(currentGroup);

		for (idx in 0...optionOrder.length)
		{
			var n = optionOrder[idx];
			var group = groups.get(n);
			if (members.contains(group) && idx != selected)
				remove(group);
			else if (!members.contains(group) && idx == selected)
			{
				add(group);
				currentWidgets = allWidgets.get(n);
				currentGroup = group;
			}
		}

		////
		selectableWidgetObjects = [
			for (object in currentGroup.members){
				if (currentWidgets.exists(object))
					object;
			}
		];

		changeWidget(null, true);
	}

	////
	var scrubbingBar:FlxSprite; // TODO: maybe make the bar a seperate class and then have this handled in that class

	function updateWidget(object:FlxObject, widget:Widget, elapsed:Float)
	{
		var optBox = widget.data.get("optionBox");
		var locked:Bool = widget.optionData.data.exists("locked") ? widget.optionData.data.get("locked") : false;

		widget.data.get("lockOverlay").visible = locked;
		widget.locked = locked;
		switch (widget.type)
		{
			case Toggle:
				var checkbox:Checkbox = widget.data.get("checkbox");
				var text:FlxText = widget.data.get("text");
				if (checkbox.toggled != widget.optionData.value)
					checkbox.toggled = widget.optionData.value;

				if (!widget.locked)
				{
					if (FlxG.mouse.justPressed)
					{
						if (overlaps(optBox, optionCamera))
						{
							checkbox.toggled = !checkbox.toggled;
							changeToggleW(widget, checkbox.toggled);
						}
					}
				}

				text.text = checkbox.toggled ? "on" : "off";
				text.x = object.x + 450;
				text.y = object.y + ((object.height - text.height) / 2);

				checkbox.x = object.x + 800;
				checkbox.y = object.y + ((object.height - checkbox.height) / 2);
			case Dropdown:
				var arrow:FlxSprite = widget.data.get("arrow");
				var daCamera:FlxCamera = widget.data.get("camera");
				var label:FlxText = widget.data.get("text");
				var dropBox:FlxSprite = widget.data.get("hitbox");
				var camFollowPos:FlxObject = widget.data.get("camFollowPos");
				var camFollow:FlxPoint = widget.data.get("camFollow");
				var height:Float = widget.data.get("height");

				var optionMap:Map<FlxText, String> = widget.data.get("optionMap");
				var boxes:Array<FlxUI9SliceSprite> = widget.data.get("boxes");

				if (!widget.locked)
				{
					if (FlxG.mouse.justPressed)
					{
						var interacted:Bool = false;
						if (overlaps(optBox, optionCamera))
						{
							if (openedDropdown == widget)
								openedDropdown = null;
							else
								openedDropdown = widget;
							interacted = true;
						}

						if (openedDropdown == widget)
						{
							for (obj => opt in optionMap)
							{
								if (obj.isOnScreen(daCamera))
								{
									if (overlaps(obj, daCamera) || overlaps(boxes[obj.ID], daCamera))
									{
										// widget.optionData.value = (opt);
										interacted = true;
										openedDropdown = null;
										changeDropdownW(widget, opt);
										// onDropdownChanged(widget.optionData.data.get("optionName"), widget.optionData.value, opt);
										break;
									}
								}
							}

							if (!interacted)
							{
								if (overlaps(dropBox, daCamera))
									interacted = true;
							}

							if (!interacted)
								openedDropdown = null;
						}
					}
				}
				else if (openedDropdown == widget)
					openedDropdown = null;

				if (openedDropdown == widget && overlaps(dropBox, daCamera))
				{
					var wheel = FlxG.mouse.wheel;
					camFollow.y -= wheel * 35;
					camFollowPos.y -= wheel * 35;

					if (camFollow.y < 0)
						camFollow.y = 0;
					if (camFollow.y > height)
						camFollow.y = height;
				}

				var lerpVal = Math.exp(-elapsed * 12);
				camFollowPos.setPosition(
					FlxMath.lerp(camFollow.x, camFollowPos.x, lerpVal), 
					FlxMath.lerp(camFollow.y, camFollowPos.y, lerpVal)
				);
				if (camFollowPos.y < 0)
					camFollowPos.y = 0;
				if (camFollowPos.y > height)
					camFollowPos.y = height;

				switch (widget.optionData.data.get("optionName"))
				{
					default:
						label.text = widget.optionData.value;
				}

				var active = openedDropdown == widget;
				daCamera.alpha = FlxMath.lerp(daCamera.alpha, active ? 1 : 0, lerpVal);
				arrow.angle = active ? -90 : 0; // FlxMath.lerp(arrow.angle, active?-90:0, lerpVal * 2);

				arrow.x = object.x + 800;
				arrow.y = object.y + ((object.height - arrow.height) / 2);

				label.x = object.x + 450;
				label.y = object.y + ((object.height - label.height) / 2);

				daCamera.x = optionCamera.x + optBox.x + optBox.width + 25; // wow thats alot of math
				daCamera.y = optionCamera.y - optionCamera.scroll.y + optBox.y;

				if (daCamera.y + daCamera.height > FlxG.height)
					daCamera.y = FlxG.height - daCamera.height; // kick it up so nothing ends up off screen

			case Number:
				var box:FlxSprite = widget.data.get("box");
				var bar:FlxSprite = widget.data.get("bar");
				var text:FlxText = widget.data.get("text");
				var min:Float = widget.optionData.data.get("min");
				var max:Float = widget.optionData.data.get("max");
				var oldVal = widget.optionData.value;
				var newVal = oldVal;
				if (!widget.locked)
				{
					if (FlxG.mouse.justPressed && overlaps(box, optionCamera) || FlxG.mouse.pressed && scrubbingBar == bar)
					{
						scrubbingBar = bar;
						_mousePoint = FlxG.mouse.getWorldPosition(optionCamera, _mousePoint);
						var localX = _mousePoint.x - box.x;
						var value = FlxMath.lerp(min, max, localX / bar.frameWidth);
						newVal = value;
					}
				}
				if (newVal < min)
					newVal = min;
				if (newVal > max)
					newVal = max;

				if (newVal != oldVal)
					changeNumberW(widget, newVal, true);

				var value = widget.optionData.value;

				bar.scale.x = (value - min) / (max - min);
				bar.updateHitbox();

				box.x = object.x + 600;
				box.y = object.y + ((object.height - bar.height) / 2);

				text.text = '';
				if (widget.optionData.data.exists("prefix"))
					text.text += widget.optionData.data.get("prefix");
				text.text += value;
				if (widget.optionData.data.exists("suffix"))
					text.text += widget.optionData.data.get("suffix");
				text.x = object.x + 450;
				text.y = object.y + ((object.height - text.height) / 2);

				bar.x = box.x + 4;
				bar.y = box.y + 4;
			case Button:
				if (!widget.locked)
				{
					if (FlxG.mouse.justPressed && overlaps(optBox, optionCamera))
						onButtonPressed(widget.optionData.data.get("optionName"));
				}
		}
	}

	inline function getNumber(name:String):Float
		return actualOptions.get(name).value;

	inline function getNumberW(widget:Widget):Float
		return getNumber(widget.optionData.data.get("optionName"));

	function changeNumber(name:String, val:Float, abs:Bool = false)
	{
		var option:OptionData = actualOptions.get(name);
		var valSnap:Float = option.data.get("step");
		var maxVal:Float = option.data.get("max");
		var minVal:Float = option.data.get("min");

		var oldVal = option.value;
		var newVal = abs ? val : (oldVal + val);

		if (newVal > maxVal)
			newVal = maxVal;
		else if (newVal < minVal)
			newVal = minVal;

		var snappedVal:Float = CoolUtil.snap(newVal, valSnap);
		option.value = snappedVal;
		
		if (oldVal != snappedVal)
			onNumberChanged(name, oldVal, snappedVal);

		if (Reflect.hasField(ClientPrefs, name)) {
			var val = snappedVal / (option.data.get("type") == 'percent' ? 100 : 1);
			Reflect.setField(ClientPrefs, name, val);
			if(Std.string(originalValues.get(name)) != Std.string(val)){
				if (!changed.contains(name))changed.push(name);
			}else
				changed.remove(name);
		}
	}

	function changeNumberW(widget:Widget, val:Float, abs:Bool = false)
		changeNumber(widget.optionData.data.get("optionName"), val, abs);

	function getToggle(name:String):Bool
		return actualOptions.get(name).value;

	function getToggleW(widget:Widget):Bool
		return getToggle(widget.optionData.data.get("optionName"));

	function changeToggle(name:String, val:Bool)
	{
		var data = actualOptions.get(name);
		var oldVal = data.value;
		data.value = (val);
		if (oldVal != val)
			onToggleChanged(name, val);

		if (Reflect.hasField(ClientPrefs, name))
			Reflect.setField(ClientPrefs, name, val);
		if (originalValues.get(name) != val){
			if (!changed.contains(name))changed.push(name);
		}else
			changed.remove(name);
		// checkbox.toggled = Reflect.field(ClientPrefs, name);
	}

	function changeToggleW(widget:Widget, val:Bool)
		changeToggle(widget.optionData.data.get("optionName"), val);

	function getDropdown(name:String):String
		return actualOptions.get(name).value;

	function getDropdownW(widget:Widget):String
		return getDropdown(widget.optionData.data.get("optionName"));

	function changeDropdown(name:String, val:String)
	{
		var data = actualOptions.get(name);
		var oldVal = data.value;
		if (!data.data.get("options").contains(val))
			return;

		data.value = (val);
		if (oldVal != val)
			onDropdownChanged(name, oldVal, val);

		if (Reflect.hasField(ClientPrefs, name))
			Reflect.setField(ClientPrefs, name, val);

		if (originalValues.get(name) != val)
			if (!changed.contains(name))changed.push(name);
		else if (changed.contains(name))
			changed.remove(name);
	}

	function changeDropdownW(widget:Widget, val:String)
		changeDropdown(widget.optionData.data.get("optionName"), val);

	// stolen from flxspritegroup
	function findMinYHelper()
	{
		var value = Math.POSITIVE_INFINITY;
		var sprites:Array<FlxSprite> = cast currentGroup.members;
		for (member in sprites)
		{
			if (member == null)
				continue;

			var minY:Float = member.y;

			if (minY < value)
				value = minY;
		}
		return value;
	}

	function findMaxYHelper()
	{
		var value = Math.NEGATIVE_INFINITY;
		var sprites:Array<FlxSprite> = cast currentGroup.members;
		for (member in sprites)
		{
			if (member == null)
				continue;

			var maxY:Float = member.y + member.height;

			if (maxY > value)
				value = maxY;
		}
		return value;
	}

	function getHeight():Float
		return heights[selected];

	//// For keyboard
	var selectableWidgetObjects:Array<FlxObject> = [];
	var curOption:Null<Int> = null;

	function changeWidget(val:Null<Int>, ?isAbs:Bool = false)
	{
		var nextOption:Null<Int> = null; 
		var nextWidget:Null<Widget> = null;

		if (val == null) {
			// Don't change
		}else if (isAbs)
			nextOption = val;
		else if (curOption == null) 
			nextOption = 0;
		else {
			nextOption = (curOption + val);
			if (nextOption < 0) nextOption += selectableWidgetObjects.length;
			nextOption = (selectableWidgetObjects.length > 0) ? (nextOption % selectableWidgetObjects.length) : 0;
		}

		for (idx in 0...selectableWidgetObjects.length) {
			var object:FlxText = cast selectableWidgetObjects[idx];
			
			if (idx == nextOption) {
				nextWidget = currentWidgets.get(object);
				object.color = FlxColor.YELLOW;
			}else {
				object.color = TextFormats.OPT_NAME.color;
			}
		}

		if (curWidget != null)
			onWidgetUnselected(curWidget);

		if (nextWidget != null) {
			// Focus camera on option
			var optBox:FlxObject = nextWidget.data.get("optionBox");
			camFollow.y = optBox.y + (optBox.height - optBox.camera.height) / 2;
		}

		curWidget = nextWidget;
		curOption = nextOption;
	}
	
	function onWidgetUnselected(widget:Widget) {
		switch(widget.type) {
			case Number:
				widget.data.get("leftAdjust").release();
				widget.data.get("rightAdjust").release();
			
			default:
		}
	}

	////
	function showOptionDesc(?text:String){
		if (text == null || text == '') {
			FlxTween.cancelTweensOf(optionDesc);
			FlxTween.tween(optionDesc, {alpha: 0, y: optionDesc.y + 12}, 0.16, {ease: FlxEase.quadOut});
			return;
		}
		
		////
		optionDesc.text = text;

		////
		var maxWidth = FlxG.width - 30;
		if (optionDesc.width > maxWidth)
			optionDesc.fieldWidth = maxWidth;
		else
			optionDesc.fieldWidth = 0;
		
		//// Scale down the text if it doesn't fit
		
		optionDesc.drawFrame(true); // to get the realest frameHeight

		var optionsTail = Std.int(optionCamera.y + optionCamera.height) + 2; // lowest part of options
		var scaledHeight = FlxG.height - optionsTail; // screen space below options
		scaledHeight = (optionDesc.frameHeight > scaledHeight) ? scaledHeight - 4 : optionDesc.frameHeight;
		optionDesc.setGraphicSize(0, scaledHeight);
		optionDesc.updateHitbox();
		
		////
		var goalY = ((optionCamera.y + optionCamera.height) + (FlxG.height - optionDesc.height)) / 2;
		optionDesc.screenCenter(X);
		
		optionDesc.y = goalY - 12;
		optionDesc.alpha = 0;
		FlxTween.cancelTweensOf(optionDesc);
		FlxTween.tween(optionDesc, {y: goalY, alpha: 1}, 0.35, {ease: FlxEase.quadOut});
	}

	var curWidget:Widget;

	//// workaround for when you switch from a state that set the camera to a different zoom value (like the tgt main menu)
	var prevScreenX:Int;
	var prevScreenY:Int;

	override function update(elapsed:Float)
	{
		if (subState == null)
		{
			var pHov = curWidget;
			var doUpdate = false;

			if (FlxG.keys.justPressed.TAB){
				FlxG.sound.play(Paths.sound("scrollMenu"));
				changeCategory(1);
				
				doUpdate = true;
				pHov = null;
			}

			if (FlxG.keys.justPressed.UP){
				FlxG.sound.play(Paths.sound("scrollMenu"));
				changeWidget(-1);
			}
			if (FlxG.keys.justPressed.DOWN){
				FlxG.sound.play(Paths.sound("scrollMenu"));
				changeWidget(1);
			}

			if (curWidget != null && !curWidget.locked){
				var optionName:String = curWidget.optionData.data.get("optionName");

				switch (curWidget.type){
					case Toggle:
						if (FlxG.keys.justPressed.ENTER){
							var checkbox:Checkbox = curWidget.data.get("checkbox");
							checkbox.toggled = !checkbox.toggled;
							changeToggle(optionName, checkbox.toggled);

							doUpdate = true;
						}

						if (FlxG.keys.justPressed.R){
							@:privateAccess
							changeToggle(optionName, ClientPrefs.defaultOptionDefinitions.get(optionName).value);
							doUpdate = true;
						}
						
					case Button:
						if (FlxG.keys.justPressed.ENTER){
							onButtonPressed(optionName);
							doUpdate = true;
						}

					case Number:
						// ;_;	
						var data = curWidget.data;

						if (FlxG.keys.justPressed.LEFT)	{
							if (FlxG.keys.pressed.SHIFT)	changeNumber(optionName, data.get("min"), true);
							else							data.get("leftAdjust").press();
						}
						else if (FlxG.keys.justReleased.LEFT) {
							data.get("leftAdjust").release();
						}		

						if (FlxG.keys.justPressed.RIGHT) {
							if (FlxG.keys.pressed.SHIFT)	changeNumber(optionName, data.get("max"), true);
							else							data.get("rightAdjust").press();
						}
						else if (FlxG.keys.justReleased.RIGHT) {
							data.get("rightAdjust").release();
						}

						if (FlxG.keys.justPressed.R){
							@:privateAccess
							var defaultDefinition = ClientPrefs.defaultOptionDefinitions.get(optionName);
							var defaultValue = defaultDefinition.value;

							if (defaultDefinition.data.get("type") == "percent")
								defaultValue *= 100;

							changeNumber(optionName, defaultValue, true);
							doUpdate = true;
						}
						if (FlxG.keys.pressed.LEFT || FlxG.keys.pressed.RIGHT || FlxG.mouse.pressed){
							doUpdate = true;
						}

					case Dropdown:
						var change = 0;
						if (FlxG.keys.justPressed.LEFT) change--;
						if (FlxG.keys.justPressed.RIGHT) change++;

						if (change != 0){
							var sowy = actualOptions.get(optionName);
							var allOptions:Array<String> = sowy.data.get("options");
							var idx = FlxMath.wrap(allOptions.indexOf(sowy.value) + change, 0, allOptions.length-1);

							changeDropdown(optionName, allOptions[idx]);

							doUpdate = true;
						}

						if (FlxG.keys.justPressed.R){
							@:privateAccess
							changeDropdown(optionName, ClientPrefs.defaultOptionDefinitions.get(optionName).value);
							doUpdate = true;
						}

						doUpdate=true; // wont fade in and out otherwise :T
				}
			}

			if (FlxG.mouse.released)
				scrubbingBar = null;
			else if (FlxG.mouse.justPressed)
			{
				for (idx in 0...optionOrder.length)
				{
					if (FlxG.mouse.overlaps(buttons[idx], mainCamera))
					{
						changeCategory(idx, true);
						pHov = null;
						break;
					}
				}
			}

			var movedMouse = Math.abs(FlxG.mouse.wheel) + Math.abs(FlxG.mouse.screenX - prevScreenX) + Math.abs(FlxG.mouse.screenY - prevScreenY) != 0;
			if (movedMouse) FlxG.mouse.visible = true;
			prevScreenX = FlxG.mouse.screenX;
			prevScreenY = FlxG.mouse.screenY;

			if (pHov == null || doUpdate || movedMouse || FlxG.mouse.justPressed || forceWidgetUpdate)
			{
				for (object => widget in currentWidgets)
				{
					if (movedMouse && widget != pHov && overlaps(widget.data.get("optionBox"), optionCamera))
					{
						changeWidget(null); // to reset keyboard selection
						curWidget = widget;
						// trace(widget.optionData.display);
					}

					updateWidget(object, widget, elapsed);
				}
				forceWidgetUpdate = false;
			}

			if (curWidget == null){
				showOptionDesc(null);
			}
			else if (pHov != curWidget)
			{
				var hovering:OptionData = curWidget.optionData;
				var optDesc:String = hovering.desc;

				if (!optState){
					var oN = hovering.data.get("optionName");
					
					/*if(oN == 'customizeHUD' )
						optDesc += "\n(NOTE: This does not work because you're ingame!)";
					else */if (requiresRestart.exists(oN))
						optDesc += "\nWARNING: You will need to restart the song if you change this!";
					else if (recommendsRestart.exists(oN))
						optDesc += "\nNOTE: This won't have any effect unless you restart the song!";
				}
				
				showOptionDesc(optDesc);
			}

			////
			if (openedDropdown == null)
			{
				var movement:Float = -FlxG.mouse.wheel * 45;
				var keySpeed = elapsed * 1200;

				if (FlxG.keys.pressed.PAGEUP)
					movement -= keySpeed;
				if (FlxG.keys.pressed.PAGEDOWN)
					movement += keySpeed;

				camFollow.y += movement;
				camFollowPos.y += movement;
			}

			var height = getHeight();
			camFollow.y = FlxMath.bound(camFollow.y, 0, height);

			var lerpVal = Math.exp(-elapsed * 12);
			camFollowPos.setPosition(
				FlxMath.lerp(camFollow.x, camFollowPos.x, lerpVal), 
				FlxMath.lerp(camFollow.y, camFollowPos.y, lerpVal)
			);
			camFollowPos.y = FlxMath.bound(camFollowPos.y, 0, height);

			cameraPositions[selected].copyFrom(camFollow);
		}

		super.update(elapsed);

		if (subState == null)
		{
			if (controls.BACK)
			{
				save();
				FlxG.sound.play(Paths.sound('cancelMenu'));
			
				if(goBack!=null)
					goBack(changed);
			}
		} 
	}

	override function destroy()
	{
		_mousePoint.put();
		FlxG.sound.onVolumeChange.remove(onVolumeChange);

		for (val in cameraPositions)
			val.put();

		super.destroy();
	}
}

class WidgetButton extends WidgetSprite
{
	public var canRepeat:Bool = false;
	public var repeatTime:Float = 0.25;
	public var isPressed:Bool = false;

	public var onPressed:Void->Void;
	public var onReleased:Void->Void;
	public var whilePressed:Void->Void;

	var pressedTime:Float = 0;
	var repeatingTime:Float = 0;

	public function press(){
		isPressed = true;
		if (onPressed != null)
			onPressed();
	}
	public function release(){
		isPressed = false;
		if (onReleased != null)				
			onReleased();
	}

	override function update(elapsed:Float)
	{
		if (!isPressed)
		{
			pressedTime = 0;
			repeatingTime = 0;
			if (FlxG.mouse.justPressed)
			{
				for (camera in cameras)
				{
					if (FlxG.mouse.overlaps(this, camera))
					{
						press();
						break;
					}
				}
			}
		}
		else
		{
			pressedTime += elapsed;
			if (canRepeat && pressedTime >= 0.25)
			{
				repeatingTime += elapsed;
				var time = repeatTime * (FlxG.keys.pressed.SHIFT ? 0.5 : 1);
				while (repeatingTime >= time)
				{
					repeatingTime -= time;
					if (onPressed != null)
						onPressed();
				}
			}
			if (FlxG.mouse.justReleased)
			{
				release();
			}
			else
			{
				if (whilePressed != null)
					whilePressed();
			}
		}
		super.update(elapsed);
	}
}

class WidgetSprite extends FlxSprite
{
	public var track:FlxObject;
	public var trackOffset:FlxPoint = FlxPoint.get();

	override function destroy()
	{
		trackOffset.put();
		return super.destroy();
	}

	override function update(elapsed:Float)
	{
		if (track != null)
			setPosition(track.x + trackOffset.x, track.y + ((track.height - height) / 2) + trackOffset.y);

		return super.update(elapsed);
	}
}

class Checkbox extends WidgetSprite
{
	public var toggled(default, set) = false;

	function set_toggled(val:Bool)
	{
		animation.play(val ? "toggled" : "idle", true);
		return toggled = val;
	}

	public function new(x:Float = 0, y:Float = 0, defaultToggled:Bool = false)
	{
		super(x, y);
		frames = Paths.getSparrowAtlas("optionsMenu/checkbox");
		animation.addByPrefix("toggled", "selected", 0, false);
		animation.addByPrefix("idle", "deselected", 0, false);
		animation.play("idle", true);

		// antialiasing = false;

		toggled = defaultToggled;
	}
}

class TextFormats {
	public static final TAB_NAME:FlxTextFormatData = {
		font: "vcr.ttf",
		pixelPerfectRender: true,
		antialiasing: false,
	
		size: 32,
		color: 0xFFFFFFFF,
		alignment: CENTER
	};
	
	public static final OPT_LABEL:FlxTextFormatData = {
		font: "vcr.ttf",
		pixelPerfectRender: true,
		antialiasing: false,
	
		size: 32,
		color: 0xFFFFFFFF,
		alignment: LEFT
	};
	
	public static final OPT_NAME:FlxTextFormatData = {
		font: "calibri.ttf",
		
		size: 28,
		color: 0xFFFFFFFF,
		alignment: LEFT
	};

	public static final OPT_VALUE_TEXT:FlxTextFormatData = {
		font: "calibri.ttf",
		size: 24,
		color: 0xFFFFFFFF,
		alignment: LEFT
	};
	
	public static final OPT_DROPDOWN_OPTION_TEXT:FlxTextFormatData = {
		font: "calibri.ttf",
		size: 24,
		color: 0xFFFFFFFF,
		alignment: LEFT
	};

	public static final OPT_DESC:FlxTextFormatData = {
		font: "vcr.ttf",
		pixelPerfectRender: true,
		antialiasing: false,
	
		size: 16,
		color: 0xFFFFFFFF,
		alignment: CENTER,
	
		borderStyle: OUTLINE,
		borderColor: 0xFF000000
	};
}