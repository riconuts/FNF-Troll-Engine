package;

import haxe.io.Path;
import editors.ChartingState;
import flixel.math.FlxPoint;
import math.Vector3;
import openfl.utils.Assets;
import scripts.*;

using StringTools;

typedef EventNote = {
	strumTime:Float,
	event:String,
	value1:String,
	value2:String
}

class Note extends FlxSprite
{
	public var vec3Cache:Vector3 = new Vector3(); // for vector3 operations in modchart code
	public var defScale:FlxPoint = FlxPoint.get(); // for modcharts to keep the scaling

	override function destroy()
	{
		defScale.put();
		super.destroy();
	}
	public var mAngle:Float = 0;
	public var bAngle:Float = 0;
	
	public var noteScript:FunkinScript;

	public static var quants:Array<Int> = [
		4, // quarter note
		8, // eight
		12, // etc
		16,
		20,
		24,
		32,
		48,
		64,
		96,
		192
	];

	public static function getQuant(beat:Float){
		var row = Conductor.beatToNoteRow(beat);
		for(data in quants){
			if(row%(Conductor.ROWS_PER_MEASURE/data) == 0){
				return data;
			}
		}
		return quants[quants.length-1]; // invalid
	}
	public var noteDiff:Float = 1000;
	public var quant:Int = 4;
	public var zIndex:Float = 0;
	public var desiredZIndex:Float = 0;
	public var z:Float = 0;
	public var garbage:Bool = false; // if this is true, the note will be removed in the next update cycle
	public var alphaMod:Float = 1;
	public var alphaMod2:Float = 1; // TODO: unhardcode this shit lmao

	public var extraData:Map<String, Dynamic> = [];
	public var hitbox:Float = Conductor.safeZoneOffset;
	public var isQuant:Bool = false; // mainly for color swapping, so it changes color depending on which set (quants or regular notes)
	public var canQuant:Bool = true;
	public var strumTime:Float = 0;

	public var mustPress:Bool = false;
	public var noteData:Int = 0;
	public var canBeHit:Bool = false;
	public var tooLate:Bool = false;
	public var wasGoodHit:Bool = false;
	public var ignoreNote:Bool = false;
	public var hitByOpponent:Bool = false;
	public var noteWasHit:Bool = false;
	public var prevNote:Note;
	public var nextNote:Note;

	public var spawned:Bool = false;

	public var tail:Array<Note> = []; // for sustains
	public var parent:Note;
	public var blockHit:Bool = false; // only works for player

	public var sustainLength:Float = 0;
	public var isSustainNote:Bool = false;
	public var noteType(default, set):String = null;

	public var eventName:String = '';
	public var eventLength:Int = 0;
	public var eventVal1:String = '';
	public var eventVal2:String = '';

	public var colorSwap:ColorSwap;
	public var inEditor:Bool = false;
	public var gfNote:Bool = false;
	public var baseScaleX:Float = 1;
	public var baseScaleY:Float = 1;

	public var animSuffix:String = '';
	public var earlyHitMult:Float = 0.5;
	public var lateHitMult:Float = 1;
	public var lowPriority:Bool = false;
	
	public static var swagWidth:Float = 160 * 0.7;
	
	private var colArray:Array<String> = ['purple', 'blue', 'green', 'red'];

	// Lua shit
	public var noteSplashDisabled:Bool = false;
	public var noteSplashTexture:String = null;
	public var noteSplashHue:Float = 0;
	public var noteSplashSat:Float = 0;
	public var noteSplashBrt:Float = 0;

	// mod manager
	public var typeOffsetX:Float = 0; // used to offset notes, mainly for note types. use in place of offset.x and offset.y when offsetting notetypes
	public var typeOffsetY:Float = 0;

	public var offsetX:Float = 0;
	public var offsetY:Float = 0;
	public var offsetAngle:Float = 0;
	public var multAlpha:Float = 1;
	public var multSpeed(default, set):Float = 1;

	public var copyX:Bool = true;
	public var copyY:Bool = true;
	public var copyAngle:Bool = true;
	public var copyAlpha:Bool = true;

	public var hitHealth:Float = 0.023;
	public var missHealth:Float = 0.0475;
	public var rating:String = 'unknown';
	public var ratingMod:Float = 0; //9 = unknown, 0.25 = shit, 0.5 = bad, 0.75 = good, 1 = sick
	public var ratingDisabled:Bool = false;

	public var texture(default, set):String = null;

	public var noAnimation:Bool = false;
	public var noMissAnimation:Bool = false;
	public var hitCausesMiss:Bool = false;
	public var distance:Float = 2000; //plan on doing scroll directions soon -bb

	public var hitsoundDisabled:Bool = false;

	public static var defaultNotes = [
		'No Animation',
		'GF Sing',
		''
	];

	private function set_multSpeed(value:Float):Float {
		resizeByRatio(value / multSpeed);
		multSpeed = value;
		trace('fuck cock');
		return value;
	}

