package funkin.objects.cutscenes;

import flixel.util.typeLimit.OneOfTwo;
import flixel.util.FlxSignal.FlxTypedSignal;
import flixel.tweens.FlxEase;

#if USING_FLXANIMATE
import flxanimate.FlxAnimate;
#end

class TimelineAction {
	public var parent:Timeline;
	public var frame:Int = 0;
	public var finished:Bool = false;
	public var updateEveryFrame:Bool = false;

	public function new(frame:Int){
		this.frame = frame;
	}
	
	public function execute(frame: Int, frameTime:Float){
		// no code since base action

	}
}

class PlayAnimationAction extends TimelineAction {
	public var sprite: FlxSprite;
	public var name: String;
	public var syncToTimeline: Bool = false;

	public function new(frame:Int, sprite:FlxSprite, name:String, syncToTimeline:Bool = false){
		super(frame);
		this.sprite = sprite;
		this.name = name;
		this.syncToTimeline = syncToTimeline;
	}

	var firstExecute:Bool = true;
	public override function execute(curFrame:Int, frameTime:Float){
		var actionLocalSecs: Float = (curFrame - frame) * parent.frameInterval;
		if (firstExecute){
			#if USING_FLXANIMATE
			if(sprite is FlxAnimate){
				var animate: FlxAnimate = cast sprite;
				animate.anim.play(name, true);
				animate.anim.curFrame = Math.floor(actionLocalSecs * animate.anim.framerate);
			}else
			#end
			{
				if(sprite is Character){
					var ch:Character = cast sprite;
					ch.voicelining = !ch.idleSequence.contains(name);
					ch.playAnim(name, true);
				}else
					sprite.animation.play(name, true);
				
				sprite.animation.curAnim.curFrame = Math.floor(actionLocalSecs * sprite.animation.curAnim.frameRate);
			}
		}
		firstExecute = false;
		if(syncToTimeline){
			#if USING_FLXANIMATE
			if(sprite is FlxAnimate){
				var animate: FlxAnimate = cast sprite;
				if (animate != null && animate.anim != null && animate.anim.curInstance != null && animate.anim.curInstance.symbol != null && animate.anim.curInstance.symbol.name == name){
					animate.anim.pause();
					animate.anim.curFrame = Math.floor(actionLocalSecs * animate.anim.framerate);
					finished = animate.anim.curFrame >= animate.anim.length;
				}else{
					finished = true;
				}
			}else
			#end
			{
				// i love flixel 
				if (sprite != null && sprite.animation != null && sprite.animation.curAnim != null && sprite.animation.curAnim.name == name){
					sprite.animation.curAnim.paused = true;
					sprite.animation.curAnim.curFrame = Math.floor(actionLocalSecs * sprite.animation.curAnim.frameRate);
					// TODO: loop points
					if(sprite.animation.curAnim.looped)
						sprite.animation.curAnim.curFrame %= sprite.animation.curAnim.numFrames - 1;
					
					finished = sprite.animation.curAnim.finished;
				}else{
					finished = true;
				}
			}
			return;
		}
			
		finished = true;
	}
}

class CallbackAction extends TimelineAction {
	public var callback: Int -> Null<Bool>;

	public function new(frame:Int, callback:Int->Null<Bool>){
		super(frame);
		this.callback = callback;
	}

	public override function execute(curFrame:Int, frameTime:Float)
		finished = callback(curFrame) ?? false;
	
}

typedef EaseInfo = {
	name: String,
	value: Float,
	?startValue: Float,
	?range: Float
}

class SetPropertiesAction extends TimelineAction {
	var propertyInfo: Array<{name: String, value:Float}> = [];
	var obj:Dynamic;
	public function new(frame:Int, obj:Dynamic, properties:Dynamic) {
		super(frame);
		this.obj = obj;
		this.propertyInfo = [
			for (p in Reflect.fields(properties)) {
				var v = Reflect.field(properties, p);
				{
					name: p,
					value: v
				}
			}
		];
	}

