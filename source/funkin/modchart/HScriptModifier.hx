package funkin.modchart;
// @author Riconuts


import funkin.objects.playfields.NoteField;
import funkin.scripts.FunkinHScript;
import funkin.modchart.Modifier;
import math.Vector3;

class HScriptModifier extends Modifier
{
	public var script:FunkinHScript;
	public var name:String = "unknown";

	public function new(modMgr:ModManager, ?parent:Modifier, script:FunkinHScript) 
	{
		this.script = script;
		this.modMgr = modMgr;
		this.parent = parent;

		script.set("this", this);
		script.set("modMgr", this.modMgr);
		script.set("parent", this.parent);
		script.set("getValue", getValue);
		script.set("getPercent", getPercent);
		script.set("getSubmodValue", getSubmodValue);
		script.set("getSubmodPercent", getSubmodPercent);
		script.set("setValue", setValue);
		script.set("setPercent", setPercent);
		script.set("setSubmodValue", setSubmodValue);
		script.set("setSubmodPercent", setSubmodPercent);

		script.executeFunc("onCreate");

		super(this.modMgr, this.parent);

		script.executeFunc("onCreatePost");
	}

	@:noCompletion
	private static final _scriptEnums:Map<String, Dynamic> = [
		"NOTE_MOD" => NOTE_MOD,
		"MISC_MOD" => MISC_MOD,

		"FIRST" => FIRST,
		"PRE_REVERSE" => PRE_REVERSE,
		"REVERSE" => REVERSE,
		"POST_REVERSE" => POST_REVERSE,
		"DEFAULT" => DEFAULT,
		"LAST" => LAST
	];

	public static function fromString(modMgr:ModManager, ?parent:Modifier, scriptSource:String):HScriptModifier
	{
		return new HScriptModifier(
			modMgr, 
			parent, 
			FunkinHScript.fromString(scriptSource, "HScriptModifier", _scriptEnums, false)
		);
	}

	public static function fromName(modMgr:ModManager, ?parent:Modifier, scriptName:String):Null<HScriptModifier>
	{		
		var filePath:String = Paths.getHScriptPath('modifiers/$scriptName');
		if(filePath == null){
			trace('Modifier script: $scriptName not found!');
			return null;
		}

		var mod = new HScriptModifier(
			modMgr, 
			parent, 
			FunkinHScript.fromFile(filePath, filePath, _scriptEnums, false)
		);
		mod.name = scriptName;
		return mod;

	}

	//// this is where a macro could have helped me, if i weren't so stupid.
	// lol i'll probably rewrite this to use a macro dont worry bb

	override public function getModType()
		return script.exists("getModType") ? script.executeFunc("getModType") : super.getModType();

	override public function ignorePos()
		return script.exists("ignorePos") ? script.executeFunc("ignorePos") : super.ignorePos();

	override public function ignoreUpdateReceptor()
		return script.exists("ignoreUpdateReceptor") ? script.executeFunc("ignoreUpdateReceptor") : super.ignoreUpdateReceptor();

	override public function ignoreUpdateNote()
		return script.exists("ignoreUpdateNote") ? script.executeFunc("ignoreUpdateNote") : super.ignoreUpdateNote();

	override public function doesUpdate()
		return script.exists("doesUpdate") ? script.executeFunc("doesUpdate") : super.doesUpdate();

	override public function shouldExecute(player:Int, value:Float):Bool
		return script.exists("shouldExecute") ? script.executeFunc("shouldExecute", [player, value]) : super.shouldExecute(player, value);

	override public function getOrder():Int
		return script.exists("getOrder") ? script.executeFunc("getOrder") : super.getOrder();

	override public function getName():String
		return script.exists("getName") ? script.executeFunc("getName") : name;

	override public function getSubmods():Array<String>
		return script.exists("getSubmods") ? script.executeFunc("getSubmods") : super.getSubmods();

	override public function updateReceptor(beat:Float, receptor:StrumNote, player:Int) 
		return script.exists("updateReceptor") ? script.executeFunc("updateReceptor", [beat, receptor, player]) : super.updateReceptor(beat, receptor, player);

	override public function updateNote(beat:Float, note:Note, player:Int)
		return script.exists("updateNote") ? script.executeFunc("updateNote", [beat, note, player]) : super.updateNote(beat, note, player);

	override public function getPos(diff:Float, tDiff:Float, beat:Float, pos:Vector3, data:Int, player:Int, obj:NoteObject, field:NoteField):Vector3 
		return script.exists("getPos") ? script.executeFunc("getPos", [diff, tDiff, beat, pos, data, player, obj, field]) : super.getPos(diff, tDiff, beat, pos, data, player, obj, field);

	override public function modifyVert(beat:Float, vert:Vector3, idx:Int, obj:NoteObject, pos:Vector3, player:Int, data:Int, field:NoteField):Vector3 
		return script.exists("modifyVert") ? script.executeFunc("modifyVert",
			[beat, vert, idx, obj, pos, player, data, field]) : super.modifyVert(beat, vert, idx, obj, pos, player, data, field);

	override public function getExtraInfo(diff:Float, tDiff:Float, beat:Float, info:RenderInfo, obj:NoteObject, player:Int, data:Int):RenderInfo
	{
		return script.exists("getExtraInfo") ? script.executeFunc("getExtraInfo",
			[diff, tDiff, beat, info, obj, player, data]) : super.getExtraInfo(diff, tDiff, beat, info, obj, player, data);
	}

	override public function update(elapsed:Float, beat:Float) 
		return script.exists("update") ? script.executeFunc("update", [elapsed, beat]) : super.update(elapsed, beat);

	override public function isRenderMod():Bool 
		return script.exists("isRenderMod") ? script.executeFunc("isRenderMod") : super.isRenderMod();
}