	public function resizeByRatio(ratio:Float) //haha funny twitter shit
	{
		if(isSustainNote && !animation.curAnim.name.endsWith('end'))
		{
			scale.y *= ratio;
			baseScaleY = scale.y;
			updateHitbox();
		}
	}

	private function set_texture(value:String):String {
		if(texture != value) {
			reloadNote('', value);
		}
		texture = value;
		return value;
	}

	private function set_noteType(value:String):String {
		noteSplashTexture = PlayState.SONG.splashSkin;
		if(isQuant){
			var idx = quants.indexOf(quant);
			colorSwap.hue = ClientPrefs.quantHSV[idx][0] / 360;
			colorSwap.saturation = ClientPrefs.quantHSV[idx][1] / 100;
			colorSwap.brightness = ClientPrefs.quantHSV[idx][2] / 100;
			if (noteSplashTexture == 'noteSplashes' || noteSplashTexture == null || noteSplashTexture.length <= 0 )
				noteSplashTexture = 'QUANTnoteSplashes'; // give it da quant notesplashes!!
		}else{
			colorSwap.hue = ClientPrefs.arrowHSV[noteData % 4][0] / 360;
			colorSwap.saturation = ClientPrefs.arrowHSV[noteData % 4][1] / 100;
			colorSwap.brightness = ClientPrefs.arrowHSV[noteData % 4][2] / 100;
		}

		noteScript = null;

		if(noteData > -1 && noteType != value) {
			switch(value) {
				case 'Hurt Note':
					ignoreNote = mustPress;
					reloadNote('HURT');
					noteSplashTexture = 'HURTnoteSplashes';
					colorSwap.hue = 0;
					colorSwap.saturation = 0;
					colorSwap.brightness = 0;
					if(isSustainNote) {
						missHealth = 0.1;
					} else {
						missHealth = 0.3;
					}
					hitCausesMiss = true;

				case 'No Animation':
					noAnimation = true;
					noMissAnimation = true;
				case 'GF Sing':
					gfNote = true;
				default:
					if (!inEditor && PlayState.instance != null)
						noteScript = PlayState.instance.notetypeScripts.get(value);
					/*else
						noteScript = ChartingState.instance.notetypeScripts.get(value);*/
					
					if (noteScript != null && noteScript.scriptType == 'hscript')
					{
						var noteScript:FunkinHScript = cast noteScript;
						noteScript.executeFunc("setupNote", [this], this);
					}
						
			}
			noteType = value;
		}
		noteSplashHue = colorSwap.hue;
		noteSplashSat = colorSwap.saturation;
		noteSplashBrt = colorSwap.brightness;
		return value;
	}

	public function new(strumTime:Float, noteData:Int, ?prevNote:Note, ?sustainNote:Bool = false, ?inEditor:Bool = false)
	{
		super();

		if (prevNote == null)
			prevNote = this;
		
		this.prevNote = prevNote;
		isSustainNote = sustainNote;

		if (ClientPrefs.noteSkin == 'Quants' && canQuant){
			var beat = Conductor.getBeatInMeasure(strumTime);
			if(prevNote!=null && isSustainNote)
				quant = prevNote.quant;
			else
				quant = getQuant(beat);
		}
		this.inEditor = inEditor;

		x += (ClientPrefs.middleScroll ? PlayState.STRUM_X_MIDDLESCROLL : PlayState.STRUM_X) + 50;
		// MAKE SURE ITS DEFINITELY OFF SCREEN?
		y -= 2000;
		this.strumTime = strumTime;
		if(!inEditor) this.strumTime += ClientPrefs.noteOffset;

		this.noteData = noteData;

		if(noteData > -1) {
			texture = '';
			colorSwap = new ColorSwap();
			shader = colorSwap.shader;

			x += swagWidth * (noteData);
			if(!isSustainNote && noteData > -1 && noteData < 4) { //Doing this 'if' check to fix the warnings on Senpai songs
				var animToPlay:String = '';
				animToPlay = colArray[noteData % 4];
				animation.play(animToPlay + 'Scroll');
			}
		}

		// trace(prevNote);

		if(prevNote!=null)
			prevNote.nextNote = this;

		if (isSustainNote && prevNote != null)
		{
			alpha = 0.6;
			multAlpha = 0.6;
			hitsoundDisabled = true;
			//if(ClientPrefs.downScroll) flipY = true;

			offsetX += width* 0.5;
			copyAngle = false;

			animation.play(colArray[noteData % 4] + 'holdend');

			updateHitbox();

			offsetX -= width* 0.5;

			if (prevNote.isSustainNote)
			{
				prevNote.animation.play(colArray[prevNote.noteData % 4] + 'hold');

				prevNote.scale.y *= Conductor.stepCrochet / 100 * 1.05;
				if(PlayState.instance != null)
				{
					prevNote.scale.y *= PlayState.instance.songSpeed;
				}
				
				prevNote.updateHitbox();
				prevNote.defScale.copyFrom(prevNote.scale);
				// prevNote.setGraphicSize();
			}
		} else if(!isSustainNote) {
			earlyHitMult = 1;
		}
		defScale.copyFrom(scale);
		x += offsetX;
	}

