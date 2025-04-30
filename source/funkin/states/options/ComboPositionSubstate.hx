package funkin.states.options;

import funkin.objects.hud.BaseHUD;
import funkin.objects.RatingGroup;
import funkin.objects.RatingGroup.RatingSprite;

import flixel.util.FlxColor;
import flixel.text.FlxText;
import flixel.math.FlxPoint;

private enum abstract RatingElement(Int) from Int to Int {
	var NONE = -1;
	var JUDGE = 0;
	var COMBO = 1;
	var TIMER = 2;
}

class ComboPositionSubstate extends MusicBeatSubstate
{
	////
	private final fuckingBgColor:FlxColor;
	private final canClose:Bool = true;

	//// Preview	
	var judge:RatingSprite;
	var combo:Array<RatingSprite>;
	var timing:FlxText;

	//// Offset Texts
	var txt_rating:FlxText;
	var txt_combo:FlxText;
	var txt_timing:FlxText;

	///
	var mouseGrabbed:RatingElement = NONE; 
	var keyboardGrabbed:RatingElement = NONE;

	var prevMousePos:FlxPoint = FlxPoint.get();
	var curMousePos:FlxPoint = FlxPoint.get();

	public function new(?bgColor:FlxColor, ?canClose:Bool = true){
		super();

		this.fuckingBgColor = bgColor==null ? 0x00000000 : bgColor;
		this.canClose = canClose != false;
	}

	override public function create()
	{
		camera = new FlxCamera();
		camera.bgColor = fuckingBgColor;
		FlxG.cameras.add(camera, false);
		this.cameras = [camera];

		FlxG.mouse.getScreenPosition(camera, prevMousePos);

		////
		var judgeName:Null<String> = null;
		var judgeColor:Null<FlxColor> = null;

		if (PlayState.instance != null && PlayState.instance.hud != null) // could be cool
		{
			var hud = PlayState.instance.hud;
			var highestJudgement = hud.displayedJudges[0];
			
			if (highestJudgement != null){
				judgeName = highestJudgement;
				judgeColor = hud.judgeColours.get(judgeName);
			}
		}   

		if (judgeName == null)
			judgeName = ClientPrefs.useEpics ? "epic" : "sick";

		if (judgeColor == null){
			if (BaseHUD._judgeColours.exists(judgeName))
				judgeColor = BaseHUD._judgeColours.get(judgeName);
			else
				judgeColor = 0xFFFFFFFF;
		}

		var comboColor:FlxColor = ClientPrefs.coloredCombos ? judgeColor : 0xFFFFFFFF;
		
		////////
		var rat = new RatingGroup();
		rat.exists = false;
		add(rat);
		
		////
		judge = rat.displayJudgment(judgeName);
		judge.cameras = cameras;
		add(judge);

		////
		for (num in combo = rat.displayCombo(10 + Std.random(980))){
			num.color = comboColor;
			num.cameras = cameras;
			add(num);
		};

		////
		timing = new FlxText(0, 0, 0, "0 ms");
		#if tgt
		timing.setFormat(Paths.font("calibri.ttf"), 28, 0xFFFFFFFF, CENTER, FlxTextBorderStyle.OUTLINE, 0xFF000000);
		#else
		timing.setFormat(Paths.font("vcr.ttf"), 28, 0xFFFFFFFF, CENTER, FlxTextBorderStyle.OUTLINE, 0xFF000000);
		#end
		timing.color = judgeColor;
		timing.scrollFactor.set();
		timing.borderSize = 1.25;
		timing.cameras = cameras;
		timing.updateHitbox();
		add(timing);

		////
		function makeText(i){
			var text:FlxText = new FlxText(
				10, 
				48 + (i * 30) + 24 * Math.floor(i / 2), 
				0, 
				'', 
				24
			);
			text.scrollFactor.set();
			#if tgt
			text.setFormat(Paths.font("calibri.ttf"), 24, 0xFFFFFFFF, LEFT, FlxTextBorderStyle.OUTLINE, 0xFF000000);
			text.borderSize = 1.5;
			#else
			text.setFormat(Paths.font("vcr.ttf"), 24, 0xFFFFFFFF, LEFT, FlxTextBorderStyle.OUTLINE, 0xFF000000);
			text.borderSize = 2;
			#end
			text.cameras = cameras;
			add(text);

			return text;
		}

		makeText(0).text = "Judgement Offset:";
		txt_rating = makeText(1);
		makeText(2).text = "Combo Offset:";
		txt_combo = makeText(3);
		makeText(4).text = "Timing Offset:";
		txt_timing = makeText(5);

		updateJudgePos();
		updateComboPos();
		updateTimingPos();
		
		super.create();
	}

	////
	function updateJudgePos(){
		judge.x = FlxG.width * 0.5 + ClientPrefs.comboOffset[0];
		judge.y = FlxG.height * 0.5 - ClientPrefs.comboOffset[1];
		
		txt_rating.text = '[${ClientPrefs.comboOffset[0]}, ${ClientPrefs.comboOffset[1]}]';
	}

	function updateComboPos(){
		var x = FlxG.width * 0.5 + ClientPrefs.comboOffset[2] - combo[0].width;
		var y = FlxG.height * 0.5 - ClientPrefs.comboOffset[3];

		for (i in 0...combo.length){
			var spr:RatingSprite = combo[i];
			spr.x = x + i *	spr.width;
			spr.y = y;
		}

		txt_combo.text = '[${ClientPrefs.comboOffset[2]}, ${ClientPrefs.comboOffset[3]}]';
	}

