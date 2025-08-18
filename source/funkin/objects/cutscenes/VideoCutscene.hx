package funkin.objects.cutscenes;

// idc to do hxcodec etc lmao!
#if hxvlc
import hxvlc.flixel.FlxVideoSprite;
import hxvlc.util.Location;
#end

class VideoCutscene extends Cutscene {
	var video: FlxVideoSprite;
	var videoId:String = '';

	public override function createCutscene() {
		video = new FlxVideoSprite(0, 0);
		video.bitmap.onEndReached.add(() -> {
			onEnd.dispatch(false);
		});
		
		video.bitmap.onFormatSetup.add(()-> { 
			video.setGraphicSize(FlxG.width, FlxG.height);
			video.cameras = [FlxG.cameras.list[FlxG.cameras.list.length - 1]];
			video.screenCenter(XY);
		});
		
		onEnd.addOnce(onEndCutscene);
		add(video);

		var videoLocation:Location = Paths.video(videoId);
		var videoLoaded:Bool = video.load(videoLocation);
		if (videoLoaded) {
			video.play();
			video.bitmap.rate = Math.min(4, FlxG.timeScale); // above 4x the audio cuts out so just cap it at 4x
		}else {
			trace('Failed to load video: $videoLocation');
			FlxG.signals.postUpdate.addOnce(onEnd.dispatch.bind(true)); // onSceneFinished signal hasn't been added yet :l
		}
	}

	/** This function exists so you can do `onEnd.remove(onEndCutscene)` if necessary **/
	public function onEndCutscene(wasSkipped:Bool) {
		destroyVideo();
	}

	public function destroyVideo() {
		if (video != null) {
			video.stop();
			video.bitmap.dispose();
			video.destroy();
			remove(video);
			video = null;
		}
	}

	override public function pause(){
		#if(hxvlc >= "2.1.0")
		@:privateAccess
		video.bitmap.resumeOnFocus = false;
		#end
		video.bitmap.pause();
	}

	override public function resume() {
		video.bitmap.resume();
		#if(hxvlc < "2.1.1")
		video.bitmap.time = video.bitmap.time; // trust
		// (fixes desync)
		#end
	}

	override public function restart(){
		video.stop();
		video.bitmap.time = 0;
		video.play();
	}

	public function new(videoId:String = ''){
		super();
		this.videoId = videoId;
	}

}