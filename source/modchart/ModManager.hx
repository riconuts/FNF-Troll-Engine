// @author Nebula_Zorua

package modchart;
import modchart.Modifier.RenderInfo;
import flixel.math.FlxPoint;
import flixel.tweens.FlxEase;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.FlxSprite;
import flixel.FlxG;
import math.Vector3;
import modchart.Modifier.ModifierType;
import modchart.modifiers.*;
import modchart.events.*;
import playfields.NoteField;

// Weird amalgamation of Schmovin' modifier system, Andromeda modifier system and my own new shit -neb
class ModManager {
	public function registerDefaultModifiers()
	{
		var quickRegs:Array<Any> = [
			ReverseModifier,
			SwapModifier,
			DrunkModifier,
			BeatModifier,
			AlphaModifier,
			ReceptorScrollModifier, 
			ScaleModifier, 
			ConfusionModifier, 
			OpponentModifier, 
			TransformModifier, 
			// InfinitePathModifier,  // broken
			PathModifier,
			AccelModifier,
			PerspectiveModifier,
			ZoomModifier
		];
		for (mod in quickRegs)
			quickRegister(Type.createInstance(mod, [this]));

		quickRegister(new RotateModifier(this));
		quickRegister(new RotateModifier(this, 'center', new Vector3(FlxG.width* 0.5, FlxG.height* 0.5)));
		quickRegister(new LocalRotateModifier(this, 'local'));
		quickRegister(new SubModifier("noteSpawnTime", this));
		quickRegister(new SubModifier("drawDistance", this));
		quickRegister(new SubModifier("flashR", this));
		quickRegister(new SubModifier("flashG", this));
		quickRegister(new SubModifier("flashB", this));
		quickRegister(new SubModifier("xmod", this));
		for (i in 0...4){
			quickRegister(new SubModifier("xmod" + i, this));
			quickRegister(new SubModifier("noteSpawnTime" + i, this));
		}

		for (pN => mods in activeMods)
			setDefaultValues(pN);
		

	}

	function setDefaultValues(mN:Int=-1){
		for(modName => mod in register)
			setValue(modName, 0, mN);
		
		for (i in 0...4)
			setValue("noteSpawnTime" + i, 0, mN);
		
		setValue("noteSpawnTime", 1500, mN); // maybe a ClientPrefs.noteSpawnTime
		setValue("drawDistance", FlxG.height * 1.1, mN); // MAY NOT REPRESENT ACTUAL DRAWDISTANCE: drawDistance is modified by the notefields aswell
		// so when you set drawDistance is might be lower or higher than expected because of the draw distance mult. setting
		setValue("xmod", 1, mN);
		for (i in 0...4)
			setValue('xmod$i', 1, mN);

		setValue("flashR", 1, mN);
		setValue("flashG", 1, mN);
		setValue("flashB", 1, mN);
	}


    private var state:PlayState;
	public var receptors:Array<Array<StrumNote>> = []; // for modifiers to be able to access receptors directly if they need to
	public var timeline:EventTimeline = new EventTimeline();

	public var notemodRegister:Map<String, Modifier> = [];
	public var miscmodRegister:Map<String, Modifier> = [];

    public var register:Map<String, Modifier> = [];

    public var modArray:Array<Modifier> = [];

    public var activeMods:Array<Array<String>> = [[], []]; // by player
    
    inline public function quickRegister(mod:Modifier)
        registerMod(mod.getName(), mod);

    public function registerMod(modName:String, mod:Modifier, ?registerSubmods = true){
        register.set(modName, mod);
		//registerByType.get(mod.getModType()).set(modName, mod);
		switch (mod.getModType()){
			case NOTE_MOD:
				notemodRegister.set(modName, mod);
			case MISC_MOD:
				miscmodRegister.set(modName, mod);
		}
		timeline.addMod(modName);
		modArray.push(mod);

		if (registerSubmods){
			for (name in mod.submods.keys())
			{
				var submod = mod.submods.get(name);
				quickRegister(submod);
			}
        }

		setValue(modName, 0); // so if it should execute it gets added Automagically
		modArray.sort((a, b) -> Std.int(a.getOrder() - b.getOrder()));
        // TODO: sort by mod.getOrder()
    }

	public function addHScriptModifier(modName:String, ?defaultVal:Float):Null<HScriptModifier>
	{	
		var modifier = HScriptModifier.fromName(this, null, modName);
		if (modifier == null) return null;
	
		quickRegister(modifier);
		setValue(modifier.getName(), defaultVal==null ? 0 : defaultVal);
		
		return modifier;
	}

    inline public function get(modName:String)
        return register.get(modName);

	inline public function getPercent(modName:String, player:Int)
		return !register.exists(modName)?0:register.get(modName).getPercent(player);

	inline public function getValue(modName:String, player:Int)
		return !register.exists(modName)?0:register.get(modName).getValue(player);

    inline public function setPercent(modName:String, val:Float, player:Int=-1)
		setValue(modName, val/100, player);
    

