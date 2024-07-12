package funkin.objects;

import funkin.states.PlayState;
import funkin.data.JudgmentManager.Judgment;
import funkin.states.editors.ChartingState;
import math.Vector3;
import funkin.scripts.*;
import funkin.objects.playfields.*;
import funkin.objects.shaders.ColorSwap;

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
	/**Only splashes on judgements that have splashes**/
	var DEFAULT = 0;
	/**Never splashes**/
	var DISABLED = -1;
	/**Always splashes**/
	var FORCED = 1;
}
class Note extends NoteObject
{
	public static var swagWidth(default, set):Float = 160 * 0.7;
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

	public static function getQuant(beat:Float){
		var row:Int = Conductor.beatToNoteRow(beat);
		for(data in quants){
			if (row % (Conductor.ROWS_PER_MEASURE/data) == 0)
				return data;
		}
		return quants[quants.length-1]; // invalid
	}

	@:noCompletion private static function set_swagWidth(val:Float){
		halfWidth = val * 0.5;
		return val;
	}
	public static var halfWidth(default, null):Float = swagWidth * 0.5;
	public static var quantShitCache = new Map<String, Bool>();

	////

	public var hitResult:HitResult = {judgment: UNJUDGED, hitDiff: 0}

	public var mAngle:Float = 0;
	public var bAngle:Float = 0;
	
	public var noteScript:FunkinHScript;
    public var genScript:FunkinHScript; // note generator script (used for shit like pixel notes or skin mods) ((script provided by the HUD skin))
	public var extraData:Map<String, Dynamic> = [];
	
	// basic stuff
	public var beat:Float = 0;
	public var strumTime(default, set):Float = 0;
    function set_strumTime(val:Float){
        row = Conductor.secsToRow(val);
        return strumTime=val;
    }
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
	public var causedMiss:Bool = false;
	function get_canBeHit()return PlayState.instance.judgeManager.judgeNote(this)!=UNJUDGED;
	
	// quant shit
	public var row:Int = 0;
	public var quant:Int = 4;
	public var isQuant:Bool = false; // mainly for color swapping, so it changes color depending on which set (quants or regular notes)
	
	// note type/customizable shit
	public var canQuant:Bool = true; // whether a quant texture should be searched for or not
    public var noteMod(default, set):String = null; 
	public var noteType(default, set):String = null;  // the note type
	public var usesDefaultColours:Bool = true; // whether this note uses the default note colours (lets you change colours in options menu)
	// This automatically gets set if a notetype changes the ColorSwap values

	/** If you need to tap the note to hit it, or just have the direction be held when it can be judged to hit.
		An example is Stepmania mines **/
	public var requiresTap:Bool = true; 

	/** The maximum amount of time you can release a hold before it counts as a miss**/
	public var maxReleaseTime:Float = 0.25;

	public var blockHit:Bool = false; // whether you can hit this note or not
	#if PE_MOD_COMPATIBILITY
	public var lowPriority:Bool = false; // Shadowmario's shitty workaround for really bad mine placement, yet still no *real* hitbox customization lol! Only used when PE Mod Compat is enabled in project.xml
	#end
	@:isVar
	public var noteSplashDisabled(get, set):Bool = false; // disables the notesplash when you hit this note
	function get_noteSplashDisabled()
		return noteSplashBehaviour == DISABLED;
	function set_noteSplashDisabled(val:Bool){
		noteSplashBehaviour = val ? DISABLED : DEFAULT;
		return val;
	}

	public var noteSplashBehaviour:SplashBehaviour = DEFAULT;
	public var noteSplashTexture:String = null; // spritesheet for the notesplash
	public var noteSplashHue:Float = 0; // hueshift for the notesplash, can be changed in note-type but otherwise its whatever the user sets in options
	public var noteSplashSat:Float = 0; // ditto, but for saturation
	public var noteSplashBrt:Float = 0; // ditto, but for brightness
	//public var ratingDisabled:Bool = false; // disables judging this note
	public var missHealth:Float = 0; // damage when hitCausesMiss = true and you hit this note
    @:isVar	
	public var texture(get, set):String; // texture for the note
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

	// hold shit
	public var tail:Array<Note> = []; 
	public var unhitTail:Array<Note> = [];
	public var parent:Note;
	public var sustainLength:Float = 0;
	public var isSustainNote:Bool = false;
	public var holdingTime:Float = 0;
	public var tripProgress:Float = 0;
    public var isHeld:Bool = false;
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
    public var realColumn:Int;
	public var vec3Cache:Vector3 = new Vector3(); // for vector3 operations in modchart code

