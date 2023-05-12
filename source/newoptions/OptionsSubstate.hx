package newoptions;

import flixel.input.keyboard.FlxKey;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxTimer;
import flixel.addons.transition.FlxTransitionableState;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.group.FlxGroup.FlxTypedGroup;
import openfl.geom.Rectangle;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.addons.ui.FlxUI9SliceSprite;
import ClientPrefs.OptionData;
import ClientPrefs.OptionType;

typedef Widget =
{
	type:OptionType,
	optionData:OptionData,
	locked:Bool,
	data:Map<String, Dynamic>,
}

class OptionsSubstate extends MusicBeatSubstate
{
	public static var recommendsRestart:Array<String> = [
		"etternaHUD",
		"judgeCounter",
		"hudPosition",
		"gradeSet",
		"shaders",
		"lowQuality",
		"globalAntialiasing",
	];

	public static var requiresRestart:Array<String> = [
		"modcharts", 
		"noteOffset", 
		"ratingOffset", 
		"wife3", 
		"useEpics", 
		"judgePreset", 
		"epicWindow", 
		"sickWindow", 
		"goodWindow", 
		"badWindow", 
		"hitWindow",
		"judgeDiff", 
		"noteSkin",
	];
	
	var changed:Array<String> = [];
	var originalValues:Map<String, Dynamic> = [];


