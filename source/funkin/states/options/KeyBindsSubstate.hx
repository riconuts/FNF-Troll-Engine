package funkin.states.options;

import funkin.states.options.BindsBullshit.KeyboardNavHelper;
import funkin.states.options.BindsBullshit.BindButton;

import funkin.CoolUtil.overlapsMouse as overlaps;

import flixel.input.keyboard.FlxKey;
import flixel.math.FlxMath;
import flixel.addons.ui.FlxUI9SliceSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.math.FlxPoint;
import openfl.geom.Rectangle;

using StringTools;

inline function getKeyName(id:Int):String
	return funkin.input.InputFormatter.getKeyName(id);

inline function getJustPressed():Int
	return FlxG.keys.firstJustPressed();

class KeyBindsSubstate extends MusicBeatSubstate  {
	// if an option is in this list, then atleast ONE key will have to be bound.
	var forcedBind:Array<String> = ["ui_up", "ui_down", "ui_left", "ui_right", "accept", "back",];

	var binds:Array<Array<String>> = [
		[Paths.getString('controls_gameplay')],
		[Paths.getString('control_note_left'), 'note_left'],
		[Paths.getString('control_note_down'), 'note_down'],
		[Paths.getString('control_note_up'), 'note_up'],
		[Paths.getString('control_note_right'), 'note_right'],
		[Paths.getString('control_pause'), 'pause'],
		[Paths.getString('control_reset'), 'reset'],

		[Paths.getString('controls_ui')],
		[Paths.getString('control_ui_up'), 'ui_up'],
		[Paths.getString('control_ui_down'), 'ui_down'],
		[Paths.getString('control_ui_left'), 'ui_left'],
		[Paths.getString('control_ui_right'), 'ui_right'],
		[Paths.getString('control_accept'), 'accept'],
		[Paths.getString('control_back'), 'back'],

		[Paths.getString('controls_misc')],
		[Paths.getString('control_volume_mute'), 'volume_mute'],
		[Paths.getString('control_volume_up'), 'volume_up'],
		[Paths.getString('control_volume_down'), 'volume_down'],
		[Paths.getString('control_fullscreen'), 'fullscreen'],

		[Paths.getString('controls_debug')],
		// honestly might just replace this with one debug thing
		// and make it so pressing it in playstate will open a debug menu w/ a bunch of stuff
		// chart editor/character editor, botplay, skip to time, etc. move it from pause menu during charting mode lol
		[Paths.getString('control_debug_1'), 'debug_1'],
		[Paths.getString('control_debug_2'), 'debug_2'],
		[Paths.getString('control_botplay'), 'botplay']
	];


	public var changedBind:(String, Int, FlxKey) -> Void;

	// anything beyond this point prob shouldnt be touched too much
	final clientBinded:Map<String, Array<FlxKey>> = ClientPrefs.keyBinds;
	final clientDefaults:Map<String, Array<FlxKey>> = ClientPrefs.defaultKeys;

	var cam:FlxCamera = new FlxCamera();
	var overCam:FlxCamera = new FlxCamera();
	var scrollableCam:FlxCamera = new FlxCamera();

	var camFollow = new FlxPoint(0, 0);
	var camFollowPos = new FlxObject(0, 0);

	var bindIndex:Int = -1;
	var bindID:Int = 0;
	var bindButtons:Array<Array<BindButtonK>> = []; // the actual bind buttons. used for input etc lol
	var internals:Array<String> = [];
	var resetBinds:FlxUI9SliceSprite;
	var cancelKey:FlxKey;

	//// Keyboard navigation
	var keyboardNavigation:Array<KeyboardNavHelper<BindButtonK>> = [];
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
		
		FlxG.cameras.add(cam, false);
		FlxG.cameras.add(scrollableCam, false);
		FlxG.cameras.add(overCam, false);
		
		cam.bgColor = 0;
		scrollableCam.bgColor = 0;
		overCam.bgColor = FlxColor.fromRGBFloat(0,0,0,.5);
		overCam.alpha = 0;

