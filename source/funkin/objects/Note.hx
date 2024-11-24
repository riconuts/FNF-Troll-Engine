package funkin.objects;

import funkin.objects.NoteObject.IColorable;
import math.Vector3;
import flixel.math.FlxMath;
import funkin.scripts.*;
import funkin.states.PlayState;
import funkin.states.editors.ChartingState;
import funkin.data.NoteStyles;
import funkin.objects.notestyles.BaseNoteStyle;
import funkin.objects.shaders.ColorSwap;
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

class NoteType {
	public function new() {
	
	}
}

class Note extends NoteObject implements IColorable
{
	public static var swagWidth(default, set):Float = 160 * 0.7;
	public static var halfWidth(default, null):Float = swagWidth * 0.5;

	public static var colArray:Array<String> = ['purple', 'blue', 'green', 'red'];
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

	// should move these to Paths maybe
	public static final quantShitCache = new Map<String, Null<String>>();

	/** Return null if there's no quant texture file **/
	public static function getQuantTexture(dir:String, fileName:String, textureKey:String):Null<String> {
		var quantKey:Null<String>;

		if (quantShitCache.exists(textureKey)) {
			quantKey = quantShitCache.get(textureKey);

		}else {
			quantKey = dir + "QUANT" + fileName;
			if (!Paths.imageExists(quantKey)) quantKey = null;
			quantShitCache.set(textureKey, quantKey);
		}

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
	public var extraData:Map<String, Dynamic> = [];
	
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
	public var tripProgress:Float = 0;
	public var tail:Array<Note> = []; 
	public var unhitTail:Array<Note> = [];

	// quant shit
	public var quant:Int = 4;

	// note status
	public var spawned:Bool = false;
	public var tooLate:Bool = false;
	public var wasGoodHit:Bool = false;
	public var noteWasHit:Bool = false;
	public var causedMiss:Bool = false;
	public var canBeHit(get, never):Bool;

	public var hitResult:HitResult = {judgment: UNJUDGED, hitDiff: 0}
	public var rating:String = 'unknown';
	public var ratingMod:Float = 0; // 0 = unknown, 0.25 = shit, 0.5 = bad, 0.75 = good, 1 = sick
	
	//// note type/customizable shit
    public var noteMod(default, set):String = null; 
	public var noteType(default, set):String = null;  // the note type
	public var noteStyle(default, set) = null; // the note's visual appearance
	var _noteStyle:BaseNoteStyle; // the actual note style script
	public var canQuant:Bool = true; // whether a quant texture should be searched for or not
	public var usesDefaultColours:Bool = true; // whether this note uses the default note colours (lets you change colours in options menu)
	// This automatically gets set if a notetype changes the ColorSwap values

	//// note behaviour
	public var breaksCombo:Bool = false; // hitting this will cause a combo break
	public var blockHit:Bool = false; // whether you can hit this note or not
	public var hitCausesMiss:Bool = false; // hitting this causes a miss
	public var missHealth:Float = 0; // damage when hitCausesMiss = true and you hit this note
	public var ratingDisabled:Bool = false; // hitting or missing this note shouldn't affect stats, this doesn't prevent sing/miss animations and sounds from playing! 
	public var hitsoundDisabled:Bool = false; // hitting this does not cause a hitsound when user turns on hitsounds

	public var gfNote:Bool = false; // gf sings this note (pushes gf into characters array when the note is hit)
	public var noAnimation:Bool = false; // disables the animation for hitting this note
	public var noMissAnimation:Bool = false; // disables the animation for missing this note

	/** If not null, then the characters will play these anims instead of the default ones when hitting this note. **/
	public var characterHitAnimName:Null<String> = null;
	/** If not null, then the characters will play these anims instead of the default ones when missing this note. **/
	public var characterMissAnimName:Null<String> = null;
	// suffix to be added to the base default anim names (for ex. the resulting anim name to be played would be 'singLEFT'+'suffix'+'miss')
	// gets unused if the default anim names are overriden by the vars above
	public var characterHitAnimSuffix:String = "";
	public var characterMissAnimSuffix:String = "";

	/** If you need to tap the note to hit it, or just have the direction be held when it can be judged to hit.
	 * An example is Stepmania mines **/
	public var requiresTap:Bool = true; 

	/** The maximum amount of time you can release a hold before it counts as a miss**/
	public var maxReleaseTime:Float = 0.25;

	#if PE_MOD_COMPATIBILITY
	public var lowPriority:Bool = false; // John Psych Engine's shitty workaround for really bad mine placement, yet still no *real* hitbox customization lol! Only used when PE Mod Compat is enabled in project.xml
	#end

	/** Which characters sing this note, if it's blank then the playfield's characters are used **/
	public var characters:Array<Character> = []; 
	
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
	public var colorSwap:ColorSwap;
	public var inEditor:Bool = false;
	public var desiredZIndex:Float = 0;

	// mod manager
	public var garbage:Bool = false; // if this is true, the note will be removed in the next update cycle
	public var alphaMod:Float = 1;
	public var alphaMod2:Float = 1; // TODO: unhardcode this shit lmao
	public var typeOffsetX:Float = 0; // used to offset notes, mainly for note types. use in place of offset.x and offset.y when offsetting notetypes
	public var typeOffsetY:Float = 0;
	public var typeOffsetAngle:Float = 0;
	public var multSpeed:Float = 1.0;

	// do not tuch
	public var baseScaleX:Float = 1;
	public var baseScaleY:Float = 1;
	public var zIndex:Float = 0;
	public var z:Float = 0;
	public var vec3Cache:Vector3 = new Vector3(); // for vector3 operations in modchart code

	// Determines how the note can be modified by the modchart system
	// Could be moved into NoteObject? idk lol
	public var copyX:Bool = true;
	public var copyY:Bool = true;
	public var copyAlpha:Bool = true;
	public var copyVerts:Bool = true;
	
	#if PE_MOD_COMPATIBILITY
	// Angle is controlled by verts in the modchart system
    @:isVar public var copyAngle(get, set):Bool;
    function get_copyAngle()return copyVerts;
    function set_copyAngle(val:Bool)return copyVerts = val;
    #end

	@:noCompletion function get_canBeHit() return UNJUDGED != PlayState.instance.judgeManager.judgeNote(this);

	@:noCompletion inline function get_noteSplashDisabled() return noteSplashBehaviour == DISABLED;
	@:noCompletion inline function set_noteSplashDisabled(val:Bool) {
		noteSplashBehaviour = val ? DISABLED : DEFAULT;
		return val;
	}

	private function set_noteMod(value:String):String
	{
		if (value == null)
			value = 'default';

		////
		if (!inEditor && PlayState.instance != null)
			genScript = PlayState.instance.getHudSkinScript(value);

		return noteMod = value;
	}

	private function set_noteStyle(name:String):String {
		if (noteStyle == name)
			return name;

		if (_noteStyle != null) 
			_noteStyle.unloadNote(this);
		
		
		// find the first existing style in the following order [hudskin.getNoteStyle(name), name, 'default']
		var newStyle:BaseNoteStyle = null;

		if (genScript != null) {
			var ret = genScript.executeFunc("getNoteStyle", [name]);
			if (ret is String)newStyle = NoteStyles.get(ret, name);
			
		}

		if (newStyle == null) newStyle = NoteStyles.get(name, 'default');
		if (newStyle.loadNote(this))
			noteStyle = name; // yes, the base name, not the hudskin name.
		
		_noteStyle = newStyle;
		return noteStyle;
	}

	private function set_noteType(value:String):String {
		if (column > -1 && (noteType==null || noteType != value)) {
			var instance:NoteScriptState = inEditor ? ChartingState.instance : PlayState.instance;
			noteScript = (instance == null) ? null : instance.notetypeScripts.get(value);

			if (noteScript != null) {
				noteScript.executeFunc("setupNote", [this], this, ["this" => this]);
			
			}else { // default notes. these values won't get set if you make a script for them!
				switch (value) {
					case 'Alt Animation':
						characterHitAnimSuffix = "-alt";
						characterMissAnimSuffix = "-alt";

					case 'Hey!': 
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
			
			if (noteStyle == null) 
				noteStyle = (field==null) ? 'default' : field.defaultNoteStyle;

			if (noteScript != null)
				noteScript.executeFunc("postSetupNote", [this], this, ["this" => this]);
		}

		// this should prob be determined by notestyle

		noteSplashHue = colorSwap.hue;
		noteSplashSat = colorSwap.saturation;
		noteSplashBrt = colorSwap.brightness;
		

		return noteType;
	}

	override function toString()
	{
		return '(ID: $ID, column: $column | noteType: $noteType | strumTime: $strumTime | visible: $visible)';
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

		if ((FlxG.state is PlayState))
			this.strumTime -= (cast FlxG.state).offset;

		if (!inEditor) {
			this.strumTime += ClientPrefs.noteOffset;            
			visualTime = PlayState.instance.getNoteInitialTime(this.strumTime);
		}

		if (prevNote != null) 
			prevNote.nextNote = this;

		colorSwap = new ColorSwap();
		shader = colorSwap.shader;

		if (column >= 0) 
			this.noteMod = noteMod;
	}

	override function draw()
	{
		var holdMult:Float = isSustainNote ? 0.6 : 1;

		if (isSustainNote && parent.wasGoodHit)
			holdMult = FlxMath.lerp(0.3, 1, parent.tripProgress);
		
		colorSwap.daAlpha = alphaMod * alphaMod2 * holdMult;

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

		if (!inEditor) {
			if (noteScript != null){
				noteScript.executeFunc("noteUpdate", [elapsed], this);
			}

			if (genScript != null){
				genScript.executeFunc("noteUpdate", [elapsed], this);
			}
		}

		if (_noteStyle != null)
			_noteStyle.updateObject(this, elapsed);

		var diff = (strumTime - Conductor.songPosition);
		if (diff < -Conductor.safeZoneOffset && !wasGoodHit)
			tooLate = true;
	}

	override function destroy(){
		super.destroy();
		if (noteStyle != null) {
			var prevStyle:BaseNoteStyle = NoteStyles.get(noteStyle);
			prevStyle.unloadNote(this);
		}
	}
}
