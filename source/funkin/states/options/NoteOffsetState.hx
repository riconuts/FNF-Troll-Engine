package funkin.states.options;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxCamera;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.ui.FlxBar;
import flixel.text.FlxText;
import flixel.math.FlxPoint;
import flixel.util.FlxColor;
import flixel.util.FlxStringUtil;
import funkin.scripts.FunkinHScript;
import flixel.addons.transition.FlxTransitionableState;
import funkin.states.options.ComboPositionSubstate;

using StringTools;

class NoteOffsetState extends MusicBeatState
{
	var stage:Stage;
	var stageScript:Null<FunkinHScript> = null;
	var boyfriend:Character;
	var gf:Character;

	public var camHUD:FlxCamera;
	public var camGame:FlxCamera;
	public var camOther:FlxCamera;

	var comboSubstate:ComboPositionSubstate;

	var barPercent:Float = 0;
	var delayMin:Int = 0;
	var delayMax:Int = 500;
	var timeBarBG:FlxSprite;
	var timeBar:FlxBar;
	var timeTxt:FlxText;
	var beatText:Alphabet;
	var beatTween:FlxTween;

	var changeModeText:FlxText;

	override public function create()
	{
		//// Cameras
		camGame = new FlxCamera();
		var camStageUnderlay = new FlxCamera();
		camHUD = new FlxCamera();
		camOther = new FlxCamera();
		
		camHUD.bgColor.alpha = 0;
		camOther.bgColor.alpha = 0;
		camStageUnderlay.bgColor.alpha = 0;

		FlxG.cameras.reset(camGame);
		FlxG.cameras.add(camStageUnderlay, false);
		FlxG.cameras.add(camHUD, false);
		FlxG.cameras.add(camOther, false);

		FadeTransitionSubstate.nextCamera = camOther;

		persistentUpdate = true;
		FlxG.sound.pause();

		//// Stage
		var stageId = 'stage' #if tgt + "1" #end;

		stage = new Stage(stageId);
		stage.buildStage();
		stageScript = stage.stageScript;
		add(stage);	

		var stageData = stage.stageData;
		var bgColor = FlxColor.fromString(stageData.bg_color);
		camGame.bgColor = bgColor == null ? 0xFF000000 : bgColor;

		////
		var stageOpacity = new FlxSprite().makeGraphic(2, 2, 0xFFFFFFFF);
		stageOpacity.color = 0xFF000000;
		stageOpacity.alpha = ClientPrefs.stageOpacity;
		stageOpacity.cameras=[camStageUnderlay]; // just to force it above camGame but below camHUD
		stageOpacity.scrollFactor.set();
		stageOpacity.screenCenter();
		stageOpacity.scale.set(FlxG.width * 3, FlxG.height * 3);
		add(stageOpacity);

		//// Characters
		var gfId:String = 'gf';
		var bfId:String = 'bf';

		gf = new Character(stageData.girlfriend[0], stageData.girlfriend[1], gfId);
		gf.setupCharacter();
		gf.x += gf.positionArray[0];
		gf.y += gf.positionArray[1];
		gf.scrollFactor.set(0.95, 0.95);
		add(gf);

		boyfriend = new Character(stageData.boyfriend[0], stageData.boyfriend[1], bfId, true);
		boyfriend.setupCharacter();
		boyfriend.x += boyfriend.positionArray[0];
		boyfriend.y += boyfriend.positionArray[1];
		add(boyfriend);

		// Stage Foreground
		add(stage.foreground);

		////
		comboSubstate = new ComboPositionSubstate(0, false);
		subStateClosed.add((ss)->
			this.destroySubStates = (ss != comboSubstate)
		);

		//// Note delay stuff
		beatText = new Alphabet(0, 0, 'Beat Hit!', true, false, 0.05, 0.6);
		beatText.cameras = [camHUD];
		beatText.scrollFactor.set();
		beatText.x += 260;
		beatText.alpha = 0;
		beatText.acceleration.y = 250;
		beatText.visible = false;
		add(beatText);
		
		timeTxt = new FlxText(0, 600, FlxG.width, "", 32);
		timeTxt.setFormat(Paths.font("calibri.ttf"), 32, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		timeTxt.scrollFactor.set();
		timeTxt.borderSize = 2;
		timeTxt.visible = false;
		timeTxt.cameras = [camHUD];

		barPercent = ClientPrefs.noteOffset;
		updateNoteDelay();
		
		timeBarBG = new FlxSprite(0, timeTxt.y + 8).loadGraphic(Paths.image('timeBar'));
		timeBarBG.setGraphicSize(Std.int(timeBarBG.width * 1.2));
		timeBarBG.updateHitbox();
		timeBarBG.cameras = [camHUD];
		timeBarBG.screenCenter(X);
		timeBarBG.visible = false;

		timeBar = new FlxBar(0, timeBarBG.y + 4, LEFT_TO_RIGHT, Std.int(timeBarBG.width - 8), Std.int(timeBarBG.height - 8), this, 'barPercent', delayMin, delayMax);
		timeBar.scrollFactor.set();
		timeBar.screenCenter(X);
		timeBar.createFilledBar(0xFF000000, 0xFFFFFFFF);
		timeBar.numDivisions = 800; //How much lag this causes?? Should i tone it down to idk, 400 or 200?
		timeBar.visible = false;
		timeBar.cameras = [camHUD];

		add(timeBarBG);
		add(timeBar);
		add(timeTxt);

		///////////////////////

		/*var blackBox:FlxSprite = new FlxSprite().makeGraphic(FlxG.width, 40, FlxColor.BLACK);
		blackBox.scrollFactor.set();
		blackBox.alpha = 0.6;
		blackBox.cameras = [camHUD];
		add(blackBox);

		changeModeText = new FlxText(0, 4, FlxG.width, "", 32);
		changeModeText.setFormat(Paths.font("calibri.ttf"), 32, FlxColor.WHITE, CENTER);
		changeModeText.scrollFactor.set();
		changeModeText.cameras = [camHUD];
		add(changeModeText);*/

		Conductor.changeBPM(128.0);
		FlxG.sound.playMusic(Paths.music('offsetSong'), 1 , true);

		// Focus camera on Boyfriend
		var bfCam = boyfriend.getCamera();
		var camFollowPos = new FlxObject(bfCam[0], bfCam[1]);
		add(camFollowPos);
		
		camGame.follow(camFollowPos);

		super.create();

		updateMode();
	}

	var holdTime:Float = 0;
	var onComboMenu:Bool = true;
	var holdingObjectType:Null<Bool> = null;

	var startMousePos:FlxPoint = new FlxPoint();
	var startComboOffset:FlxPoint = new FlxPoint();

	override public function update(elapsed:Float)
	{
		var addNum:Int = 1;
		if(FlxG.keys.pressed.SHIFT) addNum = 10;

		if(onComboMenu)
		{
			
		}
		else
		{
			if(controls.UI_LEFT_P)
			{
				barPercent = Math.max(delayMin, Math.min(ClientPrefs.noteOffset - 1, delayMax));
				updateNoteDelay();
			}
			else if(controls.UI_RIGHT_P)
			{
				barPercent = Math.max(delayMin, Math.min(ClientPrefs.noteOffset + 1, delayMax));
				updateNoteDelay();
			}

			var mult:Int = 1;
			if(controls.UI_LEFT || controls.UI_RIGHT)
			{
				holdTime += elapsed;
				if(controls.UI_LEFT) mult = -1;
			}

			if(controls.UI_LEFT_R || controls.UI_RIGHT_R) holdTime = 0;

			if(holdTime > 0.5)
			{
				barPercent += 100 * elapsed * mult;
				barPercent = Math.max(delayMin, Math.min(barPercent, delayMax));
				updateNoteDelay();
			}

			if(controls.RESET)
			{
				holdTime = 0;
				barPercent = 0;
				updateNoteDelay();
			}
		}

		/*if(controls.ACCEPT)
		{
			onComboMenu = !onComboMenu;
			updateMode();
		}*/

		if(controls.BACK)
		{
			if(zoomTween != null) zoomTween.cancel();
			if(beatTween != null) beatTween.cancel();

			persistentUpdate = false;
			MusicBeatState.switchState(new funkin.states.options.OptionsState());
			MusicBeatState.playMenuMusic(true);
			FlxG.mouse.visible = false;
		}

		Conductor.songPosition = FlxG.sound.music.time;
		super.update(elapsed);
	}

	var lastStepHit:Int = -1;
	override public function stepHit(){
		super.stepHit();

		if (lastStepHit == curStep)
			return;

		if (stageScript != null) {
			stageScript.set("curStep", curStep);
			stageScript.call("onStepHit");
		}

		lastStepHit = curStep;
	}

	var zoomTween:FlxTween;
	var lastBeatHit:Int = -1;
	override public function beatHit()
	{
		super.beatHit();

		if(lastBeatHit == curBeat)
			return;

		if (stageScript != null){
			stageScript.set("curBeat", curBeat);
			stageScript.call("onBeatHit");
		}

		if(curBeat % 2 == 0)
		{
			boyfriend.dance();
			gf.dance();
		}
		
		if(curBeat % 4 == 2)
		{
			FlxG.camera.zoom = 1.15;

			if(zoomTween != null) zoomTween.cancel();
			zoomTween = FlxTween.tween(FlxG.camera, {zoom: 1}, 1, {ease: FlxEase.circOut, onComplete: function(twn:FlxTween)
				{
					zoomTween = null;
				}
			});

			beatText.alpha = 1;
			beatText.y = 320;
			beatText.velocity.y = -150;

			if(beatTween != null) beatTween.cancel();
			beatTween = FlxTween.tween(beatText, {alpha: 0}, 1, {ease: FlxEase.sineIn, onComplete: function(twn:FlxTween)
				{
					beatTween = null;
				}
			});
		}

		lastBeatHit = curBeat;
	}

	function updateNoteDelay()
	{
		ClientPrefs.noteOffset = Math.round(barPercent);
		timeTxt.text = 'Current offset: ' + Math.floor(barPercent) + ' ms';
	}

	function updateMode()
	{
		/*timeBarBG.visible = !onComboMenu;
		timeBar.visible = !onComboMenu;
		timeTxt.visible = !onComboMenu;
		beatText.visible = !onComboMenu;*/

		if (onComboMenu){
			// changeModeText.text = '< Combo Offset (Press Accept to Switch) >';
			openSubState(comboSubstate);
		}else{
			// changeModeText.text = '< Note/Beat Delay (Press Accept to Switch) >';
			comboSubstate.close();
		}

		// changeModeText.text = changeModeText.text.toUpperCase();
		FlxG.mouse.visible = onComboMenu;
	}

	override function destroy()
	{
		comboSubstate.destroy();
		return super.destroy();
	}

	function getLowestState():FlxState{
		if (onComboMenu)
			return comboSubstate;
		else if (subState != null)
			return subState;
		
		return this;
	}

	var transitioned = false;
	override public function resetSubState(){
		super.resetSubState();

		if (!transitioned){
			transitioned = true;
			doDaInTrans();
		}
	}
	
	override function finishTransIn()
		getLowestState().closeSubState();
	
	
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
			getLowestState().openSubState(trans);

			trans.finishCallback = finishTransIn;
			FadeTransitionSubstate.nextCamera = camOther;
			trans.start(OUT);
		}
	}

	function doDaOutTrans(?OnExit:Void->Void){
		_onExit = OnExit;
		if (hasTransOut)
		{
			var trans = Type.createInstance(transOut, []);
			getLowestState().openSubState(trans);

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
		doDaOutTrans(MusicBeatState.switchState.bind(nextState));

		if (FlxTransitionableState.skipNextTransOut){
			FlxTransitionableState.skipNextTransOut = false;
			finishTransOut();
		}
	}


	override public function transitionOut(?_):Void{} // same as transitionin
	
	override public function transitionIn(?_):Void{} // so the super.create doesnt transition
}

/*
	NOTE: THE CHANGES MADE TO THIS STATE ARE JUST DUCT TAPE SO IT WORKS IN GAMEPLAY!!
	THIS SHIT SHOULD ABSOLUTELY BE MADE GOOD LATER!!
	(also removing the note offset part completely might not be the best move, just because having a visual indicator for the timing might be better for some ppl)
*/