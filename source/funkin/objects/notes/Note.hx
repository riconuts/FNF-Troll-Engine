package funkin.objects.notes;

import math.Vector3;
import flixel.math.FlxMath;
import funkin.scripts.*;
import funkin.states.PlayState;
import funkin.states.editors.ChartingState;
import funkin.objects.shaders.NoteColorSwap;
import funkin.objects.playfields.*;
import funkin.data.JudgmentManager.Judgment;

using StringTools;

typedef HitResult = {
	judgment: Judgment,
	hitDiff: Float
}

enum abstract SplashBehaviour(Int) from Int to Int
{
	/**Only splashes on judgements that have splashes**/
	var DEFAULT = 0;
	/**Never splashes**/
	var DISABLED = -1;
	/**Always splashes**/
	var FORCED = 1;
}

enum abstract SustainPart(Int) from Int to Int
{
	var TAP = -1; // Not a sustain
	var HEAD = 0; // TapNote at the start of a sustain
	var PART = 1;
	var END = 2;
}

private typedef NoteScriptState = {
	var notetypeScripts:Map<String, FunkinHScript>;
}

class Note extends NoteObject
{
	public var holdGlow:Bool = true; // Whether holds should "glow" / increase in alpha when held
	public var baseAlpha:Float = 1;

	public static var spriteScale:Float = 0.7;
	public static var swagWidth(default, set):Float = 160 * spriteScale;
	public static var halfWidth(default, null):Float = swagWidth * 0.5;

	private static var colArray:Array<String> = ['purple', 'blue', 'green', 'red'];

	public static var defaultNoteAnimNames:Array<String> = ['purple0', 'blue0', 'green0', 'red0'];
	public static var defaultHoldAnimNames:Array<String> = ['purple hold piece', 'blue hold piece', 'green hold piece', 'red hold piece'];
	public static var defaultTailAnimNames:Array<String> = ['purple hold end', 'blue hold end', 'green hold end', 'red hold end'];

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

	public static var defaultNotes = [
		'No Animation',
		'GF Sing',
		''
	];

	public static final quantShitCache = new Map<String, Null<String>>();

	// should move this to Paths maybe
	public static function getQuantTexture(dir:String, fileName:String, textureKey:String) {
		
		if (quantShitCache.exists(textureKey))
			return quantShitCache.get(textureKey);
		
		var quantKey:Null<String> = dir + "QUANT" + fileName;
		// trace('$textureKey = "$dir", "$fileName", "$quantKey"');
		if (!Paths.imageExists(quantKey)) quantKey = null;
		
		quantShitCache.set(textureKey, quantKey);
		return quantKey;
	}

	inline public static function beatToNoteRow(beat:Float):Int
		return Math.round(beat * Conductor.ROWS_PER_BEAT);

	public static function getQuant(beat:Float){
		var row:Int = beatToNoteRow(beat);
		for (data in quants) {
			if (row % (Conductor.ROWS_PER_MEASURE/data) == 0)
				return data;
		}
		return quants[quants.length-1]; // invalid
	}

	@:noCompletion private static function set_swagWidth(val:Float) {
		halfWidth = val * 0.5;
		return swagWidth = val;
	}

	////

	/**note generator script (used for shit like pixel notes or skin mods) ((script provided by the HUD skin))*/
	public var genScript:FunkinHScript;
	/**note type script*/
	public var noteScript:FunkinHScript;
	
	// editor stuff for hit sounds
	public var editorHitBeat:Float = 0;

	// basic stuff
	public var beat:Float = 0;
	public var strumTime:Float = 0;

	public var visualTime:Float = 0;
	public var mustPress:Bool = false;
	public var ignoreNote:Bool = false;
	public var prevNote:Note;
	public var nextNote:Note;

	// hold shit
	public var holdType:SustainPart = TAP;
	public var isSustainNote:Bool = false;
	public var isSustainEnd:Bool = false;
	public var isRoll:Bool = false;
	public var isHeld:Bool = false;
	public var parent:Note;
	public var sustainLength:Float = 0;
	public var holdingTime:Float = 0;
	public var tripProgress:Float = 1;
	public var tail:Array<Note> = []; 
	public var unhitTail:Array<Note> = [];

	// quant shit
	public var row:Int = 0;
	public var quant:Int = 4;
	public var isQuant:Bool = false; // Whether the loaded texture is a quant texture.

	// note status
	public var spawned:Bool = false;
	public var tooLate:Bool = false;
	public var wasGoodHit:Bool = false;
	public var hitByOpponent:Bool = false;
	public var noteWasHit:Bool = false;
	public var causedMiss:Bool = false;
	public var canBeHit(get, never):Bool;