    @:isVar
	public var realNoteData(get, set):Int; // backwards compat
    inline function get_realNoteData()
        return realColumn;
    inline function set_realNoteData(v:Int)
        return realColumn = v;

	/*
	private var colArray(get, never):Array<String>;
	inline function set_colArray() return Note.colArray;
	*/

	// mod manager
	public var garbage:Bool = false; // if this is true, the note will be removed in the next update cycle
	public var alphaMod:Float = 1;
	public var alphaMod2:Float = 1; // TODO: unhardcode this shit lmao
	public var typeOffsetX:Float = 0; // used to offset notes, mainly for note types. use in place of offset.x and offset.y when offsetting notetypes
	public var typeOffsetY:Float = 0;
	public var typeOffsetAngle:Float = 0;
	public var multSpeed:Float = 1.0;
	/* useless shit mostly
	public var offsetAngle:Float = 0;
	*/

	public var copyX:Bool = true;
	public var copyY:Bool = true;
	public var copyAngle:Bool = true;
	public var copyAlpha:Bool = true;

	public var rating:String = 'unknown';
	public var ratingMod:Float = 0; //9 = unknown, 0.25 = shit, 0.5 = bad, 0.75 = good, 1 = sick

	public var isSustainEnd:Bool = false;
	/*
	@:isVar
	public var isSustainEnd(get, null):Bool = false;

	public function get_isSustainEnd():Bool
		return (isSustainNote && animation != null && animation.curAnim != null && animation.curAnim.name != null && animation.curAnim.name.endsWith("end"));
	*/

	public function resizeByRatio(ratio:Float) //haha funny twitter shit
	{
		
	}

	private function set_texture(value:String):String {
        if(tex != value)reloadNote(texPrefix, value, texSuffix);
        return tex;
	}

    function get_texture():String{
        return tex;
    }

	public function updateColours(ignore:Bool=false){		
		if (!ignore && !usesDefaultColours) return;
		if (colorSwap==null) return;
		if (column == -1) return; // FUCKING PSYCH EVENT NOTES!!!
		
		var hsb = isQuant ? ClientPrefs.quantHSV[quants.indexOf(quant)] : ClientPrefs.arrowHSV[column % 4];
		if (hsb != null){ // sigh
			colorSwap.hue = hsb[0] / 360;
			colorSwap.saturation = hsb[1] / 100;
			colorSwap.brightness = hsb[2] / 100;
		}else{
			colorSwap.hue = 0.0;
			colorSwap.saturation = 0.0;
			colorSwap.brightness = 0.0;
		}

		if (noteScript != null)
		{
			noteScript.executeFunc("onUpdateColours", [this], this);
		}

		if (genScript != null)
		{
			genScript.executeFunc("onUpdateColours", [this], this);
		}
	}

