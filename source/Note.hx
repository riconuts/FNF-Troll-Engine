package;

import sys.FileSystem;
import JudgmentManager.Judgment;
import editors.ChartingState;
import math.Vector3;
import scripts.*;
import playfields.*;

using StringTools;

typedef EventNote = {
	strumTime:Float,
	event:String,
	value1:String,
	value2:String
}

typedef HitResult = {
	judgment: Judgment,
	hitDiff: Float
}

@:enum abstract SplashBehaviour(Int) from Int to Int
{
	var DEFAULT = 0; // only splashes on judgements that have splashes
	var DISABLED = -1; // never splashes
	var FORCED = 1; // always splashes
}
class Note extends NoteObject
{
	public var vec3Cache:Vector3 = new Vector3(); // for vector3 operations in modchart code
	public var hitResult:HitResult = {
		judgment: UNJUDGED,
		hitDiff: 0
	}

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

	// quant shit
	public var quant:Int = 4;
	public var extraData:Map<String, Dynamic> = [];
	public var isQuant:Bool = false; // mainly for color swapping, so it changes color depending on which set (quants or regular notes)
	public var canQuant:Bool = true;
	
	// basic stuff
	public var beat:Float = 0;
	public var strumTime:Float = 0;
	public var visualTime:Float = 0;
	public var mustPress:Bool = false;
	@:isVar
	public var canBeHit(get, null):Bool = false;
	public var tooLate:Bool = false;
	public var wasGoodHit:Bool = false;
	public var ignoreNote:Bool = false;
	public var hitByOpponent:Bool = false;
	public var noteWasHit:Bool = false;
	public var prevNote:Note;
	public var nextNote:Note;
	public var spawned:Bool = false;
	function get_canBeHit()return PlayState.instance.judgeManager.judgeNote(this)!=UNJUDGED;
	
	
	// note type/customizable shit
	
	public var noteType(default, set):String = null;  // the note type
	public var causedMiss:Bool = false;
	public var usesDefaultColours:Bool = true; // whether this note uses the default note colours (lets you change colours in options menu)

	public var blockHit:Bool = false; // whether you can hit this note or not
	#if PE_MOD_COMPATIBILITY
	public var lowPriority:Bool = false; // Unused. shadowmario's shitty workaround for really bad mine placement, yet still no *real* hitbox customization lol!
	#end
	@:isVar
	public var noteSplashDisabled(get, set):Bool = false; // disables the notesplash when you hit this note
	function get_noteSplashDisabled()
		return noteSplashBehaviour==DISABLED;
	function set_noteSplashDisabled(val:Bool){
		noteSplashBehaviour = val?DISABLED:DEFAULT;
		return val;
	}

	public var noteSplashBehaviour:SplashBehaviour = DEFAULT;
	public var noteSplashTexture:String = null; // spritesheet for the notesplash
	public var noteSplashHue:Float = 0; // hueshift for the notesplash, can be changed in note-type but otherwise its whatever the user sets in options
	public var noteSplashSat:Float = 0; // ditto, but for saturation
	public var noteSplashBrt:Float = 0; // ditto, but for brightness
	//public var ratingDisabled:Bool = false; // disables judging this note
	public var missHealth:Float = 0; // damage when hitCausesMiss = true and you hit this note	
	public var texture(default, set):String = null; // texture for the note
	public var noAnimation:Bool = false; // disables the animation for hitting this note
	public var noMissAnimation:Bool = false; // disables the animation for missing this note
	public var hitCausesMiss:Bool = false; // hitting this causes a miss
	public var breaksCombo:Bool = false; // hitting this will cause a combo break
	public var hitsoundDisabled:Bool = false; // hitting this does not cause a hitsound when user turns on hitsounds
	public var gfNote:Bool = false; // gf sings this note (pushes gf into characters array when the note is hit)
	public var characters:Array<Character> = []; // which characters sing this note, leave blank for the playfield's characters
	public var fieldIndex:Int = -1; // Used to denote which PlayField to be placed into
	// Leave -1 if it should be automatically determined based on mustPress and placed into either bf or dad's based on that.
	// Note that holds automatically have this set to their parent's fieldIndex
	public var field:PlayField; // same as fieldIndex but lets you set the field directly incase you wanna do that i  guess

