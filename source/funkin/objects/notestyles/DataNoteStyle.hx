package funkin.objects.notestyles;

import funkin.objects.shaders.ColorSwap;
import funkin.data.NoteStyles;

class DataNoteStyle extends BaseNoteStyle
{
	private static function structureToMap(st):Map<String, Dynamic> {
		return [
			for (k in Reflect.fields(st)){
				k => Reflect.field(st, k);
			}
		];
	}

	private static function getData(name:String):NoteStyleData {
		var path = Paths.getPath('notestyles/$name.json');
		var json = Paths.getJson(path);
		if (json == null) return null;

		var assetsMap = structureToMap(json.assets);
		json.assets = assetsMap;
		if (json.scale == null) json.scale = 1.0;

		for (name => asset in assetsMap) {
			asset.canBeColored = asset.canBeColored != false;
			// if (asset.scale == null) asset.scale = 1.0;
			if (asset.alpha == null) asset.alpha = 1.0;

			if (asset.animations != null)
				asset.animations = structureToMap(asset.animations);
		}

		return cast json;
	}

	public static function getDefault():DataNoteStyle {
		return new DataNoteStyle('default', getData('default'));
	}

	public static function fromName(name:String):Null<DataNoteStyle> {
		var data = getData(name);
		return data==null ? null : new DataNoteStyle(name, null);
	}

	final loadedNotes:Array<Note> = []; 
	final data:NoteStyleData;

	private function new(id:String, data:NoteStyleData) {
		this.data = data;

		trace("made default with", data.assets);

		super(id);
	}

	function updateColours(note:Note):Void {
		var hsb:Array<Int> = note.isQuant ? ClientPrefs.quantHSV[Note.quants.indexOf(note.quant)] : ClientPrefs.arrowHSV[note.column];
		var colorSwap:ColorSwap = note.colorSwap;

		if (colorSwap != null) {
			(hsb == null) ? colorSwap.setHSB() : colorSwap.setHSB(
				hsb[0] / 360, 
				hsb[1] / 100, 
				hsb[2] / 100
			);
		}
	}

	function getNoteAsset(note:Note):Null<NoteStyleAsset> {
		var usingQuants = ClientPrefs.noteSkin=="Quants";

		var name:String = switch(note.holdType) {
			default: "tap";
			case PART: "hold";
			case END: "holdEnd";
			// what abt rolls
		}

		if (usingQuants) {
			if (data.assets.exists("QUANT"+name)){
				return data.assets.get("QUANT"+name);
			}
		}

		return data.assets.get(name);
	}

	inline function getNoteAnim(note:Note, asset:NoteStyleAnimatedAsset<Any>):Null<Any> {
		if (asset.animation != null) 
			return asset.animation 
		else if (asset.data != null)
			return asset.data[note.column];
		else
			return null;
	}

	override function optionsChanged(changed) {
		if (true) {
			for (note in loadedNotes)
				updateColours(note);
		}
	}

	override function unloadNote(note:Note) {
		loadedNotes.remove(note);
	}

	override function loadNote(note:Note) {
		loadedNotes.push(note);

		var asset:NoteStyleAsset = getNoteAsset(note);

		switch (asset.type) {
			case SPARROW: var asset:NoteStyleSparrowAsset = cast asset;
				note.frames = Paths.getSparrowAtlas(asset.imageKey);

				var anim:String = getNoteAnim(note, asset);
				note.animation.addByPrefix('', anim); // might want to use the json anim name, whatever
				note.animation.play('');

				trace(note, asset, anim);

			case INDICES: var asset:NoteStyleIndicesAsset = cast asset;
				note.loadGraphic(Paths.image(asset.imageKey), true, asset.hInd, asset.vInd);
				
				var anim:Array<Int> = getNoteAnim(note, asset);
				note.animation.add('', anim);
				note.animation.play('');

			case SINGLE:
				note.loadGraphic(asset.imageKey);

			case SOLID: // lol
				note.makeGraphic(1, 1, CoolUtil.colorFromString(asset.imageKey), false, asset.imageKey);

			default: //case NONE: 
				note.makeGraphic(1,1,0,false,'invisible'); // idfk something might want to change .visible so
		}

		// note.alpha = asset.alpha;

		if (asset.antialiasing != null) {
			note.antialiasing = asset.antialiasing;
		}else {
			note.useDefaultAntialiasing = true;
		}

		if (asset.canBeColored == false) {
			note.colorSwap = null;
			note.shader = null;
		}else {
			note.colorSwap = new ColorSwap(); 
			note.shader = note.colorSwap.shader;
			updateColours(note);
		}
		
		note.scale.x = note.scale.y = (asset.scale ?? data.scale);
		note.defScale.copyFrom(note.scale);
		note.updateHitbox();

		return true; 
	}
}