	function updateTimingPos() {
		timing.screenCenter();
		timing.x += ClientPrefs.comboOffset[4];
		timing.y -= ClientPrefs.comboOffset[5];

		txt_timing.text = '[${ClientPrefs.comboOffset[4]}, ${ClientPrefs.comboOffset[5]}]';
	}

	////

	// fuck this nonsense
	function sowy(okay:Any){
		final mp = curMousePos;

		if (okay is Array) {
			for (i in (okay:Array<Dynamic>))
				if (sowy(i)) return true;

			return false;
		}
		else if (okay is RatingSprite) {
			var okay = (okay:RatingSprite);
			var hW = okay.width * 0.5;
			var hH = okay.height * 0.5;

			return (Math.abs(okay.x - mp.x) <= hW && Math.abs(okay.y - mp.y) <= hH);
		}
		else if (okay is FlxSprite) {
			return FlxG.mouse.overlaps(okay, camera);
		}
		
		return false;
	}

	override public function update(elapsed)
	{
		//// Update mouse
		FlxG.mouse.getScreenPosition(camera, curMousePos);
		var deltaX:Int = Std.int(curMousePos.x - prevMousePos.x);
		var deltaY:Int = Std.int(curMousePos.y - prevMousePos.y);
		prevMousePos.set(curMousePos.x, curMousePos.y);

		FlxG.mouse.visible = true;

		if (FlxG.mouse.justPressed){
			mouseGrabbed = NONE;

			var toCheck:Array<Dynamic> = [timing, combo, judge];
			for (idx => chk in toCheck){				
				if (sowy(chk)){
					mouseGrabbed = toCheck.length-1-idx;
					break;
				}
			}
		}
		if (FlxG.mouse.justReleased)
			mouseGrabbed = NONE;

		if (deltaX != 0 || deltaY != 0){
			switch(mouseGrabbed){
				default:

				case JUDGE:
					ClientPrefs.comboOffset[0] += deltaX;
					ClientPrefs.comboOffset[1] -= deltaY; // Why the fuck is this inverted!!!!!!!!!!!!!!!!!!!!!!
					updateJudgePos();
				case COMBO:
					ClientPrefs.comboOffset[2] += deltaX;
					ClientPrefs.comboOffset[3] -= deltaY;
					updateComboPos();
				case TIMER:
					ClientPrefs.comboOffset[4] += deltaX;
					ClientPrefs.comboOffset[5] -= deltaY;
					updateTimingPos();			  
			}
		}

		//// Update keyboard
		var addNum:Int = 1;
		if(FlxG.keys.pressed.SHIFT) addNum = 10;

		// bringing back this old ass shit for now JUST because the keybinds are helpful
		var controlArray:Array<Bool> = [
			FlxG.keys.justPressed.LEFT,
			FlxG.keys.justPressed.RIGHT,
			FlxG.keys.justPressed.UP,
			FlxG.keys.justPressed.DOWN,
		
			FlxG.keys.justPressed.A,
			FlxG.keys.justPressed.D,
			FlxG.keys.justPressed.W,
			FlxG.keys.justPressed.S,

			FlxG.keys.justPressed.J,
			FlxG.keys.justPressed.L,
			FlxG.keys.justPressed.I,
			FlxG.keys.justPressed.K
		];

		if(controlArray.contains(true)) {
			for (i in 0...controlArray.length){
				if(controlArray[i]){
					switch(i)
					{
						case 0:
							ClientPrefs.comboOffset[0] -= addNum;
						case 1:
							ClientPrefs.comboOffset[0] += addNum;
						case 2:
							ClientPrefs.comboOffset[1] += addNum;
						case 3:
							ClientPrefs.comboOffset[1] -= addNum;
						
						////
						case 4:
							ClientPrefs.comboOffset[2] -= addNum;
						case 5:
							ClientPrefs.comboOffset[2] += addNum;
						case 6:
							ClientPrefs.comboOffset[3] += addNum;
						case 7:
							ClientPrefs.comboOffset[3] -= addNum;

						////
						case 8:
							ClientPrefs.comboOffset[4] -= addNum;
						case 9:
							ClientPrefs.comboOffset[4] += addNum;
						case 10:
							ClientPrefs.comboOffset[5] += addNum;
						case 11:
							ClientPrefs.comboOffset[5] -= addNum;							
					}
					updateJudgePos();
					updateComboPos();
					updateTimingPos();
				}
			}
		}

		if(controls.RESET) {
			ClientPrefs.comboOffset[0] = -60;
			ClientPrefs.comboOffset[1] = 60;
			ClientPrefs.comboOffset[2] = -260;
			ClientPrefs.comboOffset[3] = -80;
			ClientPrefs.comboOffset[4] = 0;
			ClientPrefs.comboOffset[5] = 0;
			updateJudgePos();
			updateComboPos();
			updateTimingPos();
		}

		////
		super.update(elapsed);

		if (canClose && controls.BACK) {
			FlxG.sound.play(Paths.sound("cancelMenu"));
			close();
		}
		
	}

	override public function close(){
		FlxG.cameras.remove(camera, true);
		super.close();
	}
	
	override public function destroy(){
		super.destroy();
		
		curMousePos.put();
		prevMousePos.put();
	}
}