package funkin.objects.cutscenes;

// idc to do hxcodec etc lmao!
import flixel.util.FlxTimer;
import hxvlc.flixel.FlxVideoSprite;

class VideoCutscene extends Cutscene {
	var video: FlxVideoSprite;
	var videoId:String = '';

	public override function createCutscene() {
		video = new FlxVideoSprite();
		video.bitmap.onEndReached.add(() -> {
			onEnd.dispatch(false);
		});
		
		video.bitmap.onFormatSetup.add(()-> { 
			video.setGraphicSize(FlxG.width, FlxG.height);
			video.cameras = [FlxG.cameras.list[FlxG.cameras.list.length - 1]];
			video.screenCenter(XY);
		});
		
		onEnd.addOnce((wasSkipped:Bool) -> {
			video.stop();
			video.bitmap.dispose();
			remove(video);
			video.destroy();
		});
		
		video.load(Paths.video(videoId));
		video.play();
		add(video);
		
	}

	override public function pause(){
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