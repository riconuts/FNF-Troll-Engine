var game = getInstance();
var defaultZoom:Float = game.defaultCamZoom;

function shouldPush(eventNote):Bool{
	return true;
}

function getOffset(eventNote): Float{
  return 0; // If this is anything but 0, the event will be offset backwards by the specified number in ms
  // so returning 250 will move it from being triggered at 1000, to 750
  // likewise, -250 will go from 1000 to 1250
}

function onTrigger(value1:Dynamic, value2:Dynamic, time:Float){
	for (boi in game.playerStrums)
		FlxTween.tween(boi, {alpha: 0}, Std.parseFloat(value2), {ease: FlxEase.expoIn});
		
	for (boi in game.opponentStrums)
		FlxTween.tween(boi, {alpha: 0}, Std.parseFloat(value2), {ease: FlxEase.expoIn});
}