	public var hitResult:HitResult = {judgment: UNJUDGED, hitDiff: 0}
	public var rating:String = 'unknown';
	public var ratingMod:Float = 0; // 0 = unknown, 0.25 = shit, 0.5 = bad, 0.75 = good, 1 = sick
	
	//// note type/customizable shit
	public var noteMod(default, set):String = null; 
	public var noteType(default, set):String = null;  // the note type
	public var texture(default, set):String; // texture for the note
	public var canQuant:Bool = true; // whether a quant texture should be searched for or not
	public var usesDefaultColours:Bool = true; // whether this note uses the default note colours (lets you change colours in options menu)
	// This automatically gets set if a notetype changes the ColorSwap values

	//// note 
	public var defaultJudgement:Judgment;
	public var breaksCombo:Bool = false; // hitting this will cause a combo break
	public var blockHit:Bool = false; // whether you can hit this note or not
	public var hitCausesMiss:Bool = false; // hitting this causes a miss
	public var missHealth:Float = 0; // damage when hitCausesMiss = true and you hit this note
	public var ratingDisabled:Bool = false; // hitting or missing this note shouldn't affect stats, this doesn't prevent sing/miss animations and sounds from playing! 
	public var hitsoundDisabled:Bool = false; // hitting this does not cause a hitsound when user turns on hitsounds

	//// characters

	/** Which characters sing this note, if it's blank then the playfield's characters are used **/
	public var characters:Array<Character> = [];
	/** Whether if gf should also sing this note **/
	public var gfNote:Bool = false;
	
	/** If true, then characters won't play an animation upon hitting this note. **/
	public var noAnimation:Bool = false;
	/** If true, then characters won't play an animation upon missing this note. **/
	public var noMissAnimation:Bool = false;

	/** If not null, then characters will play this animation instead of the default ones upon hitting this note. **/
	public var characterHitAnimName:Null<String> = null;
	/** If not null, then characters will play this animation instead of the default ones upon missing this note. **/
	public var characterMissAnimName:Null<String> = null;
	
	/** Suffix to be added to the **default** sing animation names (resulting name would be 'singLEFT'+'suffix') **/
	public var characterHitAnimSuffix:String = "";
	/** Suffix to be added to the **default** sing animation names (resulting name would be 'singLEFT'+'suffix') **/
	public var characterMissAnimSuffix:String = "miss";

	////
	/** If you need to tap the note to hit it, or just have the direction be held when it can be judged to hit.
	 * An example is Stepmania mines **/
	public var requiresTap:Bool = true; 

	/** The maximum amount of time you can release a hold before it counts as a miss**/
	public var maxReleaseTime:Float = 0.25;
	
	/**Used to denote which PlayField to be placed into.
	 * 
	 * If it's -1 then it gets placed on bf's or dad's field depending on the mustPress value.
	 * 
	 * Note that holds automatically have this set to their parent's fieldIndex
	 */
	public var fieldIndex:Int = -1;
	public var field:PlayField; // same as fieldIndex but lets you set the field directly incase you wanna do that i  guess


	public var noteSplashBehaviour:SplashBehaviour = DEFAULT;
	public var noteSplashDisabled(get, set):Bool; // shortcut, disables the notesplash when you hit this note
	public var noteSplashTexture:String = null; // spritesheet for the notesplash
	public var noteSplashHue:Float = 0; // hueshift for the notesplash, can be changed in note-type but otherwise its whatever the user sets in options
	public var noteSplashSat:Float = 0; // ditto, but for saturation
	public var noteSplashBrt:Float = 0; // ditto, but for brightness

	// event shit (prob can be removed??????)
	public var eventName:String = '';
	public var eventVal1:String = '';
	public var eventVal2:String = '';
	public var eventLength:Int = 0;

	// etc
	public var inEditor:Bool = false;
	public var desiredZIndex:Float = 0;

	// mod manager
	public var garbage:Bool = false; // if this is true, the note will be removed in the next update cycle
	public var alphaMod:Float = 1;
	public var alphaMod2:Float = 1; // TODO: unhardcode this shit lmao
	// What is this even used for anymore??

	public var typeOffsetX:Float = 0; // used to offset notes, mainly for note types. use in place of offset.x and offset.y when offsetting notetypes
	public var typeOffsetY:Float = 0;
	public var typeOffsetAngle:Float = 0;
	public var multSpeed:Float = 1.0;

	// do not tuch
	public var baseScaleX:Float = 1;
	public var baseScaleY:Float = 1;
	public var z:Float = 0;

