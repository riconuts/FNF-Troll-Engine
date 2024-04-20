package options;

import flixel.addons.transition.FlxTransitionableState;

class OptionsState extends MusicBeatState 
{
    var bg:FlxSprite;
	var backdrop:flixel.addons.display.FlxBackdrop;

	var daSubstate:OptionsSubstate;

	var transCamera:FlxCamera; // JUST for the transition	
    var transitioned:Bool = false;

    override function create(){
        daSubstate = new OptionsSubstate(true);
		daSubstate.goBack = (changedOptions:Array<String>)->{
			FadeTransitionSubstate.nextCamera = daSubstate.transCamera;
			MusicBeatState.switchState(new MainMenuState());
        };

		#if tgt
		final bgGraphic = Paths.image('tgtmenus/optionsbg');
		bg = new FlxSprite((FlxG.width - bgGraphic.width) * 0.5, (FlxG.height - bgGraphic.height) * 0.5, bgGraphic);
		#else
		final bgGraphic = Paths.image('menuDesat');
		bg = new FlxSprite((FlxG.width - bgGraphic.width) * 0.5, (FlxG.height - bgGraphic.height) * 0.5, bgGraphic);
		bg.color = 0xFFea71fd;
		#end
		add(bg);

		backdrop = new flixel.addons.display.FlxBackdrop(Paths.image("grid"));
		backdrop.velocity.set(30, 30);
		backdrop.alpha = 0.15;
		add(backdrop);

		openSubState(daSubstate);

        persistentUpdate=true;
        persistentDraw=true;

        super.create();

		#if !tgt
		// ill clean this up later haha

		var adjustColor = new shaders.AdjustColor();
		bg.shader = adjustColor.shader;
		adjustColor.contrast = 1.0;
		adjustColor.brightness = -0.125;

		bg.alpha = 0.25;
		bg.blend = INVERT;
		bg.setColorTransform(-1, -1, -1, 1,
			Std.int(255 + bg.color.red / 3), 
			Std.int(255 + bg.color.green / 3), 
			Std.int(255 + bg.color.blue / 3),
			0
		);

		var gradient = flixel.util.FlxGradient.createGradientFlxSprite(FlxG.width, FlxG.height, [0xFFFFFFFF, 0xFF000000]);
		gradient.alpha = 1.0;
		insert(0, gradient);

		var bruh = new FlxSprite(bg.x, bg.y).makeGraphic(bg.frameWidth, bg.frameHeight, 0x00000000, false, 'OptionsState_bg');
		bruh.stamp(bg, 0, 0);

		bg.destroy();
		remove(bg, true);

		var grid = new openfl.display.BitmapData(2, 2);
		grid.setPixel32(0, 0, 0xFFC0C0C0);
		grid.setPixel32(1, 1, 0xFFC0C0C0);

		backdrop.loadGraphic(grid, false, 0, 0, false, 'OptionsState_grid');
		backdrop.scale.set(FlxG.height / 3, FlxG.height / 3);
		backdrop.updateHitbox();
		backdrop.antialiasing = true;

		backdrop.alpha = 0.5;
		backdrop.blend = ADD;
		backdrop.color = 0xFFea71fd;
		
		var bg = bruh;
		bg.blend = cast 9;
		bg.alpha = 1.0;
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