package funkin.objects.notes;

import funkin.states.PlayState;
import funkin.scripts.Globals;
import flixel.FlxG;
import funkin.objects.shaders.NoteColorSwap;

class NoteSplash extends NoteObject
{
	private var idleAnim:String;
	private var textureLoaded:String = null;

	public function new(x:Float = 0, y:Float = 0, ?note:Int = 0) {
		super(x, y);
		objType = SPLASH;
		
		colorSwap = new NoteColorSwap();
		shader = NoteColorSwap.shader;

		loadAnims(PlayState.splashSkin);
		setupNoteSplash(x, y, note);
		visible = false;
	}

	function callOnHScripts(event:String, ?args:Array<Dynamic>, ?vars:Map<String, Dynamic>, ignoreStops = false, ?exclusions:Array<String>):Dynamic{
		if(FlxG.state == PlayState.instance)
			return PlayState.instance.callOnScripts(event, args, ignoreStops, exclusions, PlayState.instance.hscriptArray, vars);
		else
			return Globals.Function_Continue;

	}
	
	public var animationAmount:Int = 2;
	public function setupNoteSplash(x:Float, y:Float, column:Int = 0, texture:String = null, hueColor:Float = 0, satColor:Float = 0, brtColor:Float = 0, ?note:Note) 
	{
		visible = true;
		var doR:Bool = false;
		if (note != null && note.genScript != null){
			var ret:Dynamic = note.genScript.call("preSetupNoteSplash", [x, y, column, texture, hueColor, satColor, brtColor, note], ["this" => this, "noteData" => noteData, "column" => column]);
			if(ret == Globals.Function_Stop) doR = true;
		}
		
		if (callOnHScripts("preSetupNoteSplash", [x, y, column, texture, hueColor, satColor, brtColor, note], ["this" => this, "noteData" => noteData, "column" => column]) == Globals.Function_Stop)
			return;

		if (doR)return;
		

		setPosition(x, y);
		animationAmount = 2;
		alpha = 0.6;
		scale.set(0.8, 0.8);
		updateHitbox();

		this.column = column;
		if (texture == null) texture = PlayState.splashSkin;

		if(note != null && note.genScript != null){
			if (note.genScript.exists("texturePrefix")) texture = note.genScript.get("texturePrefix") + texture;

			if (note.genScript.exists("textureSuffix")) texture += note.genScript.get("textureSuffix");
		}

		if (textureLoaded != texture) {
			var ret = Globals.Function_Continue;

			if (note != null && note.genScript != null)
				ret = note.genScript.call("loadSplashAnims", [texture], ["this" => this, "noteData" => noteData, "column" => column]);
			
			var ret2 = callOnHScripts("loadSplashAnims", [texture], ["this" => this, "noteData" => noteData, "column" => column]);

			if (ret != Globals.Function_Stop && ret2 != Globals.Function_Stop) 
				loadAnims(texture);
		}

		colorSwap.hue = hueColor;
		colorSwap.saturation = satColor;
		colorSwap.brightness = brtColor;

		var ret = Globals.Function_Continue;
		if (note != null && note.genScript != null)
			ret = note.genScript.call("postSetupNoteSplash", [x, y, column, texture, hueColor, satColor, brtColor, note], ["this" => this, "noteData" => noteData, "column" => column]);
		
		var ret2 = callOnHScripts("postSetupNoteSplash", [x, y, column, texture, hueColor, satColor, brtColor, note], ["this" => this, "noteData" => noteData, "column" => column]);

		if (ret != Globals.Function_Stop && ret2 != Globals.Function_Stop){
			var playAnim = 'note$column';
			if (animationAmount > 1) playAnim += '-${FlxG.random.int(1, animationAmount)}';

			animation.play(playAnim, true);
			if (animation.curAnim != null) animation.curAnim.frameRate = 24 + FlxG.random.int(-2, 2);
		}
	}

	function loadAnims(skin:String) {
		textureLoaded = skin;
		frames = Paths.getSparrowAtlas(skin);
		for (i in 1...animationAmount+1)
		{
			animation.addByPrefix("note0-" + i, "note splash purple " + i, 24, false);
			animation.addByPrefix("note1-" + i, "note splash blue " + i, 24, false);
			animation.addByPrefix("note2-" + i, "note splash green " + i, 24, false);
			animation.addByPrefix("note3-" + i, "note splash red " + i, 24, false);
		}
	}

	override function update(elapsed:Float) 
	{
		if (animation.curAnim == null || animation.curAnim.finished)  kill();

		super.update(elapsed);
	}
}