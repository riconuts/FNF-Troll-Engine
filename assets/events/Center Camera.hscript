function shouldPush(eventNote):Bool{
	return true;
}

function getOffset(eventNote):Float{
	return 0;
}

function onPush(eventNote){}
function onLoad(){}

function onTrigger(value1, value2, time)
{
	if (value1 == "true")
	{
		var camDad = game.dad.getCamera();
		var camBf = game.boyfriend.getCamera();
		
		game.triggerEventNote(
			"Camera Follow Pos", 
			Std.string((camDad[0] + camBf[0]) * 0.5), 
			Std.string((camDad[1] + camBf[1]) * 0.5)
		);
	}
	else
	{
		game.triggerEventNote("Camera Follow Pos", "", "");
	}
}