package funkin.scripts;

import flixel.tweens.FlxTween;
import flixel.system.FlxAssets.FlxGraphicAsset;
import flixel.util.FlxColor;
import funkin.scripts.Globals.*;
import funkin.states.PlayState;
import funkin.states.GameOverSubstate;
import Type.ValueType;

import animateatlas.AtlasFrameMaker;
import openfl.display.BlendMode;
import flixel.*;
import flixel.text.FlxText;
import flixel.math.FlxMath;
import flixel.group.FlxGroup;
import flixel.tweens.FlxEase;

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

	inline public static function getLuaObject(tag:String, ?checkForTextsToo:Bool):Null<FlxSprite>
		return PlayState.instance.getLuaObject(tag, checkForTextsToo);

	inline public static function getObjectDirectly(tag:String):Null<Dynamic>
		return getLuaObject(tag, true) ?? getVarInArray(getInstance(), tag);

	public static function getObjectSimple(tag:String):Null<Dynamic>
		return getLuaObject(tag, true) ?? Reflect.getProperty(getInstance(), tag);

	public static function getTextObject(name:String):Null<FlxText> {
		if (PlayState.instance.modchartTexts.exists(name))
			return PlayState.instance.modchartTexts.get(name);
		var obj = Reflect.getProperty(PlayState.instance, name);
		return (obj is FlxText) ? obj : null;
	}

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

	public static function loadFrames(spr:FlxSprite, image:String, spriteType:String)
	{
		switch(spriteType.toLowerCase().trim())
		{
			case "texture" | "textureatlas" | "tex":
				spr.frames = AtlasFrameMaker.construct(image);

			case "texture_noaa" | "textureatlas_noaa" | "tex_noaa":
				spr.frames = AtlasFrameMaker.construct(image, null, true);

			case "packer" | "packeratlas" | "pac":
				spr.frames = Paths.getPackerAtlas(image);

			default:
				spr.frames = Paths.getSparrowAtlas(image);
		}
	}

	public static function resetTextTag(tag:String) {
		if(!PlayState.instance.modchartTexts.exists(tag))
			return;

		var pee:ModchartText = PlayState.instance.modchartTexts.get(tag);
		pee.kill();
		if(pee.wasAdded)
			PlayState.instance.remove(pee, true);
		
		pee.destroy();
		PlayState.instance.modchartTexts.remove(tag);
	}

	public static function resetSpriteTag(tag:String) {
		if(!PlayState.instance.modchartSprites.exists(tag))
			return;

		var pee:ModchartSprite = PlayState.instance.modchartSprites.get(tag);
		pee.kill();
		if(pee.wasAdded)
			PlayState.instance.remove(pee, true);
		
		pee.destroy();
		PlayState.instance.modchartSprites.remove(tag);
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

	public static function getMouseClicked(button:String) {
		return switch(button){
			case 'middle': FlxG.mouse.justPressedMiddle;
			case 'right': FlxG.mouse.justPressedRight;
			default: FlxG.mouse.justPressed;
		};
	}
	public static function getMousePressed(button:String) {
		return switch(button){
			case 'middle': FlxG.mouse.pressedMiddle;
			case 'right': FlxG.mouse.pressedRight;
			default: FlxG.mouse.pressed;
		};
	}
	public static function getMouseReleased(button:String) {
		return switch(button){
			case 'middle': FlxG.mouse.justReleasedMiddle;
			case 'right': FlxG.mouse.justReleasedRight;
			default: FlxG.mouse.justReleased;
		}
	}
	
	public static function getFlxEaseByString(?ease:String):Float->Float
	{
		return (ease==null) ? FlxEase.linear : switch(ease.toLowerCase()) 
		{
			case 'backin': FlxEase.backIn;
			case 'backinout': FlxEase.backInOut;
			case 'backout': FlxEase.backOut;
			case 'bouncein': FlxEase.bounceIn;
			case 'bounceinout': FlxEase.bounceInOut;
			case 'bounceout': FlxEase.bounceOut;
			case 'circin': FlxEase.circIn;
			case 'circinout': FlxEase.circInOut;
			case 'circout': FlxEase.circOut;
			case 'cubein': FlxEase.cubeIn;
			case 'cubeinout': FlxEase.cubeInOut;
			case 'cubeout': FlxEase.cubeOut;
			case 'elasticin': FlxEase.elasticIn;
			case 'elasticinout': FlxEase.elasticInOut;
			case 'elasticout': FlxEase.elasticOut;
			case 'expoin': FlxEase.expoIn;
			case 'expoinout': FlxEase.expoInOut;
			case 'expoout': FlxEase.expoOut;
			case 'quadin': FlxEase.quadIn;
			case 'quadinout': FlxEase.quadInOut;
			case 'quadout': FlxEase.quadOut;
			case 'quartin': FlxEase.quartIn;
			case 'quartinout': FlxEase.quartInOut;
			case 'quartout': FlxEase.quartOut;
			case 'quintin': FlxEase.quintIn;
			case 'quintinout': FlxEase.quintInOut;
			case 'quintout': FlxEase.quintOut;
			case 'sinein': FlxEase.sineIn;
			case 'sineinout': FlxEase.sineInOut;
			case 'sineout': FlxEase.sineOut;
			case 'smoothstepin': FlxEase.smoothStepIn;
			case 'smoothstepinout': FlxEase.smoothStepInOut;
			case 'smoothstepout': FlxEase.smoothStepInOut;
			case 'smootherstepin': FlxEase.smootherStepIn;
			case 'smootherstepinout': FlxEase.smootherStepInOut;
			case 'smootherstepout': FlxEase.smootherStepOut;
			default: FlxEase.linear;
		};
	}

	public static function blendModeFromString(blend:String):BlendMode
	{
		return switch(blend.toLowerCase()) 
		{
			case 'add': ADD;
			case 'alpha': ALPHA;
			case 'darken': DARKEN;
			case 'difference': DIFFERENCE;
			case 'erase': ERASE;
			case 'hardlight': HARDLIGHT;
			case 'invert': INVERT;
			case 'layer': LAYER;
			case 'lighten': LIGHTEN;
			case 'multiply': MULTIPLY;
			case 'overlay': OVERLAY;
			case 'screen': SCREEN;
			case 'shader': SHADER;
			case 'subtract': SUBTRACT;
			default: NORMAL;
		};
	}

	public static function cameraFromString(cam:String):FlxCamera {
		return switch(cam.toLowerCase()) {
			case 'camhud' | 'hud': 
				PlayState.instance.camHUD;
			case 'camother' | 'other': 
				PlayState.instance.camOther;
			default: 
				PlayState.instance.camGame;
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


class ModchartSprite extends FlxSprite
{
	public var wasAdded:Bool = false;
	//public var isInFront:Bool = false;
	public var animOffsets:Map<String, Array<Float>> = new Map<String, Array<Float>>();

	public function new(?x:Float = 0, ?y:Float = 0, ?Graphic:FlxGraphicAsset)
	{
		super(x, y, Graphic);
		//antialiasing = ClientPrefs.globalAntialiasing;
	}
}

class ModchartText extends FlxText
{
	public var wasAdded:Bool = false;
	public function new(x:Float, y:Float, text:String, width:Float)
	{
		super(x, y, width, text, 16);
		setFormat(Paths.font("vcr.ttf"), 16, 0xFFFFFFFF, CENTER, FlxTextBorderStyle.OUTLINE, 0xFF000000);
		cameras = [PlayState.instance.camHUD];
		scrollFactor.set();
		borderSize = 2;
	}
}