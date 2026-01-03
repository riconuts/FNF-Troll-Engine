package funkin.scripts;

import flixel.tweens.FlxTween;
import flixel.system.FlxAssets.FlxGraphicAsset;
import flixel.util.FlxColor;
import funkin.scripts.Globals.*;
import funkin.states.PlayState;
import funkin.states.GameOverSubstate;
import Type.ValueType;

import openfl.display.BlendMode;
import flixel.*;
import flixel.text.FlxText;
import flixel.math.FlxMath;
import flixel.group.FlxGroup;
import flixel.tweens.FlxEase;
#if USING_FLXANIMATE
import animate.FlxAnimate;
import animate.FlxAnimateFrames;
#end

using SpriteTools;
using StringTools;

class Util
{
	public static function getProperty(variable:String) {
		var killMe:Array<String> = variable.split('.');
		if (killMe.length > 1)
			return getVarInArray(getPropertyLoopThingWhatever(killMe), killMe[killMe.length-1]);
		else
			return getVarInArray(getInstance(), variable);
	}
	public static function setProperty(variable:String, value:Dynamic) {
		var killMe:Array<String> = variable.split('.');
		if (killMe.length > 1)
			setVarInArray(getPropertyLoopThingWhatever(killMe), killMe[killMe.length-1], value);
		else
			setVarInArray(getInstance(), variable, value);
	}

	public static function getPropertyFromGroup(obj:String, index:Int, variable:Dynamic) {
		var shitMyPants:Array<String> = obj.split('.');
		var realObject:Dynamic = Reflect.getProperty(getInstance(), obj);
		if(shitMyPants.length>1)
			realObject = getPropertyLoopThingWhatever(shitMyPants, false);

		if(Std.isOfType(realObject, FlxTypedGroup))
			return getGroupStuff(realObject.members[index], variable);

		var leArray:Dynamic = realObject[index];
		if (leArray != null) {
			if(Type.typeof(variable) == ValueType.TInt) {
				return leArray[variable];
			}
			return getGroupStuff(leArray, variable);
		}
		trace("Object #" + index + " from group: " + obj + " doesn't exist!");
		return null;
	}
	public static function setPropertyFromGroup(obj:String, index:Int, variable:Dynamic, value:Dynamic) {
		var shitMyPants:Array<String> = obj.split('.');
		var realObject:Dynamic = Reflect.getProperty(getInstance(), obj);
		if(shitMyPants.length>1)
			realObject = getPropertyLoopThingWhatever(shitMyPants, false);

		if(Std.isOfType(realObject, FlxTypedGroup)) {
			setGroupStuff(realObject.members[index], variable, value);
			return;
		}

		var leArray:Dynamic = realObject[index];
		if(leArray != null) {
			if(Type.typeof(variable) == ValueType.TInt) {
				leArray[variable] = value;
				return;
			}
			setGroupStuff(leArray, variable, value);
		}
	}
	public static function removeFromGroup(obj:String, index:Int, dontDestroy:Bool = false) {
		var instance = getInstance();

		if(Std.isOfType(Reflect.getProperty(instance, obj), FlxTypedGroup)) {
			var sex = Reflect.getProperty(instance, obj).members[index];
			if(!dontDestroy)
				sex.kill();
			Reflect.getProperty(instance, obj).remove(sex, true);
			if(!dontDestroy)
				sex.destroy();
			return;
		}
		Reflect.getProperty(instance, obj).remove(Reflect.getProperty(instance, obj)[index]);
	}

	public static function getPropertyFromClass(classVar:String, variable:String) {
		var killMe:Array<String> = variable.split('.');
		if(killMe.length > 1) {
			var coverMeInPiss:Dynamic = getVarInArray(Type.resolveClass(classVar), killMe[0]);
			for (i in 1...killMe.length-1) {
				coverMeInPiss = getVarInArray(coverMeInPiss, killMe[i]);
			}
			return getVarInArray(coverMeInPiss, killMe[killMe.length-1]);
		}
		return getVarInArray(Type.resolveClass(classVar), variable);
	}
	public static function setPropertyFromClass(classVar:String, variable:String, value:Dynamic) {
		var killMe:Array<String> = variable.split('.');
		if(killMe.length > 1) {
			var coverMeInPiss:Dynamic = getVarInArray(Type.resolveClass(classVar), killMe[0]);
			for (i in 1...killMe.length-1) {
				coverMeInPiss = getVarInArray(coverMeInPiss, killMe[i]);
			}
			setVarInArray(coverMeInPiss, killMe[killMe.length-1], value);
			return true;
		}
		setVarInArray(Type.resolveClass(classVar), variable, value);
		return true;
	}

	public static function getPropertyLoopThingWhatever(killMe:Array<String>, getProperty:Bool = true):Dynamic {
		var coverMeInPiss:Dynamic = getObjectDirectly(killMe[0]);
		for (i in 1...(getProperty ? killMe.length-1 : killMe.length))
			coverMeInPiss = getVarInArray(coverMeInPiss, killMe[i]);

		return coverMeInPiss;
	}

	inline public static function getObjectDirectly(tag:String):Null<Dynamic>
		return getVarInArray(getInstance(), tag);

	public static function getObjectSimple(tag:String):Null<Dynamic>
		return Reflect.getProperty(getInstance(), tag);

