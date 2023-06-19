var phillyCityLights = [];
var phillyTrain:FlxSprite;
var trainSound:FlxSound;

function onLoad(stage, foreground)
{
	var add = function(o){
		return stage.add(o);
	}

	var bg:FlxSprite = new FlxSprite(-100).loadGraphic(Paths.image('philly/sky'));
	bg.scrollFactor.set(0.1, 0.1);
	add(bg);

	var city:FlxSprite = new FlxSprite(-10).loadGraphic(Paths.image('philly/city'));
	city.scrollFactor.set(0.3, 0.3);
	city.setGraphicSize(Std.int(city.width * 0.85));
	city.updateHitbox();
	add(city);

	lightFadeShader = newShader("buildingShader");
	lightFadeShader.data.alphaShit.value = [0];

	var phillyLightsColors = [0xFF31A2FD, 0xFF31FD8C, 0xFFFB33F5, 0xFFFD4531, 0xFFFBA633];
	for (i in 0...5)
	{
		var light:FlxSprite = new FlxSprite(city.x).loadGraphic(Paths.image('philly/window'));
		light.color = phillyLightsColors[i];
		light.scrollFactor.set(0.3, 0.3);
		light.visible = false;
		light.setGraphicSize(Std.int(light.width * 0.85));
		light.updateHitbox();
		light.antialiasing = true;
		light.shader = lightFadeShader;
		add(light);
		phillyCityLights.push(light);
	}

	phillyCityLights[0].visible = true;

	var streetBehind:FlxSprite = new FlxSprite(-40, 50).loadGraphic(Paths.image('philly/behindTrain'));
	add(streetBehind);

	phillyTrain = new FlxSprite(2000, 360).loadGraphic(Paths.image('philly/train'));
	add(phillyTrain);

	trainSound = new FlxSound().loadEmbedded(Paths.sound('train_passes'));
	FlxG.sound.list.add(trainSound);

	// var cityLights:FlxSprite = new FlxSprite().loadGraphic(AssetPaths.win0.png);

	var street:FlxSprite = new FlxSprite(-40, streetBehind.y).loadGraphic(Paths.image('philly/street'));
	add(street);
	
}

var startedMoving = false;
var trainFinishing = false;
var trainMoving = false;
var trainCars = 8;
var trainCooldown = 0;

function updateTrainPos(){
	if(trainSound.time >= 4700){
		startedMoving = true;
		game.gf.playAnim("hairBlow");
	}
	if(startedMoving){
		phillyTrain.x -= 400;
		if(phillyTrain.x < -2000 && !trainFinishing){
			phillyTrain.x = -1150;
			trainCars--;
			if(trainCars <= 0){
				trainFinishing = true;
			}

		}
		if(phillyTrain.x < -4000 && trainFinishing)
			resetTrain();
	}
}

function startTrain(){
	trainMoving = true;
	trainSound.play(true);
}

function resetTrain(){
	game.gf.playAnim("hairFall");
	phillyTrain.x = FlxG.width + 200;
	trainMoving = false;
	trainFinishing = false;
	startedMoving = false;
	trainCars = 8;
}

function onSectionHit(){
	lightFadeShader.data.alphaShit.value = [0];
	for(light in phillyCityLights)
		light.visible = false;

	phillyCityLights[FlxG.random.int(0, phillyCityLights.length-1)].visible = true;	
}

function onBeatHit(){
	if(!trainMoving)
		trainCooldown++;

	if(curBeat % 8 == 4 && FlxG.random.bool(30) && !trainMoving && trainCooldown >= 8){
		trainCooldown = FlxG.random.int(-4, 0);
		startTrain();
	}
}

var trainFrameTiming = 0;

function onUpdate(elapsed:Float){
	lightFadeShader.data.alphaShit.value[0] += (Conductor.crochet / 1000) * elapsed * 1.5;

	if(trainMoving){
		trainFrameTiming += elapsed;
		while(trainFrameTiming >= 1/24){
			updateTrainPos();
			trainFrameTiming -= 1/24;
		}
	}	
}