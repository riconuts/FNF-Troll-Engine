package funkin.objects;

import haxe.Json;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.FlxBasic;
import funkin.Paths;
import funkin.Paths.ContentMetadata;
import funkin.data.Song;
import funkin.scripts.*;

using StringTools;

typedef StageFile =
{
	var directory:String;
	var defaultZoom:Float;

	var boyfriend:Array<Dynamic>;
	var girlfriend:Array<Dynamic>;
	var opponent:Array<Dynamic>;
	@:optional var hide_girlfriend:Bool;

	@:optional var camera_boyfriend:Array<Float>;
	@:optional var camera_opponent:Array<Float>;
	@:optional var camera_girlfriend:Array<Float>;
	@:optional var camera_speed:Null<Float>;

	@:optional var bg_color:Null<String>;

	// title screen vars
	@:optional var camera_stage:Array<Float>; 
	@:optional var title_zoom:Float;

	// caching
	@:optional var preloadStrings:Array<String>;
	@:optional var preload:Array<funkin.data.Cache.AssetPreload>; // incase you would like to add more information, though you shouldnt really need to
}

class Stage extends FlxTypedGroup<FlxBasic>
{
	public var curStage:String = "stage" #if tgt + "1" #end;
	public var stageData:StageFile = {
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
	public var foreground = new FlxTypedGroup<FlxBasic>();

	public var stageScript:FunkinHScript;
	public var spriteMap = new Map<String, FlxBasic>();

	public function new(?stageName:String, ?runScript:Bool = true)
	{
		super();

		if (stageName != null)
			curStage = stageName;
		
		var stageData = StageData.getStageFile(curStage);
		if (stageData != null)
			this.stageData = stageData;
		else
			trace('Failed to load StageData file "$curStage"');

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

		var file = Paths.getHScriptPath('stages/$curStage');
		if (file != null){
			stageScript = FunkinHScript.fromFile(file, file, additionalVars);

			// define variables lolol
			stageScript.set("stage", this); // for backwards compat lol
			stageScript.set("add", add);
			stageScript.set("remove", remove);
			stageScript.set("insert", insert);
			stageScript.set("this", this);
			stageScript.set("foreground", foreground);

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
			switch (curStage)
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
			
			if (stageScript != null){
				if (stageScript is FunkinLua)
					stageScript.call("onCreate", []);
				else
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
		return 'Stage: "$curStage"';
	}
}

class StageData {
	public static var forceNextDirectory:String = null;

	public static function loadDirectory(SONG:SwagSong) {
		var stage:String = 'stage';

		if (SONG.stage != null)
			stage = SONG.stage;

		var stageFile:StageFile = getStageFile(stage);

		// preventing crashes
		forceNextDirectory = stageFile == null ? '' : stageFile.directory;
	}
	
	public static function getStageFile(stageName:String):Null<StageFile> 
	{
		return Paths.json('stages/$stageName.json', false);
	}

	/** Return all stages that can currently be loaded **/
	public static function getAllStages():Array<String> {
		var m = new Map<String, Bool>();

		for (mod in Paths.getContentOrder()) {
			for (stage in mod.stageList) {
				m.set(stage, true);
			}
		}

		return [for (k in m.keys()) k];
	}
}