		var backdropGraphic = Paths.image("optionsMenu/backdrop");

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
		for(data in binds){
			var label = data[0];

			if (data.length > 1) {
				// its a bind
				var buttArray:Array<BindButtonK> = [];
				var internal:String = data[1];
				internals.push(data[1]);
				
				var text = new FlxText(16, daY, 0, label, 16);
				text.cameras = [scrollableCam];
				text.setFormat(Paths.font("quantico.ttf"), 28, 0xFFFFFFFF, FlxTextAlign.LEFT);
				text.updateHitbox();

				var height = Math.min(45, text.height + 12);
				var drop:FlxUI9SliceSprite = new FlxUI9SliceSprite(text.x - 12, text.y, backdropGraphic, new Rectangle(0, 0, optionMenu.width - text.x - 8, height), [22, 22, 89, 89]);
				drop.cameras = [scrollableCam];
				text.y += (height - text.height) / 2;


				var rect = new Rectangle(0, 0, 200, height - 10);
				var currentBinds = clientBinded.get(internal);

				var prButt = new BindButtonK(drop.x + drop.width - 40, drop.y, rect, currentBinds[0]);
				prButt.x -= prButt.width * 2;
				prButt.y += 5;
				prButt.ID = idx;
				prButt.cameras = [scrollableCam];
				buttArray.push(prButt);

				var secButt = new BindButtonK(drop.x + drop.width - 20, drop.y, rect, currentBinds[1]);
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

			}else{
				// its just a label
				var text = new FlxText(8, daY, 0, label, 16);
				text.cameras = [scrollableCam];
				text.setFormat(Paths.font("quanticob.ttf"), 32, 0xFFFFFFFF, FlxTextAlign.LEFT);
				group.add(text);
				daY += text.height;
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

		resetBinds = new FlxUI9SliceSprite(text.x - 12, text.y, backdropGraphic,
			new Rectangle(0, 0, optionMenu.width - text.x - 8, height), [22, 22, 89, 89]);
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
		var popupDrop:FlxUI9SliceSprite = new FlxUI9SliceSprite(0, 0, backdropGraphic, new Rectangle(0, 0, 880, 225), [22, 22, 89, 89]);
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

	////

	function exitBinding()
	{
		bindID = 0;
		bindIndex = -1;
		FNFGame.specialKeysEnabled = true;
	}

	function confirmBinding(key) {
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

	override function update(elapsed:Float){
		cam.bgColor = FlxColor.interpolate(0x80000000, cam.bgColor, Math.exp(-elapsed * 6));

		if (bindIndex == -1)
			updateMenu(elapsed);
		else
			updateBindingSubmenu(elapsed);

		super.update(elapsed);
	}

	function updateMenu(elapsed:Float) {
		if (controls.BACK) {
			FlxG.sound.play(Paths.sound('cancelMenu'));
			close();
			return;
		}

		////////
		var wasKeyboarding = selectionArrow.visible;
		var updateKeyboard = false;
		var prevY = keyboardY; // to unhighlight text

		if (FlxG.keys.justPressed.UP){
			if (wasKeyboarding) keyboardY--;
			updateKeyboard = true;
		}
		if (FlxG.keys.justPressed.DOWN)
		{
			if (wasKeyboarding) keyboardY++;
			updateKeyboard = true;
		}
		if (FlxG.keys.justPressed.LEFT)
		{
			if (wasKeyboarding) keyboardX--;
			updateKeyboard = true;
		}
		if (FlxG.keys.justPressed.RIGHT)
		{
			if (wasKeyboarding) keyboardX++;
			updateKeyboard = true;
		}

		if (updateKeyboard)
		{
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

		if (FlxG.keys.justPressed.R)
			resetSelectedBind();
		
		var curSel = keyboardNavigation[keyboardY];
		if (wasKeyboarding && FlxG.keys.justPressed.ENTER){
			var bindButton = curSel.bindButtons != null ? curSel.bindButtons[keyboardX] : null;
			
			if (bindButton != null)
				startRebind(keyboardY, keyboardX, bindButton);
			else if (curSel.onTextPress != null)
				curSel.onTextPress();
		}

		if (FlxG.mouse.deltaX + FlxG.mouse.deltaY != 0){
			FlxG.mouse.visible = true;
			curSel.text.color = 0xFFFFFFFF;
			selectionArrow.visible = false;
		}
		
		////////
		if (FlxG.mouse.justPressed){
			for (y => buttons in bindButtons){
				for (x => butt in buttons){
					if (overlaps(butt, scrollableCam)){
						startRebind(y, x, butt);
					}
				}
			}

			if (bindIndex == -1){
				if (overlaps(resetBinds, scrollableCam))
					resetAllBinds();
			}
		}

		var movement:Float = -FlxG.mouse.wheel * 45;
		var keySpeed = elapsed * 1200;
		if (FlxG.keys.pressed.PAGEUP)
			movement -= keySpeed;
		if (FlxG.keys.pressed.PAGEDOWN)
			movement += keySpeed;

		camFollow.y += movement;
		camFollowPos.y += movement;

		camFollow.y = FlxMath.bound(camFollow.y, 0, height);

		var lerpVal = Math.exp(-elapsed * 12);
		camFollowPos.setPosition(
			FlxMath.lerp(camFollow.x, camFollowPos.x, lerpVal), 
			FlxMath.lerp(camFollow.y, camFollowPos.y, lerpVal)
		);
		camFollowPos.y = FlxMath.bound(camFollowPos.y, 0, height);

		overCam.alpha = FlxMath.lerp(0, overCam.alpha, lerpVal);
	}

	function updateBindingSubmenu(elapsed:Float) {
		overCam.alpha = FlxMath.lerp(1, overCam.alpha, Math.exp(-elapsed * 12));

		var keyPressed:FlxKey = getJustPressed();
		if (keyPressed != NONE){
			if (keyPressed == cancelKey)
				cancelBinding();
			else
				confirmBinding(keyPressed);
		}
	}

	function bind(bindIndex:Int, bindID:Int, key:FlxKey){
		var opp = bindID == 0 ? 1 : 0;
		var internal = internals[bindIndex];

		trace('bound $internal ($bindID) to ' + getKeyName(key));

		var binds = clientBinded.get(internal);
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

	function startRebind(index:Int, id:Int, butt:BindButtonK){
		var internal = internals[index];
		var actionToBindTo:String = binds[butt.ID][0];
		var currentBinded:FlxKey = clientBinded.get(internal)[id];

		bindID = id;
		bindIndex = index;
		cancelKey = (currentBinded == BACKSPACE) ? FlxKey.ESCAPE : FlxKey.BACKSPACE;
		FNFGame.specialKeysEnabled = false;
		
		// 
		unbindText.visible = forcedBind.contains(internal);

		// 'Press any key to bind, or press [BACKSPACE] to cancel.';
		popupText.text = Paths.getString("control_rebind").replace("{cancelKey}", '[${getKeyName(cancelKey)}]'); 
		
		// '\nPress [${getKeyName(currentBinded)}] to unbind.';
		if (currentBinded != NONE)
			popupText.text += "\n" + Paths.getString("control_unbind").replace("{unbindKey}", '[${getKeyName(currentBinded)}]');
		
		// "CURRENTLY BINDING " + actionToBindTo.toUpperCase();
		popupTitle.text = Paths.getString("control_binding")
			.replace("{controlNameUpper}", actionToBindTo.toUpperCase())
			.replace("{controlName}", actionToBindTo); 
	}

	function resetSelectedBind() {
		var actionName:Null<String> = internals[keyboardY];
		if (actionName != null){
			var defaultBindKeys:Null<Array<FlxKey>> = clientDefaults.get(actionName);
			if (defaultBindKeys != null){
				var defaultKey:FlxKey = defaultBindKeys[keyboardX];
				var binded = bind(keyboardY, keyboardX, defaultKey);
				FlxG.sound.play(Paths.sound(binded[keyboardX] == defaultKey ? 'confirmMenu' : 'cancelMenu') );
			}
		}
	}

	function resetAllBinds(){
		// i hate haxeflixel lmao
		for (key => val in clientDefaults.copy()){
			clientBinded.set(key, []);
			for(i => v in val){
				if (changedBind!=null)
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

class BindButtonK extends BindButton<FlxKey> {
	override function _getBindedName(id:FlxKey)
		return getKeyName(id);
}