package funkin.states.options;

import flixel.addons.transition.FlxTransitionableState;

class OptionsState extends MusicBeatState 
{
	var daSubstate:OptionsSubstate;

	var transCamera:FlxCamera; // JUST for the transition	
	var transitioned:Bool = false;

	override function create()
	{
		persistentUpdate = true;
		persistentDraw = true;

		daSubstate = new OptionsSubstate(true);
		daSubstate.goBack = (changedOptions:Array<String>)->{
			FadeTransitionSubstate.nextCamera = transCamera;
			MusicBeatState.switchState(new MainMenuState());
		};
		openSubState(daSubstate);

		super.create();

		subStateOpened.addOnce((_) -> {
			transCamera = new FlxCamera();
			transCamera.bgColor = 0;
			FlxG.cameras.add(transCamera, false);
		});

		var bg = new funkin.objects.CoolMenuBG(Paths.image('menuDesat', null, false), 0xff7186fd);
		add(bg);
	}

	override public function resetSubState(){
		super.resetSubState();
		if (!transitioned){
			transitioned = true;
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
			FlxG.switchState(nextState);
		});

		if (FlxTransitionableState.skipNextTransOut)
		{
			FlxTransitionableState.skipNextTransOut = false;
			finishTransOut();
		}
	}


	override public function transitionIn(?OnEnter:Void->Void):Void {} // so the super.create doesnt transition
	override public function transitionOut(?OnExit:Void->Void):Void {} // same as transitionin
}