	// Determines how the note can be modified by the modchart system
	// Could be moved into NoteObject? idk lol
	public var copyX:Bool = true;
	public var copyY:Bool = true;
	public var copyAlpha:Bool = true;
	public var copyVerts:Bool = true;

	#if ALLOW_DEPRECATION
	// Angle is controlled by verts in the modchart system
	@:noCompletion public var copyAngle(get, set):Bool;
	@:noCompletion inline function get_copyAngle() return copyVerts;
	@:noCompletion inline function set_copyAngle(val:Bool) return copyVerts = val;
	
	@:noCompletion public var multAlpha(get, set):Float;
	@:noCompletion inline function get_multAlpha()return alphaMod;
	@:noCompletion inline function set_multAlpha(v:Float)return alphaMod = v;
	
	public var realColumn:Int; 
	//// backwards compat
	@:noCompletion public var realNoteData(get, set):Int; 
	@:noCompletion inline function get_realNoteData() return realColumn;
	@:noCompletion inline function set_realNoteData(v:Int) return realColumn = v;
	#end

	@:noCompletion function get_canBeHit() return UNJUDGED != PlayState.instance.judgeManager.judgeNote(this);

	@:noCompletion inline function get_noteSplashDisabled() return noteSplashBehaviour == DISABLED;
	@:noCompletion inline function set_noteSplashDisabled(val:Bool) {
		noteSplashBehaviour = val ? DISABLED : DEFAULT;
		return val;
	}

	////
	private function set_texture(value:String):String {
		if (tex != value) reloadNote(texPrefix, value, texSuffix);
		return tex;
	}

	public function updateColours(ignore:Bool=false){		
		if (!ignore && !usesDefaultColours) return;
		if (colorSwap==null) return;
		if (column == -1) return; // FUCKING PSYCH EVENT NOTES!!!
		
		var hsb = isQuant ? ClientPrefs.quantHSV[quants.indexOf(quant)] : ClientPrefs.arrowHSV[column % 4];
		(hsb == null) ? colorSwap.setHSB() : colorSwap.setHSB(
			hsb[0] / 360, 
			hsb[1] / 100, 
			hsb[2] / 100
		);

		if (noteScript != null)
			noteScript.executeFunc("onUpdateColours", [this], this);

		if (genScript != null)
			genScript.executeFunc("onUpdateColours", [this], this);
	}

	private function set_noteMod(value:String):String
	{
		if (value == null)
			value = 'default';

		updateColours();

		////
		if (!inEditor && PlayState.instance != null)
			genScript = PlayState.instance.getHudSkinScript(value);

		////
		if (genScript == null){
			texture = "";

		}else if (genScript.exists("setupNoteTexture")) {
			genScript.executeFunc("setupNoteTexture", [this]);

		}else {
			if (genScript.exists("texturePrefix"))
				texPrefix = genScript.get("texturePrefix");

			if (genScript.exists("textureSuffix"))
				texSuffix = genScript.get("textureSuffix");

			if (genScript.exists("noteTexture"))
				texture = genScript.get("noteTexture");
		}

		return noteMod = value;
	}

	private function set_noteType(value:String):String {
		noteSplashTexture = PlayState.splashSkin;

		updateColours();

		// just to make sure they arent 0, 0, 0
		colorSwap.hue += 0.0127;
		colorSwap.saturation += 0.0127;
		colorSwap.brightness += 0.0127;
		var hue = colorSwap.hue;
		var sat = colorSwap.saturation;
		var brt = colorSwap.brightness;

		if (value == 'Hurt Note')
			value = 'Mine';

		if (column > -1 && noteType != value) {
			var instance:NoteScriptState = inEditor ? ChartingState.instance : PlayState.instance;
			noteScript = (instance == null) ? null : instance.notetypeScripts.get(value);

			if (noteScript != null) {
				noteScript.executeFunc("setupNote", [this], this, ["this" => this]);
			
			}else { // default notes. these values won't get set if you make a script for them!
				switch (value) {
					case 'Alt Animation':
						characterHitAnimSuffix = "-alt";
						characterMissAnimSuffix = "-altmiss";

					case 'Hey!':
						characterHitAnimName = 'hey';
						// TODO

					//case 'Hurt Note':
							

					case 'GF Sing':
						gfNote = true;

					case 'No Animation':
						noAnimation = true;
						noMissAnimation = true;
				}
			}

			noteType = value;

			if (genScript != null)
				genScript.executeFunc("setupNoteType", [this], this, ["this" => this]);
		}

		if (usesDefaultColours) {
			if (colorSwap.hue != hue || colorSwap.saturation != sat || colorSwap.brightness != brt)
				usesDefaultColours = false;// just incase
		}

		if (colorSwap.hue==hue)
			colorSwap.hue -= 0.0127;
		if (colorSwap.saturation==sat)
			colorSwap.saturation -= 0.0127;
		if (colorSwap.brightness==brt)
			colorSwap.brightness -= 0.0127;

		////

		if (noteScript != null)
			noteScript.executeFunc("postSetupNote", [this], this, ["this" => this]);

		if (genScript != null)
			genScript.executeFunc("postSetupNoteType", [this], this, ["this" => this]);

		////
		if (isQuant && Paths.imageExists('QUANT' + noteSplashTexture))
			noteSplashTexture = 'QUANT' + noteSplashTexture;

		if (!isQuant || (isQuant && noteSplashTexture.startsWith("QUANT"))){
			noteSplashHue = colorSwap.hue;
			noteSplashSat = colorSwap.saturation;
			noteSplashBrt = colorSwap.brightness;
		}
		return value;
	}

