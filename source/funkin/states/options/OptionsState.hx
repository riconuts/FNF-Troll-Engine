package funkin.states.options;

import flixel.addons.transition.FlxTransitionableState;

class OptionsState extends MusicBeatState 
{
    var bg:FlxSprite;
	var backdrop:flixel.addons.display.FlxBackdrop;

	var daSubstate:OptionsSubstate;

	var transCamera:FlxCamera; // JUST for the transition	
    var transitioned:Bool = false;

    override function create()
	{
        persistentUpdate = true;
        persistentDraw = true;

        daSubstate = new OptionsSubstate(true);
		daSubstate.goBack = (changedOptions:Array<String>)->{
			FadeTransitionSubstate.nextCamera = daSubstate.transCamera;
			MusicBeatState.switchState(new MainMenuState());
        };

		openSubState(daSubstate);

        super.create();

		#if tgt
		var bgGraphic = Paths.image('tgtmenus/optionsbg');
		bg = new FlxSprite((FlxG.width - bgGraphic.width) * 0.5, (FlxG.height - bgGraphic.height) * 0.5, bgGraphic);
		add(bg);

		backdrop = new flixel.addons.display.FlxBackdrop(Paths.image("grid"));
		backdrop.velocity.set(30, 30);
		backdrop.alpha = 0.15;
		add(backdrop);

		#else
		
		var color = 0xff7186fd; //0xFFea71fd;
		var bgGraphic = Paths.image('menuDesat');
		var adjustColor = new funkin.objects.shaders.AdjustColor();
		adjustColor.contrast = 1.0;
		adjustColor.brightness = -0.125;

		bg = new FlxSprite((FlxG.width - bgGraphic.width) * 0.5, (FlxG.height - bgGraphic.height) * 0.5, bgGraphic);
		bg.shader = adjustColor.shader;
		bg.blend = INVERT;
		bg.color = color;
		bg.alpha = 0.25;
		bg.setColorTransform(-1, -1, -1, 1,
			Std.int(255 + bg.color.red / 3), 
			Std.int(255 + bg.color.green / 3), 
			Std.int(255 + bg.color.blue / 3),
			0
		);

		var bg2 = new FlxSprite(bg.x, bg.y).makeGraphic(bg.frameWidth, bg.frameHeight, 0x00000000, false, 'OptionsState_bg');
		bg2.blend = MULTIPLY;
		bg2.stamp(bg);
		
		bg.destroy();
		bg = bg2;

		var grid = new openfl.display.BitmapData(2, 2);
		grid.setPixel32(0, 0, 0xFFC0C0C0);
		grid.setPixel32(1, 1, 0xFFC0C0C0);

		var grid = flixel.graphics.FlxGraphic.fromBitmapData(grid, false, 'OptionsState_grid');

		backdrop = new flixel.addons.display.FlxBackdrop(grid);
		backdrop.scale.x = backdrop.scale.y = FlxG.height / 3;
		backdrop.updateHitbox();
		backdrop.velocity.set(30, 30);
		backdrop.antialiasing = true;
		backdrop.color = color;
		backdrop.alpha = 0.5;
		backdrop.blend = ADD;

		var gradient = flixel.util.FlxGradient.createGradientFlxSprite(FlxG.width, FlxG.height, [0xFFFFFFFF, 0xFF000000]);

		add(gradient);
		add(backdrop);
		add(bg);
		#end
    }

	override public function resetSubState(){
		super.resetSubState();
		if (!transitioned){
			transitioned = true;
			transCamera = daSubstate.transCamera;
		    doDaInTrans();
        }
    }
    
	override function finishTransIn()
		subState.closeSubState();
	
    
    function doDaInTrans(){
		if (transIn != null)
		{
			if (FlxTransitionableState.skipNextTransIn)
			{
				FlxTransitionableState.skipNextTransIn = false;
				if (finishTransIn != null)
					finishTransIn();
				
				return;
			}

			var trans = Type.createInstance(transIn, []);
			subState.openSubState(trans);

			trans.finishCallback = finishTransIn;
			FadeTransitionSubstate.nextCamera = transCamera;
			trans.start(OUT);
		}
    }

	function doDaOutTrans(?OnExit:Void->Void){
		_onExit = OnExit;
		if (hasTransOut)
		{
			var trans = Type.createInstance(transOut, []);
			subState.openSubState(trans);

			trans.finishCallback = finishTransOut;
			trans.start(IN);
		}
		else
		{
			_onExit();
		}
    }

	override function transitionToState(nextState:FlxState):Void
	{
		// play the exit transition, and when it's done call FlxG.switchState
		_exiting = true;
		doDaOutTrans(function()
		{
			for (cam in daSubstate.camerasToRemove)
				FlxG.cameras.remove(cam);
			FlxG.switchState(nextState);
		});

		if (FlxTransitionableState.skipNextTransOut)
		{
			FlxTransitionableState.skipNextTransOut = false;
			finishTransOut();
		}
	}


	override public function transitionOut(?OnExit:Void->Void):Void{} // same as transitionin
	
	override public function transitionIn():Void{} // so the super.create doesnt transition
	

}