	public static function getObject(tag:String):Null<Dynamic> {
		var killMe:Array<String> = tag.split('.');
		if (killMe.length > 1)
			return getVarInArray(getPropertyLoopThingWhatever(killMe), killMe[killMe.length-1]);
		else
			return getObjectSimple(killMe[0]);
	}

	public static function setVarInArray(instance:Dynamic, variable:String, value:Dynamic):Any
	{
		var shit:Array<String> = variable.split('[');
		if (shit.length > 1) {
			var blah:Dynamic = Reflect.getProperty(instance, shit[0]);
			for (i in 1...shit.length) {
				var leNum:Dynamic = shit[i].substr(0, shit[i].length - 1);
				if (i >= shit.length-1) //Last array
					blah[leNum] = value;
				else //Anything else
					blah = blah[leNum];
			}
			return blah;
		}

		if (isMap(instance))
			instance.set(variable, value);
		else
			Reflect.setProperty(instance, variable, value);

		return true;
	}
	public static function getVarInArray(instance:Dynamic, variable:String):Any
	{
		var shit:Array<String> = variable.split('[');
		if (shit.length > 1) {
			var blah:Dynamic = Reflect.getProperty(instance, shit[0]);
			for (i in 1...shit.length) {
				var leNum:Dynamic = shit[i].substr(0, shit[i].length - 1);
				blah = blah[leNum];
			}
			return blah;
		}
		
		if (isMap(instance))
			return instance.get(variable);
		else
			return Reflect.getProperty(instance, variable);
	}

	public static function getGroupStuff(leArray:Dynamic, variable:String) {
		var killMe:Array<String> = variable.split('.');
		if(killMe.length > 1) {
			var coverMeInPiss:Dynamic = Reflect.getProperty(leArray, killMe[0]);
			for (i in 1...killMe.length-1) {
				coverMeInPiss = Reflect.getProperty(coverMeInPiss, killMe[i]);
			}
			if (isMap(coverMeInPiss))
				return coverMeInPiss.get(killMe[killMe.length-1]);
			else
				return Reflect.getProperty(coverMeInPiss, killMe[killMe.length-1]);
		}

		if (isMap(leArray))
			return leArray.get(variable);
		else
			return Reflect.getProperty(leArray, variable);
	}
	public static function setGroupStuff(leArray:Dynamic, variable:String, value:Dynamic) {
		var killMe:Array<String> = variable.split('.');
		if(killMe.length > 1) {
			var coverMeInPiss:Dynamic = Reflect.getProperty(leArray, killMe[0]);
			for (i in 1...killMe.length-1) {
				coverMeInPiss = Reflect.getProperty(coverMeInPiss, killMe[i]);
			}
			Reflect.setProperty(coverMeInPiss, killMe[killMe.length-1], value);
			return;
		}
		Reflect.setProperty(leArray, variable, value);
	}

	public static function cancelTween(tag:String) {
		if (PlayState.instance.modchartTweens.exists(tag)) {
			var twn = PlayState.instance.modchartTweens.get(tag);
			twn.cancel();
			twn.destroy();
			PlayState.instance.modchartTweens.remove(tag);
		}
	}

	public static function cancelTimer(tag:String) {
		if (PlayState.instance.modchartTimers.exists(tag)) {
			var tmr = PlayState.instance.modchartTimers.get(tag);
			tmr.cancel();
			tmr.destroy();
			PlayState.instance.modchartTimers.remove(tag);
		}
	}

	public static function isOfTypes(value:Any, types:Array<Dynamic>):Bool {
		for (type in types) {
			if (Std.isOfType(value, type))
				return true;
		}
		return false;
	}

	inline public static function isMap(obj:Dynamic) {
		return switch(Type.typeof(obj)) {
			case ValueType.TClass(haxe.ds.StringMap) | ValueType.TClass(haxe.ds.ObjectMap) | ValueType.TClass(haxe.ds.IntMap) | ValueType.TClass(haxe.ds.EnumValueMap):
				true;
			default:
				false;
		};
	}

	public static function parseFloatArray(str:String):Array<Float> {
		var arr:Array<Float> = new Array<Float>();
		for (s in str.split(',')) {
			if (s != "") {
				arr.push(Std.parseFloat(s));
			}
		}
		return arr;
	}
	
	public static function parseIntArray(str:String):Array<Int> {
		var arr:Array<Int> = new Array<Int>();
		for (s in str.split(',')) {
			if (s != "") {
				arr.push(Std.parseInt(s));
			}
		}
		return arr;
	}
}

class DebugText extends FlxText
{
	private var disableTime:Float = 6;
	public var parentGroup:FlxTypedGroup<DebugText>;
	public function new(text:String, parentGroup:FlxTypedGroup<DebugText>) {
		this.parentGroup = parentGroup;
		super(10, 10, 0, text, 16);
		setFormat(Paths.font("vcr.ttf"), 20, 0xFFFFFFFF, LEFT, FlxTextBorderStyle.OUTLINE, 0xFF000000);
		scrollFactor.set();
		borderSize = 1;
	}

	override function update(elapsed:Float) {
		super.update(elapsed);
		disableTime -= elapsed;
		if(disableTime <= 0) {
			kill();
			parentGroup.remove(this);
			destroy();
		}
		else if(disableTime < 1) alpha = disableTime;
	}
}