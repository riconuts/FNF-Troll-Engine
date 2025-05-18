package funkin.objects.cutscenes;

import flixel.util.typeLimit.OneOfTwo;
import flxanimate.FlxAnimate;
import flixel.util.FlxSignal.FlxTypedSignal;
import flixel.tweens.FlxEase;

class TimelineAction {
	public var parent:Timeline;
	public var frame:Int = 0;
	public var finished:Bool = false;

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

	public function new(frame:Int, sprite: FlxSprite, name:String){
		super(frame);
		this.sprite = sprite;
		this.name = name;
	}

	public override function execute(curFrame:Int, frameTime:Float){
		// TODO: code to make sure it stays synced
		#if USING_FLXANIMATE
		if(sprite is FlxAnimate)
			cast(sprite, FlxAnimate).anim.play(name, true);
		else if(sprite is Character)
		#else
		if(sprite is Character)
		#end
		{
			var ch:Character = cast sprite;
			ch.voicelining = !ch.idleSequence.contains(name);
			ch.playAnim(name, true);
		}else
			sprite.animation.play(name, true);

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

class EasePropertiesAction extends TimelineAction {
	public var endFrame:Int = 0;
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

	public override function execute(curFrame:Int, frameTime:Float) {
		var passed:Float = curFrame - frame;
		progress = Math.min(1, passed / (endFrame - frame));

		if (curFrame % updateInterval == 0){
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
	public var endFrame:Int = 0;
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

	public override function execute(curFrame:Int, frameTime:Float) {
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
		curFrame = frame;

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
	}

	public function playSound(frame:Int, sound:OneOfTwo<FlxSound, String>, obeysBitch:Bool = true)
		addAction(new SoundAction(frame, sound, obeysBitch));

	public function playAnimation(frame:Int, obj:FlxSprite, anim:String)
		addAction(new PlayAnimationAction(frame, obj, anim));

	public function on(frame:Int, callback:Int->Null<Bool>)
		addAction(new CallbackAction(frame, callback));

	public function finish(frame:Int)
		addAction(new CallbackAction(frame, (f:Int) -> {
			onFinish.dispatch();
			return true;
		}));

	public function once(frame:Int, callback:Int->Void)
		addAction(new CallbackAction(frame, (f:Int) -> {
			callback(f);
			return true;
		}));

	public function until(frame:Int, endFrame:Int, callback:Int->Void)
		addAction(new CallbackAction(frame, (f:Int)->{
			callback(f);
			return f >= endFrame;
		}));
	
	public function easeCallback(frame:Int, endFrame:Int, callback:(Float, Float)->Void, ?style:EaseFunction)
		addAction(new EaseCallbackAction(frame, endFrame, callback, style ?? FlxEase.linear));

	public function easeProperties(frame:Int, endFrame:Int, obj:Dynamic, properties:Dynamic, ?style:EaseFunction, ?interval:Int)
		addAction(new EasePropertiesAction(frame, endFrame, obj, properties, style ?? FlxEase.linear, interval));

	// secs -> frames and vice versa
	public function secToFrame(s:Float):Int return Math.floor(s / frameInterval);
	public function frameToSec(f:Int):Float return f * frameInterval;


	public override function update(dt:Float){
		#if FLX_DEBUG
		FlxBasic.activeCount++;
		#end

		frameTimer += dt;
		totalTime += dt;
		var garbage:Array<TimelineAction> = [];
		while(frameTimer >= frameInterval){
			curFrame++;
			// run the actions every timeline frame
			for(i in 0...actions.length){
				var action: TimelineAction = actions[i];
				if (action.finished)
					continue;

				if (action.frame <= curFrame)
					action.execute(curFrame, totalTime);
				else
					break;
			}
			frameTimer -= frameInterval;
		}
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

		frameTimer += dt;
		totalTime += dt;
		var garbage:Array<TimelineAction> = [];
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
	}
}