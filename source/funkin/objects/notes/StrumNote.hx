package funkin.objects.notes;

import funkin.states.PlayState;
import funkin.objects.playfields.PlayField;
import funkin.scripts.FunkinHScript;
#if !macro
import funkin.objects.shaders.NoteColorSwap;

using StringTools;
#end

// honestly we should make it so you can attach a hscript to receptors and type-less notes
// maybe notetypes/default.hx and notetypes/receptor.hx
// idk lol i'll explore it more once i get around to making skins/assetpacks (resource packs but troll engine)

class StrumNote extends NoteObject
{
	public static var defaultStaticAnimNames:Array<String> = ['arrowLEFT', 'arrowDOWN', 'arrowUP', 'arrowRIGHT'];
	public static var defaultPressAnimNames:Array<String> = ["left press", "down press", "up press", "right press"];
	public static var defaultConfirmAnimNames:Array<String> = ["left confirm", "down confirm", "up confirm", "right confirm"];

	////
	public var texture(default, set):String = null;
	public var downScroll:Bool = false;
	public var isQuant:Bool = false;
	public var resetAnim:Float = 0;

	////
	public var noteMod(default, set):String;
	public var genScript:FunkinHScript;

	////
	public var z:Float = 0;

	private var field:PlayField;

	public function new(x:Float, y:Float, leColumn:Int, ?playField:PlayField, ?hudSkin:String = 'default') {
		super(x, y);
		colorSwap = new NoteColorSwap();
		shader = NoteColorSwap.shader;

		objType = STRUM;
		column = leColumn;
		field = playField;
		noteMod = hudSkin;
	}

	override function toString()
		return '(column: $column | texture $texture | visible: $visible)';
	
	private function set_texture(value:String):String {
		if(texture != value) {
			texture = value;
			reloadNote();
		}
		return value;
	}

	function set_noteMod(value:String) {
		genScript = (PlayState.instance == null) ? null : PlayState.instance.getHudSkinScript(value);

		if (genScript == null) {
			texture = PlayState.arrowSkin;

		}else if (genScript.exists("setupReceptorTexture")) {
			genScript.executeFunc("setupReceptorTexture", [this]);
		
		}else {
			var skin:String = PlayState.arrowSkin;

			var newTex = (genScript != null && genScript.exists("texture")) ? genScript.get("texture") : skin;
			if (genScript != null)
			{
				if (genScript.exists("texturePrefix"))
					newTex = genScript.get("texturePrefix") + texture;

				if (genScript.exists("textureSuffix"))
					newTex += genScript.get("textureSuffix");
			}

			texture = newTex; // Load texture and anims
		}

		return noteMod = value;
	}

	public function reloadNote()
	{
		// TODO: add indices support n shit

		var textureKey:String;

		if (ClientPrefs.noteSkin == 'Quants') {
			var split = texture.split('/');
			var fileName = split.pop();
			var folderPath = split.join('/') + '/';

			textureKey = Note.getQuantTexture(folderPath, fileName, texture);
			if (textureKey != null) isQuant = true;
			else textureKey = texture;

		}else
			textureKey = texture;

		var lastAnim:String = animation.name;
		if (lastAnim == null) lastAnim = 'static';

		frames = Paths.getSparrowAtlas(textureKey);

		animation.addByPrefix('static', defaultStaticAnimNames[column], 24, false);
		animation.addByPrefix('pressed', defaultPressAnimNames[column], 24, false);
		animation.addByPrefix('confirm', defaultConfirmAnimNames[column], 24, false);

		playAnim(lastAnim, true);

		scale.x = scale.y = Note.spriteScale;
		defScale.copyFrom(scale);
		updateHitbox();
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
		super.update(elapsed);
	}

	public function playAnim(anim:String, ?force:Bool = false, ?note:Note) {
		animation.play(anim, force);
		centerOrigin();
		centerOffsets();

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

	#if NMV_MOD_COMPATIBILITY
	public function addOffset(name:String, x:Float = 0, y:Float = 0) {} // StrumNotes dont have offsets
	#end
}