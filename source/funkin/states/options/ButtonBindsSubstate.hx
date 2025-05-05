package funkin.states.options;
// too lazy to finish merging this w the keyboard version rn

import funkin.states.options.BindsBullshit.KeyboardNavHelper;
import funkin.states.options.BindsBullshit.BindButton;

import funkin.CoolUtil.overlapsMouse as overlaps;

import flixel.input.gamepad.FlxGamepadInputID;
import flixel.math.FlxMath;
import flixel.addons.ui.FlxUI9SliceSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.math.FlxPoint;
import openfl.geom.Rectangle;

using StringTools;

inline function getButtonName(id:Int)
	return FlxGamepadInputID.toStringMap.exists(id) ? FlxGamepadInputID.toStringMap.get(id) : "Unknown";

inline function getJustPressed():Int
	return FlxG.gamepads.firstActive==null ? -1 : FlxG.gamepads.firstActive.firstJustPressedID();

class ButtonBindsSubstate extends MusicBeatSubstate  
{
	// if an option is in this list, then atleast ONE key will have to be bound.
	var forcedBind:Array<String> = ["ui_up", "ui_down", "ui_left", "ui_right", "accept", "back",];

	var binds:Array<Array<String>> = [
		[Paths.getString('controls_gameplay')],
		[Paths.getString('control_note_left'), 'note_left'],
		[Paths.getString('control_note_down'), 'note_down'],
		[Paths.getString('control_note_up'), 'note_up'],
		[Paths.getString('control_note_right'), 'note_right'],
		/*
		[Paths.getString('control_pause'), 'pause'],
		[Paths.getString('control_reset'), 'reset'],

		[Paths.getString('controls_ui')],
		[Paths.getString('control_accept'), 'accept'],
		[Paths.getString('control_back'), 'back'],
		*/
	];

	public var changedBind:(String, Int, FlxGamepadInputID) -> Void;

	// anything beyond this point prob shouldnt be touched too much
	final clientBinded:Map<String, Array<FlxGamepadInputID>> = ClientPrefs.buttonBinds;
	final clientDefaults:Map<String, Array<FlxGamepadInputID>> = ClientPrefs.defaultButtons;

	var cam:FlxCamera = new FlxCamera();
	var overCam:FlxCamera = new FlxCamera();
	var scrollableCam:FlxCamera = new FlxCamera();

	var camFollow = new FlxPoint(0, 0);
	var camFollowPos = new FlxObject(0, 0);

	var bindIndex:Int = -1;
	var bindID:Int = 0;
	var bindButtons:Array<Array<BindButtonC>> = []; // the actual bind buttons. used for input etc lol
	var internals:Array<String> = [];
	var resetBinds:FlxUI9SliceSprite;
	var cancelKey:Int;

	//// Keyboard navigation
	var keyboardNavigation:Array<KeyboardNavHelper<BindButtonC>> = [];
	var selectionArrow:FlxSprite;
	var keyboardY:Int = 0;
	var keyboardX:Int = 0;

	var height:Float = 0;

	var popupTitle:FlxText;
	var popupText:FlxText;
	var unbindText:FlxText;

