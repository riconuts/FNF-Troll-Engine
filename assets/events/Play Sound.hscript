function shouldPush(eventNote):Bool{
	return true;
}
function getOffset(eventNote): Float{
	return 0;
}

function onTrigger(value1:Dynamic, value2:Dynamic, time:Float){ 
	var volume = value2 != "" ? Std.parseFloat(value2) : 1;
	FlxG.sound.play(Paths.sound(value1), volume);
}