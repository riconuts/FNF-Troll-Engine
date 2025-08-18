package funkin.objects;

import funkin.data.CharacterData;
import haxe.Json;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.FlxBasic;
import funkin.Paths;
import funkin.Paths.ContentMetadata;
import funkin.data.Song;
import funkin.scripts.*;
import flixel.system.FlxAssets.FlxGraphicAsset;
import animateatlas.AtlasFrameMaker;

using StringTools;

typedef VSliceStageProp = {
	?name:String,
	assetPath:String,
	position:Array<Float>,
	?zIndex:Int,
	?isPixel:Bool,
	?flipX:Bool,
	?flipY:Bool,
	?scale:haxe.ds.Either<Float, Array<Float>>,
	?alpha:Float,
	?danceEvery:Float,
	?scroll:Array<Float>,
	?animations:Array<funkin.data.CharacterData.VSliceAnimData>,
	?startingAnimation:String,
	?animType: String,
	?angle:Float,
	?blend:String,
	?color:String
}

typedef VSliceStageChar = {
	?zIndex:Int, 
	?position: Array<Float>,
	?scale: Float,
	?cameraOffsets:Array<Float>,
	?scroll: Array<Float>,
	?alpha:Float,
	?angle:Float
}

typedef VSliceStageFile = 
{
	version:String,
	name:String,
	props:Array<VSliceStageProp>,
	characters:{bf: VSliceStageChar, gf: VSliceStageChar, dad:VSliceStageChar},
	?cameraZoom: Float,
	?directory:String
}

// prop shit is kinda just here for vslice compat
// eventually we should make it all polished and add an editor and the like lol
// Also should prob make a generic prop typedef which both LevelProp and StageProp can extend from
// Also maybe a generic prop/bopper class lol

typedef StagePropData = {
	// Scripting
	?id:String,
	// Position shit
	?x:Float,
	?y:Float,
	?flipX:Bool,
	?flipY:Bool,
	
	// Visuals
	graphic:String,
	?alpha:Float,
	?scrollFactor:Array<Float>,
	?scale:Array<Float>,
	?antialiasing:Bool,
	?animations:Array<funkin.data.Level.LevelPropAnimation>,

	// Ordering
	?index:Int, // ZIndex within the layer (stage or foreground)
	?foreground:Bool, // Whether to put this in the foreground

	// Bopping
	?danceSequence:Array<String>, // Cycles through this every dance
	?danceBeat:Float, // What beat to dance on. 0 = disabled
}

