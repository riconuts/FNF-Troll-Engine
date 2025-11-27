package funkin.objects.notes;

import funkin.states.PlayState;
import funkin.scripts.Globals;
import flixel.FlxG;
import funkin.objects.shaders.NoteColorSwap;

class NoteSplash extends NoteObject
{
	private var textureLoaded:String = null;

	public var animationAmount:Int = 2;

	public function new(x:Float = 0, y:Float = 0, ?note:Int = 0) {
		super(SPLASH);
		
		colorSwap = new NoteColorSwap();
		shader = NoteColorSwap.shader;

		loadAnims(PlayState.splashSkin);
		setupNoteSplash(x, y, note);
		visible = false;
	}
	
	public function setupNoteSplash(x:Float, y:Float, column:Int = 0, texture:String = null, hueColor:Float = 0, satColor:Float = 0, brtColor:Float = 0, ?note:Note) 
	{
		visible = true;

		if (scriptCall(note, "preSetupNoteSplash", [x, y, column, texture, hueColor, satColor, brtColor, note]) == STOP)
			return;

		setPosition(x, y);
		animationAmount = 2;
		alpha = 0.6;
		var realScale:Float = 0.8 * (Note.spriteScales[PlayState.keyCount - 1] / 0.7);
		scale.set(realScale, realScale);
		updateHitbox();

		this.column = column;
		if (texture == null) texture = PlayState.splashSkin;

		if (note?.genScript != null) {
			if (note.genScript.exists("textureSuffix")) 
				texture += note.genScript.get("textureSuffix");
		}

		if (textureLoaded != texture) {
			if (scriptCall(note, "loadSplashAnims", [texture]) != STOP)
				loadAnims(texture);
		}

		colorSwap.hue = hueColor;
		colorSwap.saturation = satColor;
		colorSwap.brightness = brtColor;

		if (scriptCall(note, "postSetupNoteSplash", [x, y, column, texture, hueColor, satColor, brtColor, note]) != STOP){
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
			for(j in 0...PlayState.keyCount){
				animation.addByPrefix('note$j-$i', 'note splash ${Note.currentNoteAnimNames[j]} $i', 24, false);
			}
		}
	}

	override function update(elapsed:Float) 
	{
		if (animation.curAnim == null || animation.curAnim.finished)  kill();

		super.update(elapsed);
	}

	private function scriptCall(note:Note, funcName:String, args:Array<Dynamic>):FunctionReturn {
		var vars:Map<String, Dynamic> = [
			"this" => this, 
			#if ALLOW_DEPRECATION
			"noteData" => this.column,
			#end
			"column" => this.column,
		];

		var ret:FunctionReturn = CONTINUE;
		if (note?.genScript != null)
			ret = note.genScript.call(funcName, args, vars);
		
		var ret2:FunctionReturn = CONTINUE;
		if (FlxG.state == PlayState.instance)
			ret2 = PlayState.instance.callOnScripts(funcName, args, false, null, null, vars);

		return (ret == STOP || ret2 == STOP) ? STOP : CONTINUE;
	}
}