	override public function create()
	{
		super.create();

		this.persistentUpdate = false;
		this.destroySubStates = false;
		
		FlxG.cameras.add(cam, false);
		FlxG.cameras.add(scrollableCam, false);
		FlxG.cameras.add(overCam, false);
		
		cam.bgColor = 0;
		scrollableCam.bgColor = 0;
		overCam.bgColor = FlxColor.fromRGBFloat(0,0,0,.5);
		overCam.alpha = 0;
		
		var backdropGraphic = Paths.image("optionsMenu/backdrop");
		var backdropSlice = [22, 22, 89, 89];

		var optionMenu = new FlxSprite(84, 80, CoolUtil.makeOutlinedGraphic(920, 570, FlxColor.fromRGB(82, 82, 82), 2, FlxColor.fromRGB(70, 70, 70)));
		optionMenu.alpha = 0.8;
		optionMenu.cameras = [cam];
		optionMenu.screenCenter(XY);
		add(optionMenu);


		scrollableCam.width = Std.int(optionMenu.width);
		scrollableCam.height = Std.int(optionMenu.height);
		scrollableCam.x = optionMenu.x;
		scrollableCam.y = optionMenu.y;

		scrollableCam.targetOffset.x = scrollableCam.width / 2;
		scrollableCam.targetOffset.y = scrollableCam.height / 2;

		scrollableCam.follow(camFollowPos);
		var group = new FlxTypedGroup<FlxObject>();
		
		
		var daY:Float = 0;
		var idx:Int = 0;
		for (data in binds) {
			if (data.length == 0)
				continue;

			var label = data[0];

			if (data.length == 1) {
				// its just a label
				var text = new FlxText(8, daY, 0, label, 16);
				text.cameras = [scrollableCam];
				text.setFormat(Paths.font("quanticob.ttf"), 32, 0xFFFFFFFF, FlxTextAlign.LEFT);
				group.add(text);
				daY += text.height;

			}else {
				// its a bind
				var buttArray:Array<BindButtonC> = [];
				var internal:String = data[1];
				internals.push(data[1]);
				
				var text = new FlxText(16, daY, 0, label, 16);
				text.setFormat(Paths.font("quantico.ttf"), 28, 0xFFFFFFFF, FlxTextAlign.LEFT);
				text.cameras = [scrollableCam];
				text.updateHitbox();

				var height = Math.min(45, text.height + 12);
				var drop:FlxUI9SliceSprite = new FlxUI9SliceSprite(text.x - 12, text.y, backdropGraphic, new Rectangle(0, 0, optionMenu.width - text.x - 8, height), backdropSlice);
				drop.cameras = [scrollableCam];
				text.y += (height - text.height) / 2;


				var rect = new Rectangle(0, 0, 200, height - 10);
				var binded = clientBinded.get(internal);
				trace(internal, binded);

				var prButt = new BindButtonC(drop.x + drop.width - 40, drop.y, rect, binded[0]);
				prButt.x -= prButt.width * 2;
				prButt.y += 5;
				prButt.ID = idx;
				prButt.cameras = [scrollableCam];
				buttArray.push(prButt);

				var secButt = new BindButtonC(drop.x + drop.width - 20, drop.y, rect, binded[1]);
				secButt.x -= secButt.width;
				secButt.y += 5;
				secButt.ID = idx;
				secButt.cameras = [scrollableCam];
				buttArray.push(secButt);

				group.add(drop);
				group.add(text);
				group.add(prButt);
				group.add(secButt);
				daY += height + 3;

				keyboardNavigation.push(new KeyboardNavHelper(text, drop, buttArray));

				bindButtons.push(buttArray);
			}

			idx++;
		}
		
		//////
		var text = new FlxText(16, daY, 0, Paths.getString("control_default"), 16);
		text.cameras = [scrollableCam];
		text.setFormat(Paths.font("quantico.ttf"), 28, 0xFFFFFFFF, FlxTextAlign.LEFT);
		text.updateHitbox();
		
		var height = text.height + 12;
		if (height < 45) height = 45;

		resetBinds = new FlxUI9SliceSprite(text.x - 12, text.y, backdropGraphic, new Rectangle(0, 0, optionMenu.width - text.x - 8, height), backdropSlice);
		resetBinds.cameras = [scrollableCam];
		text.y += (height - text.height) / 2;
		daY += height + 3;

		daY += 4;

		this.height = daY > scrollableCam.height ? daY - scrollableCam.height : 0;

		group.add(resetBinds);
		group.add(text);
		keyboardNavigation.push(new KeyboardNavHelper(text, resetBinds, null, resetAllBinds));

		add(group);

		////
		selectionArrow = new FlxSprite(Paths.image('optionsMenu/arrow'));
		selectionArrow.setGraphicSize(16, 16);
		selectionArrow.updateHitbox();
		selectionArrow.visible = false;
		selectionArrow.cameras = [scrollableCam];
		add(selectionArrow);

		////
		var popupDrop:FlxUI9SliceSprite = new FlxUI9SliceSprite(0, 0, backdropGraphic, new Rectangle(0, 0, 880, 225), backdropSlice);
		popupDrop.cameras = [overCam];
		popupDrop.screenCenter(XY);

		popupTitle = new FlxText(popupDrop.x, popupDrop.y + 10, popupDrop.width, "Currently binding my penis", 16);
		popupTitle.setFormat(Paths.font("quanticob.ttf"), 32, 0xFFFFFFFF, FlxTextAlign.CENTER);
		popupTitle.cameras = [overCam];
		
		popupText = new FlxText(popupDrop.x, popupDrop.y + popupTitle.height, popupDrop.width, "Press key to bind\npress to unbind", 16);
		popupText.setFormat(Paths.font("quantico.ttf"), 32, 0xFFFFFFFF, FlxTextAlign.CENTER);
		popupText.cameras = [overCam];
		
		unbindText = new FlxText(popupDrop.x, popupDrop.y + 180, popupDrop.width, "(Note that this action needs atleast one key bound)", 16);
		unbindText.setFormat(Paths.font("quantico.ttf"), 32, 0xFFFFFFFF, FlxTextAlign.CENTER);
		unbindText.cameras = [overCam];

		add(popupDrop);
		add(popupTitle);
		add(popupText);
		add(unbindText);
	}