typedef StageFile =
{
	var directory:String;
	var defaultZoom:Float;

	var boyfriend:Array<Dynamic>;
	var girlfriend:Array<Dynamic>;
	var opponent:Array<Dynamic>;
	@:optional var props:Array<StagePropData>;

	@:optional var hide_girlfriend:Bool;

	@:optional var camera_boyfriend:Array<Float>;
	@:optional var camera_opponent:Array<Float>;
	@:optional var camera_girlfriend:Array<Float>;
	@:optional var camera_speed:Null<Float>;

	@:optional var bg_color:Null<String>;

	// v-slice positioning using the character's width and height to offset them
	@:optional var alternate_char_pos:Bool;

	// title screen vars
	@:optional var camera_stage:Array<Float>; 
	@:optional var title_zoom:Float;

	// caching
	@:optional var preloadStrings:Array<String>;
	@:optional var preload:Array<funkin.data.Cache.AssetPreload>; // incase you would like to add more information, though you shouldnt really need to
}

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
			prop.frames = AtlasFrameMaker.construct(propData.graphic);
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
	public var spriteMap(get, null):Map<String, FlxBasic>;

	
	#if ALLOW_DEPRECATION
	@:deprecated("spriteMap is deprecated. Use props instead.")
	function get_spriteMap()return props;

	@:deprecated("curStage is deprecated. Use stageId instead.")
	public var curStage(get, never):String;
	inline function get_curStage() return stageId;
	#end

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
			startScript(false);
	}

	var stageBuilt:Bool = false;
	public function startScript(?buildStage = false, ?additionalVars:Map<String, Any>)
	{
		if (stageScript != null)
		{
			trace("Stage script already started!");
			return;
		}   

		var file = Paths.getHScriptPath('stages/$stageId');
		if (file != null){
			stageScript = FunkinHScript.fromFile(file, file, additionalVars);

			// define variables lolol
			stageScript.set("this", this);
			stageScript.set("foreground", foreground);

			#if ALLOW_DEPRECATION
			stageScript.set("stage", this); // for backwards compat lol
			#end

			stageScript.set("add", add);
			stageScript.set("remove", remove);
			stageScript.set("insert", insert);


			if (buildStage) {
				stageScript.call("onLoad", [this, foreground]);
				stageBuilt = true;
			}
		}
	}

	public function buildStage()
	{
		if (!stageBuilt){
			// In case you want to hardcode your stages
			/* 
			switch (stageId)
			{
				case "example":
					var ground = new FlxSprite(-2048, -100);
					ground.makeGraphic(4096, 1280, 0xFFEAEAEA);
					this.add(ground);

					var block1 = new FlxSprite(-1750, -250);
					block1.makeGraphic(512, 512, 0xFF888888);
					block1.offset.set(256, 256);
					block1.scrollFactor.set(1.6, 1.2);
					foreground.add(block1);

					var block2 = new FlxSprite(1000, -250);
					block2.makeGraphic(512, 512, 0xFF888888);
					block2.offset.set(256, 256);
					block2.scrollFactor.set(1.6, 1.2);
					foreground.add(block2);
			}
			*/
			
			if(stageData.props != null){
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



			if (stageScript != null){
				stageScript.call("onLoad", [this, foreground]);
			}

			stageBuilt = true;
		} 

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

	/**
		Return an array with the names in the stageList file(s).
	**/ 
	public static function getTitleStages(modsOnly = false):Array<String>{
	
		var daList:Array<String> = [];
		#if MODS_ALLOWED
		if (modsOnly){
			var modPath:String = Paths.modFolders('data/stageList.txt');
			if (Paths.exists(modPath))
			{
				var modsList = Paths.getContent(modPath);
				if (modsList != null && modsList.trim().length > 0)
					for (shit in modsList.split("\n"))
						daList.push(shit.trim().replace("\n", ""));
			}

		}else{
			var modsList = Paths.text('data/stageList.txt', false);
			if (modsList != null && modsList.trim().length > 0)
				for (shit in modsList.split("\n"))
					daList.push(shit.trim().replace("\n", ""));
		}


		 
		var path = Paths.modFolders("metadata.json");
		var rawJson:Null<String> = Paths.getContent(path);

		if (rawJson != null && rawJson.length > 0)
		{
			var daJson:Dynamic = Json.parse(rawJson);
			if (Reflect.field(daJson, "titleStages") != null)
			{
				var data:ContentMetadata = cast daJson;
				for (stage in data.titleStages)
				{
					daList.push(stage.trim().replace("\n",""));
				}
			}
		}

		#end
		return daList;
	}

	/**
		Returns an array with every stage in the stages folder(s).
	**/
	#if !sys
	@:noCompletion private static var _listCache:Null<Array<String>> = null;
	#end
	public static function getAllStages(modsOnly = false):Array<String>
	{
		#if !sys
		if (_listCache != null)
			return _listCache;

		var stages:Array<String> = _listCache = [];
		#else
		var stages:Array<String> = [];
		#end

		var _stages = new Map<String, Bool>();

		function readFileNameAndPush(fileName: String){
			if (fileName==null)return;
			
			if (!fileName.endsWith(".json")) return;

			var name = fileName.substr(0, fileName.length - 5);
			_stages.set(name, true);
		}
		
		for (folderPath in Paths.getFolders("stages", modsOnly))
		{
			Paths.iterateDirectory(folderPath, readFileNameAndPush);
		}

		for (name in _stages.keys())
			stages.push(name);

		return stages;
	}
}

class StageData {
	/*
	public static var forceNextDirectory:String = null;

	public static function loadDirectory(SONG:SwagSong) {
		var stage:String = 'stage';

		if (SONG.stage != null)
			stage = SONG.stage;

		var stageFile:StageFile = getStageFile(stage);

		// preventing crashes
		forceNextDirectory = stageFile == null ? '' : stageFile.directory;
	}
	*/
	
	public inline static function convertVSliceProps(json: VSliceStageFile)
	{
		var props:Array<StagePropData> = [];

		for (v in json.props) {
			var scale:Array<Float> = [1, 1];
			if (v.scale is Float) {
				var c:Float = cast v.scale;
				scale = [c, c];
			} else if (v.scale is Array) scale = cast scale;

			var sequence = ["idle"];

			props.push({
				id: v.name,
				graphic: v.assetPath,
				x: v.position[0],
				y: v.position[1],
				flipX: v?.flipX ?? false,
				flipY: v?.flipY ?? false,
				alpha: v?.alpha ?? 1,
				scrollFactor: v?.scroll ?? [1],
				scale: scale,
				antialiasing: !(v?.isPixel ?? false),
				animations: [
					for (a in v.animations) {
						if (a.name == 'danceLeft') sequence = ["danceLeft", "danceRight"];

						{
							name: a.name,
							prefix: a.prefix,
							looped: a?.looped ?? false,
							fps: a?.frameRate ?? 24,
							indices: a.frameIndices,
							offset: a.offsets == null ? [0, 0] : [Std.int(a.offsets[0]), Std.int(a.offsets[1])],
							flipX: a?.flipX,
							flipY: a?.flipY
						}
					}
				],
				index: (v.zIndex >= json.characters.bf.zIndex) ? v.zIndex - json.characters.bf.zIndex : v.zIndex,
				foreground: v.zIndex >= json.characters.bf.zIndex,

				danceSequence: sequence,
				danceBeat: v?.danceEvery ?? 0
			});
		}

		trace(props);
	
		return props;

	}

	public static function convertVSlice(json: VSliceStageFile):StageFile 
	{
		return {
			props: StageData.convertVSliceProps(json),
			directory: "", // json.directory maybe idfk
			defaultZoom: json.cameraZoom,
			boyfriend: json.characters.bf.position,
			girlfriend: json.characters.gf.position,
			opponent: json.characters.dad.position,
			hide_girlfriend: false,
			camera_boyfriend: json.characters.bf.cameraOffsets == null ? [0, 0] : [json.characters.bf.cameraOffsets[0] * -1, json.characters.bf.cameraOffsets[1] * -1],
			camera_opponent: json.characters.dad.cameraOffsets,
			camera_girlfriend: json.characters.gf.cameraOffsets,
			camera_speed: 1,
			alternate_char_pos: true
		}
	}

	public static function getStageFile(stageId:String):Null<StageFile> 
	{
		var json:Dynamic = Paths.json('stages/$stageId.json', false);
		if(json != null && Reflect.field(json, "version") != null){
			var json:VSliceStageFile = cast json;
			return StageData.convertVSlice(json);
		}
		return json;
	}
}
