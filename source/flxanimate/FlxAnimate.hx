package flxanimate;

import funkin.Paths as Assets;

import flxanimate.display.FlxAnimateFilterRenderer;
import openfl.filters.BitmapFilter;
import flxanimate.geom.FlxMatrix3D;
import openfl.display.Sprite;
import flixel.util.FlxColor;
import flixel.graphics.FlxGraphic;
import openfl.geom.Rectangle;
import openfl.display.BitmapData;
import flixel.util.FlxDestroyUtil;
import flixel.math.FlxRect;
import flixel.graphics.frames.FlxFrame;
import flixel.math.FlxPoint;
import flixel.FlxCamera;
import flxanimate.animate.*;
import flxanimate.zip.Zip;
import haxe.io.BytesInput;
import flixel.system.FlxSound;
import flixel.FlxG;
import flxanimate.data.AnimationData;
import flixel.FlxSprite;
import flxanimate.animate.FlxAnim;
import flxanimate.frames.FlxAnimateFrames;
import flixel.math.FlxMatrix;
import openfl.geom.ColorTransform;
import flixel.math.FlxMath;
import flixel.FlxBasic;
import flixel.system.FlxAssets.FlxGraphicAsset;

using StringTools;

typedef Settings = {
	?ButtonSettings:Map<String, flxanimate.animate.FlxAnim.ButtonSettings>,
	?FrameRate:Float,
	?Reversed:Bool,
	?OnComplete:Void->Void,
	?ShowPivot:Bool,
	?Antialiasing:Bool,
	?ScrollFactor:FlxPoint,
	?Offset:FlxPoint,
}

@:access(openfl.geom.ColorTransform)
@:access(openfl.geom.Rectangle)
@:access(flixel.graphics.frames.FlxFrame)
class FlxAnimate extends FlxSprite
{
	public var anim(default, null):FlxAnim;

	// #if FLX_SOUND_SYSTEM
	// public var audio:FlxSound;
	// #end
	
	var rect:Rectangle;

	var _symbols:Array<FlxSymbol>;
	
	public var showPivot:Bool = #if debug true #else false #end;

	var _pivot:FlxFrame;
	var _indicator:FlxFrame;

	var renderer:FlxAnimateFilterRenderer = new FlxAnimateFilterRenderer();

	var filterCamera:FlxCamera;


	var _sprite:Sprite;
	
	/**
	 * # Description
	 * The `FlxAnimate` class calculates in real time a texture atlas through
	 * ## WARNINGS
	 * - This does **NOT** convert the frames into a spritesheet
	 * - Since this is some sort of beta, expect that there could be some inconveniences (bugs, crashes, etc).
	 *
	 * @param X 		The initial X position of the sprite.
	 * @param Y 		The initial Y position of the sprite.
	 * @param Path      The path to the texture atlas, **NOT** the path of the any of the files inside the texture atlas (`Animation.json`, `spritemap.json`, etc).
	 * @param Settings  Optional settings for the animation (antialiasing, framerate, reversed, etc.).
	 */
	public function new(X:Float = 0, Y:Float = 0, ?Path:String, ?Settings:Settings)
	{
		super(X, Y);
		_sprite = new Sprite();
		anim = new FlxAnim(this);
		if (Path != null)
			loadAtlas(Path);
		if (Settings != null)
			setTheSettings(Settings);
		_pivot = FlxGraphic.fromBitmapData(Assets.getBitmapData("flxanimate/images/pivot.png"), "__pivot").imageFrame.frame;
		_indicator = FlxGraphic.fromBitmapData(Assets.getBitmapData("flxanimate/images/indicator.png"), "__indicator").imageFrame.frame;
		camera.canvas.addChild(_sprite);
		rect = Rectangle.__pool.get();
	}

	public function loadAtlas(Path:String)
	{
		if(haxe.io.Path.extension(Path) != "zip" && !Assets.exists('$Path/Animation.json') )
		{
			FlxG.log.error('Animation file not found in specified path: "$path", have you written the correct path?');
			return;
		}
		anim._loadAtlas(atlasSetting(Path));
		frames = FlxAnimateFrames.fromTextureAtlas(Path);
		origin = anim.curInstance.symbol.transformationPoint;
	}

