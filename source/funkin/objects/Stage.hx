package funkin.objects;

import haxe.Json;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.FlxBasic;
import funkin.Paths;
import funkin.data.StageData;
import funkin.scripts.*;
import flixel.system.FlxAssets.FlxGraphicAsset;
import animate.FlxAnimate;
import animate.FlxAnimateFrames;

using StringTools;

class StageProp extends FlxSprite {
	public var canDance:Bool = true;
	public var bopTime:Float = 0;
	public var idleSequence:Array<String> = ['idle'];
	public var offsets:Map<String, Array<Float>> = [];
	public var interruptDanceAnims:Array<String> = [];

	var sequenceIndex:Int = 0;

	var nextDanceBeat:Float = 0;

	override public function new(?x:Float, ?y:Float, ?graphic:FlxGraphicAsset) {
		nextDanceBeat = Conductor.curDecBeat;
		super(x, y, graphic);
	}

	public function dance() {
		if (!canDance || animation.curAnim != null && interruptDanceAnims.contains(animation.curAnim.name)) 
			return;
		

		sequenceIndex++;
		if (sequenceIndex >= idleSequence.length)
			sequenceIndex = 0;

		playAnim(idleSequence[sequenceIndex], true);
	}

	public function playAnim(animName:String, forced:Bool, reversed:Bool = false, frame:Int = 0) {
		animation.play(animName, forced, reversed, frame);
		var theOffset = offsets.get(animName) ?? [0, 0];
		offset.set(theOffset[0], theOffset[1]);
	}

	override function update(elapsed:Float) {
		if (bopTime > 0) {
			while (Conductor.curDecBeat >= nextDanceBeat) {
				nextDanceBeat += bopTime;
				dance();
			}
		} else
			nextDanceBeat = Conductor.curBeat;

		super.update(elapsed);
	}

	public static function buildFromData(propData:StagePropData) {
		var prop:StageProp = new StageProp(propData.x ?? 0.0, propData.y ?? 0.0);

		if (Paths.fileExists('images/${propData.graphic}/Animation.json', TEXT))
			prop.frames = FlxAnimateFrames.fromAnimate(Paths.animateAtlasPath(propData.graphic));
		else if (Paths.fileExists('images/${propData.graphic}.txt', TEXT))
			prop.frames = Paths.getPackerAtlas(propData.graphic);
		else if (Paths.fileExists('images/${propData.graphic}.xml', TEXT))
			prop.frames = Paths.getSparrowAtlas(propData.graphic);
		else
			prop.loadGraphic(Paths.image(propData.graphic));

		if (propData.scale != null)
			prop.scale.set(propData.scale[0], propData.scale[1]);
		prop.updateHitbox();

		// TODO: allow FlxAnimate and multisparrow
		if (propData.animations != null) {
			for (animation in propData.animations) {
				if (animation.indices != null)
					prop.animation.addByIndices(animation.name, animation.prefix, animation.indices, '', animation.fps ?? 24, animation.looped ?? false,
						animation?.flipX ?? false, animation?.flipY ?? false);
				else
					prop.animation.addByPrefix(animation.name, animation.prefix, animation.fps ?? 24, animation.looped ?? false, animation?.flipX ?? false, animation?.flipY ?? false);

				if (animation.offset != null && animation.offset.length == 2)
					prop.offsets.set(animation.name, animation.offset);

				if (animation.haltsDancing == true)
					prop.interruptDanceAnims.push(animation.name);
				
				if (prop.animation.curAnim == null)
					prop.playAnim(animation.name, true);
			}
		}

		if (propData.antialiasing != null)
			prop.antialiasing = propData.antialiasing; // if null then dont set, because default antialiasing should be affecting it

		if (propData.danceSequence != null)
			prop.idleSequence = propData.danceSequence;

		if (propData.danceBeat != null) {
			prop.bopTime = propData.danceBeat;
			prop.playAnim(prop.idleSequence[0], true);
		}

		prop.alpha = propData?.alpha ?? 1.0;
		prop.flipX = propData?.flipX ?? false;
		prop.flipY = propData?.flipY ?? false;

		if(propData.scrollFactor != null)
			prop.scrollFactor.set(propData.scrollFactor[0], propData.scrollFactor[1]);

		prop.antialiasing = propData?.antialiasing ?? false;

		return prop;
	}
}

class Stage extends FlxTypedGroup<FlxBasic>
{
	public var stageId(default, null):String;
	public var stageData(default, null):StageFile;
	
	public var foreground = new FlxTypedGroup<FlxBasic>();

	public var props:Map<String, FlxBasic> = [];

	public var stageScript:FunkinHScript;

	public var stageBuilt:Bool = false;

	public function new(stageId:String, runScript:Bool = true)
	{
		super();

		this.stageId = stageId;
		this.stageData = StageData.getStageFile(stageId) ?? {
			directory: "",
			defaultZoom: 0.8,
			boyfriend: [500, 100],
			girlfriend: [0, 100],
			opponent: [-500, 100],
			hide_girlfriend: false,
			camera_boyfriend: [0, 0],
			camera_opponent: [0, 0],
			camera_girlfriend: [0, 0],
			camera_speed: 1
		};

		if (runScript)
			startScript();
	}

	public function startScript()
	{
		if (stageScript != null) {
			trace("Stage script already started!");
			return;
		}   

		var file = Paths.getHScriptPath('stages/$stageId');
		if (file == null) {
			stageScript = null;
			return;
		}
	
		stageScript = FunkinHScript.fromFile(file);

		// define variables lolol
		stageScript.set("this", this);
		stageScript.set("foreground", foreground);

		stageScript.set("add", add);
		stageScript.set("remove", remove);
		stageScript.set("insert", insert);
	}

	public function buildStage()
	{
		if (stageBuilt)
			return this;

		stageBuilt = true;
		if (stageScript != null && stageScript.exists("buildStage"))
			stageScript.call("buildStage", null, ["super" => _buildStage]);
		else
			_buildStage();

		return this;
	}

	private function _buildStage()
	{
		if (stageData.props != null) {
			for (propData in stageData.props) {
				var prop:StageProp = StageProp.buildFromData(propData);
				if (propData.id != null)
					props.set(propData.id, prop);

				if (propData.foreground)
					foreground.insert(propData?.index ?? foreground.members.length, prop);
				else
					insert(propData?.index ?? members.length, prop);
			}
		}

		#if ALLOW_DEPRECATION
		if (stageScript != null)
			stageScript.call("onLoad", [this, foreground]);
		#end

		return this;
	}

	override function destroy()
	{
		if (stageScript != null){
			stageScript.call("onDestroy");
			stageScript.stop();
			stageScript = null;
		}
		
		super.destroy();
	}

	override function toString(){
		return 'Stage($stageId)';
	}

	#if ALLOW_DEPRECATION
	@:deprecated("spriteMap is deprecated. Use props instead.")
	public var spriteMap(get, null):Map<String, FlxBasic>;
	function get_spriteMap()return props;

	@:deprecated("curStage is deprecated. Use stageId instead.")
	public var curStage(get, never):String;
	inline function get_curStage() return stageId;
	
	@:deprecated("Stage.getTitleStages is deprecated. Use StageData.getTitleStages instead.")
	inline public static function getTitleStages(modsOnly = false):Array<String>
		return StageData.getTitleStages(modsOnly);

	@:deprecated("Stage.getAllStages is deprecated. Use StageData.getAllStages instead.")
	inline public static function getAllStages(modsOnly = false):Array<String>
		return StageData.getAllStages(modsOnly);
	#end
}