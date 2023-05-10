package newoptions;

import flixel.addons.transition.FlxTransitionableState;


class OptionsState extends MusicBeatState {
	var transCamera:FlxCamera; // JUST for the transition

	override public function switchTo(to)
	{
		FadeTransitionSubstate.nextCamera = daSubstate.transCamera;
		return super.switchTo(to);
	}
	var daSubstate:OptionsSubstate;
    var transitoned:Bool = false;
    var bg:FlxSprite;
	var backdrop:flixel.addons.display.FlxBackdrop;

    override function create(){
        daSubstate = new OptionsSubstate(true);
		daSubstate.goBack = (function(changedOptions:Array<String>){
            MusicBeatState.switchState(new MainMenuState());
        }); 
 		bg = new FlxSprite().loadGraphic(Paths.image('newmenuu/optionsbg'));
		bg.screenCenter(XY);
		add(bg);
        
		backdrop = new flixel.addons.display.FlxBackdrop(Paths.image("grid"));
		backdrop.velocity.set(30, 30);
		backdrop.alpha = 0.15;
		add(backdrop); 
		openSubState(daSubstate);


        persistentUpdate=true;
        persistentDraw=true;
        super.create();

    }

	override public function resetSubState(){
		super.resetSubState();
		if (!transitoned){
			transitoned = true;
			transCamera = daSubstate.transCamera;
/* 			bg.cameras = [FlxG.cameras.list[0]];
			backdrop.cameras = [FlxG.cameras.list[0]]; */
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
				{
					finishTransIn();
				}
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