	/**
	 * the function `draw()` renders the symbol that `anim` has currently plus a pivot that you can toggle on or off.
	 */
	public override function draw():Void
	{
		_matrix.identity();
		if (flipX)
		{
			_matrix.a *= -1;
			_matrix.tx += width;
		}
		if (flipY)
		{
			_matrix.d *= -1;
			_matrix.ty += height;
		}
		frameWidth = 0;
		frameHeight = 0;
		width = 0;
		height = 0;
		_flashRect.setEmpty();
		
		parseElement(anim.curInstance, anim.curFrame, _matrix, colorTransform, true, cameras);

		width = _flashRect.width;
		height = _flashRect.height;
		frameWidth = Std.int(width);
		frameHeight = Std.int(height);

		if (showPivot)
		{
			drawLimb(_pivot, new FlxMatrix(1, 0, 0, 1, origin.x - _pivot.frame.width * 0.5, origin.y - _pivot.frame.height * 0.5), cameras);
			drawLimb(_indicator, new FlxMatrix(1, 0, 0, 1, -_indicator.frame.width * 0.5, -_indicator.frame.height * 0.5), cameras);
		}
	}

	function parseElement(instance:FlxElement, curFrame:Int, m:FlxMatrix, colorFilter:ColorTransform, mainSymbol:Bool = false, ?filterInstance:{?instance:FlxElement} = null, ?cameras:Array<FlxCamera> = null)
	{
		var filterin = filterInstance != null;
		if (cameras == null)
			cameras = this.cameras;

		var matrix = new FlxMatrix();

		matrix.concat(instance.matrix);
		matrix.concat(m);


		var colorEffect = new ColorTransform();
		colorEffect.__copyFrom(colorFilter);

		var symbol = (instance.symbol != null) ? anim.symbolDictionary.get(instance.symbol.name) : null;

		if (instance.symbol != null)
		{
			if (instance.symbol.colorEffect != null)
				colorEffect.concat(instance.symbol.colorEffect.__create());
			
			if (instance.symbol.cacheAsBitmap)
			{
				if (instance.symbol._renderDirty)
				{
					instance.symbol._renderDirty = false;
					if (filterCamera == null)
						filterCamera = new FlxCamera(0,0,0,0,1);
					
					
					instance.symbol._cacheBitmapMatrix.copyFrom(instance.symbol.cacheAsBitmapMatrix);

					parseElement(instance, curFrame, instance.symbol._cacheBitmapMatrix, new ColorTransform(), mainSymbol, {instance: instance}, [filterCamera]);
					
					
					if (instance.symbol._filterBitmap == null)
						instance.symbol._filterBitmap = FlxGraphic.fromRectangle(1,1, 0, true).imageFrame.frame;

					@:privateAccess
					renderFilter(filterCamera, instance.symbol.filters, instance.symbol._filterBitmap, instance.symbol._cacheBitmapMatrix, renderer);
					instance.symbol._renderDirty = false;
	
				}
				if ((!filterin || filterin && filterInstance.instance != instance) && instance.symbol._filterBitmap != null)
				{
					matrix.identity();
					matrix.concat(instance.symbol._cacheBitmapMatrix);
					matrix.concat(m);
					drawLimb(instance.symbol._filterBitmap, matrix, colorEffect, filterin, cameras);
					return;
				}
			}
		}

		if (instance.bitmap != null)
		{
			drawLimb(frames.getByName(instance.bitmap), matrix, colorEffect, filterin, cameras);
			return;
		}
		
		var firstFrame:Int = instance.symbol.firstFrame + curFrame;
		switch (instance.symbol.type)
		{
			case Button: firstFrame = setButtonFrames(firstFrame);
			default:
		}

		firstFrame = switch (instance.symbol.loop)
		{
			case Loop: firstFrame % symbol.length;
			case PlayOnce: cast FlxMath.bound(firstFrame, 0, symbol.length - 1);
			default: firstFrame;
		}
		
		var layers = symbol.timeline.getList();
		for (i in 0...layers.length)
		{
			var layer = layers[layers.length - 1 - i];
			
			if (!layer.visible && !filterin && mainSymbol) continue;

			layer._setCurFrame(firstFrame);
			var frame = layer._currFrame;
			
			if (frame == null) continue;
			
			frame.update(firstFrame);

			var toBitmap = frame.filters != null;

			if (toBitmap)
			{
				if (!frame._renderDirty && frame._filterFrame != null)
				{
					var mat = new FlxMatrix();
					mat.concat(frame._bitmapMatrix);
					mat.concat(instance.matrix);
					mat.concat(m);
					drawLimb(frame._filterFrame, mat, null, filterin, cameras);
					continue;
				}
				else
				{
					frame._filterFrame = FlxGraphic.fromRectangle(1,1, 0, true).imageFrame.frame;
					if (layer._filterCamera == null)
						layer._filterCamera = new FlxCamera();
				}
			}
			for (element in frame.getList())
			{
				var firstframe = 0;
				if (element.symbol != null && element.symbol.type == Graphic && element.symbol.loop != SingleFrame)
				{
					firstframe = firstFrame - frame.index;
				}
				
				var coloreffect = new ColorTransform();
				coloreffect.__copyFrom(colorEffect);
				if (frame.colorEffect != null)
					coloreffect.concat(frame.colorEffect.__create());
				parseElement(element, firstframe, (toBitmap) ? new FlxMatrix() : matrix, coloreffect, false, (toBitmap) ? {instance: null} : filterInstance, (toBitmap) ? [layer._filterCamera] : cameras);

				if (toBitmap && element.symbol != null && element.symbol._layerDirty)
					element.symbol._layerDirty = false;
			}
			
			if (toBitmap)
			{
				frame._bitmapMatrix.identity();

				renderFilter(layer._filterCamera, frame.filters, frame._filterFrame, frame._bitmapMatrix, renderer);
				frame._renderDirty = false;

				var mat = new FlxMatrix();
				mat.concat(frame._bitmapMatrix);
				mat.concat(instance.matrix);
				mat.concat(m);

				drawLimb(frame._filterFrame, mat, null, filterin, cameras);
			}
		}
	}
	function renderFilter(filterCamera:FlxCamera, filters:Array<BitmapFilter>, filter:FlxFrame,  _cacheBitmapMatrix:FlxMatrix, renderer:FlxAnimateFilterRenderer)
	{	
		@:privateAccess
		filterCamera.render();
		
		var gfx = renderer.graphicstoBitmapData(filterCamera.canvas.graphics);
		
		
		if (gfx == null) return;

		@:privateAccess
		var bounds = gfx.rect.clone();

		if (bounds == null) return;
		
		var b = new Rectangle();

		@:privateAccess
		filterCamera.canvas.__getBounds(b, _cacheBitmapMatrix);

		if (filters != null && filters.length > 0)
			gfx = applyFilter(renderer, gfx, filters, bounds);
		
		
		_cacheBitmapMatrix.translate((b.x + bounds.x) - (gfx.width - bounds.width) * 0.5, (b.y + bounds.y) - (gfx.height - bounds.height) * 0.5);

		@:privateAccess
		filterCamera.clearDrawStack();
		filterCamera.canvas.graphics.clear();
		filter.parent.bitmap.dispose();
		filter.parent.bitmap = gfx;
		filter.frame.setSize(gfx.width, gfx.height);
	}

