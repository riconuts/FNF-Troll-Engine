package funkin.data;

import haxe.Constraints.Function;

typedef TextObject = {
	function set_text(str:String):String;
}

class PauseMenuOption
{
	public var id:String;
	
	public var displayName:String;
	public var obj:TextObject = null;

	public var onSelect:Function = null;
	public var unSelect:Function = null;
	public var onAccept:Function = null;
	public var onUpdate:Float -> Void = null;

	public function new(id:String, ?onAccept:Void->Void = null) {
		this.id = id;
		this.displayName = Paths.getString('pauseoption_$id') ?? id;
		this.onAccept = onAccept;
	}

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