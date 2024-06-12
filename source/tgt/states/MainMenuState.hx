package tgt;

import flixel.text.FlxText;
import flixel.addons.display.FlxBackdrop;
import flixel.effects.FlxFlicker;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.util.FlxColor;
import flixel.util.FlxSort;
import flixel.util.FlxTimer;
import flixel.math.FlxMath;
import flixel.math.FlxAngle;
import flixel.group.FlxGroup.FlxTypedGroup;
import editors.MasterEditorMenu;

import flixel.input.keyboard.FlxKey;
import openfl.events.MouseEvent;
import openfl.ui.Mouse;
import openfl.ui.MouseCursor;

#if debug
import sowy.Sowy;
#end

using StringTools;

class ZSprite extends FlxSprite
{
    public var order:Float = 0;
}
@:injectMoreFunctions([
    "updateMouseIcon",
    #if mobile
    "onMouseDown",
    #end
    "onMouseUp",
    "moveBoxes",
    "onSelected",
	"changeItem",
    "bgFlicker",
    "magentaFlicker"
])
class MainMenuState extends MusicBeatState 
{
	final optionShit:Array<String> = [
		'story_mode',
 		'freeplay',
		'promo',
		'options' 
	];

	final sideShit:Array<String> = [
		'credits',
 		'gallery'
	];

	var engineWatermark:FlxText;
	var magenta:FlxBackdrop;
	var backdrop:FlxBackdrop;
	var menuItems:FlxTypedGroup<ZSprite>;
    var buttons:Array<ZSprite> = [];
	var artBoxes:Array<ZSprite> = [];

	var sideItems:FlxTypedGroup<FlxSprite>;

	public static var curSelected:Int = 0;
	var selectedSomethin:Bool = false;

	inline function toRad(input:Float)
		return FlxAngle.TO_RAD * input;

	override function startOutro(onOutroFinished:()->Void){
		persistentUpdate = false;
		return onOutroFinished();
	}

