// @author Nebula_Zorua

package modchart;
import flixel.tweens.FlxEase.EaseFunction;
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
// NEW: Now also has some features of mirin (aliases, nodes)


/**
 * So, what is a Node?
 * A Node can be used to extend or otherwise modify modifiers
 * (for example you can have a screen bounce aux mod + node w/ that aux mod as an input, and then change transformX)
 */
typedef Node = {
	var lastSeen:Int; // to make sure it doesnt get hit multiple times per update
    var in_mods:Array<String>; /// the modifiers that get input into this node
    var out_mods:Array<String>; // the modifiers that get transformed by this node
	var nodeFunc:(Array<Float>, Int)->Dynamic; // takes an array of the input mods' values, and returns an array of transformed modifier values, if out_mods.length > 0
}

class ModManager {
	public function new(state:PlayState) {
        this.state=state;
    }

	public function registerAux(name:String)
		return quickRegister(new SubModifier(name, this));
    
	public function registerDefaultModifiers()
	{
		var quickRegs:Array<Any> = [
			ReverseModifier,
			SwapModifier,
			DrunkModifier,
			BeatModifier,
			AlphaModifier,
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

		registerAux("noteSpawnTime");
		registerAux("drawDistance");
		registerAux("disableDrawDistMult");
		registerAux("flashR");
		registerAux("flashG");
		registerAux("flashB");
		registerAux("xmod");
		registerAux("cmod");
		registerAux("movePastReceptors");
		for (i in 0...4){
			registerAux("xmod" + i);
			registerAux("cmod" + i);
			registerAux("noteSpawnTime" + i);
		}

		for (playerNumber => mods in activeMods)
			setDefaultValues(playerNumber);
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
		setValue("cmod", -1, mN);
		setValue("scale", 1, mN);
		setValue("scaleX", 1, mN);
		setValue("scaleY", 1, mN);
		for (i in 0...4){
			setValue('cmod$i', -1, mN);
			setValue('xmod$i', 1, mN);
			setValue('scale${i}', 1, mN);
			setValue('scale${i}X', 1, mN);
			setValue('scale${i}Y', 1, mN);
		}
		setValue("movePastReceptors", 0); // effects shouldnt go on
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
    public var tempActiveMods:Array<Array<String>> = [[], []];
	public var lastActiveMods:Array<Array<String>> = [[], []]; // by player
    public var aliases:Map<String, String> = [];
    var nodeSeen:Int = 0;

    public var nodes:Map<String, Array<Node>> = []; // maps nodes by their inputs
    public var nodeArray:Array<Node> = [];

    inline public function quickRegister(mod:Modifier)
        registerMod(mod.getName(), mod);

    public function registerAlias(alias:String, mod:String)
		aliases.set(alias, mod);

    public function registerNode(node:Node){
        var inputs = node.in_mods;
		for(inp in inputs){
            if(!nodes.exists(inp))
                nodes.set(inp, []);
            
            nodes.get(inp).push(node);
        }
		nodeArray.push(node);
    }

	public function quickNode(inputs:Array<String>, nodeFunc:(Array<Dynamic>, Int) -> Dynamic, ?outputs:Array<String>){
		if (outputs == null)
			outputs=[];
		registerNode({
			lastSeen: -1,
			in_mods: inputs,
			out_mods: outputs,
			nodeFunc: nodeFunc
		});
    }

    public function getActualModName(m:String)
		return aliases.exists(m) ? aliases.get(m) : m;

    public function registerMod(modName:String, mod:Modifier, ?registerSubmods = true){
        register.set(modName, mod);
		switch (mod.getModType()){
			case NOTE_MOD:
				notemodRegister.set(modName, mod);
			case MISC_MOD:
				miscmodRegister.set(modName, mod);
		}

		timeline.addMod(modName);
		modArray.push(mod);
        
        for(a => m in mod.getAliases())
            registerAlias(a, m);
        

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

	public function addHScriptModifier(modName:String, ?defaultVal:Float = 0):Null<HScriptModifier>
	{	
		var modifier = HScriptModifier.fromName(this, null, modName);
		if (modifier == null) return null;
	
		quickRegister(modifier);
		setValue(modifier.getName(), defaultVal==null ? 0 : defaultVal);
		
		return modifier;
	}

    inline public function get(modName:String)
		return register.get(getActualModName(modName));
    
	inline public function getPercent(modName:String, player:Int)
		return !register.exists(getActualModName(modName))?0:get(modName).getPercent(player);

	inline public function getValue(modName:String, player:Int)
		return !register.exists(getActualModName(modName))?0:get(modName).getValue(player);

    inline public function setPercent(modName:String, val:Float, player:Int=-1)
		setValue(modName, val/100, player);

	public function getCMod(data:Int, player:Int, ?defaultSpeed:Float){
		var daSpeed = getValue('cmod${data}', player);
		if (daSpeed < 0){
			daSpeed = getValue('cmod', player);

			if (daSpeed < 0){
				if (defaultSpeed == null)
					return PlayState.instance.songSpeed;
				else
					return defaultSpeed;
			}
		}

		return daSpeed;
	}

	public function getXMod(data:Int, player:Int)
		return getValue("xmod", player) * getValue('xmod${data}', player);

	inline public function getSpeed(dir:Int, player:Int, ?songSpeed:Float)
		return getCMod(dir, player, songSpeed) * getXMod(dir, player);
	
	inline public function getNoteSpeed(note:Note, pN:Int, ?songSpeed:Float)
		return getCMod(note.noteData, pN, songSpeed) * note.multSpeed * getXMod(note.noteData, pN);
	

	public function getActiveMods(pN:Int){
		if(activeMods[pN]==null){
			activeMods[pN] = [];
			setDefaultValues(pN);
		}
/* 
		if (tempActiveMods[pN] == null)
			tempActiveMods[pN] = [];


        if(tempActiveMods[pN].length > 0){
			return activeMods[pN].concat(tempActiveMods[pN]);
        }else */
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
			var daMod = get(modName);
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

			get(modName).setValue(val, player);
			
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
						aMods.sort((a, b) -> Std.int(get(a).getOrder() - get(b).getOrder()));
						return;
					}
					for (subname => submod in modParent.submods){
						if(submod.shouldExecute(player, submod.getValue(player))){
							aMods.sort((a, b) -> Std.int(get(a).getOrder() - get(b).getOrder()));
							return;
						}
					}
					aMods.remove(modParent.getName());
				}else
					aMods.remove(daMod.getName());
			}

			aMods.sort((a, b) -> Std.int(get(a).getOrder() - get(b).getOrder()));
		}
    }

	public function update(elapsed:Float)
	{
		//tempActiveMods = [[], []];
		if (FlxG.state == PlayState.instance){
			for (mod in modArray)
			{
                //mod._internalUpdate();
				if (mod.doesUpdate())
					mod.update(elapsed, PlayState.instance.curDecBeat);
			}
		}else{
			for (mod in modArray)
			{
                //mod._internalUpdate();
				if (mod.doesUpdate())
					mod.update(elapsed, 0);
			}
		}
        
		/*for (node in nodeArray){
			if (node.out_mods.length > 0)
			{
                for(out in node.out_mods){
                    for(pN in 0...activeMods.length){
						if (tempActiveMods[pN] == null)
							tempActiveMods[pN] = [];

                        if (!tempActiveMods[pN].contains(out))
                            tempActiveMods[pN].push(out);
						if (!lastActiveMods[pN].contains(out))
							lastActiveMods[pN].push(out);
                    }
                }
            }
        }

        // honestly i can probably optimize this some day but for now its fine

        if(nodeArray.length > 0){
            for (pN => mods in lastActiveMods){ // dont use activeMods just incase the value has just rolled over to 0 so the node will have to be disabled
                // alternatively i add a seperate array for activeNodes so nodes can get a final call in b4 being disabled + still have up-to-date active mod data
                // honestly probably the best idea i'll do that tmrw
				
                var touched:Array<String> = [];
                nodeSeen++;
                var values:Map<String, Float> = []; // to prevent calling getValue over and over
                
                for(mod in mods){
                    if(nodes.exists(mod)){
                        for(node in nodes.get(mod)){
                            if (node.lastSeen != nodeSeen){
                                node.lastSeen = nodeSeen; // to prevent the node from being called over and over in the same frame by having multiple inputs

                                // collect up all the input values from the in_mods array
                                var inputValues:Array<Float> = []; 
                                for(in_mod in node.in_mods){
                                    if(!values.exists(in_mod))
                                        values.set(in_mod, getValue(in_mod, pN));

                                    inputValues.push(values.get(in_mod));
                                }
                                var returnValue:Dynamic = node.nodeFunc(inputValues, pN);
                                if(node.out_mods.length > 0){ // if this has outputs then output them
                                    if((returnValue is Array)){
                                        var values:Array<Float> = cast returnValue;
                                        for (idx in 0...values.length){ // goes over all the values
                                            // better have only floats in here if you dont then THATS NOT MY FAULT IF IT CRASHES!!
                                            var value:Float = values[idx];
                                            var output:String = node.out_mods[idx];
                                            var oM = get(output);
											var perc:Null<Float> = cast oM._percents[pN];
											if (node.in_mods.contains(output) || perc == null) // if the output is also an input then set it directly, otherwise add it
                                                oM._percents[pN] = value;
                                            else
                                                oM._percents[pN] += value;

											if (oM.shouldExecute(pN, oM._percents[pN]) && !touched.contains(output))
                                                touched.push(output);

                                            // honestly i should make it so anything that is outputted gets added to tempactivemods BEFORE doing any node stuff
                                            // and then remove them if they didnt change after doing nodes
                                            // so then nodes that get outputted by another node are set active
                                            
                                            
                                        }
                                    }
                                }
                            }
                            
                        }
                    }
                }

                var toRemove:Array<String> = [];
                for(shit in tempActiveMods[pN]){
                    if (!touched.contains(shit))
                        toRemove.push(shit);
                }
                for(shit in toRemove)
                    tempActiveMods[pN].remove(shit);
            }
        } */
	}

    public function updateTimeline(curStep:Float){
		lastActiveMods = activeMods.copy();
		timeline.update(curStep);
    }

 	public var playerAmount:Int = 2;
	public var playerOOBIsCentered:Bool = true; // Player Out of Bounds is centered

	public function getBaseX(direction:Int, player:Float, receptorAmount:Int = 4):Float
	{
		if (playerOOBIsCentered && (player >= playerAmount || player < 0))
			player = 0.5; // replicating old behaviour for upcoming modcharts
		
		var spaceWidth = FlxG.width / playerAmount;
		var spaceX = spaceWidth * (playerAmount-1-player);

		var baseX:Float = spaceX + (spaceWidth - Note.swagWidth * receptorAmount) * 0.5;
		var x:Float = baseX + Note.swagWidth * direction;

		return x;
	}

	public function updateObject(beat:Float, obj:FlxSprite, player:Int){
		if (obj.active)
		for (name in getActiveMods(player))
		{
			/*if (!obj.active)
				continue;*/

			var mod:Modifier = notemodRegister.get(name);
			if (mod==null) continue;
			
			if(obj is Note){
				if (mod.ignoreUpdateNote()) continue;
				mod.updateNote(beat, cast obj, player);
			}
			else if(obj is StrumNote){
				if (mod.ignoreUpdateReceptor()) continue;
				mod.updateReceptor(beat, cast obj, player);
			}
		}
		
		if (obj is Note){
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
		if (!obj.alive) 
			return pos;

		if (exclusions == null) 
			exclusions = []; // since [] cant be a default value for.. some reason?? "its not constant!!" kys haxe
		
		if (pos == null)
			pos = new Vector3();
		
		pos.setTo(
			(Note.swagWidth / 2) + getBaseX(data, player, field.field.keyCount),
			(Note.swagWidth / 2) + 50 + diff,
			0
		);

 		for (name in getActiveMods(player)){
			/*if (!obj.alive) 
				continue;*/
			
			if (exclusions.contains(name)) 
				continue; // because some modifiers may want the path without reverse, for example. (which is actually more common than you'd think!)
			
			var mod:Modifier = notemodRegister.get(name);
			if (mod != null && !mod.ignorePos())
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
			if (exclusions.contains(name)) 
				continue;

			var mod:Modifier = miscmodRegister.get(name);
			if (mod != null && mod.affectsField()) 
				zoom = mod.getFieldZoom(zoom, beat, songPos, player, field);
		}

		return zoom;
	}

	public function modifyVertex(beat:Float, vert:Vector3, idx:Int, obj:FlxSprite, pos:Vector3, player:Int, data:Int, field:NoteField, ?exclusions:Array<String>):Vector3
	{
		if (!obj.active) 
			return vert;

		if (exclusions == null) 
			exclusions = [];

		for (name in getActiveMods(player))
		{
			/*if (!obj.active) 
				return vert;*/

			if (exclusions.contains(name))
				continue;

			var mod:Modifier = notemodRegister.get(name);
			if (mod != null && mod.isRenderMod())
				vert = mod.modifyVert(beat, vert, idx, obj, pos, player, data, field);
		}
		return vert;
	}

	public function getExtraInfo(diff:Float, tDiff:Float, beat:Float, ?info:RenderInfo, obj:FlxSprite, player:Int, data:Int, ?exclusions:Array<String>):RenderInfo
	{
		if (!obj.active)
			return info;

		if (exclusions == null)
			exclusions = [];

		if (info == null){
			info = {
				alpha: 1,
				glow: 0,
				scale: FlxPoint.weak(0.7, 0.7)
			};
		}

		for (name in getActiveMods(player))
		{
			/*if (!obj.active)
				return info;*/

			if (exclusions.contains(name))
				continue;

			var mod:Modifier = notemodRegister.get(name);
			if (mod != null && mod.isRenderMod())
				info = mod.getExtraInfo(diff, tDiff, beat, info, obj, player, data);
		}

		return info;
	}

	public function queueEase(step:Float, endStep:Float, modName:String, target:Float, style:Any, player:Int = -1, ?startVal:Float)
	{
		/*
		if (startVal != null)
			queueSet(step, modName, startVal, player);
		*/

		var easeFunc:EaseFunction = FlxEase.linear;

		if (style == null){
		
		}else if (style is String){
			// most common use of the style var is to just use an existing FlxEase
			easeFunc = CoolUtil.getEaseFromString(style);

		}else if (Reflect.isFunction(style)){
			// probably gonna be useful SOMEWHERE
			// maybe custom eases?
			easeFunc = style;
		}

		if (player == -1)
			for (pN => mods in activeMods)
				timeline.addEvent(new ModEaseEvent(step, endStep, modName, target, easeFunc, pN, this));				
		else
			timeline.addEvent(new ModEaseEvent(step, endStep, modName, target, easeFunc, player, this));
	}

	public function queueSet(step:Float, modName:String, target:Float, player:Int = -1)
	{
		if (player == -1)
			for (pN => mods in activeMods)
				timeline.addEvent(new SetEvent(step, modName, target, pN, this));
		else
			timeline.addEvent(new SetEvent(step, modName, target, player, this));
		
	}

	public function queueEaseP(step:Float, endStep:Float, modName:String, percent:Float, style:Dynamic = 'linear', player:Int = -1, ?startVal:Float)
		queueEase(step, endStep, modName, percent * 0.01, style, player, startVal * 0.01);
	
	public function queueSetP(step:Float, modName:String, percent:Float, player:Int = -1)
		queueSet(step, modName, percent * 0.01, player);

	public function queueFunc(step:Float, endStep:Float, callback:(CallbackEvent, Float) -> Void)
		timeline.addEvent(new StepCallbackEvent(step, endStep, callback, this));
    
	public function queueFuncOnce(step:Float, callback:(CallbackEvent, Float) -> Void)
		timeline.addEvent(new CallbackEvent(step, callback, this));
	
	public function queueEaseFunc(step:Float, endStep:Float, func:EaseFunction, callback:(EaseEvent, Float, Float) -> Void)
		timeline.addEvent(new EaseEvent(step, endStep, func, callback, this));

}