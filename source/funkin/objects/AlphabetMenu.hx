package funkin.objects;

import funkin.input.Controls;
import funkin.objects.Alphabet;
import flixel.group.FlxGroup.FlxTypedGroup;
import haxe.Constraints.Function;

typedef OptionCallbacks = {
	?onSelect:Function,
	?unSelect:Function,
	?onAccept:Function
}

class AlphabetMenu extends FlxTypedGroup<Alphabet>
{
	public var curSelected(default, set):Null<Int> = null;
	public var curItem:Null<Alphabet> = null;
	public var controls:Null<Controls>;
	
	private var itemCallbacks:Map<Alphabet, OptionCallbacks> = [];
	/** (`Int`, `Alphabet`) -> `Void` **/
	public final callbacks:OptionCallbacks = {}

	function set_curSelected(value:Null<Int>)
	{
		var range:Int = members.length;

		if (range > 0){
			if (value < 0) value += range * Std.int(-value / range + 1);
			value %= range;
		}else{
			value = null;
		}

		////

		var prevItem = curItem;
		if (prevItem != null){
			prevItem.alpha = 0.6;

			if (callbacks.unSelect != null)
				callbacks.unSelect(curSelected, prevItem);

			var callbacks = itemCallbacks.get(prevItem);
			if (callbacks != null && callbacks.unSelect != null)
				callbacks.unSelect();
		}
		
		curItem = members[value];
		if (curItem != null){
			curItem.alpha = 1.0;

			if (callbacks.onSelect != null)
				callbacks.onSelect(value, curItem);

			var callbacks = itemCallbacks.get(curItem);
			if (callbacks != null && callbacks.onSelect != null)
				callbacks.onSelect();
		}

		if (value != null){
			for (i => item in members)
				item.targetY = i - value;
		}

		if (value != null && value != curSelected)
			FlxG.sound.play(Paths.sound("scrollMenu"), 0.4);

		return curSelected = value;
	}

	public function addTextOption(text:String, ?callbacks:OptionCallbacks, ?textSize:Float)
	{
		var index = members.length;

		var item = new Alphabet(0, 70 * index + 30, text, true, false, null, textSize);
		item.isMenuItem = true;
		item.targetY = index;
		item.ID = index;
		add(item);

		itemCallbacks.set(item, callbacks);

		if (curSelected == null)
			curSelected = index;
		else
			item.alpha = 0.6;

		return item;
	}

	private var holdTimer:Float = 0.0;
	function updateInput(elapsed:Float, controls:Controls)
	{
		/*
		var justUp = FlxG.keys.justPressed.UP; 
		var justDown = FlxG.keys.justPressed.DOWN;
		var up = justUp || FlxG.keys.pressed.UP;
		var down = justDown || FlxG.keys.pressed.DOWN;
		*/
		var justUp = controls.UI_UP_P;
		var justDown = controls.UI_DOWN_P;
		var up = justUp || controls.UI_UP;
		var down = justDown || controls.UI_DOWN;
		var accept = controls.ACCEPT;

		if (FlxG.mouse.wheel != 0)
			curSelected -= FlxG.mouse.wheel;

		// kind of a mess but it works just like i want it to

		if (up || down){
			if (justUp){
				curSelected--;
				holdTimer = 0.0;
			}
			else if (up){
				if (holdTimer < -0.25){
					holdTimer += 0.05;
					curSelected--;
				}
				holdTimer -= elapsed;
			}

			if (justDown){
				curSelected++;
				holdTimer = 0.0;
			}
			else if (down){
				if (holdTimer > 0.25){
					holdTimer -= 0.05;
					curSelected++;
				}
				holdTimer += elapsed;
			}
		}else{
			holdTimer = 0.0;
		}
		
		if (accept && curItem != null){
			if (callbacks.onAccept != null)
				callbacks.onAccept(curSelected, curItem);

			var callbacks = itemCallbacks.get(curItem);
			if (callbacks != null && callbacks.onAccept != null)
				callbacks.onAccept();
		}
	}

	override public function update(elapsed:Float)
	{
		if (controls != null)
			updateInput(elapsed, controls);

		super.update(elapsed);
	}

	/** Removes and destroys every item added to this group **/
	override function clear(){
		while (members.length > 0){
			var last = members[members.length - 1];
			last.destroy();
			itemCallbacks.remove(last);
			remove(last, true);
		}

		curSelected = null;

		super.clear();
	}

	override function destroy(){
		itemCallbacks.clear();

		return super.destroy();
	}
}