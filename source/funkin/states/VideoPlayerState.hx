package funkin.states;

#if !VIDEOS_ALLOWED
#elseif (hxCodec >= "3.0.0") import hxcodec.flixel.FlxVideo as VideoHandler;
#elseif (hxCodec >= "2.6.1") import hxcodec.VideoHandler as VideoHandler;
#elseif (hxCodec == "2.6.0") import VideoHandler;
#elseif (hxCodec) import vlc.MP4Handler as VideoHandler; 
#elseif (hxvlc) import hxvlc.flixel.FlxVideo as VideoHandler;
#end
class VideoPlayerState extends MusicBeatState
{  
	final videoPath:String;
	final isSkippable:Bool;
	final onComplete:Void -> Void;

	public var autoDestroy:Bool = true;

	public function new(videoPath:String, onComplete:Void -> Void, isSkippable:Bool = true)
	{
		super();

		this.videoPath = videoPath;
		this.isSkippable = isSkippable==true;
		this.onComplete = onComplete;
	}

	#if VIDEOS_ALLOWED
	var video:VideoHandler;
	#end
	override public function create(){
		FlxG.camera.bgColor = 0xFF000000;

		super.create();

		#if !VIDEOS_ALLOWED
		onComplete();
		trace("Video playback is unavailable");

		#else
		if (!Paths.exists(videoPath)){
			onComplete();
			trace('$videoPath does not exist');
		}else{
			#if (hxvlc) 
            video = new VideoHandler();
			video.onEndReached.add(function()
			{
				onComplete();
			});
			video.load(videoPath);
            video.play();
            #elseif(hxCodec >= "3.0.0")
			video = new VideoHandler();
			video.onEndReached.add(function(){
				onComplete();
            });
			video.play(videoPath);
            #else
			video = new VideoHandler();
			video.finishCallback = onComplete;
			video.playVideo(videoPath);
            #end
		}
		#end
	}

	#if VIDEOS_ALLOWED
	override public function update(e) {
		if (isSkippable && controls.ACCEPT)
			onComplete();

		super.update(e);
	}

	override public function destroy(){
		#if hxvlc
		video.stop();
		video.dispose();
		#elseif(hxCodec >= "3.0.0")
		if (FlxG.game.contains(video))
			FlxG.game.removeChild(video);
		#end

		super.destroy();
	}
	#end
}