package funkin.data;

import haxe.Constraints.Function;

typedef TextObject = {
	function set_text(str:String):String;
}

class PauseMenuOption
{
	public var name:String;
	
	public var displayName:String;
	public var text:TextObject = null;

	public var onSelect:Function = null;
	public var unSelect:Function = null;
	public var onAccept:Function = null;
	public var onUpdate:Float -> Void = null;

	public function new() {}

	public function select() {
		if (onSelect != null) onSelect();
	}

	public function unselect() {
		if (unSelect != null) unSelect();	
	}

	public function accept() {
		if (onAccept != null) onAccept();		
	}

	public function update(elapsed:Float) {
		if (onUpdate != null) onAccept();	
	}
}