	// custom health values
	public var ratingHealth:Map<String, Float> = [];

	// hold/roll shit
	public var sustainMult:Float = 1;
	public var tail:Array<Note> = []; 
	public var unhitTail:Array<Note> = [];
	public var parent:Note;
	public var sustainLength:Float = 0;
	public var isSustainNote:Bool = false;
	public var holdingTime:Float = 0;
	public var tripTimer:Float = 0;
	public var isRoll:Bool = false;

	// event shit (prob can be removed??????)
	public var eventName:String = '';
	public var eventLength:Int = 0;
	public var eventVal1:String = '';
	public var eventVal2:String = '';

	// etc

	public var colorSwap:ColorSwap;
	public var inEditor:Bool = false;
	public var desiredZIndex:Float = 0;
	
	// do not tuch
	public var baseScaleX:Float = 1;
	public var baseScaleY:Float = 1;
	public var zIndex:Float = 0;
	public var z:Float = 0;
	public var realNoteData:Int;
	public static var swagWidth:Float = 160 * 0.7;
	
	
	private var colArray:Array<String> = ['purple', 'blue', 'green', 'red'];


	// mod manager
	public var garbage:Bool = false; // if this is true, the note will be removed in the next update cycle
	public var alphaMod:Float = 1;
	public var alphaMod2:Float = 1; // TODO: unhardcode this shit lmao
	public var typeOffsetX:Float = 0; // used to offset notes, mainly for note types. use in place of offset.x and offset.y when offsetting notetypes
	public var typeOffsetY:Float = 0;
	public var typeOffsetAngle:Float = 0;
	public var multSpeed(default, set):Float = 1;
	// useless shit mostly
	public var offsetAngle:Float = 0;
	public var multAlpha:Float = 1;

	public var copyX:Bool = true;
	public var copyY:Bool = true;
	public var copyAngle:Bool = true;
	public var copyAlpha:Bool = true;

	public var rating:String = 'unknown';
	public var ratingMod:Float = 0; //9 = unknown, 0.25 = shit, 0.5 = bad, 0.75 = good, 1 = sick

	public var distance:Float = 2000; //plan on doing scroll directions soon -bb


	public static var defaultNotes = [
		'No Animation',
		'GF Sing',
		''
	];

	@:isVar
	public var isSustainEnd(get, null):Bool = false;

	public function get_isSustainEnd():Bool
	{
		if (isSustainNote && animation != null && animation.curAnim != null && animation.curAnim.name != null && animation.curAnim.name.endsWith("end"))
			return true;

		return false;
	}

	private function set_multSpeed(value:Float):Float {
		return multSpeed = value;
	}

	public function resizeByRatio(ratio:Float) //haha funny twitter shit
	{
		
	}

	private function set_texture(value:String):String {
		if(texture != value) {
			reloadNote('', value);
		}
		texture = value;
		return value;
	}

	public function updateColours(ignore:Bool=false){		
		if(!ignore && !usesDefaultColours)return;
		if (colorSwap==null)return;
		if(isQuant){
			var idx = quants.indexOf(quant);
			colorSwap.hue = ClientPrefs.quantHSV[idx][0] / 360;
			colorSwap.saturation = ClientPrefs.quantHSV[idx][1] / 100;
			colorSwap.brightness = ClientPrefs.quantHSV[idx][2] / 100;
		}else{
			colorSwap.hue = ClientPrefs.arrowHSV[noteData % 4][0] / 360;
			colorSwap.saturation = ClientPrefs.arrowHSV[noteData % 4][1] / 100;
			colorSwap.brightness = ClientPrefs.arrowHSV[noteData % 4][2] / 100;
		}

		if (noteScript != null && noteScript.scriptType == 'hscript')
		{
			var noteScript:FunkinHScript = cast noteScript;
			noteScript.executeFunc("onUpdateColours", [this], this);
		}
	}

