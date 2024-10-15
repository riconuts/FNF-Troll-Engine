package funkin.data;

import flixel.util.typeLimit.OneOfTwo;
import funkin.objects.notestyles.*;

enum abstract NoteStyleAssetType(String) from String to String {
	var INDICES = "indices";
	var SPARROW = "sparrow";
	var MULTISPARROW = "multisparrow";
	var SINGLE = "single";
	var SOLID = "solid";
	var NONE = "none";
}

enum abstract NoteStyleAnimationType(String) from String to String
{
	var COLUMN = "column";
	var STATIC = "static";
	// might wanna add more so!!
}

typedef NoteStyleData = {
	var name:String;
	var scale:Float;
	var antialiasing:Bool;
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
	@:optional var quant:Bool;
}

typedef NoteStyleAnimationData<T:Any> = {
	type:NoteStyleAnimationType,
	name:String,
	//?hasRandom:Bool, // because I forgot indices use an array LOL
	?data:Array<OneOfTwo<T, Array<T>>>, // used for 'column' typE. If its an array and hasRandom is true then it should randomly pick between the 2 options
	?animation:OneOfTwo<T, Array<T>>, // used for 'static' type. If its an array and hasRandom is true then randomly pick

	?framerate:Int, // prob default to 24?
	?looped:Bool,

	?imageKey:String // only used in multisparrow!!
}

typedef NoteStyleAnimatedAsset<T:Any> = {
	> NoteStyleAsset,

	@:optional var framerate:Int; // default framerate

	@:optional var animations:Array<NoteStyleAnimationData<T>>; // primarily for stuff like receptors
	//@:optional var data:Array<OneOfTwo<T, NoteStyleAnimationData<T>>>; // I cant check for typedef kms

	@:optional var data:Array<T>; // for stuff like notes
	@:optional var animation:T; // for whatever

	@:optional var looped:Bool; // default looped
}

typedef NoteStyleSparrowAsset = NoteStyleAnimatedAsset<String>;

typedef NoteStyleMultiSparrowAsset = {
	> NoteStyleAnimatedAsset<String>,
	additionalAtlases:Array<String>
}

typedef NoteStyleIndicesAsset = {
	> NoteStyleAnimatedAsset<Array<Int>>, // this is kinda nuts
	var hInd:Int;
	var vInd:Int;

	@:optional var rows:Int;
	@:optional var columns:Int;
}

class NoteStyles 
{
	private static final map:Map<String, BaseNoteStyle> = [];
	
	private static function set(name, style:BaseNoteStyle){
		map.set(name, style);
		return style;
	} 

	public static function tryGetNewStyle(name:String, ?useCache:Bool = true){
		if (exists(name) && useCache)
			return map.get(name);
		
		var dataStyle = DataNoteStyle.fromName(name);
		if(dataStyle != null){
			if (useCache)
				set(name, dataStyle);
			return dataStyle;
		}
/* 		var scriptedStyle = ScriptedNoteStyle.fromName(name);
		if(scriptedStyle != null)return scriptedStyle; */
		return null;
	}

	public static function get(name:String, fallback:Null<String> = 'default', ?tryToCreate:Bool = true):Null<BaseNoteStyle> {
		if (tryToCreate && !exists(name)){
			var newStyle:BaseNoteStyle = tryGetNewStyle(name);
			if(newStyle != null)
				return newStyle;
			
		}

		return fallback == null ? map.get(name) : map.get(exists(name) ? name : fallback);
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