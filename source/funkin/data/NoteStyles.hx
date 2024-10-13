package funkin.data;

import funkin.objects.notestyles.*;

enum abstract NoteStyleAssetType(String) from String to String {
	var INDICES = "indices";
	var SPARROW = "sparrow";
	var SINGLE = "single";
	var SOLID = "solid";
	var NONE = "none";
}

typedef NoteStyleData = {
	var name:String;
	var scale:Float;
	var assets:Map<String, NoteStyleAsset>;
} 

typedef NoteStyleAsset = {
	////
	var type:NoteStyleAssetType;
	var imageKey:String;

	////
	var canBeColored:Bool; // affected by ClientPrefs.arrowHSV and shit
	var antialiasing:Null<Bool>;
	var scale:Float;
	var alpha:Float;
}

typedef NoteStyleAnimatedAsset<T:Any> = {
	> NoteStyleAsset,
	
	@:optional var animations:Map<String, Array<T>>; // for stuff like receptors, splashes
	@:optional var data:Array<T>; // for stuff like notes
	@:optional var animation:T; // for whatever
} 

typedef NoteStyleSparrowAsset = NoteStyleAnimatedAsset<String>;

typedef NoteStyleIndicesAsset = {
	> NoteStyleAnimatedAsset<Array<Int>>, // this is kinda nuts
	var hInd:Int;
	var vInd:Int;
}

class NoteStyles {
	private static final map:Map<String, BaseNoteStyle> = [];
	
	private static function set(name, style:BaseNoteStyle){
		map.set(name, style);
		return style;
	} 

	public static function get(name:String, fallback:String = 'default'):Null<BaseNoteStyle> {
		return map.get(exists(name) ? name : fallback);
	}

	public static function loadDefault() {
		clear();
		set("default", DataNoteStyle.getDefault());
	}

	public static function exists(name:String) {
		return map.exists(name);
	}

	public static function clear() {
		for (ns in map) {
			ns.destroy();
		}
		map.clear();
	}

	public static function iterator() {
		return map.iterator();
	}

	public static function keyValueIterator() {
		return map.keyValueIterator();
	}
}