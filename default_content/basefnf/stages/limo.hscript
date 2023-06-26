var bgDancers:Array<FlxSprite> = [];

var dancerDanced:Bool = false;


var limo:FlxSprite;
var fastCar:FlxSprite;

function onAddSpriteGroups(){
    game.add(this);

    game.add(game.gfGroup);
    game.add(limo);
    game.add(game.dadGroup);
    game.add(game.boyfriendGroup);

    game.add(this.foreground);
    return Function_Stop;
}

function onLoad(stage, foreground){
    if(game.gf.curCharacter == 'gf')game.changeCharacter("gf-car", 2);
    

    var add = stage.add;
    var skyBG:FlxSprite = new FlxSprite(-120, -50).loadGraphic(Paths.image('limo/limoSunset'));
    skyBG.scrollFactor.set(0.1, 0.1);
    add(skyBG);

    var bgLimo:FlxSprite = new FlxSprite(-200, 480);
    bgLimo.frames = Paths.getSparrowAtlas('limo/bgLimo');
    bgLimo.animation.addByPrefix('drive', "background limo pink", 24);
    bgLimo.animation.play('drive');
    bgLimo.scrollFactor.set(0.4, 0.4);
    add(bgLimo);


    for (i in 0...5)
    {
        var dancer:FlxSprite = new FlxSprite((370 * i) + 130, bgLimo.y - 400);
        dancer.frames = Paths.getSparrowAtlas("limo/limoDancer");
		dancer.animation.addByIndices('danceLeft', 'bg dancer sketch PINK', [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14], "", 24, false);
		dancer.animation.addByIndices('danceRight', 'bg dancer sketch PINK', [15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29], "", 24, false);
		dancer.animation.play('danceLeft');
		dancer.animation.finish();
		dancer.antialiasing = true;
        dancer.scrollFactor.set(0.4, 0.4);
        bgDancers.push(dancer);
        add(dancer);
    }
 
    var overlayShit:FlxSprite = new FlxSprite(-500, -600).loadGraphic(Paths.image('limo/limoOverlay'));
    overlayShit.alpha = 0.5;
    // add(overlayShit);
    // var shaderBullshit = new BlendModeEffect(new OverlayShader(), FlxColor.RED);
    // FlxG.camera.setFilters([new ShaderFilter(cast shaderBullshit.shader)]);
    // overlayShit.shader = shaderBullshit;

    limo = new FlxSprite(-120, 550);
    limo.frames = Paths.getSparrowAtlas('limo/limoDrive');
    limo.animation.addByPrefix('drive', "Limo stage", 24);
    limo.animation.play('drive');
    limo.antialiasing = true;

    fastCar = new FlxSprite(-300, 160).loadGraphic(Paths.image('limo/fastCarLol'));
    foreground.add(fastCar);
    resetFastCar();
}

var fastCarCanDrive = false;

function resetFastCar():Void
{
    fastCar.x = -12600;
    fastCar.y = FlxG.random.int(140, 250);
    fastCar.velocity.x = 0;
    fastCarCanDrive = true;
}

function fastCarDrive()
{
    FlxG.sound.play(Paths.soundRandom('carPass', 0, 1), 0.7);

    fastCar.velocity.x = (FlxG.random.int(170, 220) / FlxG.elapsed) * 3;
    fastCarCanDrive = false;
    new FlxTimer().start(2, function(tmr:FlxTimer)
    {
        resetFastCar();
    });
}


function onBeatHit(){
    dancerDanced = !dancerDanced;
    for(shit in bgDancers)
        shit.animation.play(dancerDanced ? 'danceRight' : 'danceLeft', true);

    if (FlxG.random.bool(5) && fastCarCanDrive)
        fastCarDrive();
    
}