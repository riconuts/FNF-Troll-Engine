#if LUA_ALLOWED
import llua.Convert;
import llua.Lua;
import llua.LuaL;
import llua.State;
#end

import Controls;
import Type.ValueType;
import animateatlas.AtlasFrameMaker;
import flixel.FlxBasic;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.FlxSprite;
import flixel.addons.effects.FlxTrail;
import flixel.addons.transition.FlxTransitionableState;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.input.keyboard.FlxKey;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.system.FlxSound;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxSave;
import flixel.util.FlxTimer;
import openfl.Lib;
import openfl.display.BlendMode;
import openfl.filters.BitmapFilter;
import openfl.utils.Assets;

using StringTools;
#if sys
import sys.FileSystem;
import sys.io.File;
#end
#if desktop
import Discord;
#end


class FunkinLua {
	public static var Function_Stop:Dynamic = 1;
	public static var Function_Continue:Dynamic = 0;
	public static var Function_StopLua:Dynamic = 2;

	public var errorHandler:String->Void;
	
	public var camTarget:FlxCamera;
	public var scriptName:String = '';
	var gonnaClose:Bool = false;

	public var accessedProps:Map<String, Dynamic> = null;
	public function new(script:String) {
		
	}

	public static function setVarInArray(instance:Dynamic, variable:String, value:Dynamic):Any
	{
		var shit:Array<String> = variable.split('[');
		if(shit.length > 1)
		{
			var blah:Dynamic = Reflect.getProperty(instance, shit[0]);
			for (i in 1...shit.length)
			{
				var leNum:Dynamic = shit[i].substr(0, shit[i].length - 1);
				if(i >= shit.length-1) //Last array
					blah[leNum] = value;
				else //Anything else
					blah = blah[leNum];
			}
			return blah;
		}
		/*if(Std.isOfType(instance, Map))
			instance.set(variable,value);
		else*/
		switch(Type.typeof(instance)){
			case ValueType.TClass(haxe.ds.StringMap) | ValueType.TClass(haxe.ds.ObjectMap) | ValueType.TClass(haxe.ds.IntMap) | ValueType.TClass(haxe.ds.EnumValueMap):
				instance.set(variable, value);
			default:
				Reflect.setProperty(instance, variable, value);
		};


		return true;
	}
	public static function getVarInArray(instance:Dynamic, variable:String):Any
	{
		var shit:Array<String> = variable.split('[');
		if(shit.length > 1)
		{
			var blah:Dynamic = Reflect.getProperty(instance, shit[0]);
			for (i in 1...shit.length)
			{
				var leNum:Dynamic = shit[i].substr(0, shit[i].length - 1);
				blah = blah[leNum];
			}
			return blah;
		}
		switch(Type.typeof(instance)){
			case ValueType.TClass(haxe.ds.StringMap) | ValueType.TClass(haxe.ds.ObjectMap) | ValueType.TClass(haxe.ds.IntMap) | ValueType.TClass(haxe.ds.EnumValueMap):
				return instance.get(variable);
			default:
				return Reflect.getProperty(instance, variable);
		};
	}

	public function luaTrace(text:String, ignoreCheck:Bool = false, deprecated:Bool = false) {
		
	}
}

class DebugLuaText extends FlxText
{
	private var disableTime:Float = 6;
	public var parentGroup:FlxTypedGroup<DebugLuaText>;
	public function new(text:String, parentGroup:FlxTypedGroup<DebugLuaText>) {
		this.parentGroup = parentGroup;
		super(10, 10, 0, text, 16);
		setFormat(Paths.font("calibri.ttf"), 20, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
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
