package;

import editors.MasterEditorMenu;
import flixel.input.keyboard.FlxKey;
import flixel.util.FlxColor;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.effects.FlxFlicker;
import flixel.group.FlxSpriteGroup.FlxTypedSpriteGroup;
import flixel.util.FlxSort;
import flixel.math.FlxMath;
import flixel.math.FlxAngle;
import flixel.group.FlxGroup.FlxTypedGroup;

class ZSprite extends FlxSprite
{
    public var order:Float = 0;
}

class MainMenuState extends MusicBeatState {
	var menuItems:FlxTypedGroup<ZSprite>;
    var buttons:Array<ZSprite> = [];
	var artBoxes:Array<ZSprite> = [];
	var selectedSomethin:Bool = false;

	var optionShit:Array<String> = [
		'story_mode',
 		'freeplay',
		'promo',
		'options' 
	];

	public static var engineVersion:String = '0.1'; // This is also used for Discord RPC
	public static var selected:Int = 0;

	inline function toRad(input:Float)
		return FlxAngle.TO_RAD * input;

    override function create()
    {
		persistentUpdate = true;
		persistentDraw = true;
		super.create();
		debugKeys = ClientPrefs.copyKey(ClientPrefs.keyBinds.get('debug_1'));

		Paths.loadTheFirstEnabledMod();
        FlxG.mouse.visible = true;
		FlxG.camera.bgColor = FlxColor.BLACK;

		var bg:ZSprite = cast new ZSprite().loadGraphic(Paths.image('newmenuu/mainmenu/menuBG'));
		bg.scrollFactor.set();
		bg.updateHitbox();
		bg.screenCenter();
		bg.antialiasing = ClientPrefs.globalAntialiasing;
		add(bg);

		MusicBeatState.playMenuMusic();

		menuItems = new FlxTypedGroup<ZSprite>();
        
        for(option in optionShit){
			var art = new ZSprite();
			art.loadGraphic(Paths.image("newmenuu/mainmenu/cover_" + option));
			art.scrollFactor.set();
			art.antialiasing = false;
			art.ID = artBoxes.length;

			var butt = new ZSprite();
			butt.loadGraphic(Paths.image("newmenuu/mainmenu/menu_" + option));
			butt.scrollFactor.set();
			butt.antialiasing = false;
			butt.ID = art.ID;

			artBoxes.push(art);
			buttons.push(butt);

			menuItems.add(butt);
            menuItems.add(art);
        }
		add(menuItems);

		changeItem();

		moveBoxes(1);
    }

	function onSelected()
	{
		if (selectedSomethin)return;
		if (optionShit[selected] == 'promo')
		{
			CoolUtil.browserLoad('http://www.tailsgetstrolled.org/');
			return;
		}
        trace(selected);

		selectedSomethin = true;

		FlxG.sound.play(Paths.sound('confirmMenu'));

		FlxG.mouse.visible = false;

/* 		for (spr in [creditButton, jukeboxButton])
			FlxTween.tween(spr, {alpha: 0}, 0.4, {
				ease: FlxEase.quadOut,
				onComplete: function(twn:FlxTween)
				{
					spr.kill();
				}
			});
 */
		menuItems.forEach(function(spr)
		{
			if (selected != spr.ID)
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
					switch (optionShit[selected])
					{
						case 'story_mode':
							MusicBeatState.switchState(new StoryMenuState());
						case 'freeplay':
							MusicBeatState.switchState(new FreeplayState());
						case 'options':
							LoadingState.loadAndSwitchState(new options.OptionsState());
					}
				});
			}
		});
	}

    function changeItem(?val:Int=0, absolute:Bool=false){
		var difference = absolute?Math.abs(selected - val):val;
        if(difference != 0)
			FlxG.sound.play(Paths.sound('scrollMenu'));

        if(absolute)
            selected = val;
        else
            selected += val;

        if(selected >= menuItems.members.length)
            selected = 0; 
        else if(selected < 0)
            selected = menuItems.members.length-1;
    }
    
	function sortByOrder(wat:Int, Obj1:ZSprite, Obj2:ZSprite):Int
		return FlxSort.byValues(FlxSort.ASCENDING, Obj1.order, Obj2.order);
	
	var originX = FlxG.width / 2;
	var originY = FlxG.height / 2 + 310;

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

			var input = (idx - selected) * rads;
			var desiredX = FlxMath.fastSin(input) * 450;
			var desiredY = -(FlxMath.fastCos(input) * 275);

			var shit = FlxMath.fastSin(input);

			var scaleX = FlxMath.lerp(obj.scale.x, 1 - (.3 * Math.abs(shit)), lerpVal);
			var scaleY = FlxMath.lerp(obj.scale.y, 1 - (.3 * Math.abs(shit)), lerpVal);

			obj.scale.set(scaleX, scaleY);
			obj.updateHitbox();
			obj.x = FlxMath.lerp(obj.x, originX - obj.width / 2 + desiredX, lerpVal);
			obj.y = FlxMath.lerp(obj.y, originY - obj.height / 2 + desiredY, lerpVal);

			if (but != null)
			{
				but.order = obj.order + 1;
				but.alpha = obj.alpha;
				but.visible = obj.visible;


				var scaleX = FlxMath.lerp(but.scale.x, 1 - (.3 * Math.abs(shit)), lerpVal);
				var scaleY = FlxMath.lerp(but.scale.y, 1 - (.3 * Math.abs(shit)), lerpVal);

				but.scale.set(scaleX, scaleY);
				but.updateHitbox();
				but.x = (obj.x - (but.width - obj.width) / 2);
				but.y = (obj.y + (415 * scaleX));
			}
		}

	}
	var debugKeys:Array<FlxKey>;
    override function update(elapsed:Float){
        super.update(elapsed);
		if (FlxG.sound.music != null && FlxG.sound.music.volume < 0.8)
		{
			FlxG.sound.music.volume += 0.5 * FlxG.elapsed;
		}



		if (FlxG.keys.justPressed.CONTROL)
			Paths.clearUnusedMemory();

		if (!selectedSomethin){
			if (controls.ACCEPT)
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

    }
}