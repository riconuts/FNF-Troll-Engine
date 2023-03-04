var instance = getInstance();
var defaultZoom:Float = instance.defaultCamZoom;
var twnN = 0;

var lastTween = null;

function doZoomTween(zoom:Float, duration:Float)
{
	zoom = Math.isNaN(zoom) ? defaultZoom : zoom;
	duration = Math.isNaN(duration) ? 1 : Math.abs(duration);
	
	instance.camZooming = true;
	
	if (lastTween != null)
	{
		lastTween.cancel();
		lastTween.destroy();
		lastTween = null;
	}
	
	if (duration == 0){
		instance.defaultCamZoom = zoom;
	}else{
		lastTween = FlxTween.num(
			instance.defaultCamZoom, 
			zoom, 
			duration, 
			{
				ease: FlxEase.quadInOut, 
				onUpdate: function(twn){
					instance.defaultCamZoom = twn.value;
				},
				onComplete: function(wtf){
					instance.defaultCamZoom = zoom;
					if (lastTween == wtf) lastTween = null;
				}
			}
		);
	
		instance.modchartTweens.set(scriptName + twnN, lastTween);
	}
}

function shouldPush(eventNote):Bool{
	return true;
}

function onPush(eventNote){}

function onLoad(){}

function getOffset(eventNote):Float
{
	var dur = Std.parseFloat(eventNote.value2);

	return (dur < 0) ? (dur * 1000) : 0; 
}

function onTrigger(value1:Dynamic, value2:Dynamic){
	doZoomTween(Std.parseFloat(value1), Std.parseFloat(value2));
}