	function applyFilter(renderer:FlxAnimateFilterRenderer, image:BitmapData, filters:Array<BitmapFilter>, rect:Rectangle)
	{

		@:privateAccess
		var extension = Rectangle.__pool.get();

		for (filter in filters)
		{
			@:privateAccess
			extension.__expand(-filter.__leftExtension,
				-filter.__topExtension, filter.__leftExtension
				+ filter.__rightExtension,
				filter.__topExtension
				+ filter.__bottomExtension);
		}
		rect.width += extension.width;
		rect.height += extension.height;
		rect.x += extension.x;
		rect.y += extension.y;

		@:privateAccess
		Rectangle.__pool.release(extension);

		

		return renderer.applyFilter(image, filters, rect);
	}
	var pressed:Bool = false;
	function setButtonFrames(frame:Int)
	{
		var badPress:Bool = false;
		var goodPress:Bool = false;
		#if !mobile
		if (FlxG.mouse.pressed && FlxG.mouse.overlaps(this))
			goodPress = true;
		if (FlxG.mouse.pressed && !FlxG.mouse.overlaps(this) && !goodPress)
		{
			badPress = true;
		}
		if (!FlxG.mouse.pressed)
		{
			badPress = false;
			goodPress = false;
		}
		if (FlxG.mouse.overlaps(this) && !badPress)
		{
			@:privateAccess
			var event = anim.buttonMap.get(anim.curSymbol.name);
			if (FlxG.mouse.justPressed && !pressed)
			{
				if (event != null)
					new ButtonEvent((event.Callbacks != null) ? event.Callbacks.OnClick : null #if FLX_SOUND_SYSTEM, event.Sound #end).fire();
				pressed = true;
			}
			frame = (FlxG.mouse.pressed) ? 2 : 1;

			if (FlxG.mouse.justReleased && pressed)
			{
				if (event != null)
					new ButtonEvent((event.Callbacks != null) ? event.Callbacks.OnRelease : null #if FLX_SOUND_SYSTEM, event.Sound #end).fire();
				pressed = false;
			}
		}
		else
		{
			frame = 0;
		}
		#else
		FlxG.log.error("Button stuff isn't available for mobile!");
		#end
		return frame;
	}
	var _mat:FlxMatrix = new FlxMatrix();
	function drawLimb(limb:FlxFrame, _matrix:FlxMatrix, ?colorTransform:ColorTransform = null, filterin:Bool = false, cameras:Array<FlxCamera> = null)
	{
		if (cameras == null || alpha == 0 || colorTransform != null && (colorTransform.alphaMultiplier == 0 || colorTransform.alphaOffset == -255) || limb == null || limb.type == EMPTY)
			return;

		for (camera in cameras)
		{
			limb.prepareMatrix(_mat);
			var matrix = _mat;
			matrix.concat(_matrix);
			if (!camera.visible || !camera.exists)
				return;
			
			if (!filterin)
			{
				getScreenPosition(_point, camera).subtractPoint(offset);
				if ([_pivot, _indicator].indexOf(limb) == -1)
				{
					matrix.translate(-origin.x, -origin.y);

					matrix.scale(scale.x, scale.y);
					
					if (bakedRotationAngle <= 0)
					{
						updateTrig();
			
						if (angle != 0)
							matrix.rotateWithTrig(_cosAngle, _sinAngle);
					}

					_point.addPoint(origin);
				}
				else
				{
					matrix.scale(0.7, 0.7);

					matrix.a /= camera.zoom;
					matrix.d /= camera.zoom;
					matrix.tx /= camera.zoom;
					matrix.ty /= camera.zoom;
					
					
				}
				
				
				if (isPixelPerfectRender(camera))
				{
					_point.floor();
				}

				matrix.translate(_point.x, _point.y);

				if (!limbOnScreen(limb, matrix, camera))
					return;
			}
			camera.drawPixels(limb, null, matrix, colorTransform, blend, antialiasing);
		}

		#if FLX_DEBUG
		if (FlxG.debugger.drawDebug)
			drawDebug();
		#end
		#if FLX_DEBUG
		FlxBasic.visibleCount++;
		#end
	}
	
	function limbOnScreen(limb:FlxFrame, m:FlxMatrix, ?Camera:FlxCamera = null)
	{
		if (Camera == null)
			Camera = FlxG.camera;

		limb.frame.copyToFlash(rect);

		rect.x = 0;
		rect.y = 0;

		rect.__transform(rect, m);

		_point.copyFromFlash(rect.topLeft);

		if (limb != _pivot)
			_flashRect = _flashRect.union(rect);
		
		return Camera.containsPoint(_point, rect.width, rect.height);
	}

	override function destroy()      
	{                                                                
		if (anim != null)
			anim.destroy();
		anim = null;
		
		// #if FLX_SOUND_SYSTEM
		// if (audio != null)
		// 	audio.destroy();
		// #end
		super.destroy();
	}

	public override function updateAnimation(elapsed:Float) 
	{
		anim.update(elapsed);
	}

	public function setButtonPack(button:String, callbacks:ClickStuff #if FLX_SOUND_SYSTEM , sound:FlxSound #end):Void
	{
		@:privateAccess
		anim.buttonMap.set(button, {Callbacks: callbacks, #if FLX_SOUND_SYSTEM Sound:  sound #end});
	}

	public function setTheSettings(?Settings:Settings):Void
	{
		@:privateAccess
		if (true)
		{
			antialiasing = Settings.Antialiasing;
			if (Settings.ButtonSettings != null)
			{
				anim.buttonMap = Settings.ButtonSettings;
				if (anim.symbolType != Button)
					anim.symbolType = Button;
			}
			if (Settings.Reversed != null)
				anim.reversed = Settings.Reversed;
			if (Settings.FrameRate != null)
				anim.framerate = (Settings.FrameRate > 0) ? anim.metadata.frameRate : Settings.FrameRate;
			if (Settings.OnComplete != null)
				anim.onComplete = Settings.OnComplete;
			if (Settings.ShowPivot != null)
				showPivot = Settings.ShowPivot;
			if (Settings.Antialiasing != null)
				antialiasing = Settings.Antialiasing;
			if (Settings.ScrollFactor != null)
				scrollFactor = Settings.ScrollFactor;
			if (Settings.Offset != null)
				offset = Settings.Offset;
		}
	}

	function atlasSetting(Path:String):AnimAtlas
	{
		var jsontxt:AnimAtlas = null;
		if (haxe.io.Path.extension(Path) == "zip")
		{
			var thing = Zip.readZip(Assets.getBytes(Path));
			
			for (list in Zip.unzip(thing))
			{
				if (list.fileName.indexOf("Animation.json") != -1)
				{
					jsontxt = haxe.Json.parse(list.data.toString());
					thing.remove(list);
					continue;
				}
			}
			@:privateAccess
			FlxAnimateFrames.zip = thing;
		}
		else
		{
			jsontxt = haxe.Json.parse(Assets.getText('$Path/Animation.json'));
		}

		return jsontxt;
	}

	public function loadAtlasEx(img:FlxGraphicAsset, pathOrStr:String = null, myJson:Dynamic = null)
	{
		var animJson:AnimAtlas = null;
		if(myJson is String)
		{
			var trimmed:String = pathOrStr.trim();
			trimmed = trimmed.substr(trimmed.length - 5).toLowerCase();

			if(trimmed == '.json') myJson = Assets.getContent(myJson); //is a path
			animJson = cast haxe.Json.parse(_removeBOM(myJson));
		}
		else animJson = cast myJson;

		var isXml:Null<Bool> = null;
		var myData:Dynamic = pathOrStr;

		var trimmed:String = pathOrStr.trim();
		trimmed = trimmed.substr(trimmed.length - 5).toLowerCase();

		if(trimmed == '.json') //Path is json
		{
			myData = Assets.getContent(pathOrStr);
			isXml = false;
		}
		else if (trimmed.substr(1) == '.xml') //Path is xml
		{
			myData = Assets.getContent(pathOrStr);
			isXml = true;
		}
		myData = _removeBOM(myData);

		// Automatic if everything else fails
		switch(isXml)
		{
			case true:
				myData = Xml.parse(myData);
			case false:
				myData = haxe.Json.parse(myData);
			case null:
				try
				{
					myData = haxe.Json.parse(myData);
					isXml = false;
					//trace('JSON parsed successfully!');
				}
				catch(e)
				{
					myData = Xml.parse(myData);
					isXml = true;
					//trace('XML parsed successfully!');
				}
		}

		anim._loadAtlas(animJson);
		if(!isXml) frames = FlxAnimateFrames.fromAnimateAtlas(cast myData, img);
		else frames = FlxAnimateFrames.fromSparrow(cast myData, img);
		origin = anim.curInstance.symbol.transformationPoint;
	}

	function _removeBOM(str:String) //Removes BOM byte order indicator
	{
		if (str.charCodeAt(0) == 0xFEFF) str = str.substr(1); //myData = myData.substr(2);
		return str;
	}
}