    override function create()
    {
		persistentUpdate = true;
		persistentDraw = true;

		FadeTransitionSubstate.nextCamera = FlxG.camera; // AAAA

		#if discord_rpc
		// Updating Discord Rich Presence
		Discord.DiscordClient.changePresence("In the Menus", null);
		#end

		super.create();
		
		debugKeys = ClientPrefs.copyKey(ClientPrefs.keyBinds.get('debug_1'));
		
		#if MODS_ALLOWED
		Paths.pushGlobalContent();
		Paths.loadTheFirstEnabledMod();
        #end
		FlxG.mouse.visible = true;
		FlxG.camera.bgColor = FlxColor.BLACK;

		////
		var bg:ZSprite = cast new ZSprite().loadGraphic(Paths.image('tgtmenus/mainmenu/menuBG'));
		bg.scrollFactor.set();
		bg.setGraphicSize(0, FlxG.height);
		bg.updateHitbox();
		bg.screenCenter();
		add(bg);

		/*
		var grad = flixel.util.FlxGradient.createGradientFlxSprite(FlxG.width, FlxG.height, [0xFF9BDCED, 0xFF6A94E5]);
		add(grad);
		*/

		backdrop = new FlxBackdrop(Paths.image("grid"));
		backdrop.velocity.set(30, 30);
		backdrop.color = 0xFF467aeb;
		backdrop.alpha = 0.175;
		add(backdrop);

		magenta = new FlxBackdrop(Paths.image("grid"));
		magenta.velocity.set(30, 30);
		magenta.color = 0xFFFF0078;
		magenta.alpha = 0.6;
		magenta.visible = false;
		add(magenta);

		////
		menuItems = new FlxTypedGroup<ZSprite>();
        for(option in optionShit)
		{
			var art = new ZSprite();
			art.loadGraphic(Paths.image("tgtmenus/mainmenu/cover_" + option));
			art.scrollFactor.set();
			art.ID = artBoxes.length;

			var butt = new ZSprite();
			butt.loadGraphic(Paths.image("tgtmenus/mainmenu/menu_" + option));
			butt.scrollFactor.set();
			butt.ID = art.ID;

			artBoxes.push(art);
			buttons.push(butt);

			menuItems.add(butt);
            menuItems.add(art);
        }
		add(menuItems);

		////
		var buttonBg = new FlxSprite(FlxG.width, 0, Paths.image('tgtmenus/mainmenu/extra_pad'));
		buttonBg.x -= buttonBg.width;
		add(buttonBg);

		sideItems = new FlxTypedGroup<FlxSprite>();
		for (idx in 0...sideShit.length)
		{
			var button = new FlxSprite(
				buttonBg.x + 125 - 93, 
				10 + (10 + idx * (83 + 16)), 
				Paths.image('tgtmenus/mainmenu/button_${sideShit[idx]}')
			);

			button.ID = idx;
			sideItems.add(button);
		}
		add(sideItems);

		engineWatermark = new FlxText(0, 0, 0, 'Troll Engine');
		engineWatermark.setFormat(Paths.font("calibrib.ttf"), 16, Main.outOfDate?FlxColor.RED:FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
		add(engineWatermark);
		#if (tgt && final)
		engineWatermark.text += " | Tails Gets Trolled v" + lime.app.Application.current.meta.get('version');
		#elseif debug
		engineWatermark.text += ' [${Sowy.getBuildDate()}]';
		#else
		engineWatermark.text += ' ${Main.displayedVersion}';
		if (Main.outOfDate)
			engineWatermark.text += " [UPDATE AVAILABLE]";
		#end
		engineWatermark.x = FlxG.width - engineWatermark.width;
		engineWatermark.y = FlxG.height - engineWatermark.height;

		////
		changeItem(curSelected, true);
		moveBoxes(1);

		#if mobile
		FlxG.stage.addEventListener(MouseEvent.MOUSE_DOWN, onMouseDown);
		#end
		FlxG.stage.addEventListener(MouseEvent.MOUSE_MOVE, onMouseMove);
		FlxG.stage.addEventListener(MouseEvent.MOUSE_UP, onMouseUp);
    
		MusicBeatState.playMenuMusic();

		Paths.clearUnusedMemory();
	}

	function fuckOff(?who:FlxSprite) 
	{
		selectedSomethin = true;

		FlxG.sound.play(Paths.sound('confirmMenu'));

		bgFlicker();

		menuItems.forEach(function(spr){
			FlxTween.tween(spr, {alpha: 0}, 0.4, {
				ease: FlxEase.quadOut,
				onComplete: function(_){spr.kill();}
			});
		});

		for (spr in sideItems){
			if (spr == who){
				FlxFlicker.flicker(spr, 1, 0.06, false, false, function(_){
					switch(sideShit[who.ID]){
						case "credits":
							MusicBeatState.switchState(new CreditsState());
						case "gallery":
							MusicBeatState.switchState(new tgt.gallery.GalleryMenuState());
					}
				});
			}else{
				FlxTween.tween(spr, {alpha: 0}, 0.4, {
					ease: FlxEase.quadOut,
					onComplete: function(_){spr.kill();}
				});
			}
		}
	}

	var came = false;
	var squeaks = 0;
	private function kirbfSqueak(spr:FlxSprite){
		if (came) return false;

		squeaks++;

		if (squeaks > 4){
			FlxG.sound.play(Paths.sound("pop"));
			spr.loadGraphic(Paths.image("tgtmenus/mainmenu/cover_freeplay_alt"));
			
			came = true;
		}
		else{
			FlxG.sound.play(Paths.soundRandom("squeak", 1, 3), 1, false, true, function(){
				squeaks--;
			});
		}

		return true;
	}

	#if mobile
	var mouseHolding:Bool = false;
	var mouseHoldStartX:Float;
	var mouseSwipe:Float = 0;

	function onMouseDown(e)
	{
		mouseHolding = true;
		mouseHoldStartX = FlxG.mouse.x;
	}

	#else
	function updateMouseIcon()
	{
		if (FlxG.mouse.overlaps(engineWatermark) && Main.outOfDate)
		{
			trace(Main.outOfDate);
			Mouse.cursor = MouseCursor.BUTTON;
			return;
		}

		for (spr in sideItems){
			if (FlxG.mouse.overlaps(spr)){
				Mouse.cursor = MouseCursor.BUTTON;
				return;
			}
		}

		for (spr in menuItems){
			if (spr.ID == curSelected && FlxG.mouse.overlaps(spr))
			{
				Mouse.cursor = MouseCursor.BUTTON;
				return;
			}
		}

		Mouse.cursor = MouseCursor.AUTO;
	}
	#end

	function onMouseMove(e)
	{
		#if mobile
		if (mouseHolding && !selectedSomethin)
			mouseSwipe = (mouseHoldStartX - FlxG.mouse.x) / FlxG.width;
		else
			mouseSwipe = 0;
		
		#else

		updateMouseIcon();
		#end
	}

	function onMouseUp(e)
	{
		if (selectedSomethin)
			return;
		
		#if mobile
		mouseHolding = false;

		if (mouseSwipe < -0.65)
			return changeItem(-1);
		else if (mouseSwipe > 0.65)
			return changeItem(1);

		mouseSwipe = 0;
		#end

		for (spr in sideItems){
			if (FlxG.mouse.overlaps(spr))
				return fuckOff(spr);
		}

		if (Main.outOfDate && FlxG.mouse.overlaps(engineWatermark)){
			#if DO_AUTO_UPDATE
			if(Main.recentRelease != null)
				MusicBeatState.switchState(new UpdaterState(Main.recentRelease));
			else#end{
				CoolUtil.browserLoad('https://github.com/riconuts/troll-engine/releases');
				return;
			}
		}

		for (spr in menuItems){
			if (spr.ID == curSelected && FlxG.mouse.overlaps(spr)){
	
				//// Kirb BF
				if (spr.ID == optionShit.indexOf("freeplay") && artBoxes.contains(spr))
				{
					var clickPos = FlxG.mouse.getPositionInCameraView();

					if (clickPos.x >= spr.x + 26 && 
						clickPos.x <= spr.x + 132 &&
						clickPos.y >= spr.y + 4 &&  
						clickPos.y <= spr.y + 58
					){
						kirbfSqueak(spr);
						return;
					}
				}

				////
				return onSelected();
			}	
		}
	}

