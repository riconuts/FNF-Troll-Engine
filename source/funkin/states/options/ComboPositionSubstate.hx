package funkin.states.options;

import funkin.objects.hud.BaseHUD;
import funkin.states.PlayState.RatingSprite;

import flixel.util.FlxColor;
import flixel.text.FlxText;
import flixel.math.FlxPoint;
import flixel.group.FlxGroup.FlxTypedGroup;

class ComboPositionSubstate extends MusicBeatSubstate
{
	//// Preview	
	var rating:RatingSprite;
	var combo:FlxTypedGroup<RatingSprite>;
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
			
		////
		
		rating = new RatingSprite();
		rating.scale.set(0.7, 0.7);
		rating.scrollFactor.set();
		rating.cameras = [camHUD];
		rating.loadGraphic(Paths.image(ratingName));
		rating.updateHitbox();
		add(rating);


		combo = new FlxTypedGroup<RatingSprite>();
		var comboColor = ClientPrefs.coloredCombos ? ratingColor : 0xFFFFFFFF;
		var splitCombo = Std.string(Std.random(1000)).split("");
		while (splitCombo.length < 3) splitCombo.unshift("0");
		
		for (number in splitCombo){
			var num = new RatingSprite();
			num.loadGraphic(Paths.image('num$number'));
			num.scale.set(0.5, 0.5);
			num.scrollFactor.set();
			num.color = comboColor;
			num.cameras = [camHUD];
			num.updateHitbox();
			combo.add(num);
		};
		add(combo);


		timing = new FlxText(0, 0, 0, "0 ms");
		timing.setFormat(Paths.font("calibri.ttf"), 28, 0xFFFFFFFF, CENTER, FlxTextBorderStyle.OUTLINE, 0xFF000000);
		timing.color = ratingColor;
		timing.scrollFactor.set();
		timing.borderSize = 1.25;
		timing.cameras = [camHUD];
		timing.updateHitbox();
		add(timing);


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
		rating.screenCenter();
		rating.x += ClientPrefs.comboOffset[0];
		rating.y -= ClientPrefs.comboOffset[1];
		
		txt_rating.text = '[${ClientPrefs.comboOffset[0]}, ${ClientPrefs.comboOffset[1]}]';
	}

	function updateComboPos(){
		var numStartX:Float = (FlxG.width - combo.length * 41) * 0.5 + ClientPrefs.comboOffset[2];

		for (idx in 0...combo.members.length){
			var num = combo.members[idx];
			num.x = numStartX + 41.5 * idx;
			num.screenCenter(Y);
			num.y -= ClientPrefs.comboOffset[3];
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
	// 0: rating, 1: combo, 2: timing, null: NOTHING.
	var mouseGrabbed:Null<Int> = null; 
	var keyboardGrabbed:Int = 0;

	var prevMousePos:FlxPoint = FlxPoint.get();
	var curMousePos:FlxPoint = FlxPoint.get();

	override public function update(elapsed)
	{
		if (FlxG.mouse.justPressed){
			var toCheck = [timing, combo, rating];
			
			mouseGrabbed=null;
			for (idx in 0...toCheck.length){
				var chk = toCheck[idx];
				if (FlxG.mouse.overlaps(chk, camHUD)){
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