	override function destroy()
	{
		FlxG.cameras.remove(cam);
		FlxG.cameras.remove(scrollableCam);
		FlxG.cameras.remove(overCam);

		return super.destroy();
	}

	function bind(bindIndex:Int, bindID:Int, key:FlxGamepadInputID){
		var opp = bindID == 0 ? 1 : 0;
		var internal = internals[bindIndex];

		trace('bound ${internal} ($bindID) to ' + (key));

		var binds:Array<FlxGamepadInputID> = clientBinded.get(internal);
		if (binds[bindID] == key)
			key = NONE;
		else if (binds[opp] == key)
		{
			if (changedBind != null)
				changedBind(internal, opp, NONE);
			binds[opp] = NONE;
			bindButtons[bindIndex][opp].bind = NONE;
		}

		if (forcedBind.contains(internal))
		{
			if (key == NONE && binds[opp] == NONE)
			{
				var defaults = clientDefaults.get(internal);
				// atleast ONE needs to be bound, so use a default
				if (defaults[bindID] == NONE)
					key = defaults[opp];
				else
					key = defaults[bindID];
			}
		}
		if (changedBind != null)
			changedBind(internal, bindID, key);
		binds[bindID] = key;

		bindButtons[bindIndex][bindID].bind = key;
		clientBinded.set(internal, binds);
		return binds;
	}

	function exitBinding() {
		bindID = 0;
		bindIndex = -1;
		FNFGame.specialKeysEnabled = true;
	}

	public function confirmBinding(key:FlxGamepadInputID) {
		FlxG.sound.play(Paths.sound('confirmMenu'));
				
		bind(bindIndex, bindID, key);
		ClientPrefs.saveBinds();
		ClientPrefs.reloadControls();

		exitBinding();
	}

	function cancelBinding() {
		FlxG.sound.play(Paths.sound('cancelMenu'));
		exitBinding();
	}

	////

	override function update(elapsed:Float){
		cam.bgColor = FlxColor.interpolate(0x80000000, cam.bgColor, Math.exp(-elapsed * 6));

		if (bindIndex == -1)
			updateMenu(elapsed);
		else
			updateBindingSubmenu(elapsed);

		super.update(elapsed);
	}

	function updateMenu(elapsed:Float) {
		var controller = FlxG.gamepads.firstActive;
		if (controller == null || controller.justPressed.B) {
			FlxG.sound.play(Paths.sound('cancelMenu'));
			close();
			return;
		}

		////////
		var prevY = keyboardY; // to unhighlight text
		var updateKeyboard = false;

		if (controller.justPressed.DPAD_UP) {
			updateKeyboard = true;
			keyboardY--;
		}
		
		if (controller.justPressed.DPAD_DOWN) {
			updateKeyboard = true;
			keyboardY++;
		}
		
		if (controller.justPressed.DPAD_LEFT) {
			updateKeyboard = true;
			keyboardX--;
		}

		if (controller.justPressed.DPAD_RIGHT) {
			updateKeyboard = true;
			keyboardX++;
		}

		if (updateKeyboard) {
			FlxG.sound.play(Paths.sound("scrollMenu"));
			FlxG.mouse.visible = false;

			var prevSel = keyboardNavigation[prevY];
			if (prevSel != null && prevSel.text != null){
				prevSel.text.color = 0xFFFFFFFF;
			}

			keyboardY = FlxMath.wrap(keyboardY, 0, keyboardNavigation.length-1);
			var curSel = keyboardNavigation[keyboardY];
			curSel.text.color = 0xFFFFFF00;

			selectionArrow.visible = true;

			if (curSel.bindButtons != null){
				keyboardX = FlxMath.wrap(keyboardX, 0, curSel.bindButtons.length-1);
				
				////
				var curButt = curSel.bindButtons[keyboardX];

				selectionArrow.alpha = 1;
				selectionArrow.angle = -90; // face right idk
				selectionArrow.setPosition(
					curButt.x - selectionArrow.width - 2,
					curButt.y + (curButt.height - selectionArrow.height) / 2
				);
			}else{
				selectionArrow.alpha = 0;
				selectionArrow.angle = 90; // face left idk
				selectionArrow.setPosition(
					curSel.text.x + curSel.text.width + 2,
					curSel.text.y + (curSel.text.height - selectionArrow.height) / 2
				);
			}

			camFollow.y = curSel.bg.y + curSel.bg.height / 2 - scrollableCam.height / 2;

			//trace(keyboardY, keyboardX);
		}

		if (controller.justPressed.Y)
			resetSelectedBind();

		if (controller.justPressed.A){
			var curSel = keyboardNavigation[keyboardY];
			var bindButton = curSel.bindButtons != null ? curSel.bindButtons[keyboardX] : null;
			
			if (bindButton != null)
				startRebind(keyboardY, keyboardX, bindButton);
			else if (curSel.onTextPress != null)
				curSel.onTextPress();
		}
		
		////////
		var lerpVal = Math.exp(-elapsed * 12.0);
		overCam.alpha = FlxMath.lerp(0, overCam.alpha, lerpVal);
		
		camFollow.y = FlxMath.bound(camFollow.y, 0, height);

		camFollowPos.setPosition(
			FlxMath.lerp(camFollow.x, camFollowPos.x, lerpVal), 
			FlxMath.lerp(camFollow.y, camFollowPos.y, lerpVal)
		);
		camFollowPos.y = FlxMath.bound(camFollowPos.y, 0, height);
	}

