// @author Riconuts

package modchart;

import scripts.FunkinHScript;
import modchart.Modifier;
import math.Vector3;

class HScriptModifier extends Modifier
{
	public var script:FunkinHScript;

	function new(modMgr:ModManager, ?parent:Modifier, script:FunkinHScript) 
	{
		this.script = script;
		script.set("this", this);
		script.set("modMgr", modMgr);
		script.set("parent", parent);
		script.set("getValue", getValue);
		script.set("getPercent", getPercent);
		script.set("getSubmodValue", getSubmodValue);
		script.set("getSubmodPercent", getSubmodPercent);
		script.set("setValue", setValue);
		script.set("setPercent", setPercent);
		script.set("setSubmodValue", setSubmodValue);
		script.set("setSubmodPercent", setSubmodPercent);

        script.executeFunc("onCreate");

		super(modMgr, parent);

        script.executeFunc("onCreatePost");
	}

	public static function fromName(modMgr:ModManager, ?parent:Modifier, scriptName:String):Null<HScriptModifier>
	{
		var fileName:String = 'modifiers/$scriptName.hscript';
		for (file in [#if MODS_ALLOWED Paths.modFolders(fileName), #end Paths.getPreloadPath(fileName)])
		{
			if (!Paths.exists(file)) continue;

			var script = FunkinHScript.fromFile(file, [
				"NOTE_MOD" => NOTE_MOD,
				"MISC_MOD" => MISC_MOD,

				"FIRST" => FIRST,
				"PRE_REVERSE" => PRE_REVERSE,
				"REVERSE" => REVERSE,
				"POST_REVERSE" => POST_REVERSE,
				"DEFAULT" => DEFAULT,
				"LAST" => LAST
			]);
			var modifier = new HScriptModifier(modMgr, parent, script);
			return modifier;
		}

		trace('Modifier script: $scriptName not found!');

		return null;
	}

	//// Fuck this shit. This is where a macro could have helped me, if Haxe and Flixel weren't so fucking retarded.
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
		return script.exists("getName") ? script.executeFunc("getName") : super.getName();

	// shouldnt be overriding getValue/getPercent/etc
	// they're used purely to get the value of a modifier and should not be overwritten

	/* 	override public function getValue(player:Int):Float
		return script.exists("getValue") ? script.executeFunc("getValue", [player]) : super.getValue(player);

	override public function getPercent(player:Int):Float
		return script.exists("getPercent") ? script.executeFunc("getPercent", [player]) : super.getPercent(player);

	override public function setValue(value:Float, player:Int = -1)
		return script.exists("setValue") ? script.executeFunc("setValue", [value, player]) : super.setValue(value, player);

	override public function setPercent(percent:Float, player:Int = -1)
		return script.exists("setPercent") ? script.executeFunc("setValue", [percent, player]) : super.setValue(percent, player);

	override public function getSubmodPercent(modName:String, player:Int)
		return script.exists("getSubmodPercent") ? script.executeFunc("getSubmodPercent", [modName, player]) : super.getSubmodPercent(modName, player);

	override public function getSubmodValue(modName:String, player:Int)
		return script.exists("getSubmodValue") ? script.executeFunc("getSubmodValue", [modName, player]) : super.getSubmodValue(modName, player); */

	override public function getSubmods():Array<String>
		return script.exists("getSubmods") ? script.executeFunc("getSubmods") : super.getSubmods();

	//
	override public function updateReceptor(beat:Float, receptor:StrumNote, player:Int) 
		return script.exists("updateReceptor") ? script.executeFunc("updateReceptor", [beat, receptor, player]) : super.updateReceptor(beat, receptor, player);

	override public function updateNote(beat:Float, note:Note, player:Int)
		return script.exists("updateNote") ? script.executeFunc("updateNote", [beat, note, player]) : super.updateNote(beat, note, player);

	override public function getPos(diff:Float, tDiff:Float, beat:Float, pos:Vector3, data:Int, player:Int, obj:FlxSprite):Vector3 
		return script.exists("getPos") ? script.executeFunc("getPos", [diff, tDiff, beat, pos, data, player, obj]) : super.getPos(diff, tDiff, beat, pos, data, player, obj);

	override public function modifyVert(beat:Float, vert:Vector3, idx:Int, obj:FlxSprite, pos:Vector3, player:Int, data:Int):Vector3 
		return script.exists("modifyVert") ? script.executeFunc("modifyVert", [beat, vert, idx, obj, pos, player, data]) : super.modifyVert(beat, vert, idx, obj, pos, player, data);

	override public function getAlpha(beat:Float, alpha:Float, obj:FlxSprite, player:Int, data:Int):Float 
		return script.exists("getAlpha") ? script.executeFunc("getAlpha", [beat, alpha, obj, player, data]) : super.getAlpha(beat, alpha, obj, player, data);

	override public function update(elapsed:Float) 
		return script.exists("update") ? script.executeFunc("update", [elapsed]) : super.update(elapsed);

	override public function isRenderMod():Bool 
		return script.exists("isRenderMod") ? script.executeFunc("isRenderMod") : super.isRenderMod();
}