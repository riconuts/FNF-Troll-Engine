package funkin.modchart;
// @author Nebula_Zorua


import funkin.objects.playfields.NoteField;
import flixel.math.FlxPoint;
import flixel.FlxSprite;
import math.Vector3;
// Based on Schmovin' and Andromeda's modifier systems

enum ModifierType {
	NOTE_MOD; // used when the mod moves notes
	MISC_MOD; // used for most things else
}

enum abstract ModifierOrder(Int) to Int{
	var FIRST = -1000;
	var PRE_REVERSE = -3;
	var REVERSE = -2;
	var POST_REVERSE = -1;
	var DEFAULT = 0;
	var LAST = 1000;
}

@:structInit
class RenderInfo {
	public var alpha:Float;
	public var glow:Float;
	public var scale:FlxPoint;
}

class Modifier {
	public var modMgr:ModManager;
	@:allow(modchart.ModManager)
	var target_percents:Array<Float> = [0, 0];
	public var percents:Array<Float> = [0, 0];

	public var submods:Map<String, Modifier> = [];
	public var parent:Modifier; // for submods

	public function affectsField()
		return false;
	
	public function getModType()
		return MISC_MOD; // if this is NOTE_MOD then this will be called on notes & receptors
	
	public function ignorePos()
		return false;

	public function ignoreUpdateReceptor()
		return true;

	public function ignoreUpdateNote()
		return true;

	public function doesUpdate()
		return getModType()==MISC_MOD; // override in your modifier if you want it to have update(elapsed, beat) called
	
	public function shouldExecute(player:Int, value:Float):Bool
	{
		return value != 0; // override if your modifier should run, even if percent isn't 0
	}

	public function getOrder():Int
		return DEFAULT;

	public function getName():String{
		throw new haxe.exceptions.NotImplementedException(); // override in your modifier!!! 
		return '';
	}

	inline public function getValue(player:Int):Float
		return percents[player];

	inline public function setCurrentValue(value:Float, player:Int = -1) // only set for like a frame
	{
		if (player == -1)
			for (idx in 0...percents.length){
				modMgr.touchMod(getName(), idx);
				percents[idx] = value;
			}
		else{
			modMgr.touchMod(getName(), player);
			percents[player] = value;
		}
		
	}

	inline public function getTargetValue(player:Int):Float // because most the time when you getValue you wanna get the CURRENT value, not the target
		return target_percents[player];

	inline public function getTargetPercent(player:Int):Float
		return getTargetValue(player) * 100;

	inline public function getPercent(player:Int):Float
		return getValue(player) * 100;
	
	inline public function setValue(value:Float, player:Int = -1) // because most the time when you setValue you wanna set the TARGET value, not the current
	{
		setCurrentValue(value, player);
		if (player == -1)
			for (idx in 0...target_percents.length)
				target_percents[idx] = value;
		else
			target_percents[player] = value;
		
	}

	inline public function setCurrentPercent(percent:Float, player:Int = -1)
		setCurrentValue(percent * 0.01, player);

	inline public function setPercent(percent:Float, player:Int = -1)
		setValue(percent * 0.01, player);
	

	public function getSubmods():Array<String>
		return [];

	public inline function addSubmod(name:String)
		submods.set(name, new SubModifier(name, modMgr, this));	

	inline public function getSubmodPercent(modName:String, player:Int)
	{
		if (submods.exists(modName))
			return submods.get(modName).getPercent(player);
		else
			return 0;
	}

	inline public function getSubmodValue(modName:String, player:Int)
	{
		if (submods.exists(modName))
			return submods.get(modName).getValue(player);
		else
			return 0;
	}

	inline public function getTargetSubmodPercent(modName:String, player:Int)
	{
		if (submods.exists(modName))
			return submods.get(modName).getTargetPercent(player);
		else
			return 0;
	}

	inline public function getTargetSubmodValue(modName:String, player:Int)
	{
		if (submods.exists(modName))
			return submods.get(modName).getTargetValue(player);
		else
			return 0;
	}

	inline public function setCurrentSubmodPercent(modName:String, endPercent:Float, player:Int)
		return submods.get(modName).setCurrentPercent(endPercent, player);

	inline public function setCurrentSubmodValue(modName:String, endValue:Float, player:Int)
		return submods.get(modName).setCurrentValue(endValue, player);

	inline public function getTargetOtherPercent(modName:String, player:Int)
		return modMgr.getTargetPercent(modName, player);

	inline public function getTargetOtherValue(modName:String, player:Int)
		return modMgr.getTargetValue(modName, player);

	inline public function setCurrentOtherPercent(modName:String, endPercent:Float, player:Int)
		return modMgr.setCurrentPercent(modName, endPercent, player);

	inline public function setCurrentOtherValue(modName:String, endValue:Float, player:Int)
		return modMgr.setCurrentValue(modName, endValue, player);
	

	inline public function setSubmodPercent(modName:String, endPercent:Float, player:Int)
		return submods.get(modName).setPercent(endPercent, player);

	inline public function setSubmodValue(modName:String, endValue:Float, player:Int)
		return submods.get(modName).setValue(endValue, player);

	inline public function getOtherPercent(modName:String, player:Int)
		return modMgr.getPercent(modName, player);
	
	public function getOtherValue(modName:String, player:Int)
		return modMgr.getValue(modName, player);
	
	inline public function setOtherPercent(modName:String, endPercent:Float, player:Int)
		return modMgr.setPercent(modName, endPercent, player);

	inline public function setOtherValue(modName:String, endValue:Float, player:Int)
		return modMgr.setValue(modName, endValue, player);
	
	public function getDefaultValues():Null<Map<String, Float>>{
		return null;
	}

	public function new(modMgr:ModManager, ?parent:Modifier)
	{
		this.modMgr = modMgr;
		this.parent = parent;
		for (submod in getSubmods())
			addSubmod(submod);
	}

	@:allow(funkin.modchart.ModManager)
	private function _internalUpdate(){
		for(pN in 0...target_percents.length){
			percents[pN] = target_percents[pN];
		}

		//for(mod in submods)mod._internalUpdate();
		
	}

	// Available whenever shouldUpdate() == true
	public function update(elapsed:Float, beat:Float){}

	// used when affectsField() == true and getModType() == MISC_MOD
	public function getFieldZoom(zoom:Float, beat:Float, songPos:Float, player:Int, field:NoteField) {
		return zoom;
	}

	// Note-based overrides (only use if getModType() == NOTE_MOD)
	// time is the note/receptor strumtime
	// diff is the 'visual difference' aka the strumTime - currentTime w/ math for scrollspeed, etc
	// beat is the curBeat, but with decimals
	// pos is the current position of the note/receptor
	// player is 0 for bf, 1 for dad
	// column is the direction/notedata
	// note/receptor is self-explanatory
	public function updateReceptor(beat:Float, receptor:StrumNote, player:Int){}
	public function updateNote(beat:Float, note:Note, player:Int){}
	public function getPos(diff:Float, tDiff:Float, beat:Float, pos:Vector3, column:Int, player:Int, obj:NoteObject, field:NoteField):Vector3{return pos;}
	public function modifyVert(beat:Float, vert:Vector3, idx:Int, obj:NoteObject, pos:Vector3, player:Int, column:Int, field:NoteField):Vector3{return vert;}
	public function getExtraInfo(diff:Float, tDiff:Float, beat:Float, info:RenderInfo, obj:NoteObject, player:Int, column:Int):RenderInfo{return info;}
	public function isRenderMod():Bool{return false;} // Override and return true if your modifier uses modifyVert or getExtraInfo
	public function getAliases():Map<String,String>{return [];}
}