	private function set_noteType(value:String):String {
		noteSplashTexture = PlayState.SONG.splashSkin;

		updateColours();

		// just to make sure they arent 0, 0, 0
		colorSwap.hue += 0.0127;
		colorSwap.saturation += 0.0127;
		colorSwap.brightness += 0.0127;
		var hue = colorSwap.hue;
		var sat = colorSwap.saturation;
		var brt = colorSwap.brightness;

		if(noteData > -1 && noteType != value) {
			noteScript = null;
			switch(value) {
				case 'Hurt Note':
					ignoreNote = mustPress;
					reloadNote('HURT');
					noteSplashTexture = 'HURTnoteSplashes';
					usesDefaultColours = false;
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
					else if(inEditor && ChartingState.instance!=null)
						noteScript = ChartingState.instance.notetypeScripts.get(value);
					
					if (noteScript != null && noteScript is FunkinHScript)
					{
						var noteScript:FunkinHScript = cast noteScript;
						noteScript.executeFunc("setupNote", [this], this, ["this" => this]);
					}
			}

			noteType = value;
		}
		if(usesDefaultColours){
			if(colorSwap.hue != hue || colorSwap.saturation != sat || colorSwap.brightness != brt){
				usesDefaultColours = false;// just incase
			}
		}

		if(colorSwap.hue==hue)
			colorSwap.hue -= 0.0127;

		if(colorSwap.saturation==sat)
			colorSwap.saturation -= 0.0127;

		if(colorSwap.brightness==brt)
			colorSwap.brightness -= 0.0127;

		if (noteScript != null && noteScript is FunkinHScript)
		{
			var noteScript:FunkinHScript = cast noteScript;
			noteScript.executeFunc("postSetupNote", [this], this, ["this" => this]);
		}

		if(isQuant){
			if (noteSplashTexture == 'noteSplashes' || noteSplashTexture == null || noteSplashTexture.length <= 0)
				noteSplashTexture = 'QUANTnoteSplashes'; // give it da quant notesplashes!!
			else if (Paths.exists(Paths.getPath("images/QUANT" + noteSplashTexture + ".png",
				IMAGE)) #if MODS_ALLOWED || Paths.exists(Paths.modsImages("QUANT" + noteSplashTexture)) #end)
				noteSplashTexture = 'QUANT${noteSplashTexture}';
		}

		if (isQuant && noteSplashTexture.startsWith("QUANT") || !isQuant){
			noteSplashHue = colorSwap.hue;
			noteSplashSat = colorSwap.saturation;
			noteSplashBrt = colorSwap.brightness;
		}
		return value;
	}

	public function new(strumTime:Float, noteData:Int, ?prevNote:Note, ?sustainNote:Bool = false, ?inEditor:Bool = false)
	{
		super();
		
		this.strumTime = strumTime;
		this.noteData = noteData;
		this.prevNote = (prevNote==null) ? this : prevNote;
		this.isSustainNote = sustainNote;
		this.inEditor = inEditor;

		if (canQuant && ClientPrefs.noteSkin == 'Quants'){
			if(prevNote != null && isSustainNote)
				quant = prevNote.quant;
			else
				quant = getQuant(Conductor.getBeatSinceChange(strumTime));
		}
		beat = Conductor.getBeat(strumTime);

		//x += PlayState.STRUM_X + 50;
		y -= 2000; // MAKE SURE ITS DEFINITELY OFF SCREEN?
		
		if(!inEditor){ 
			this.strumTime += ClientPrefs.noteOffset;
			visualTime = PlayState.instance.getNoteInitialTime(this.strumTime);
		}

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

		if(prevNote != null)
			prevNote.nextNote = this;

		if (isSustainNote && prevNote != null)
		{
			sustainMult = 0.5; // early hit mult but just so note-types can set their own and not have sustains fuck them
			alpha = 0.6;
			multAlpha = 0.6;
			hitsoundDisabled = true;
			copyAngle = false;
			//if(ClientPrefs.downScroll) flipY = true;

			//offsetX += width* 0.5;

			animation.play(colArray[noteData % 4] + 'holdend');

			updateHitbox();

			//offsetX -= width* 0.5;

			if (prevNote.isSustainNote)
			{
				prevNote.animation.play(colArray[prevNote.noteData % 4] + 'hold');

				prevNote.scale.y *= Conductor.stepCrochet / 100 * 1.5 * PlayState.instance.songSpeed * 100;
				prevNote.updateHitbox();
				prevNote.defScale.copyFrom(prevNote.scale);
				// prevNote.setGraphicSize();
			}
		}

		defScale.copyFrom(scale);
		//x += offsetX;
	}

	public static var quantShitCache = new Map<String, String>();
	var lastNoteScaleToo:Float = 1;
	public var originalHeightForCalcs:Float = 6;

	public var texPrefix:String = '';
	public var tex:String = '';
	public var texSuffix:String = '';
	public function reloadNote(?prefix:String = '', ?texture:String = '', ?suffix:String = '', ?dir:String = '', hInd:Int = 0, vInd:Int = 0) {
		if(prefix == null) prefix = '';
		if(texture == null) texture = '';
		if(suffix == null) suffix = '';

		texPrefix = prefix;
		tex = texture;
		texSuffix = suffix;
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
		arraySkin[arraySkin.length - 1] = prefix + arraySkin[arraySkin.length-1] + suffix; // add prefix and suffix to the texture file
		var blahblah:String = arraySkin.join('/');
		var wasQuant = isQuant;
		isQuant = false;
		

		var daDirs = [
			''
		];
		if(dir.trim() != '')
			daDirs.unshift(dir + '/');	
		

		for (dir in daDirs)
		{
			if (canQuant && ClientPrefs.noteSkin == 'Quants')
			{
				var texture = quantShitCache.get(dir + blahblah); // did i do this right, is this the right thing to do

				if (texture != null){
					blahblah = texture;
					isQuant = true;

				}else if (Paths.exists(Paths.getPath("images/" + dir + "QUANT" + blahblah + ".png", IMAGE))
					#if MODS_ALLOWED
					|| Paths.exists(Paths.modsImages(dir + "QUANT" + blahblah))
					#end) {

					var texture = "QUANT" + blahblah;
					quantShitCache.set(dir + blahblah, texture);

					blahblah = texture;
					isQuant = true;
				}
			}

			if (wasQuant != isQuant)
				updateColours();

			if (Paths.exists(Paths.getPath("images/" + dir + blahblah + ".png",
				IMAGE)) #if MODS_ALLOWED || Paths.exists(Paths.modsImages(dir + blahblah)) #end)
			{
				if (vInd > 0 && hInd > 0){
					loadGraphic(Paths.image(dir + blahblah));
					width = width / hInd;
					height = height / vInd;
					loadGraphic(Paths.image(dir + blahblah), true, Math.floor(width), Math.floor(height));
					loadIndNoteAnims();
					break;
				}else{	
					frames = Paths.getSparrowAtlas(dir + blahblah);
					loadNoteAnims();
					antialiasing = ClientPrefs.globalAntialiasing;
					break;
				}
			}
		}
		
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

	public function loadIndNoteAnims()
	{
		if (noteScript != null && noteScript.scriptType == 'hscript')
		{
			var noteScript:FunkinHScript = cast noteScript;
			if (noteScript.exists("loadIndNoteAnims") && Reflect.isFunction(noteScript.get("loadIndNoteAnims")))
			{
				noteScript.executeFunc("loadIndNoteAnims", [this], this, ["super" => _loadIndNoteAnims]);
				return;
			}
		}
		_loadIndNoteAnims();
	}

	function _loadIndNoteAnims()
	{
		if (isSustainNote)
		{
			animation.add(colArray[noteData] + 'holdend', [noteData + 4]);
			animation.add(colArray[noteData] + 'hold', [noteData]);
		}
		else
			animation.add(colArray[noteData] + 'Scroll', [noteData + 4]);
		
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

		if(!inEditor){
			if (noteScript != null && noteScript is FunkinHScript){
				var noteScript:FunkinHScript = cast noteScript;
				noteScript.executeFunc("noteUpdate", [elapsed], this);
			}
		}
		
		colorSwap.daAlpha = alphaMod * alphaMod2;
		
		if (hitByOpponent)
			wasGoodHit = true;

		var diff = (strumTime - Conductor.songPosition);
		if (diff < -Conductor.safeZoneOffset && !wasGoodHit)
			tooLate = true;

		if (tooLate && !inEditor)
		{
			if (alpha > 0.3)
				alpha = 0.3;
		}
	}
}