	override function destroy() {
		#if mobile
		FlxG.stage.removeEventListener(MouseEvent.MOUSE_DOWN, onMouseDown);
		#end
		FlxG.stage.removeEventListener(MouseEvent.MOUSE_UP, onMouseUp);
		FlxG.stage.removeEventListener(MouseEvent.MOUSE_MOVE, onMouseMove);

		super.destroy();
	}

	var magTwn:FlxTween = null;
	function magentaFlicker(?tmr){
		if (magTwn != null) magTwn.cancel();
		
		magenta.alpha = 0.5;
		magTwn = FlxTween.tween(magenta, {alpha: 0}, 0.15, {ease: FlxEase.circIn});
	}
	
	function bgFlicker() {
		magenta.visible = true;
		
		if (ClientPrefs.flashing){
			magentaFlicker();
			new FlxTimer().start(0.3, magentaFlicker, Std.int(1/0.3));
		}else{
			magenta.alpha = 0;
			FlxTween.tween(magenta, {alpha: 0.6}, 1.1, {ease: FlxEase.quintOut});
		}
	}

	function onSelected()
	{
		if (selectedSomethin)
			return;
		
		if (optionShit[curSelected] == 'promo'){
			CoolUtil.browserLoad('http://www.tailsgetstrolled.org/');
			return;
		}

		selectedSomethin = true;

		FlxG.sound.play(Paths.sound('confirmMenu'));

		FlxG.mouse.visible = false;

		FlxTween.tween(FlxG.camera, {zoom: 1.14}, 0.85, {ease: FlxEase.quartOut});

		bgFlicker();

		for (spr in sideItems){
			FlxTween.tween(spr, {alpha: 0}, 0.4, {
				ease: FlxEase.quadOut,
				onComplete: function(twn:FlxTween)
				{
					spr.kill();
				}
			});
		}
		
		menuItems.forEach(function(spr)
		{
			if (curSelected != spr.ID)
			{
				FlxTween.tween(spr, {alpha: 0}, 0.4, {
					ease: FlxEase.quadOut,
					onComplete: function(twn:FlxTween)
					{
						spr.kill();
					}
				});
			}
			else
			{
				FlxFlicker.flicker(spr, 1, 0.06, false, false, function(flick:FlxFlicker)
				{
					switch (optionShit[curSelected])
					{
						case 'story_mode':
							MusicBeatState.switchState(new StoryMenuState());
						case 'freeplay':
							MusicBeatState.switchState(#if !final FlxG.keys.pressed.SHIFT ? new SongSelectState() : #end new FreeplayState());
						case 'options':
							LoadingState.loadAndSwitchState(new options.OptionsState());
					}
				});
			}
		});
	}

    function changeItem(?val:Int=0, absolute:Bool=false){
		var difference = absolute?Math.abs(curSelected - val):val;
        if(difference != 0)
			FlxG.sound.play(Paths.sound('scrollMenu'));

        if(absolute)
            curSelected = val;
        else
            curSelected += val;

        if(curSelected >= optionShit.length)
            curSelected = 0; 
        else if(curSelected < 0)
            curSelected = optionShit.length-1;

		#if !mobile
		updateMouseIcon();
		#end
    }
    
	function sortByOrder(wat:Int, Obj1:ZSprite, Obj2:ZSprite):Int
		return FlxSort.byValues(FlxSort.ASCENDING, Obj1.order, Obj2.order);
	
	var originX = FlxG.width / 2;
	var originY = FlxG.height / 2 + 300;

    var heldDir:Array<Float> = [0, 0];
    var holding:Array<Float> = [0, 0];
    
	function moveBoxes(lerpSpeed:Float = 0.2){
		var lerpVal = lerpSpeed * (FlxG.elapsed / (1 / 60));
		if (lerpSpeed>=1)lerpVal=1;

		var rads = toRad(360 / artBoxes.length);
		for (obj in artBoxes)
		{
			var idx = obj.ID;
			var but = buttons[idx];

			obj.order = -obj.y;

			var input = (idx - curSelected #if mobile - mouseSwipe #end) * rads;
			var desiredX = FlxMath.fastSin(input) * 450;
			var desiredY = -(FlxMath.fastCos(input) * 350);

			var shit = 1 - (.3 * Math.abs(FlxMath.fastSin(input)));

			var scaleX = FlxMath.lerp(obj.scale.x, shit, lerpVal);
			var scaleY = FlxMath.lerp(obj.scale.y, shit, lerpVal);

			obj.scale.set(scaleX, scaleY);
			obj.updateHitbox();
			obj.x = FlxMath.lerp(obj.x, originX - obj.width * 0.5 + desiredX, lerpVal);
			obj.y = FlxMath.lerp(obj.y, originY - obj.height * 0.5 + desiredY, lerpVal);

			if (but != null)
			{
				but.order = obj.order + 1;
				but.alpha = obj.alpha;
				but.visible = obj.visible;
				
				var scaleX = FlxMath.lerp(but.scale.x, shit, lerpVal);
				var scaleY = FlxMath.lerp(but.scale.y, shit, lerpVal);

				but.scale.set(scaleX, scaleY);
				but.updateHitbox();
				but.x = (obj.x - (but.width - obj.width) * 0.5);
				but.y = (obj.y + (415 * scaleX));
			}
		}

	}
	var debugKeys:Array<FlxKey>;
    override function update(elapsed:Float){
		var targetVolume:Float =  0.8;
		if (FlxG.sound.music != null && FlxG.sound.music.volume < targetVolume)
			FlxG.sound.music.volume += 0.5 * FlxG.elapsed;

		if (FlxG.sound.music.volume > targetVolume)
			FlxG.sound.music.volume = targetVolume;

		if (!selectedSomethin){
			if (controls.BACK){
				selectedSomethin = true;
				MusicBeatState.switchState(new TitleState());
			}else if (controls.ACCEPT)
				onSelected();
			#if desktop
			else if (FlxG.keys.anyJustPressed(debugKeys))
			{
				selectedSomethin = true;
				MusicBeatState.switchState(new MasterEditorMenu());
			}				
			#end

			#if !FLX_NO_MOUSE
			if (FlxG.mouse.wheel != 0)
			{
				changeItem(FlxG.mouse.wheel);
			}
			#end

            if (controls.UI_LEFT_P || controls.UI_LEFT && heldDir[0] > .3 && holding[0] >= 0.05)
            {
                holding[0] = 0;
                changeItem(-1);
            }

            if (controls.UI_RIGHT_P || controls.UI_RIGHT && heldDir[1] >= .3 && holding[1] >= 0.05)
            {
                holding[1] = 0;
                changeItem(1);
            }

            if (controls.UI_LEFT)
            {
                heldDir[0] += elapsed;
                holding[0] += elapsed;
            }
            else
            {
                heldDir[0] = 0;
                holding[0] = 0;
            }

            if (controls.UI_RIGHT)
            {
                heldDir[1] += elapsed;
                holding[1] += elapsed;
            }
            else
            {
                heldDir[1] = 0;
                holding[1] = 0;
            }
        }

		moveBoxes();

		menuItems.sort(sortByOrder);

		super.update(elapsed);
    }
}