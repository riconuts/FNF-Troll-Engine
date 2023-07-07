package newoptions;

import flixel.util.FlxColor;
import flixel.text.FlxText;
import PlayState.RatingSprite;
import flixel.group.FlxGroup.FlxTypedGroup;

class ComboOffsetSubstate extends MusicBeatSubstate{
    
    var rating:RatingSprite;
    var combo:FlxTypedGroup<RatingSprite>;
    var timingTxt:FlxText;

    var camHUD:FlxCamera;

    override public function create(){
        camHUD = new FlxCamera();
        FlxG.cameras.add(camHUD, false);

        var ratingName:Null<String> = null;
        var ratingColor:Null<FlxColor> = null;

        if (FlxG.state == PlayState.instance){ // would be cool
            var judgeMan = PlayState.instance.judgeManager; 
            
            ratingName = judgeMan.judgmentData.get(judgeMan.hittableJudgments[0]).internalName;
            ratingColor = PlayState.instance.hud.judgeColours.get(ratingName);

            camHUD.bgColor = FlxColor.fromRGBFloat(0, 0, 0, 0.6);
        }else
            camHUD.bgColor = FlxColor.fromRGBFloat(0, 0, 0, 0);

        if (ratingName == null)
            ratingName = ClientPrefs.useEpics ? "epic" : "sick";

        if (ratingColor == null){
            ratingColor = switch(ratingName){
                case "epic": 0xFFE367E5;
                case "sick": 0xFF00A2E8;
                default: 0xFFFFFFFF;
            }
        }
        //trace(ratingName, ratingColor.toHexString(false, false));
            
        
        rating = RatingSprite.newRating();
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
            var num = RatingSprite.newNumber();
            num.loadGraphic(Paths.image('num$number'));
            num.scrollFactor.set();
            num.color = ratingColor;
            num.cameras = [camHUD];
            num.updateHitbox();
            combo.add(num);
        };
        add(combo);


        timingTxt = new FlxText(0, 0, 0, "0 ms");
		timingTxt.setFormat(Paths.font("calibri.ttf"), 28, 0xFFFFFFFF, CENTER, FlxTextBorderStyle.OUTLINE, 0xFF000000);
        timingTxt.color = ratingColor;
        timingTxt.scrollFactor.set();
		timingTxt.borderSize = 1.25;
        timingTxt.cameras = [camHUD];
        timingTxt.updateHitbox();
        add(timingTxt);


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
    }

    function updateComboPos(){
        var numStartX:Float = (FlxG.width - combo.length * 41) * 0.5 + ClientPrefs.comboOffset[2];

        for (idx in 0...combo.members.length){
            var num = combo.members[idx];
            num.x = numStartX + 41.5 * idx;
			num.screenCenter(Y);
			num.y -= ClientPrefs.comboOffset[3];
        }
    }

    function updateTimingPos() {
        timingTxt.screenCenter();
		timingTxt.x += ClientPrefs.comboOffset[4];
		timingTxt.y -= ClientPrefs.comboOffset[5];
    }

    ////
    // 0: rating, 1: combo, 2: timing, null: NOTHING.
    var mouseGrabbed:Null<Int> = null; 
    var keyboardGrabbed:Int = 0;

    override public function update(elapsed)
    {
        if (FlxG.mouse.justPressed){
            var toCheck = [timingTxt, combo, rating];
            
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

        var deltaX = FlxG.mouse.deltaScreenX;
        var deltaY = FlxG.mouse.deltaScreenY;
        if (deltaX != 0 || deltaY != 0){
            switch(mouseGrabbed){
                case 0:
                    ClientPrefs.comboOffset[0] += deltaX;
                    ClientPrefs.comboOffset[1] -= deltaY; // Why the fuck is this inverted ughhhhhh!!!!!!!!!!!!!!!!!!!!!!
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

        if (controls.BACK){
            FlxG.sound.play(Paths.sound("cancelMenu"));
            close();
        }

        super.update(elapsed);
    } 

    override public function close(){
        FlxG.cameras.remove(camHUD, false);
        super.close();
    }
}