	public override function execute(curFrame:Int, frameTime:Float) {
		for (data in propertyInfo) 
			Reflect.setProperty(obj, data.name, data.value);
		
		finished = true;

	}
}

class EasePropertiesAction extends TimelineAction {
	public var endFrame:Float = 0;
	public var obj:Dynamic;
	public var propertyInfo:Array<EaseInfo> = [];
	public var updateInterval:Int = 1;
	public var style:EaseFunction = FlxEase.quadOut;

	public var progress:Float = 0;
	var length:Int = 0;

	public function new(frame:Int, endFrame:Int, obj:Dynamic, properties:Dynamic, style:EaseFunction, onEvery:Int = 1){
		super(frame);
		this.endFrame = endFrame;
		this.obj = obj;
		this.propertyInfo = [
			for(p in Reflect.fields(properties)){
				var v = Reflect.field(properties, p);
				{
					name: p,
					value: v
				}
			}
		];
		this.style = style;
		this.updateInterval = onEvery;

		length = endFrame - frame;
	}

	public override function execute(curFrame:Float, frameTime:Float) {
		// This'll break if you're changing the timeline framerate mid-animation
		// but you shouldnt be doing that, so who care
		if (updateEveryFrame)
			curFrame = frameTime / parent.frameInterval;
		

		var passed:Float = curFrame - frame;
		var range:Float = (endFrame - frame);

		progress = Math.min(1, passed / range);

		if (updateEveryFrame || curFrame % updateInterval == 0){
			for(data in propertyInfo){
				if(data.range == null){
					var sv: Float = Reflect.getProperty(obj, data.name);
					data.startValue = sv;
					data.range = data.value - sv;
				}
				Reflect.setProperty(obj, data.name, (data.range * style(progress)) + data.startValue);
			}
		}

		if(progress >= 1)
			finished = true;

	}
}

class EaseCallbackAction extends TimelineAction {
	public var endFrame:Float = 0;
	public var callback:(Float, Float)->Void;
	public var style:EaseFunction = FlxEase.quadOut;

	public var progress:Float = 0;

	var length:Int = 0;
	var value:Float = 0;

	public function new(frame:Int, endFrame:Int, callback:(Float, Float) -> Void, style:EaseFunction) {
		super(frame);
		this.endFrame = endFrame;
		this.style = style;
		this.callback = callback;

		length = endFrame - frame;
	}

	public override function execute(curFrame:Float, frameTime:Float) {
		if (updateEveryFrame)
			curFrame = frameTime / parent.frameInterval;
		var passed:Float = curFrame - frame;
		progress = Math.min(1, passed / (endFrame - frame));

		value = style(passed / length);
		callback(value, curFrame);

		if (progress >= 1)
			finished = true;
	}
}

class SoundAction extends TimelineAction {
	var sound:FlxSound;

	public function new(frame:Int, sound:OneOfTwo<FlxSound, String>, obeysBitch:Bool = true) {
		super(frame);
		var newSound:FlxSound;
		if (sound is String){
			newSound = new FlxSound().loadEmbedded(Paths.sound(sound));
			newSound.exists = true;
			if (obeysBitch)
				newSound.pitch = FlxG.timeScale;

			FlxG.sound.list.add(newSound);
		}else
			newSound = cast sound;
		
		this.sound = newSound ?? new FlxSound();
	}

	public override function execute(curFrame:Int, frameTime:Float) {
		sound.play(true);
		// TODo: take pitch into account
		sound.time = (curFrame - frame) * parent.frameInterval;
		finished = true;
	}
}

class Timeline extends FlxBasic {
	public var onFinish:FlxTypedSignal<Void->Void> = new FlxTypedSignal<Void->Void>();

	public var frameRate(default, set):Float = 24;
	public var curFrame:Int = 0;
	public var actions: Array<TimelineAction> = [];
	public var frameInterval(default, set) = 1 / 24; // pls dont set this! set framerate!!
	var frameTimer:Float = 0;
	var totalTime:Float = 0;
	var actionIndex:Int = 0;

