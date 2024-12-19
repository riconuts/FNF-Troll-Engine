package funkin.objects;

import funkin.data.NoteStyles;
import funkin.objects.notestyles.BaseNoteStyle;
import funkin.states.PlayState;
import funkin.objects.playfields.PlayField;
import funkin.scripts.FunkinHScript;
#if !macro
import funkin.objects.shaders.ColorSwap;

using StringTools;
#end

// honestly we should make it so you can attach a hscript to receptors and type-less notes
// maybe notetypes/default.hx and notetypes/receptor.hx
// idk lol i'll explore it more once i get around to making skins/assetpacks (resource packs but troll engine)

class StrumNote extends NoteObject implements NoteObject.IColorable
{
	public var noteStyle(default, set):String;
	var _noteStyle:BaseNoteStyle;
	private function set_noteStyle(name:String):String {
		if (noteStyle == name)
			return name;

		if (_noteStyle != null) 
			_noteStyle.unloadReceptor(this);

		// find the first existing style in the following order [hudskin.getNoteStyle(name), name, 'default']
		var newStyle:BaseNoteStyle = null;

		if (genScript != null) {
			var ret = genScript.executeFunc("getNoteStyle", [name]);
			if (ret is String)
				newStyle = NoteStyles.get(ret, name);
		}

		if (newStyle == null)
			newStyle = NoteStyles.get(name, 'default');

		//trace("loading recepor", name, (newStyle==null?null:newStyle.id));
		if (newStyle.loadReceptor(this))
			noteStyle = name; // yes, the base name, not the hudskin name.

		_noteStyle = newStyle;
		return noteStyle;
	}

	////
	public var colorSwap:ColorSwap = new ColorSwap();
	public var downScroll:Bool = false;
	public var resetAnim:Float = 0;

	////
	public var noteMod(default, set):String;
	public var genScript:FunkinHScript;

	////
	public var z:Float = 0;
	public var zIndex:Float = 0;
	public var desiredZIndex:Float = 0;

	private var field:PlayField;

	public function new(x:Float, y:Float, leColumn:Int, ?playField:PlayField, ?hudSkin:String = 'default', ?noteStyle:String) {
		super(x, y);
		objType = STRUM;
		column = leColumn;
		field = playField;
		noteMod = hudSkin;
		
		shader = colorSwap.shader;

		if (noteStyle == null && field != null) 
			this.noteStyle = field.defaultNoteStyle;
		else
			this.noteStyle = noteStyle;
	}

	override function toString()
		return '(column: $column | visible: $visible)';

	public function getZIndex(?daZ:Float)
	{
		if (daZ==null) daZ = z;

		return z + desiredZIndex;
	}

	function updateZIndex()
		zIndex = getZIndex();
	

	function set_noteMod(value:String):String {
		if (value == null)
			value = 'default';

		////
		if (PlayState.instance != null)
			genScript = PlayState.instance.getHudSkinScript(value);

		return noteMod = value;
	}
	public function postAddedToGroup()
	{
		playAnim('static');
		ID = column;
	}

	override function update(elapsed:Float) {
		if (resetAnim > 0) {
			resetAnim -= elapsed;

			if (resetAnim <= 0) {
				resetAnim = 0;
				playAnim('static');
			}
		}

		if (animation.name == 'confirm') 
			centerOrigin();	
		
		updateZIndex();

		if (_noteStyle != null)
			_noteStyle.updateObject(this, elapsed);
		
		super.update(elapsed);
	}

	public function playAnim(anim:String, ?force:Bool = false, ?note:Note) {
		animation.play(anim, force);
		centerOrigin();
		centerOffsets();
		updateZIndex();

		if (animation.name == 'static') {
			colorSwap.setHSB();
		} 
		else if (note != null) {
			// ok now the quants should b fine lol
			colorSwap.copyFrom(note.colorSwap);
		}
		else if(!isQuant) {
			colorSwap.setHSBIntArray(ClientPrefs.arrowHSV[column % 4]);
		}
		else {
			colorSwap.setHSB();
		}
	}
}