	var lastNoteScaleToo:Float = 1;
	public var originalHeightForCalcs:Float = 6;
	public function reloadNote(?prefix:String = '', ?texture:String = '', ?suffix:String = '') {
		if(prefix == null) prefix = '';
		if(texture == null) texture = '';
		if(suffix == null) suffix = '';

		if (noteScript != null && noteScript.scriptType == 'hscript')
		{
			var noteScript:FunkinHScript = cast noteScript;
			if (noteScript.executeFunc("onReloadNote", [this, prefix, texture, suffix], this) == Globals.Function_Stop)
				return;
		}

		var animName:String = animation.curAnim != null ? animation.curAnim.name : null;
		var lastScaleY:Float = scale.y;

		var skin:String = texture;
		if(texture.length < 1){
			skin = PlayState.arrowSkin;
			if(skin == null || skin.length < 1)
				skin = 'NOTE_assets';
		}

		var arraySkin:Array<String> = skin.split('/');
		arraySkin[arraySkin.length-1] = prefix + arraySkin[arraySkin.length-1] + suffix; // add prefix and suffix to the texture file
		var blahblah:String = arraySkin.join('/');

		isQuant = false;
		
		if (ClientPrefs.noteSkin == 'Quants' && canQuant)
		{
			if (Paths.exists(Paths.getPath("images/QUANT" + blahblah + ".png", IMAGE))
				#if MODS_ALLOWED
				|| Paths.exists(Paths.modsImages("QUANT" + blahblah + ".png"))
				#end) { // this can probably only be done once and then added to some sort of cache
				// soon:tm:
				blahblah = "QUANT" + blahblah;
				isQuant = true;
			}
		}
		
		frames = Paths.getSparrowAtlas(blahblah);
		loadNoteAnims();
		antialiasing = ClientPrefs.globalAntialiasing;
		
		if(isSustainNote) {
			scale.y = lastScaleY;
		}
		defScale.copyFrom(scale);
		updateHitbox();

		if(animName != null)
			animation.play(animName, true);

		if(inEditor){
			setGraphicSize(ChartingState.GRID_SIZE, ChartingState.GRID_SIZE);
			updateHitbox();
		}

		if (noteScript != null && noteScript.scriptType == 'hscript')
		{
			var noteScript:FunkinHScript = cast noteScript;
			noteScript.executeFunc("postReloadNote", [this, prefix, texture, suffix], this);
		}
	}

	public function loadNoteAnims() {
		if (noteScript != null && noteScript.scriptType == 'hscript'){
			var noteScript:FunkinHScript = cast noteScript;
			if (noteScript.exists("loadNoteAnims") && Reflect.isFunction(noteScript.get("loadNoteAnims"))){
				noteScript.executeFunc("loadNoteAnims", [this], this, ["super" => _loadNoteAnims]);
				return;
			}
		}
		_loadNoteAnims();
	}

	function _loadNoteAnims() {
		animation.addByPrefix(colArray[noteData] + 'Scroll', colArray[noteData] + '0');

		if (isSustainNote)
		{
			animation.addByPrefix('purpleholdend', 'pruple end hold'); // ?????
			animation.addByPrefix(colArray[noteData] + 'holdend', colArray[noteData] + ' hold end');
			animation.addByPrefix(colArray[noteData] + 'hold', colArray[noteData] + ' hold piece');
		}

		setGraphicSize(Std.int(width * 0.7));
		updateHitbox();
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (isSustainNote)
		{
			if (prevNote != null && prevNote.isSustainNote)
				zIndex = z + prevNote.zIndex;
			
			else if (prevNote != null && !prevNote.isSustainNote)
				zIndex = z + prevNote.zIndex - 1;
			
		}
		else
			zIndex = z;
		

		zIndex += desiredZIndex;
		zIndex -= (mustPress == true ? 0 : 1);

		if(!inEditor){
			if (noteScript != null && noteScript.scriptType == 'hscript'){
				var noteScript:FunkinHScript = cast noteScript;
				noteScript.executeFunc("noteUpdate", [elapsed], this);
			}
		}
		
		colorSwap.daAlpha = alphaMod * alphaMod2;
		
		if (mustPress)
		{
			// ok river
			if (strumTime > Conductor.songPosition - (Conductor.safeZoneOffset * lateHitMult)
				&& strumTime < Conductor.songPosition + (Conductor.safeZoneOffset * earlyHitMult))
				canBeHit = true;
			else
				canBeHit = false;

			if (strumTime < Conductor.songPosition - Conductor.safeZoneOffset && !wasGoodHit)
				tooLate = true;
		}
		else
		{
			canBeHit = false;

			if (strumTime < Conductor.songPosition + (Conductor.safeZoneOffset * earlyHitMult))
			{
				if ((isSustainNote && prevNote.wasGoodHit) || strumTime <= Conductor.songPosition)
					wasGoodHit = true;
			}
		}

		if (tooLate && !inEditor)
		{
			if (alpha > 0.3)
				alpha = 0.3;
		}
	}
}
