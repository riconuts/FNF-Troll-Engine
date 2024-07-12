package funkin.objects;

import funkin.states.PlayState;
import funkin.objects.playfields.PlayField;
import funkin.scripts.FunkinHScript;
#if !macro
import math.Vector3;
import funkin.objects.shaders.ColorSwap;

using StringTools;
#end

// honestly we should make it so you can attach a hscript to receptors and type-less notes
// maybe notetypes/default.hx and notetypes/receptor.hx
// idk lol i'll explore it more once i get around to making skins/assetpacks (resource packs but troll engine)

class StrumNote extends NoteObject
{
	public var vec3Cache:Vector3 = new Vector3(); // for vector3 operations in modchart code
	
	public var z:Float = 0;
	public var zIndex:Float = 0;
	public var desiredZIndex:Float = 0;
	
	public var isQuant:Bool = false;
	public var resetAnim:Float = 0;
	public var sustainReduce:Bool = true;
	public var downScroll:Bool = false;

	private var colorSwap:ColorSwap;
	//private var player:Int;
	
	public var texture(default, set):String = null;
	private function set_texture(value:String):String {
		if(texture != value) {
			texture = value;
			reloadNote();
		}
		return value;
	}

	public function getZIndex(?daZ:Float)
	{
		if(daZ==null)daZ = z;
		var animZOffset:Float = 0;
		if (animation.curAnim != null && animation.curAnim.name == 'confirm')
			animZOffset += 1;
		return z + desiredZIndex + animZOffset;
	}

	function updateZIndex()
	{
		zIndex = getZIndex();
	}

    public var noteMod(default, set):String;
    public var genScript:FunkinHScript;

    function set_noteMod(value:String){
		if (PlayState.instance != null)
		{
            var script = PlayState.instance.hudSkinScripts.get(value);
            if(script == null){
				var baseFile = 'hudskins/$value.hscript';
				var files = [#if MODS_ALLOWED Paths.modFolders(baseFile), #end Paths.getPreloadPath(baseFile)];
				for (file in files)
				{
					if (!Paths.exists(file))
						continue;
                    script = FunkinHScript.fromFile(file, value);
                    PlayState.instance.hscriptArray.push(script);
                    PlayState.instance.funkyScripts.push(script);
                    PlayState.instance.hudSkinScripts.set(value, script);
                }

            }
			genScript = script;
		}
		// trace(noteData);

		if (genScript != null && genScript.exists("setupReceptorTexture"))
			genScript.executeFunc("setupReceptorTexture", [this]);
		else{
			var skin:String = PlayState.arrowSkin;
			if (skin == null || skin.length < 1)
				skin = 'NOTE_assets';

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
	
    var field:PlayField;

	override function toString()
	{
		return '(column: $column | texture $texture | visible: $visible)';
	}

	public function new(x:Float, y:Float, leColumn:Int, ?field:PlayField, ?hudSkin:String = 'default') {
		colorSwap = new ColorSwap();
		shader = colorSwap.shader;
        this.field = field;
		super(x, y);
		objType = STRUM;
		column = leColumn;
        
        noteMod = hudSkin;

		scrollFactor.set();
	}

	// stupid
	static var directionUpperArray = ["LEFT", "DOWN", "UP", "RIGHT"];
	static var directionLowerArray = ["left", "down", "up", "right"];
	public function reloadNote()
	{
		// TODO: add indices support n shit

		var lastAnim:String = animation.curAnim == null ? 'static' : animation.curAnim.name;
		var textureKey:String = texture;
		isQuant = false;
		
		if (ClientPrefs.noteSkin == 'Quants') {
			var quantTexKey = 'QUANT$texture';
			if (Paths.imageExists(quantTexKey)) {
				textureKey = quantTexKey;
				isQuant = true;
			}
		}

		frames = Paths.getSparrowAtlas(textureKey);
		animation.addByPrefix('static', 'arrow' + directionUpperArray[column], 24, false);
		animation.addByPrefix('pressed', directionLowerArray[column] + ' press', 24, false);
		animation.addByPrefix('confirm', directionLowerArray[column] + ' confirm', 24, false);

		if (lastAnim != null)
			playAnim(lastAnim, true);

		scale.set(0.7, 0.7);
		defScale.copyFrom(scale);
		updateHitbox();
	}

	public function postAddedToGroup()
	{
		playAnim('static');
		ID = column;
	}

	override function update(elapsed:Float) {
		if(resetAnim > 0) {
			resetAnim -= elapsed;
			if(resetAnim <= 0) {
				playAnim('static');
				resetAnim = 0;
			}
		}
		if(animation.curAnim != null){
			if(animation.curAnim.name == 'confirm') 
				centerOrigin();
			
		}
		updateZIndex();

		super.update(elapsed);
	}

	public function playAnim(anim:String, ?force:Bool = false, ?note:Note) {
		animation.play(anim, force);
		centerOrigin();
		centerOffsets();
		updateZIndex();

		if (animation.curAnim == null || animation.curAnim.name == 'static') {
			colorSwap.hue = 0;
			colorSwap.saturation = 0;
			colorSwap.brightness = 0;
		} 
		else if (note != null) {
			// ok now the quants should b fine lol
			colorSwap.hue = note.colorSwap.hue;
			colorSwap.saturation = note.colorSwap.saturation;
			colorSwap.brightness = note.colorSwap.brightness;
		}
		else if(!isQuant) {
			colorSwap.hue = ClientPrefs.arrowHSV[column % 4][0] / 360;
			colorSwap.saturation = ClientPrefs.arrowHSV[column % 4][1] / 100;
			colorSwap.brightness = ClientPrefs.arrowHSV[column % 4][2] / 100;
		}
		else {
			colorSwap.hue =  0;
			colorSwap.saturation = 0;
			colorSwap.brightness = 0;
		}
	}
}