	public function getActiveMods(pN:Int){
		if(activeMods[pN]==null){
			activeMods[pN] = [];
			setDefaultValues(pN);
		}

		return activeMods[pN];
	}
	public function setValue(modName:String, val:Float, player:Int=-1){
		if (player == -1)
		{
			for (pN => mods in activeMods)
				setValue(modName, val, pN);
		}
		else
		{
			var daMod = register.get(modName);
			if(daMod==null)return;
			var mod = daMod.parent==null?daMod:daMod.parent;
			var name = mod.getName();
            // optimization shit!! :)
            // thanks 4mbr0s3 for giving an alternative way to do all of this cus andromeda has smth similar in Flexy but like
            // this is a better way to do it
            // (ofc its not EXACTLY what 4mbr0s3 did but.. y'know, it's close to it)

			// so this actually has an issue
			// this doesnt take into account any other submods
			// so if you turn a submod off
			// it turns the parent mod off, too, when it shouldnt
			// so what I need to do is like, check other submods before removing the parent
            
			var aMods = getActiveMods(player);

			register.get(modName).setValue(val, player);
			
			if (!aMods.contains(name) && mod.shouldExecute(player, val)){
				if (daMod.getName() != name)
					aMods.push(daMod.getName());
				aMods.push(name);
			}else if (!mod.shouldExecute(player, val)){

				// there is prob a better way to do this
				// i just dont know it
				var modParent = daMod.parent;
				if(modParent==null){
					for (name => mod in daMod.submods)
					{
						modParent = daMod; // because if this gets called at all, there's atleast 1 submod!!
						break;
					}
				}
				if(daMod!=modParent)
					aMods.remove(daMod.getName());
				if (modParent!=null){
					if (modParent.shouldExecute(player, modParent.getValue(player))){
						aMods.sort((a, b) -> Std.int(register.get(a).getOrder() - register.get(b).getOrder()));
						return;
					}
					for (subname => submod in modParent.submods){
						if(submod.shouldExecute(player, submod.getValue(player))){
							aMods.sort((a, b) -> Std.int(register.get(a).getOrder() - register.get(b).getOrder()));
							return;
						}
					}
					aMods.remove(modParent.getName());
				}else
					aMods.remove(daMod.getName());
			}

			aMods.sort((a, b) -> Std.int(register.get(a).getOrder() - register.get(b).getOrder()));
		}
    }

    public function new(state:PlayState) {
        this.state=state;
    }

	public function update(elapsed:Float)
	{
		if (FlxG.state == PlayState.instance){
			for (mod in modArray)
			{
				if (mod.doesUpdate())
					mod.update(elapsed, PlayState.instance.curDecBeat);
			}
		}else{
			for (mod in modArray)
			{
				if (mod.doesUpdate())
					mod.update(elapsed, 0);
			}
		}
	}

    public function updateTimeline(curStep:Float)
		timeline.update(curStep);

 	public var playerAmount:Int = 2;
	public function getBaseX(direction:Int, player:Float, receptorAmount:Int = 4):Float
	{
		if (player > (playerAmount-1) || player < 0)
			player = 0.5; // replicating old behaviour for upcoming modcharts
		
		
		var spaceWidth = FlxG.width / playerAmount;
		var spaceX = spaceWidth * (playerAmount-1-player);

		var baseX:Float = spaceX + (spaceWidth - Note.swagWidth * receptorAmount) * 0.5;
		var x:Float = baseX + Note.swagWidth * direction;

		return x;
	}
/* 	public function getBaseX(direction:Int, player:Int):Float
	{
		var x:Float = (FlxG.width * 0.5) - Note.swagWidth - 54 + Note.swagWidth * direction;
		switch (player)
		{
			case 0:
				x += FlxG.width * 0.5 - Note.swagWidth * 2 - 100;
			case 1:
				x -= FlxG.width * 0.5 - Note.swagWidth * 2 - 100;
		}

		x -= 56;

		return x;
	} */

	public function updateObject(beat:Float, obj:FlxSprite, player:Int){
		for (name in getActiveMods(player))
		{
			var mod:Modifier = notemodRegister.get(name);
			if (mod==null)continue;
			if (!obj.active)
				continue;
            if((obj is Note)){
				if (mod.ignoreUpdateNote()) continue;
				mod.updateNote(beat, cast obj, player);
			}
            else if((obj is StrumNote)){
				if (mod.ignoreUpdateReceptor()) continue;
				mod.updateReceptor(beat, cast obj, player);
			}
        }
		
		if ((obj is Note)){
			obj.updateHitbox();

			var cum:Note = cast obj;
			if(!cum.isSustainNote){
				obj.centerOrigin();
				obj.centerOffsets();
			}
			cum.offset.x += cum.typeOffsetX;
			cum.offset.y += cum.typeOffsetY;
		}else{
			obj.centerOrigin();
			obj.centerOffsets();
		}
    }

	public inline function getBaseVisPosD(diff:Float, songSpeed:Float = 1)
	{
		return (0.45 * (diff) * songSpeed);
	}

