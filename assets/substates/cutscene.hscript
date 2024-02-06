// The cutscene substate.
// handles all the cutscene stuff.

var bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, 0xFF000000);
bg.cameras = [game.camOverlay];
bg.scrollFactor.set();

importClass("flixel.FlxObject");
var camFollowPos = new FlxObject();

var camera;

// cutsceneName, onComplete
cutsceneScript = null;
var totalTweens = [];
var daTimer = new FlxTimer();
var isSkippable = false;

function endCutscene(){
	if (cutsceneScript != null)
		cutsceneScript.call("onCutsceneEnd");

	game.inCutscene = false;

	FlxTween.tween(bg, {alpha: 0}, 0.15, {ease: FlxEase.linear, onComplete: function(twn){
		for (tween in totalTweens){
			tween.cancel();
			tween.destroy();
		}
			
		daTimer.cancel();
		daTimer.destroy();

		if (camera != null){
			FlxG.cameras.remove(camera);
			camera.destroy();	
		}
		camFollowPos.destroy();
		twn.destroy();
		
		bg.destroy();
		
		if (onComplete != null)
			onComplete();
		
		close();
	}});
}

function doTween(obj, props, duration, extra){
	var onComplete = extra.onComplete;
		
	extra.onComplete = function(twn){
		if (onComplete != null)
			onComplete();
			
		totalTweens.remove(twn);	
		twn.destroy(); // self destruct.
	}
	
	totalTweens.push(FlxTween.tween(obj, props, duration, extra));	
}
function setCameraPosition(x, y, width){
	camera.zoom = camera.width/width;
	camFollowPos.setPosition(
		(camera.width / camera.zoom) * 0.5 + x, 
		(camera.height / camera.zoom) * 0.5 + y
	);
};

function onLoad(){

	game.inCutscene = true;
	game.pause(false);
	
	trace("starting cutscene for "+ cutsceneName);

	add(bg);
	
	var fileName = 'cutscenes/' + cutsceneName + '.hscript';

	for (filePath in [Paths.modFolders(fileName), Paths.mods(fileName), Paths.getPreloadPath(fileName)])
	{
		if (!Paths.exists(filePath)) 
			continue;
		
		camera = new FlxCamera();
		camera.bgColor = 0x00000000;
		camera.follow(camFollowPos);
		FlxG.cameras.add(camera, false);

		// some shortcuts
		var variables = newMap();
		variables.set("this", this);
		
		variables.set("add", function(obj){
			add(obj).cameras = [camera];
		});
		variables.set("remove", function(obj){
			remove(obj).destroy();
		});		
		
		variables.set("tween", doTween);
		variables.set("timer", daTimer.start);
		
		variables.set("camera", camera);
		variables.set("camFollowPos", camFollowPos);
		
		variables.set("setCameraPosition", setCameraPosition); // So i can get the position straight from mspaint.
		variables.set("tweenCamera", function(props, duration, extra){
			// The considered properties are x, y and width.
			// The x and y positions get converted in the same way as the 'setCameraPosition' function.
			// Width gets converted to the camera zoom.
			
			// Destroy tween object on completion.
			var onComplete = extra.onComplete;
			extra.onComplete = function(twn){
				if (onComplete != null)
					onComplete();
					
				totalTweens.remove(twn);	
				twn.destroy();
			};
			
			var startX = camFollowPos.x;
			var startY = camFollowPos.y;
			var startZoom = camera.zoom;
			
			var goalZoom = (props.width != null) ? (camera.width/props.width) : startZoom;
			var goalX = (camera.width / goalZoom) * 0.5 + props.x;
			var goalY = (camera.height / goalZoom) * 0.5 + props.y;
			
			var startWidth = camera.width / startZoom;
			var goalWidth = props.width;
			
			totalTweens.push(FlxTween.num(0, 1, duration, extra, function(v){
				/*
				if (props.width != null)
					camera.zoom = FlxMath.lerp(startZoom, goalZoom, v);
				*/
				if (goalWidth != null)
					camera.zoom = camera.width / FlxMath.lerp(startWidth, goalWidth, v);
				
				if (goalX != null)
					camFollowPos.x = FlxMath.lerp(startX, goalX, v);
				
				if (goalY != null)
					camFollowPos.y = FlxMath.lerp(startY, goalY, v);
				
			}));
		});
		
		variables.set("getControls", getControls);
		variables.set("endCutscene", endCutscene);

		trace("loading cutscene script: " + filePath);
		var daScript = FunkinHScript.fromFile(filePath, filePath, variables);
		cutsceneScript = daScript;

		break;
	}
	
	if (cutsceneScript == null){
		isSkippable = true;
		endCutscene();
	}else{
		isSkippable = cutsceneScript.get("isSkippable") == true;
		new FlxTimer().start(1, function(tmr){
			cutsceneScript.call("cutsceneStart");
			tmr.destroy();
		});
	}

}

function onUpdate(e){
	if (isSkippable && getControls().ACCEPT)
		endCutscene();
		
	if (cutsceneScript != null)
		cutsceneScript.call("onUpdate", [e]);
}

function onClose(){}
function onDestroy(){}