	override function toString()
	{
		return '(column: $column | noteType: $noteType | strumTime: $strumTime | visible: $visible)';
	}

	public function new(strumTime:Float, column:Int, ?prevNote:Note, gottaHitNote:Bool = false, susPart:SustainPart = TAP, ?inEditor:Bool = false, ?noteMod:String = 'default')
	{
		super();
		this.objType = NOTE;

		this.strumTime = strumTime;
		this.column = column;
		this.prevNote = (prevNote==null) ? this : prevNote;
		this.mustPress = gottaHitNote;
		this.holdType = susPart;
		this.isSustainNote = susPart != HEAD && susPart != TAP; // susPart > HEAD
		this.isSustainEnd = susPart == END;
		this.inEditor = inEditor;

		this.beat = Conductor.getBeat(strumTime);
		this.hitsoundDisabled = isSustainNote;

		if (canQuant && ClientPrefs.noteSkin == 'Quants') {
			if (isSustainNote && prevNote != null)
				quant = prevNote.quant;
			else
				quant = getQuant(Conductor.getBeatSinceChange(strumTime));
		}

		baseAlpha = isSustainNote ? 0.6 : 1;
		

		if ((FlxG.state is PlayState))
			this.strumTime -= (cast FlxG.state).offset;

		if (!inEditor) {
			this.strumTime += ClientPrefs.noteOffset;			
			visualTime = PlayState.instance.getNoteInitialTime(this.strumTime);
		}

		if (prevNote != null) 
			prevNote.nextNote = this;

		colorSwap = new NoteColorSwap();
		shader = NoteColorSwap.shader;

		if (column >= 0) 
			this.noteMod = noteMod;
	}

	public var texPrefix:String = '';
	public var tex:String;
	public var texSuffix:String = '';
	public function reloadNote(?prefix:String, ?texture:String, ?suffix:String, ?folder:String, hInd:Int = 0, vInd:Int = 0) {
		if(prefix == null) prefix = '';
		if(texture == null) texture = '';
		if(suffix == null) suffix = '';
		if(folder == null) folder = '';

		texPrefix = prefix;
		tex = texture;
		texSuffix = suffix;

		if (genScript != null)
			genScript.executeFunc("onReloadNote", [this, prefix, texture, suffix], this);
		
		if (noteScript != null)
			noteScript.executeFunc("onReloadNote", [this, prefix, texture, suffix], this);

		if (genScript != null && genScript.executeFunc("preReloadNote", [this, prefix, texture, suffix], this) == Globals.Function_Stop)
			return;

		////

		/** Should join and check for shit in the following order:
		 * 
		 * folder + "/" + "QUANT" + prefix + name + suffix (if quants are enabled)
		 * folder + "/" + prefix + name + suffix
		 * "QUANT"+ prefix + name + suffix (if quants are enabled)
		 * prefix + name + suffix
		 *
		 * Sets isQuant to true if a quant texture is to be returned
		 */
		inline function getTextureKey() { // made it a function just cause i think it's easier to read it like this
			var loadQuants:Bool = this.canQuant && ClientPrefs.noteSkin=='Quants';

			var skin:String = (texture.length>0) ? texture : PlayState.arrowSkin;
			var split:Array<String> = skin.split('/');

			var fileName:String = prefix + split.pop() + suffix;
			var folderPath:String = folder + split.join('/') + "/";
			
			var foldersToCheck:Array<String> = [];
			if (folderPath != '')
				foldersToCheck.push(folderPath);
			foldersToCheck.push('');
			
			var key:String = null;
			for (dir in foldersToCheck) {
				key = dir + fileName;
	
				if (loadQuants) {
					var quantKey:Null<String> = getQuantTexture(dir, fileName, key);
					if (quantKey != null) {
						key = quantKey;
						isQuant = true;
						break;
					}
				}
				
				if (Paths.imageExists(key)) {
					isQuant = false;
					break;
				}
			}
			
			return key; 
		}

		////
		var wasQuant:Bool = isQuant;
		var textureKey:String = getTextureKey();
		if (wasQuant != isQuant) updateColours();
 		
		if (vInd > 0 && hInd > 0) {
			var graphic = Paths.image(textureKey);
			setSize(graphic.width / hInd, graphic.height / vInd);
			loadGraphic(graphic, true, Math.floor(width), Math.floor(height));
			loadIndNoteAnims();
		}else {	
			frames = Paths.getSparrowAtlas(textureKey);
			loadNoteAnims();
		} 
	
		if (inEditor)
			setGraphicSize(ChartingState.GRID_SIZE, ChartingState.GRID_SIZE);
		
		defScale.copyFrom(scale);
		updateHitbox();
		
		////	
		if (genScript != null)
			genScript.executeFunc("postReloadNote", [this, prefix, texture, suffix], this);

		if (noteScript != null)
			noteScript.executeFunc("postReloadNote", [this, prefix, texture, suffix], this);
	}