	public function set_frameInterval(_:Float){
		trace("dont set frameInterval dummy! set frameRate!!");
		return frameInterval;
	}


	public function new(?frameRate:Float = 24, ?frame:Int = 0)
	{
		super();
		this.frameRate = frameRate;
		this.curFrame = frame;
	}

	public function seek(frame: Int){ // Be careful when seeking
		var oldFrame = curFrame;
		curFrame = frame;

		if (curFrame < oldFrame)
			for(i in 0...actions.length)
				actions[i].finished = false;

	}

	public function set_frameRate(f:Float){
		@:bypassAccessor
		frameInterval = 1 / f;
		return frameRate = f;
	}

	public function addAction(action:TimelineAction){
		actions.push(action);
		action.parent = this;
		actions.sort((a, b) -> Std.int(a.frame - b.frame));
		return action;
	}

	public function setProperties(frame:Int, obj:Dynamic, properties:Dynamic)
		return addAction(new SetPropertiesAction(frame, obj, properties));

	public function playSound(frame:Int, sound:OneOfTwo<FlxSound, String>, obeysBitch:Bool = true)
		return addAction(new SoundAction(frame, sound, obeysBitch));

	public function playAnimation(frame:Int, obj:FlxSprite, anim:String)
		return addAction(new PlayAnimationAction(frame, obj, anim));

	public function on(frame:Int, callback:Int->Null<Bool>)
		return addAction(new CallbackAction(frame, callback));

	public function finish(frame:Int)
		return addAction(new CallbackAction(frame, (f:Int) -> {
			onFinish.dispatch();
			return true;
		}));

	public function once(frame:Int, callback:Int->Void)
		return addAction(new CallbackAction(frame, (f:Int) -> {
			callback(f);
			return true;
		}));

	public function until(frame:Int, endFrame:Int, callback:Int->Void)
		return addAction(new CallbackAction(frame, (f:Int)->{
			callback(f);
			return f >= endFrame;
		}));
	
	public function easeCallback(frame:Int, endFrame:Int, callback:(Float, Float)->Void, ?style:EaseFunction)
		return addAction(new EaseCallbackAction(frame, endFrame, callback, style ?? FlxEase.linear));

	public function easeProperties(frame:Int, endFrame:Int, obj:Dynamic, properties:Dynamic, ?style:EaseFunction, ?interval:Int)
		return addAction(new EasePropertiesAction(frame, endFrame, obj, properties, style ?? FlxEase.linear, interval));

	// secs -> frames and vice versa
	public function secToFrame(s:Float):Int return Math.floor(s / frameInterval);
	public function frameToSec(f:Int):Float return f * frameInterval;

	function updateTimeline(dt:Float){
		frameTimer += dt;
		totalTime += dt;
		while (frameTimer >= frameInterval) {
			curFrame++;
			// run the actions every timeline frame
			for (i in 0...actions.length) {
				var action:TimelineAction = actions[i];
				if (action.finished)
					continue;

				if (action.frame <= curFrame)
					action.execute(curFrame, totalTime);
				else
					break;
			}
			frameTimer -= frameInterval;
		}
		for (i in 0...actions.length) {
			var action:TimelineAction = actions[i];
			if (action.finished || !action.updateEveryFrame)
				continue;

			if (action.frame <= curFrame)
				action.execute(curFrame, totalTime);
			else
				break;
		}
	}

	public override function update(dt:Float){
		#if FLX_DEBUG
		FlxBasic.activeCount++;
		#end

		updateTimeline(dt);
	}
}

class ConductorTimeline extends Timeline
{
	var oldSP:Float = Conductor.songPosition;
	
	override public function seek(_:Float){
		trace("no seeking on conductor timelines!! do it manually set songposition urself lol");
	}
	
	public override function update(ft:Float) {
		#if FLX_DEBUG
		FlxBasic.activeCount++;
		#end

		var dt:Float = Conductor.songPosition - oldSP;

		if(dt < 0)
			dt = 0;
		else
			oldSP = Conductor.songPosition;
		
		updateTimeline(dt);
	}
}