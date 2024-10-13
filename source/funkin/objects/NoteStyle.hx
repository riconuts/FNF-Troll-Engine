package funkin.objects;

import funkin.scripts.FunkinHScript;
import funkin.objects.shaders.ColorSwap;
import funkin.states.PlayState;

class NoteStyle {
	static var map:Map<String, NoteStyle> = [];
	
	public static function loadDefault() {
		map.clear();
		map.set("default", new DefaultNoteStyle());
	}

	public static function get(name:String, fallback:String = 'default'):Null<NoteStyle> {
		return map.get(exists(name) ? name : fallback);
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

	////
	public function new() {
		
	}

	public function getName():String {
		return 'blank';
	}
	
	public function update(elapsed:Float):Void {
		
	}

	public function optionsChanged(changed:Array<String>):Void {
		
	}
	
	public function destroy():Void {
		
	}

	//
	public function loadReceptor(note:Note):Bool {
		return true; // Whether the style was applied or not
	}
	
	public function unloadReceptor(note:Note):Void {

	}

	//
	public function loadNote(note:Note):Bool {
		return true; // Whether the style was applied or not
	}
	
	public function unloadNote(note:Note):Void {

	}

	/// uuunhh lol idk what will happen w notesplashes cuz those get recycled n shit
	/// maybe notes should too, they could get split into notesprite and notedata, v-slice does it like that!

	public function loadNoteSplash(splash:NoteSplash):Bool {
		return true;
	}

	public function unloadNoteSplash(splash:NoteSplash):Void {
		
	}
}

/// fuckkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkllllk
typedef NoteTexture = {
	var key:String;
	var isQuant:Bool;
}

class DefaultNoteStyle extends NoteStyle
{
	var textureKey:String = 'NOTE_assets';
	var canQuant:Bool = true;
	var isQuant:Bool = false;

	var loadedNotes:Array<Note> = [];
	var frames = null;
	
	//// for jsons maybe
	var noteAnims:Array<String> = [];
    var sustainPartAnims:Array<String> = [];
    var sustainEndAnims:Array<String> = [];

    var receptorIdleAnims:Array<String> = [];
    var receptorPressAnims:Array<String> = [];
    var receptorConfirmAnims:Array<String> = [];

	function getColorName(col:Int) {
		return switch(col) {
			default:'purple';
			case 1: 'blue';
			case 2: 'green';
			case 3: 'red';
		}
	}

	function getDirectionName(col:Int) {
		return switch(col) {
			default: "left";
			case 1: "down";
			case 2: "up";
			case 3: "right";
		}
	}

	function getNoteAnimPrefix(note:Note) {
		return switch(note.holdType) {
			default: noteAnims[note.column];
			case PART: sustainPartAnims[note.column];
			case END: sustainEndAnims[note.column];
		}
	}

	function setupDefaultAnims() {
		for (i in 0...4) {
			var colorName = getColorName(i);
			noteAnims[i] = colorName+'0';
			sustainPartAnims[i] = colorName+' hold piece';
			sustainEndAnims[i] = colorName+' hold end';
		}

		sustainEndAnims[0] = 'pruple end hold'; // ?????
		// this is autistic wtf		
	}

	public function new() {
		trace("Creating default style");
		super();
		setupDefaultAnims();

		textureKey = PlayState.arrowSkin.length > 0 ? PlayState.arrowSkin : "NOTE_assets";
		var textureInfo = getTextureInfo(textureKey);
		if (textureInfo != null) {
			frames = Paths.getSparrowAtlas(textureInfo.key);
			isQuant = textureInfo.isQuant;
		}
		trace("Created default style");
	}

	function getTextureInfo(key:String):NoteTexture {
		var searchQuant:Bool = canQuant && ClientPrefs.noteSkin=='Quants';

		if (searchQuant) {
			var split = key.split('/');
			var fileName:String = split.pop();
			var dir:String = split.join('/');
			var key:String = '$dir/$fileName';

			var quantKey:Null<String> = Note.getQuantTexture(dir, fileName, key);
			if (quantKey != null) {
				return {key: quantKey, isQuant: true};
			}
		}
		
		if (Paths.imageExists(key)) {
			return {key: key, isQuant: false};
		}

		return null;
	}

	function updateColours(note:Note) {
		var hsb:Array<Int> = note.isQuant ? ClientPrefs.quantHSV[Note.quants.indexOf(note.quant)] : ClientPrefs.arrowHSV[note.column];
		var colorSwap:ColorSwap = note.colorSwap;

		(hsb == null) ? colorSwap.setHSB() : colorSwap.setHSB(
			hsb[0] / 360, 
			hsb[1] / 100, 
			hsb[2] / 100
		);
	}

	override function optionsChanged(changed) {
		if (true) {
			for (note in loadedNotes)
				updateColours(note);
		}
	}

	override function getName() {
		return 'default';
	}

	override function unloadNote(note:Note) {
		loadedNotes.remove(note);
	}

	override function loadNote(note:Note) {
		loadedNotes.push(note);

		if (note.texture != null && note.texture.length != 0) { 
			// sighhhh, i guess this is still convenient
			var textureInfo = getTextureInfo(note.texture);
			if (textureInfo != null) {
				note.frames = Paths.getSparrowAtlas(textureInfo.key);
				note.isQuant = textureInfo.isQuant;
			}

		}else {
			note.frames = this.frames;
			note.isQuant = this.isQuant;
		}
	
		var animPrefix = getNoteAnimPrefix(note);
		//trace('loaded note $note, $animPrefix');

		note.animation.addByPrefix('', animPrefix, 24);
		note.animation.play('');

		note.colorSwap = new ColorSwap(); 
		note.shader = note.colorSwap.shader;
		updateColours(note);

		note.scale.x = note.scale.y = Note.spriteScale; 
		note.defScale.copyFrom(note.scale);
		note.updateHitbox();

		return true; 
	}
}

// todooooooooo
class ScriptedNoteStyle extends DefaultNoteStyle
{
	public static function fromPath(path:String):Null<ScriptedNoteStyle> {
		return Paths.exists(path) ? new ScriptedNoteStyle(FunkinHScript.fromFile(path)) : null;
	}

	public static function fromName(name:String):Null<ScriptedNoteStyle> {
		return fromPath(Paths.getPath('notestyles/$name'));
	}
	
	final script:FunkinHScript;

	private function new(script:FunkinHScript) {
		this.script = script;
		super(); 
	}

	override function getName():String {
		return Std.string(script.get('name'));
	}
}