	public var goBack:(Array<String>)->Void;
    public function save(){
		ClientPrefs.save(actualOptions);

		Highscore.updateSave();
    }
	function windowsChanged()
	{
		var windows = ["badWindow", "goodWindow", "sickWindow"];
		if (getToggle("useEpics"))
			windows.push("epicWindow");
		else
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
		actualOptions.get("epicWindow").data.set("locked", !getToggle("useEpics"));

		for (name => windows in judgeWindows)
		{
			var compareWindow = [
				getToggle("useEpics") ? getNumber("epicWindow") : -1,
				getNumber("sickWindow"),
				getNumber("goodWindow"),
				getNumber("badWindow"),
				getNumber("hitWindow")
			];
			var isPreset:Bool = true;
			for (idx in 0...compareWindow.length)
			{
				var preset = CoolUtil.snap(windows[idx], 0.1);
				var custom = CoolUtil.snap(compareWindow[idx], 0.1);
				if (preset != custom)
				{
					isPreset = false;
					break;
				}
			}
			if (isPreset)
			{
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
				if (judgeWindows.exists(newVal))
				{
					var windows = judgeWindows.get(newVal);
					changeToggle("useEpics", windows[0] != -1);
					if (windows[0] != -1)
						changeNumber("epicWindow", windows[0], true);
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
			case 'globalAntialising':
				FlxSprite.defaultAntialiasing = ClientPrefs.globalAntialiasing;
			default:
				// nothing
		}
	}

	function onButtonPressed(option:String)
	{
		switch (option)
		{
			case 'customizeHUD':
				if((FlxG.state is OptionsState))
					LoadingState.loadAndSwitchState(new options.NoteOffsetState());
			case 'customizeColours':
				// TODO: check the note colours once you exit to see if any changed
				openSubState(ClientPrefs.noteSkin == "Quants" ? new options.QuantNotesSubState() : new options.NotesSubState());
			case 'customizeKeybinds':
				var substate = new NewBindsSubstate();
				var currentBinds:Map<String, Array<FlxKey>> = [];

				for (key => val in ClientPrefs.keyBinds.copy()) // copy the keys to the array
				{
					currentBinds.set(key, []);
					for (i => v in val)
						currentBinds.get(key)[i] = v;
				}

				substate.changedBind = function(action:String, index:Int, newBind:FlxKey){
					var daId = '${action}${index}-bind';
					trace(daId, currentBinds.get(action)[index], newBind, currentBinds.get(action)[index] == newBind);
					if (currentBinds.get(action)[index] == newBind)
						changed.remove(daId);
					else
					if (!changed.contains(daId))
						changed.push(daId);
				}
				openSubState(substate);
			default:
				// nothing
		}
	}

	function onNumberChanged(option:String, oldVal:Float, newVal:Float)
	{
		switch (option)
		{
			case 'framerate':
				if (newVal > FlxG.drawFramerate)
				{
					FlxG.updateFramerate = Math.floor(newVal);
					FlxG.drawFramerate = Math.floor(newVal);
				}
				else
				{
					FlxG.drawFramerate = Math.floor(newVal);
					FlxG.updateFramerate = Math.floor(newVal);
				}
			case 'epicWindow' | 'sickWindow' | 'goodWindow' | 'badWindow' | 'hitWindow':
				checkWindows();
			default:
				// nothing
		}
	}

	static var judgeWindows:Map<String, Array<Float>> = [
		"Standard" => [22.5, 45, 90, 135, 180],
		"Vanilla" => [
			-1, // epic (-1 to disable)
			33, // sick
			125, // good
			150, // bad
			166 // shit / max hit window
		],
		"Psych" => [-1, 45, 90, 135, 166],
		"ITG" => [21, 43, 102, 135, 180]
	];

	static var options:Map<String, Array<Dynamic>> = [
		// maps are annoying and dont preserve order so i have to do this
		"Game" => [
			[
				"Gameplay", 
				[
					"ghostTapping", 
					"directionalCam", 
					"noteOffset", 
					"ratingOffset",
				]
			],
			[
				"Audio", 
				[
					"hitsoundVolume", 
					"missVolume"
				]
			],
			[
				"Accessibility",
				[
					"flashing",
					"camShakeP",
					"camZoomP",
					"modcharts" // niixx keeps crying
				]
			],
			[
				"Advanced",
				[
					"wife3",
					"useEpics",
					"judgePreset",
					"epicWindow",
					"sickWindow",
					"goodWindow",
					"badWindow",
					"hitWindow",
					"judgeDiff", // for hooda lol
				]
			]
		],
		"UI" => [
			[
				"Notes",
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
				"HUD",
				[
					"timeBarType", "hudOpacity", "hpOpacity", "timeOpacity", "stageOpacity", "scoreZoom", "npsDisplay", "showMS", "coloredCombos",
					"simpleJudge",
					"hitbar", "judgeCounter", 'hudPosition', "customizeHUD",
				]
			],
			["Advanced", ["etternaHUD", "gradeSet"]]
		],
		"Video" => [
			["Video", ["shaders", "showFPS"]],
			["Display", ["framerate", "bread"]],
			[
				"Performance",
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
		"Controls" => [["Keyboard", ["customizeKeybinds",]], ["Controller", ["controllerMode",]]],
		/* "Accessibility" => [
				[
					"Gameplay", 
					[
						"flashing",
						"camShakeP",
						"camZoomP"
					]
				]
			] */
	];

	static var optionOrder:Array<String> = ["Game", "UI", "Video", "Controls", /* "Accessibility" */];

	var selected:Int = 0;

	var buttons:Array<FlxSprite> = [];
	var currentWidgets:Map<FlxObject, Widget> = [];
	var currentGroup:FlxTypedGroup<FlxObject>;
	var groups:Map<String, FlxTypedGroup<FlxObject>> = [];
	var allWidgets:Map<String, Map<FlxObject, Widget>> = [];
	var actualOptions = ClientPrefs.getOptionDefinitions();

	var mainCamera:FlxCamera;
	var optionCamera:FlxCamera;
	var overlayCamera:FlxCamera;
	var cameraPositions:Array<FlxPoint> = [];
	var heights:Array<Float> = [];

	var camFollow = new FlxPoint(0, 0);
	var camFollowPos = new FlxObject(0, 0);

	var openedDropdown:Widget;

	@:noCompletion
	var _point:FlxPoint = FlxPoint.get();
	@:noCompletion
	var _mousePoint:FlxPoint = FlxPoint.get();

	function overlaps(object:FlxObject, ?camera:FlxCamera)
	{
		if (camera == null)
			camera = optionCamera;

		_point = FlxG.mouse.getPositionInCameraView(camera, _point);
		if (camera.containsPoint(_point))
		{
			_point = FlxG.mouse.getWorldPosition(camera, _point);
			if (object.overlapsPoint(_point, true, camera))
				return true;
		}

		return false;
	}


	var optionDesc:FlxText;

	public var camerasToRemove:Array<FlxCamera> = [];

	public var transCamera:FlxCamera = new FlxCamera();
	public var optState:Bool = false;
	public function new(state:Bool=false){
		optState=state;
		super();
	}
	override function create()
	{
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
			FlxG.cameras.setDefaultDrawTarget(mainCamera, true);
			camerasToRemove.push(mainCamera);

		}else{
			//mainCamera = FlxG.cameras.list[FlxG.cameras.list.length - 1];
			var backdrop = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
			backdrop.setGraphicSize(FlxG.width, FlxG.height);
			backdrop.updateHitbox();
			backdrop.screenCenter(XY);
			backdrop.alpha = 0.5;
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
		FlxG.mouse.visible = true;


		////
		var optionMenu = new FlxSprite(84, 80, CoolUtil.makeOutlinedGraphic(920, FlxG.height-80, FlxColor.fromRGB(82, 82, 82), 2, FlxColor.fromRGB(70, 70, 70)));
		optionMenu.alpha = 0.8;
		add(optionMenu);

		optionCamera.width = Std.int(optionMenu.width);
		optionCamera.height = Std.int(optionMenu.height);
		optionCamera.x = optionMenu.x;
		optionCamera.y = optionMenu.y;

		optionCamera.targetOffset.x = optionCamera.width / 2;
		optionCamera.targetOffset.y = optionCamera.height / 2;

		optionCamera.follow(camFollowPos);

		var lastX:Float = optionMenu.x;
		for (idx in 0...optionOrder.length)
		{
			var name = optionOrder[idx];

			var button = new FlxSprite(lastX, optionMenu.y - 3).makeGraphic(1, 44, FlxColor.WHITE);
			button.ID = idx;
			button.color = idx == 0 ? FlxColor.fromRGB(128, 128, 128) : FlxColor.fromRGB(82, 82, 82);
			button.alpha = 0.75;

			var text = new FlxText(button.x, button.y, 0, name.toUpperCase(), 16);
			text.setFormat(Paths.font("calibrib.ttf"), 32, 0xFFFFFFFF, FlxTextAlign.CENTER);
			var width = text.fieldWidth < 86 ? 86 : text.fieldWidth;
			button.setGraphicSize(Std.int(width + 8), Std.int(button.height));
			button.updateHitbox();
			button.y -= button.height;
			text.y = button.y + ((button.height - text.height) / 2);

			text.fieldWidth = button.width;
			text.updateHitbox();

			lastX += button.width + 3;
			add(button);
			add(text);
			buttons.push(button);
		}

		// for (data in options.get("Game")){
		for (name in optionOrder)
		{
			var daY:Float = 0;
			var group = new FlxTypedGroup<FlxObject>();
			var widgets:Map<FlxObject, Widget> = [];
			cameraPositions.push(FlxPoint.weak());
			for (data in options.get(name))
			{
				var label = data[0];
				var daOpts:Array<String> = data[1];
				var text = new FlxText(8, daY, 0, label, 16);
				text.setFormat(Paths.font("calibrib.ttf"), 32, 0xFFFFFFFF, FlxTextAlign.LEFT);
				text.cameras = [optionCamera];
				group.add(text);
				daY += text.height;
				for (opt in daOpts)
				{
					if (!actualOptions.exists(opt))
						continue;
					var data = actualOptions.get(opt);
					data.data.set("optionName", opt);
					var text = new FlxText(16, daY, 0, data.display, 16);
					text.cameras = [optionCamera];
					text.setFormat(Paths.font("calibri.ttf"), 28, 0xFFFFFFFF, FlxTextAlign.LEFT);
					var height = text.height + 12;
					if (height < 45)
						height = 45;
					var drop:FlxUI9SliceSprite = new FlxUI9SliceSprite(text.x - 12, text.y, Paths.image("optionsMenu/backdrop"),
						new Rectangle(0, 0, optionMenu.width - text.x - 8, height), [22, 22, 89, 89]);
					drop.cameras = [optionCamera];
					var lock:FlxUI9SliceSprite = new FlxUI9SliceSprite(text.x - 12, text.y, Paths.image("optionsMenu/backdrop"),
						new Rectangle(0, 0, optionMenu.width - text.x - 8, height), [22, 22, 89, 89]);
					lock.alpha = 0.75;
					lock.cameras = [optionCamera];
					text.y += (height - text.height) / 2;

					var widget = createWidget(opt, drop, text, data);
					group.add(drop);
					widget.data.set("optionBox", drop);
					widget.data.set("lockOverlay", lock);
					if (widget.data.exists("objects"))
					{
						var objects:FlxTypedGroup<FlxObject> = widget.data.get("objects");
						for (obj in objects.members)
						{
							@:privateAccess
							if (obj.cameras == null || obj.cameras == FlxCamera._defaultCameras)
								obj.cameras = [optionCamera];
						}
						group.add(widget.data.get("objects"));
					}

					widgets.set(text, widget);
					group.add(text);
					group.add(lock);
					daY += height + 3;
				}
			}
			if (currentGroup == null)
			{
				currentGroup = group;
				currentWidgets = widgets;
			}
			daY += 4;
			var height = daY > optionCamera.height ? daY - optionCamera.height : 0;
			heights.push(height);
			groups.set(name, group);
			allWidgets.set(name, widgets);
		}
		add(currentGroup);

		optionDesc = new FlxText(5, FlxG.height - 48, 0, "", 20);
		optionDesc.setFormat(Paths.font("calibri.ttf"), 20, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		optionDesc.textField.background = true;
		optionDesc.textField.backgroundColor = FlxColor.BLACK;
		optionDesc.screenCenter(XY);
		optionDesc.cameras = [overlayCamera];
		optionDesc.alpha = 0;
		add(optionDesc);

		checkWindows();

		super.create();
	}

	function createWidget(name:String, drop:FlxSprite, text:FlxText, data:OptionData):Widget
	{
		var widget:Widget = {
			type: data.type,
			optionData: data,
			locked: false,
			data: ["objects" => new FlxTypedGroup<FlxObject>()]
		}

		var objects:FlxTypedGroup<FlxObject> = widget.data.get("objects");

		switch (widget.type)
		{
			case Toggle:
				var checkbox = new Checkbox();
				checkbox.scale.set(0.65, 0.65);
				checkbox.updateHitbox();
				var text = new FlxText(0, 0, 0, "off", 16);
				text.setFormat(Paths.font("calibri.ttf"), 24, 0xFFFFFFFF, FlxTextAlign.LEFT);
				// trace(data.value);
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
				var arrow:FlxSprite = new FlxSprite().loadGraphic(Paths.image("optionsMenu/arrow"));
				arrow.scale.set(0.7, 0.7);
				arrow.updateHitbox();
				arrow.antialiasing = false;

				var daCamera = new FlxCamera();
				daCamera.bgColor = FlxColor.GRAY;
				daCamera.bgColor.alpha = 204;
				camerasToRemove.push(daCamera);

				var options:Array<String> = data.data.get("options");
				var daY:Float = 0;
				var daW:Float = 100;
				var drops:Array<FlxUI9SliceSprite> = [];
				var optionMap:Map<FlxText, String> = [];
				var dV:String = data.value != null ? cast data.value : options[0];
				if (options.indexOf(dV) == -1)
					dV = options[0];

				var label = new FlxText(0, 0, 0, dV, 16);
				label.setFormat(Paths.font("calibri.ttf"), 24, 0xFFFFFFFF, FlxTextAlign.LEFT);

				for (idx in 0...options.length)
				{
					var l = options[idx];
					var text = new FlxText(8 + 4, daY + 4, 0, l, 16);
					text.cameras = [daCamera];
					text.setFormat(Paths.font("calibri.ttf"), 24, 0xFFFFFFFF, FlxTextAlign.LEFT);
					var height = 35;
					var width = text.width + 8;
					if (width < 50)
						width = 50;
					var backDrop:FlxUI9SliceSprite = new FlxUI9SliceSprite(text.x - 4, daY + 4, Paths.image("optionsMenu/backdrop"),
						new Rectangle(0, 0, width, height), [22, 22, 89, 89]);
					backDrop.cameras = [daCamera];
					text.y += (height - text.height) / 2;

					text.ID = idx;
					objects.add(backDrop);
					objects.add(text);
					drops.push(backDrop);
					optionMap.set(text, l);
					daY += backDrop.height + 2;

					if (daW < width + 16)
						daW = width + 16;
				}
				for (obj in drops)
				{
					obj.resize(daW - 8, obj.height);
					obj.x -= 4;
				}

				var height = daY;
				if (height > 35 * 12)
					height = 35 * 12;
				height += 8;
				daCamera.height = Std.int(height);
				daCamera.width = Std.int(daW);

				daCamera.x = optionCamera.x + drop.x + drop.width + 25; // wow thats alot of math
				daCamera.y = optionCamera.y + optionCamera.scroll.y + drop.y;
				if (daCamera.y + daCamera.height > FlxG.height)
					daCamera.y = FlxG.height - daCamera.height; // kick it up so nothing ends up off screen
				daCamera.alpha = 0;

				var hitbox = new FlxSprite().makeGraphic(1, 1, FlxColor.WHITE);
				hitbox.alpha = 0.1;
				hitbox.setGraphicSize(daCamera.width, daCamera.height);
				hitbox.updateHitbox();
				hitbox.scrollFactor.set();
				hitbox.cameras = [daCamera];
				objects.add(hitbox);

				var camFollow:FlxPoint = new FlxPoint(0, 0);
				var camFollowPos:FlxObject = new FlxObject(0, 0);
				daCamera.follow(camFollowPos);
				daCamera.targetOffset.x = daCamera.width / 2;
				daCamera.targetOffset.y = daCamera.height / 2;

				FlxG.cameras.add(daCamera, false);
				daY += 4;
				widget.data.set("height", daY > height ? daY - height : 0);
				widget.data.set("camFollow", camFollow);
				widget.data.set("camFollowPos", camFollowPos);
				widget.data.set("optionMap", optionMap);
				widget.data.set("boxes", drops);
				widget.data.set("hitbox", hitbox);
				widget.data.set("arrow", arrow);
				widget.data.set("text", label);
				widget.data.set("camera", daCamera);
				if (Reflect.hasField(ClientPrefs, name))
				{
					var val = Reflect.field(ClientPrefs, name);
					originalValues.set(name, val);
					data.value = (val);
					label.text = val;
				}
				else
					data.value = (dV);

				objects.add(arrow);
				objects.add(label);
			case Number:
				var box:FlxSprite = new FlxSprite().makeGraphic(240, 24, FlxColor.BLACK);
				var bar:FlxSprite = new FlxSprite().makeGraphic(240 - 8, 24 - 8, FlxColor.WHITE);
				objects.add(box);
				objects.add(bar);

				var text = new FlxText(0, 0, 0, "off", 16);
				text.setFormat(Paths.font("calibri.ttf"), 24, 0xFFFFFFFF, FlxTextAlign.LEFT);
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
		if (absolute)
			selected = val;
		else
			selected += val;

		if (selected >= buttons.length)
			selected = 0;
		else if (selected < 0)
			selected = buttons.length - 1;

		for (idx in 0...buttons.length)
		{
			var butt = buttons[idx];
			butt.color = idx == selected ? FlxColor.fromRGB(128, 128, 128) : FlxColor.fromRGB(82, 82, 82);
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
	}

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
						if (overlaps(optBox))
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
						if (overlaps(optBox))
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

				var lerpVal = 0.2 * (elapsed / (1 / 60));
				camFollowPos.setPosition(FlxMath.lerp(camFollowPos.x, camFollow.x, lerpVal), FlxMath.lerp(camFollowPos.y, camFollow.y, lerpVal));
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
					if (FlxG.mouse.justPressed && overlaps(box) || FlxG.mouse.pressed && scrubbingBar == bar)
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
					if (FlxG.mouse.justPressed && overlaps(optBox))
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
		var data = actualOptions.get(name);
		var newVal = abs ? val : data.value + val; // data.data.get("step");
		if (newVal > data.data.get("max"))
			newVal = data.data.get("max");
		else if (newVal < data.data.get("min"))
			newVal = data.data.get("min");
		var snappedVal = CoolUtil.snap(newVal, data.data.get("step"));
		var oldVal = data.value;
		data.value = (snappedVal);
		if (oldVal != snappedVal)
			onNumberChanged(name, oldVal, snappedVal);

		if (Reflect.hasField(ClientPrefs, name)){
			var val = snappedVal / (data.data.get("type") == 'percent' ? 100 : 1);
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

	var curHovering:Widget;

	override function update(elapsed:Float)
	{
		if (subState == null)
		{
			if (controls.UI_LEFT_P)
				changeCategory(-1);
			else if (controls.UI_RIGHT_P)
				changeCategory(1);

			if (FlxG.mouse.released)
				scrubbingBar = null;
			else if (FlxG.mouse.justPressed)
			{
				for (idx in 0...optionOrder.length)
				{
					if (FlxG.mouse.overlaps(buttons[idx], mainCamera))
					{
						changeCategory(idx, true);
						break;
					}
				}
			}

			var pHov = curHovering;
			for (object => widget in currentWidgets)
			{
				if (overlaps(widget.data.get("optionBox")))
					curHovering = widget;

				updateWidget(object, widget, elapsed);
			}

			if (curHovering != pHov && curHovering != null)
			{
				var hovering = curHovering.optionData;
				optionDesc.text = hovering.desc;
				if (!optState){
					var oN = hovering.data.get("optionName");
					if(oN == 'customizeHUD' )
						optionDesc.text += "\n(NOTE: This does not work because you're ingame!)";
					else if (requiresRestart.contains(oN))
						optionDesc.text += "\nWARNING: You will need to restart the song if you change this!";
					else if (recommendsRestart.contains(oN))
						optionDesc.text += "\nNOTE: This won't have any effect unless you restart the song!";
				}

				optionDesc.screenCenter(XY);
				optionDesc.y = FlxG.height - 76;
				optionDesc.alpha = 0;
				FlxTween.cancelTweensOf(optionDesc);
				FlxTween.tween(optionDesc, {y: FlxG.height - 64, alpha: 1}, 0.35, {ease: FlxEase.quadOut});
			}

			if (openedDropdown == null)
			{
				var movement:Float = -FlxG.mouse.wheel * 45;
				var es:Float = elapsed / (1 / 60);

				if (FlxG.keys.pressed.PAGEUP)
					movement -= 25 * es;
				if (FlxG.keys.pressed.PAGEDOWN)
					movement += 25 * es;

				camFollow.y += movement;
				camFollowPos.y += movement;
			}

			if (camFollow.y < 0)
				camFollow.y = 0;
			if (camFollow.y > getHeight())
				camFollow.y = getHeight();

			var lerpVal = 0.2 * (elapsed / (1 / 60));
			camFollowPos.setPosition(FlxMath.lerp(camFollowPos.x, camFollow.x, lerpVal), FlxMath.lerp(camFollowPos.y, camFollow.y, lerpVal));
			if (camFollowPos.y < 0)
				camFollowPos.y = 0;

			if (camFollowPos.y > getHeight())
				camFollowPos.y = getHeight();

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
		for (val in cameraPositions)
			val.putWeak();

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
						isPressed = true;
						if (onPressed != null)
							onPressed();
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
			if (FlxG.mouse.released)
			{
				isPressed = false;
				if (onReleased != null)
					onReleased();
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
		animation.addByPrefix("toggled", "selected", 0, true);
		animation.addByPrefix("idle", "deselected", 0, true);
		animation.play("idle", true);

		antialiasing = false;

		toggled = defaultToggled;
	}
}