	public function loadIndNoteAnims()
	{
		var changed = false;

		if (noteScript != null) {
			if (noteScript.exists("loadIndNoteAnims") && Reflect.isFunction(noteScript.get("loadIndNoteAnims"))) {
				noteScript.executeFunc("loadIndNoteAnims", [this], this, ["super" => _loadIndNoteAnims]);
				changed = true;
			}
		}

		if (genScript != null) {
			if (genScript.exists("loadIndNoteAnims") && Reflect.isFunction(genScript.get("loadIndNoteAnims"))) {
				genScript.executeFunc("loadIndNoteAnims", [this], this, ["super" => _loadIndNoteAnims, "noteTypeLoaded" => changed]);
				changed = true;
			}
		}

		if (!changed)
			_loadIndNoteAnims();
	}

	function _loadIndNoteAnims() {
		final animName:String = 'default';
		final animFrames:Array<Int> = switch (holdType) {
			default: [column + 4];
			case PART: [column];
			case END: [column + 4];
		}
		animation.add(animName, animFrames);
		animation.play(animName, true);

		//scale.set(6, 6); // causd mines to be huge lol
	} 

	public function loadNoteAnims() {
		var changed = false;

		if (noteScript != null) {
			if (noteScript.exists("loadNoteAnims") && Reflect.isFunction(noteScript.get("loadNoteAnims"))) {
				noteScript.executeFunc("loadNoteAnims", [this], this, ["super" => _loadNoteAnims]);
				changed = true;
			}
		}

		if (genScript != null) {
			if (genScript.exists("loadNoteAnims") && Reflect.isFunction(genScript.get("loadNoteAnims"))) {
				genScript.executeFunc("loadNoteAnims", [this], this, ["super" => _loadNoteAnims, "noteTypeLoaded" => changed]);
				changed = true;
			}
		}

		if (!changed)
			_loadNoteAnims();
	}

	function _loadNoteAnims() {		
		final animName:String = 'default';
		final animPrefix:String = switch (holdType) {
			default: defaultNoteAnimNames[column];
			case PART: defaultHoldAnimNames[column];
			case END: defaultTailAnimNames[column];
		}

		if (column == 0) animation.addByPrefix(animName, 'pruple end hold'); // ?????
		// this is autistic wtf

		animation.addByPrefix(animName, animPrefix);
		animation.play(animName, true);
 
		scale.set(spriteScale, spriteScale); 
	} 

	override function draw()
	{		
		colorSwap.daAlpha = alphaMod * alphaMod2;

		if (tooLate && !inEditor)
		{
			if (alpha > 0.3)
				alpha = 0.3;
		}

		super.draw();
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if(inEditor)return;

		if (noteScript != null){
			noteScript.executeFunc("noteUpdate", [elapsed], this);
		}

		if (genScript != null){
			genScript.executeFunc("noteUpdate", [elapsed], this);
		}
		

		if (hitByOpponent)
			wasGoodHit = true;

		var diff = (strumTime - Conductor.songPosition);
		if (diff < -Conductor.safeZoneOffset && !wasGoodHit)
			tooLate = true;
	}
}
