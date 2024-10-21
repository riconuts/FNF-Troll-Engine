package funkin.objects;
import funkin.data.NoteStyles;
import funkin.objects.notestyles.BaseNoteStyle;
import funkin.objects.shaders.ColorSwap;
import math.Vector3;
using StringTools;

class NoteSplash extends NoteObject implements NoteObject.IColorable {
	public var colorSwap:ColorSwap = null;

	public var vec3Cache:Vector3 = new Vector3();

	public var noteStyle(default, set):String;

	var _noteStyle:BaseNoteStyle;

	private function set_noteStyle(?name:String):String {
		if (noteStyle == name)
			return name;

		if (_noteStyle != null)
			_noteStyle.unloadNoteSplash(this);

		// find the first existing style in the following order [hudskin.getNoteStyle(name), name, 'default']
		var newStyle:BaseNoteStyle = null;

		if(name == null){
			noteStyle = null;
			return noteStyle;
		}

		if (newStyle == null)
			newStyle = NoteStyles.get(name, 'default');

		trace("loading splash", name, (newStyle == null ? null : newStyle.id));
		if (newStyle.loadNoteSplash(this)){
			noteStyle = name; // yes, the base name, not the hudskin name.
			_noteStyle = newStyle;
		}
		return noteStyle;
	}

	public function new(?noteStyle:String = 'default') {
		super();
		objType = SPLASH;

		colorSwap = new ColorSwap();
		shader = colorSwap.shader;

		this.noteStyle = noteStyle;
		visible = false;
	}

	public function hitNote(note:Note)
	{
		visible = true;
		column = note.column;

		this.noteStyle = note.noteStyle; // Set the notesplash
		
		_noteStyle.loadNoteSplash(this, note); 

		animation.play("splash", true);
		if (animation.curAnim != null) animation.curAnim.frameRate += FlxG.random.int(-2, 2); // TODO: figure out a way to make this data-driven or otherwise driven by the NoteStyle

		// TODO: canBeColored
		if(note.isQuant == isQuant)
			colorSwap.setHSB(note.noteSplashHue, note.noteSplashSat, note.noteSplashBrt);
		else
			colorSwap.setHSB(0, 0, 0);
	}

	override function update(elapsed:Float) {
		if (animation.curAnim == null || animation.curAnim.finished)
			kill();

		super.update(elapsed);
	}

}