	public function getPos(diff:Float, tDiff:Float, beat:Float, data:Int, player:Int, obj:FlxSprite, field:NoteField, ?exclusions:Array<String>, ?pos:Vector3):Vector3
	{
		if(exclusions==null)exclusions=[]; // since [] cant be a default value for.. some reason?? "its not constant!!" kys haxe
		if (pos == null)
			pos = new Vector3();
		else{
			pos.x = 0;
			pos.y = 0;
			pos.z = 0;
		}

		if (!obj.alive)return pos;

		pos.x = (Note.swagWidth / 2) + getBaseX(data, player, field.field.keyCount);
		pos.y = (Note.swagWidth / 2) + 50 + diff;
		pos.z = 0;


 		for (name in getActiveMods(player)){
			if (exclusions.contains(name))continue; // because some modifiers may want the path without reverse, for example. (which is actually more common than you'd think!)
			var mod:Modifier = notemodRegister.get(name);
			if (mod==null)continue;
			if (!obj.alive)continue;
			if (mod.ignorePos())continue;
			pos = mod.getPos(diff, tDiff, beat, pos, data, player, obj, field);
        } 

		return pos;
    }

	public function getFieldZoom(zoom:Float, beat:Float, songPos:Float, player:Int, field:NoteField, ?exclusions:Array<String>):Float
	{
		if (exclusions == null)
			exclusions = [];

		for (name in getActiveMods(player))
		{
			if (exclusions.contains(name))continue;
			var mod:Modifier = miscmodRegister.get(name);
			if (mod == null)continue;
			if (mod.affectsField())zoom = mod.getFieldZoom(zoom, beat, songPos, player, field);
		}

		return zoom;
	}

	public function modifyVertex(beat:Float, vert:Vector3, idx:Int, obj:FlxSprite, pos:Vector3, player:Int, data:Int, ?exclusions:Array<String>):Vector3
	{
		if (exclusions == null)
			exclusions = [];

		if(!obj.active)return vert;

		for (name in getActiveMods(player)){
			if(exclusions.contains(name))continue;
			var mod:Modifier = notemodRegister.get(name);
			if(mod==null) continue;
			if (!obj.active) return vert;
			if (mod.isRenderMod())
				vert = mod.modifyVert(beat, vert, idx, obj, pos, player, data);
		}
		return vert;
	}

	public function getExtraInfo(diff:Float, tDiff:Float, beat:Float, ?info:RenderInfo, obj:FlxSprite, player:Int, data:Int, ?exclusions:Array<String>):RenderInfo
	{
		if (exclusions == null)
			exclusions = [];

		if (info == null){
			info = {
				alpha: 1,
				glow: 0,
				scale: FlxPoint.weak(0.7, 0.7)
			};
		}

		if (!obj.active)
			return info;

		for (name in getActiveMods(player))
		{
			if (exclusions.contains(name))
				continue;
			var mod:Modifier = notemodRegister.get(name);
			if (mod == null)
				continue;
			if (!obj.active)
				return info;
			if (mod.isRenderMod())
				info = mod.getExtraInfo(diff, tDiff, beat, info, obj, player, data);
		}

		return info;
	}

	public function queueEaseP(step:Float, endStep:Float, modName:String, percent:Float, style:String = 'linear', player:Int = -1, ?startVal:Float)
		queueEase(step, endStep, modName, percent * 0.01, style, player, startVal * 0.01);
	
	public function queueSetP(step:Float, modName:String, percent:Float, player:Int = -1)
		queueSet(step, modName, percent * 0.01, player);
	
	

	public function queueEase(step:Float, endStep:Float, modName:String, target:Float, style:String = 'linear', player:Int = -1, ?startVal:Float)
	{
		if(player==-1){
			for (pN => mods in activeMods)
				queueEase(step, endStep, modName, target, style, pN);
		}else{
			var easeFunc = FlxEase.linear;

			try
			{
				var newEase = Reflect.getProperty(FlxEase, style);
				if (newEase != null)
					easeFunc = newEase;
			}
			

			timeline.addEvent(new ModEaseEvent(step, endStep, modName, target, easeFunc, player, this));

		}
	}

	public function queueSet(step:Float, modName:String, target:Float, player:Int = -1)
	{
		if (player == -1)
		{
			for (pN => mods in activeMods)
				queueSet(step, modName, target, pN);
		}
		else
			timeline.addEvent(new SetEvent(step, modName, target, player, this));
		
	}

	public function queueFunc(step:Float, endStep:Float, callback:(CallbackEvent, Float) -> Void)
	{
		timeline.addEvent(new StepCallbackEvent(step, endStep, callback, this));
	}
    
	public function queueFuncOnce(step:Float, callback:(CallbackEvent, Float) -> Void)
		timeline.addEvent(new CallbackEvent(step, callback, this));
	
	public function queueEaseFunc(step:Float, endStep:Float, func:EaseFunction, callback:(EaseEvent, Float, Float) -> Void)
		timeline.addEvent(new EaseEvent(step, endStep, func, callback, this));

}