	function updateBindingSubmenu(elapsed:Float) {
		overCam.alpha = CoolUtil.coolLerp(overCam.alpha, 1.0, elapsed * 12.0);

		var pressedKey = getJustPressed();
		if (pressedKey != -1) {
			if (pressedKey == cancelKey)
				cancelBinding();
			else
				confirmBinding(pressedKey);
		}
	}

	function startRebind(index:Int, id:Int, butt:BindButtonC){
		var internal = internals[index];
		var actionToBindTo:String = binds[butt.ID][0];
		var currentBinded:FlxGamepadInputID = clientBinded.get(internal)[id];

		bindID = id;
		bindIndex = index;
		
		FNFGame.specialKeysEnabled = false;
		
		cancelKey = FlxGamepadInputID.NONE; // (currentBinded == BACKSPACE) ? FlxGamepadInputID.ESCAPE : FlxGamepadInputID.BACKSPACE;

		// "CURRENTLY BINDING " + actionToBindTo.toUpperCase();
		popupTitle.text = Paths.getString("control_binding")
			.replace("{controlNameUpper}", actionToBindTo.toUpperCase())
			.replace("{controlName}", actionToBindTo); 

		// 'Press any key to bind, or press [BACKSPACE] to cancel.';
		popupText.text = Paths.getString("control_rebind").replace("{cancelKey}", '[${getButtonName(cancelKey)}]'); 

		// '\nPress [${InputFormatter.getButtonName(currentBinded)}] to unbind.';
		if (currentBinded != NONE)
			popupText.text += "\n" + Paths.getString("control_unbind").replace("{unbindKey}", '[${getButtonName(currentBinded)}]');

		unbindText.visible = forcedBind.contains(internal);
	}

	function resetSelectedBind() {
		var actionName:Null<String> = internals[keyboardY];
		if (actionName != null){
			var defaultBindKeys:Null<Array<FlxGamepadInputID>> = clientDefaults.get(actionName);
			if (defaultBindKeys != null){
				var defaultKey:FlxGamepadInputID = defaultBindKeys[keyboardX];
				var binded = bind(keyboardY, keyboardX, defaultKey);
				FlxG.sound.play(Paths.sound(binded[keyboardX] == defaultKey ? 'confirmMenu' : 'cancelMenu') );
			}
		}
	}

	function resetAllBinds(){
		// i hate haxeflixel lmao
		for (key => val in clientDefaults){
			clientBinded.set(key, []);
			for(i => v in val) {
				if (changedBind != null)
					changedBind(key, i, v);
				clientBinded.get(key)[i] = v;
			}
		}
		
		for(index => fuck in bindButtons){
			var internal = internals[index];
			for(id => butt in fuck){
				butt.bind = clientBinded.get(internal)[id];
			}
		}
		FlxG.sound.play(Paths.sound('confirmMenu'));
		ClientPrefs.saveBinds();
		ClientPrefs.reloadControls();
	}
}

class BindButtonC extends BindButton<FlxGamepadInputID> {
	override function _getBindedName(id:FlxGamepadInputID)
		return getButtonName(id);
}