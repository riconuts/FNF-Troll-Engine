var black:FlxSprite;
var white:FlxSprite;
function onCreatePost(){
    game.skipCountdown = true;
    black = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
    black.setGraphicSize(3240, 3240);
    black.updateHitbox();
    black.alpha = 1;
    black.screenCenter("XY");
    black.cameras = [game.camOther];
    game.add(black);

    white = new FlxSprite().makeGraphic(1, 1, FlxColor.WHITE);
    white.setGraphicSize(3240, 3240);
    white.updateHitbox();
    white.alpha = 0;
    white.blend = 0;
    white.screenCenter("XY");
    white.cameras = [game.camOther];

    if(game.stage.curStage == 'spooky'){
        game.stage.stageScript.set('lightningOffset', 1000);
        game.stage.stageScript.set('lightningStrikeBeat', 1000);
    }
    game.add(white);
}

var lightninged:Bool = false;

function onStepHit(){
    if(curStep >= 16 && !lightninged){
        lightninged = true;
        white.alpha = 1;
        black.alpha = 0;
        game.triggerEventNote("Lightning", "true");
    }
}

function onUpdate(elapsed:Float){
    var step = game.curDecStep;
    if(step >= 24)
        white.alpha = 0;
    else if(step >= 16){
        var shit = step - 16;
        var prog = shit / 4;
        white.alpha = 1 - prog;
    }
}