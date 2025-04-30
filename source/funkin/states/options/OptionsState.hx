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
			FadeTransitionSubstate.nextCamera = daSubstate.transCamera;
			MusicBeatState.switchState(new MainMenuState());
		};

		openSubState(daSubstate);

		super.create();

		#if tgt
		var bgGraphic = Paths.image('tgtmenus/optionsbg');
		var bg = new FlxSprite((FlxG.width - bgGraphic.width) * 0.5, (FlxG.height - bgGraphic.height) * 0.5, bgGraphic);

		if (FlxG.height < FlxG.width)
			bg.scale.x = bg.scale.y = (FlxG.height * 1.05) / bg.frameHeight;
		else
			bg.scale.x = bg.scale.y = (FlxG.width * 1.05) / bg.frameWidth;
		
		add(bg);

		var backdrop = new flixel.addons.display.FlxBackdrop(Paths.image("grid"));
		backdrop.velocity.set(30, 30);
		backdrop.scrollFactor.set();
		backdrop.alpha = 0.15;
		add(backdrop);

		#else
		var bg = new funkin.objects.CoolMenuBG(Paths.image('menuDesat', null, false), 0xff7186fd);
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


	override public function transitionIn(?OnEnter:Void->Void):Void {} // so the super.create doesnt transition
	override public function transitionOut(?OnExit:Void->Void):Void {} // same as transitionin
}