package funkin.states.options;

import funkin.objects.hud.BaseHUD;
import funkin.objects.RatingGroup;
import funkin.objects.RatingGroup.RatingSprite;

import flixel.util.FlxColor;
import flixel.text.FlxText;
import flixel.math.FlxPoint;

// since the rating graphics are now centered to the sprites position the hitbox got fucked up, so TODO: fix that ig 

class ComboPositionSubstate extends MusicBeatSubstate
{
	//// Preview	
	var judge:RatingSprite;
	var combo:Array<RatingSprite>;
	var timing:FlxText;

	//// Offset Texts
	var txt_rating:FlxText;
	var txt_combo:FlxText;
	var txt_timing:FlxText;

	////
	public var camHUD:FlxCamera;
	private final fuckingBgColor:FlxColor;
	private final canClose:Bool = true;

	public function new(?bgColor:FlxColor, ?canClose:Bool = true){
		super();

		this.fuckingBgColor = bgColor==null ? 0x00000000 : bgColor;
		this.canClose = canClose != false;
	}

	override public function create()
	{
		camHUD = new FlxCamera();
		camHUD.bgColor = fuckingBgColor;
		FlxG.cameras.add(camHUD, false);

		this.cameras = [camHUD];

		FlxG.mouse.getScreenPosition(camHUD, curMousePos);
		prevMousePos.copyFrom(curMousePos);

		var ratingName:Null<String> = null;
		var ratingColor:Null<FlxColor> = null;

		if (PlayState.instance != null && PlayState.instance.hud != null) // could be cool
		{
			var hud = PlayState.instance.hud;
			var highestJudgement = hud.displayedJudges[0];
			
			if (highestJudgement != null){
				ratingName = highestJudgement;
				ratingColor = hud.judgeColours.get(ratingName);
			}
		}   

		if (ratingName == null)
			ratingName = ClientPrefs.useEpics ? "epic" : "sick";

		if (ratingColor == null){
			if (BaseHUD._judgeColours.exists(ratingName))
				ratingColor = BaseHUD._judgeColours.get(ratingName);
			else
				ratingColor = 0xFFFFFFFF;
		}
			
		////////
		var rat = new RatingGroup();
		
		////
		judge = rat.displayJudgment(ratingName);
		judge.cameras = [camHUD];
		add(judge);

		////
		var comboColor = ClientPrefs.coloredCombos ? ratingColor : 0xFFFFFFFF;

		for (num in combo = rat.displayCombo(10 + Std.random(980))){
			num.color = comboColor;
			num.cameras = [camHUD];
			add(num);
		};

		////
		timing = new FlxText(0, 0, 0, "0 ms");
		timing.setFormat(Paths.font("calibri.ttf"), 28, 0xFFFFFFFF, CENTER, FlxTextBorderStyle.OUTLINE, 0xFF000000);
		timing.color = ratingColor;
		timing.scrollFactor.set();
		timing.borderSize = 1.25;
		timing.cameras = [camHUD];
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
			text.setFormat(Paths.font("calibri.ttf"), 24, 0xFFFFFFFF, LEFT, FlxTextBorderStyle.OUTLINE, 0xFF000000);
			text.borderSize = 1.5;
			text.cameras = [camHUD];
			add(text);

			return text;
		}

		makeText(0).text = "Rating Offset:";
		txt_rating = makeText(1);
		makeText(2).text = "Combo Offset:";
		txt_combo = makeText(3);
		makeText(4).text = "Timing Offset:";
		txt_timing = makeText(5);


		updateRatingPos();
		updateComboPos();
		updateTimingPos();
		
		super.create();
	}

	////
	function updateRatingPos(){
		judge.x = FlxG.width * 0.5 + ClientPrefs.comboOffset[0];
		judge.y = FlxG.height * 0.5 - ClientPrefs.comboOffset[1];
		
		txt_rating.text = '[${ClientPrefs.comboOffset[0]}, ${ClientPrefs.comboOffset[1]}]';
	}

	function updateComboPos(){
		var x = FlxG.width * 0.5 + ClientPrefs.comboOffset[2];
		var y = FlxG.height * 0.5 - ClientPrefs.comboOffset[3];

		x -= combo[0].width;

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
	// 0: judge, 1: combo, 2: timing, null: NOTHING.
	var mouseGrabbed:Null<Int> = null; 
	var keyboardGrabbed:Int = 0;

	var prevMousePos:FlxPoint = FlxPoint.get();
	var curMousePos:FlxPoint = FlxPoint.get();

	// fuck this nonsense
	function sowy(okay:Any){
		if (okay is Array){
			var okay:Array<Dynamic> = okay;
			for (i in okay){
				if (FlxG.mouse.overlaps(i, camHUD))
					return true;
			}
			return false;
		}else if (okay is FlxSprite){
			return FlxG.mouse.overlaps(okay, camHUD);
		}
		return false;
	}

	override public function update(elapsed)
	{
		if (FlxG.mouse.justPressed){
			mouseGrabbed=null;

			var toCheck:Array<Dynamic> = [timing, combo, judge];
			for (idx => chk in toCheck){				
				if (sowy(chk)){
					mouseGrabbed = toCheck.length-1-idx;
					break;
				}
			}
		}
		if (FlxG.mouse.justReleased)
			mouseGrabbed = null;

		FlxG.mouse.getScreenPosition(camHUD, curMousePos);
		var deltaX = Std.int(curMousePos.x - prevMousePos.x);
		var deltaY = Std.int(curMousePos.y - prevMousePos.y);
		prevMousePos.copyFrom(curMousePos);

		if (deltaX != 0 || deltaY != 0){
			switch(mouseGrabbed){
				case 0:
					ClientPrefs.comboOffset[0] += deltaX;
					ClientPrefs.comboOffset[1] -= deltaY; // Why the fuck is this inverted!!!!!!!!!!!!!!!!!!!!!!
					updateRatingPos();
				case 1:
					ClientPrefs.comboOffset[2] += deltaX;
					ClientPrefs.comboOffset[3] -= deltaY;
					updateComboPos();
				case 2:
					ClientPrefs.comboOffset[4] += deltaX;
					ClientPrefs.comboOffset[5] -= deltaY;
					updateTimingPos();			  
			}
		}

		if (canClose && controls.BACK){
			FlxG.sound.play(Paths.sound("cancelMenu"));
			close();
		}

		super.update(elapsed);
	}

	override public function destroy(){
		super.destroy();
		curMousePos.put();
		prevMousePos.put();		
		FlxG.cameras.remove(camHUD, true);
	}
}