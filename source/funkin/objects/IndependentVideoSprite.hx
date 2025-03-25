package funkin.objects;


// Purpose of this is to allow 
// 1. shit to make transitioning from other engines or older versions of troll to modern troll easier
// 2. work independently of video libraries (Hence the name IndependentVideoSprite)

// TODO: add the other video libs (hxcodec and its various versions that change its API)

import funkin.states.PlayState;
#if !VIDEOS_ALLOWED
class IndependentVideoSprite{
	
}
#else
import haxe.io.Bytes;
import sys.FileSystem;

#if (hxvlc)
#if (hxvlc > "1.5.5")
import hxvlc.util.typeLimit.OneOfThree;
#else
import hxvlc.util.OneOfThree;
#end
import hxvlc.flixel.FlxVideoSprite as VideoSprite;
#end

class IndependentVideoSprite extends VideoSprite {
	public static final muted:String = ":no-audio";
	public static final looping:String = ':input-repeat=65535';

	// TODO: add some basic easy signals
	// public var isLooping:Bool = false;
	
	var _paused:Bool = false;

	public function new(x:Float = 0, y:Float = 0, destroy:Bool = true, addToState:Bool = false) {
		#if(hxvlc)
		super(); // why does it USE INTS
		this.x = x;
		this.y = y;

		if (destroy)
			bitmap.onEndReached.add(this.destroy, true);

		#else
		super(x, y);
		#end

		if (addToState)
			FlxG.state.add(this);

		if(FlxG.state == PlayState.instance){
			PlayState.instance.signals.onPause.add(pause);
			PlayState.instance.signals.onResume.add(resume);
			bitmap.rate = PlayState.instance.playbackRate;
		}
		
	}



	// for nightmarevision
	public function addCallback(callbackName:String, callback:Void->Void, once:Bool=false){
		trace(callbackName);
		switch (callbackName){
			case 'onEnd':
				trace("end callback");
				#if(hxvlc)
				bitmap.onEndReached.add(callback, once);
				#end
			case 'onStart':
				#if (hxvlc)
				bitmap.onOpening.add(callback, once);
				#end
			case 'onFormat':
				#if (hxvlc)
				bitmap.onFormatSetup.add(callback, once);
				#end
		}
	}
	
	#if(hxCodec)
	public function load(file:String, args:Array<String>){
		if (args.contains(muted)){}
			// mute the video

		if (args.contains(looping)){}
			// loop it

		// If we can pass args straight to the vlc thing then dont do this shit ^
	}
	#elseif(hxvlc)
	override function load(location:OneOfThree<String, Int, Bytes>, ?options:Array<String>):Bool{
		if((location is String)){
			if(FileSystem.exists(Paths.getPath('videos/$location')))
				location = Paths.getPath('videos/$location');
		}

		var returnValue:Bool = super.load(location, options);

		if (FlxG.signals.focusGained.has(resume))
			FlxG.signals.focusGained.remove(resume);

		if (FlxG.signals.focusLost.has(pause))
			FlxG.signals.focusLost.remove(pause);
		

		#if (hxvlc <= "1.9.3")
		if (!FlxG.signals.focusGained.has(_autoResume))
			FlxG.signals.focusGained.add(_autoResume);

		if (!FlxG.signals.focusLost.has(_autoPause))
			FlxG.signals.focusLost.add(_autoPause);
		#end

		return returnValue;
		

	}
	#end

	#if (hxvlc <= "1.9.3")
	override function pause(){
		_paused = true;
		super.pause();
	}

	override function resume() {
		_paused = false;
		super.resume();
	}

	function _autoPause(){
		if(!autoPause)
			return;

		if (bitmap != null)
			bitmap.pause();
	}
	function _autoResume() {
		if (!autoPause)
			return;

		if(!_paused){
			if (bitmap != null)
				bitmap.resume();
		}
	}
	#end
}
#end