    private function set_noteMod(value:String):String
    {
        if(value == null)
            value = 'default';

        updateColours();

		colorSwap = new ColorSwap();
		shader = colorSwap.shader;

		// just to make sure they arent 0, 0, 0
		colorSwap.hue += 0.0127;
		colorSwap.saturation += 0.0127;
		colorSwap.brightness += 0.0127;
		var hue = colorSwap.hue;
		var sat = colorSwap.saturation;
		var brt = colorSwap.brightness;

		if (usesDefaultColours)
		{
			if (colorSwap.hue != hue || colorSwap.saturation != sat || colorSwap.brightness != brt)
			{
				usesDefaultColours = false; // just incase
			}
		}

		if (colorSwap.hue == hue)
			colorSwap.hue -= 0.0127;

		if (colorSwap.saturation == sat)
			colorSwap.saturation -= 0.0127;

		if (colorSwap.brightness == brt)
			colorSwap.brightness -= 0.0127;

		if (!inEditor && PlayState.instance != null){
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
					break;
                }
            }
			genScript = script;
        }

		if (genScript == null || !genScript.exists("setupNoteTexture")){
			if (genScript != null)
			{
				if (genScript.exists("texturePrefix"))
					texPrefix = genScript.get("texturePrefix");

				if (genScript.exists("textureSuffix"))
					texSuffix = genScript.get("textureSuffix");
			}

			texture = (genScript != null && genScript.exists("noteTexture")) ? genScript.get("noteTexture") : "";
        }
        else if(genScript.exists("setupNoteTexture"))
            genScript.executeFunc("setupNoteTexture", [this]);
        

		if (!isSustainNote && column > -1 && column < colArray.length)
		{
			var col:String = colArray[column % colArray.length];
			animation.play(col + 'Scroll');
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

        // TODO: add the ability to override these w/ scripts lol
		if(column > -1 && noteType != value) 
		{
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
					missHealth = isSustainNote ? 0.1 : 0.3;
					hitCausesMiss = true;

				case 'No Animation':
					noAnimation = true;
					noMissAnimation = true;

				case 'GF Sing':
					gfNote = true;

				default:
					if (inEditor){
						if (ChartingState.instance != null)
							noteScript = ChartingState.instance.notetypeScripts.get(value);
					}else if (PlayState.instance != null){
						noteScript = PlayState.instance.notetypeScripts.get(value);					
					}

					if (noteScript != null)
						noteScript.executeFunc("setupNote", [this], this, ["this" => this]);

					if (genScript != null)
						genScript.executeFunc("setupNoteType", [this], this, ["this" => this]);
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

	public function new(strumTime:Float, column:Int, ?prevNote:Note, ?gottaHitNote:Bool = false, ?sustainNote:Bool = false, ?inEditor:Bool = false, ?noteMod:String = 'default')
	{
		super();
		objType = NOTE;

        this.strumTime = strumTime;
		this.column = column;
		this.prevNote = (prevNote==null) ? this : prevNote;
		this.isSustainNote = sustainNote;
		this.inEditor = inEditor;
		this.mustPress = gottaHitNote;

		if (canQuant && ClientPrefs.noteSkin == 'Quants'){
			if (isSustainNote && prevNote != null)
				quant = prevNote.quant;
			else
				quant = getQuant(Conductor.getBeatSinceChange(this.strumTime));
		}
		
		beat = Conductor.getBeat(strumTime);
		
		if (!inEditor){ 
			this.strumTime += ClientPrefs.noteOffset;
			visualTime = PlayState.instance.getNoteInitialTime(this.strumTime);
		}

		if (column > -1)
			this.noteMod = noteMod;
		else
			this.colorSwap = new ColorSwap();

		if (prevNote != null)
			prevNote.nextNote = this;

		if (isSustainNote && prevNote != null)
		{
			alpha = 0.6;
			hitsoundDisabled = true;
			copyAngle = false;
			//if(ClientPrefs.downScroll) flipY = true;

			if (genScript != null && genScript.exists("setupHoldNoteTexture"))
				genScript.executeFunc("setupHoldNoteTexture", [this]);

			animation.play(colArray[column % 4] + 'holdend');
			updateHitbox();

			if (prevNote.isSustainNote)
			{
				prevNote.animation.play(colArray[prevNote.column % 4] + 'hold');

				prevNote.scale.y *= Conductor.stepCrochet / 100 * 1.5 * PlayState.instance.songSpeed * 100;
				prevNote.updateHitbox();

				prevNote.defScale.copyFrom(prevNote.scale);
			}
		}

		defScale.copyFrom(scale);
	}

	public var texPrefix:String = '';
	public var tex:String;
	public var texSuffix:String = '';
	public function reloadNote(?prefix:String, ?texture:String, ?suffix:String, ?dir:String = '', hInd:Int = 0, vInd:Int = 0) {
		if(prefix == null) prefix = '';
		if(texture == null) texture = '';
		if(suffix == null) suffix = '';

		texPrefix = prefix;
		tex = texture;
		texSuffix = suffix;

		if (genScript != null)
			genScript.executeFunc("onReloadNote", [this, prefix, texture, suffix], this);
        
		if (noteScript != null)
			noteScript.executeFunc("onReloadNote", [this, prefix, texture, suffix], this);

		if (genScript != null && genScript.executeFunc("preReloadNote", [this, prefix, texture, suffix], this) == Globals.Function_Stop)
			return;

		var animName:String = animation.curAnim != null ? animation.curAnim.name : null;
		var lastScaleY:Float = scale.y;

		////
		var skin:String = (texture.length > 0) ? texture : PlayState.arrowSkin;
		var arraySkin:Array<String> = skin.split('/');
		arraySkin[arraySkin.length - 1] = prefix + arraySkin[arraySkin.length-1] + suffix; // add prefix and suffix to the texture file
		var blahblah:String = arraySkin.join('/');

		var daDirs = [''];
		if (dir.trim() != '')
			daDirs.unshift(dir + '/');	

		var checkQuants:Bool = canQuant && ClientPrefs.noteSkin == 'Quants';
		var wasQuant:Bool = isQuant;
		isQuant = false;

		for (dir in daDirs)
		{
			var fullPath:String = dir + blahblah;

			if (checkQuants)
			{
				var quantBlahblah = "QUANT" + blahblah;
				var useQuantTex:Bool;

				if (quantShitCache.exists(fullPath)){
					useQuantTex = quantShitCache.get(fullPath);
				}else{
					useQuantTex = Paths.imageExists(dir + quantBlahblah);
					quantShitCache.set(fullPath, useQuantTex);
				}

				if (useQuantTex) {
                    isQuant = true;
					blahblah = quantBlahblah;
					fullPath = dir + quantBlahblah;
				}
			}

			if (wasQuant != isQuant)
				updateColours();

			if (Paths.imageExists(fullPath))
			{
				if (vInd > 0 && hInd > 0){
					var graphic = Paths.image(fullPath);
					width = graphic.width / hInd;
					height = graphic.height / vInd;
					loadGraphic(graphic, true, Math.floor(width), Math.floor(height));
					loadIndNoteAnims();
					break;
				}else{	
					frames = Paths.getSparrowAtlas(fullPath);
					loadNoteAnims();
					break;
				}
			}
		}
		
		if(isSustainNote)
			scale.y = lastScaleY;
		defScale.copyFrom(scale);

		if (animName != null)
			animation.play(animName, true);

		if (inEditor)
			setGraphicSize(ChartingState.GRID_SIZE, ChartingState.GRID_SIZE);
		
		updateHitbox();

		if (genScript != null)
			genScript.executeFunc("postReloadNote", [this, prefix, texture, suffix], this);

		if (noteScript != null)
			noteScript.executeFunc("postReloadNote", [this, prefix, texture, suffix], this);
	}

	public function loadIndNoteAnims()
	{
		var con = true;
		if (noteScript != null)
		{
			if (noteScript.exists("loadIndNoteAnims") && Reflect.isFunction(noteScript.get("loadIndNoteAnims")))
			{
				noteScript.executeFunc("loadIndNoteAnims", [this], this, ["super" => _loadIndNoteAnims]);
				con = false;
			}
		}

		if (genScript != null)
		{
			if (genScript.exists("loadIndNoteAnims") && Reflect.isFunction(genScript.get("loadIndNoteAnims")))
			{
				genScript.executeFunc("loadIndNoteAnims", [this], this, ["super" => _loadIndNoteAnims, "noteTypeLoaded" => con]);
				con = false;
			}
		}
		if (!con)
			return;
		_loadIndNoteAnims();
	}

	function _loadIndNoteAnims()
	{
		if (isSustainNote)
		{
			animation.add(colArray[column] + 'holdend', [column + 4]);
			animation.add(colArray[column] + 'hold', [column]);
		}
		else
			animation.add(colArray[column] + 'Scroll', [column + 4]);
	}


	public function loadNoteAnims() {
        var con = true;
		if (noteScript != null){
			if (noteScript.exists("loadNoteAnims") && Reflect.isFunction(noteScript.get("loadNoteAnims"))){
				noteScript.executeFunc("loadNoteAnims", [this], this, ["super" => _loadNoteAnims]);
				con = false;
			}
		}

		if (genScript != null)
		{
			if (genScript.exists("loadNoteAnims") && Reflect.isFunction(genScript.get("loadNoteAnims")))
			{
				genScript.executeFunc("loadNoteAnims", [this], this, ["super" => _loadNoteAnims, "noteTypeLoaded" => con]);
				con = false;
			}
		}
		if (!con)return;

		_loadNoteAnims();
	}

	function _loadNoteAnims() {
		animation.addByPrefix(colArray[column] + 'Scroll', colArray[column] + '0');

		if (isSustainNote)
		{
			animation.addByPrefix('purpleholdend', 'pruple end hold'); // ?????
            // this is autistic wtf
			animation.addByPrefix(colArray[column] + 'holdend', colArray[column] + ' hold end');
			animation.addByPrefix(colArray[column] + 'hold', colArray[column] + ' hold piece');
		}

		scale.set(0.7, 0.7);
		updateHitbox();
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if(!inEditor){
			if (noteScript != null){
				noteScript.executeFunc("noteUpdate", [elapsed], this);
			}

			if (genScript != null){
				genScript.executeFunc("noteUpdate", [elapsed], this);
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
