package funkin.states;

#if !VIDEOS_ALLOWED
#elseif (hxCodec >= "3.0.0") import hxcodec.flixel.FlxVideo as VideoHandler;
#elseif (hxCodec >= "2.6.1") import hxcodec.VideoHandler as VideoHandler;
#elseif (hxCodec == "2.6.0") import VideoHandler;
#elseif (hxCodec) import vlc.MP4Handler as VideoHandler; 
#elseif (hxvlc) import hxvlc.flixel.FlxVideo as VideoHandler;
#else typedef VideoHandler = Dynamic;
#end

#if hxvlc
import hxvlc.util.Location;
#else
typedef Location = String;
#end

#if !VIDEOS_ALLOWED
class VideoPlayerState extends BaseVideoPlayerState
{

}
#elseif hxvlc
class VideoPlayerState extends BaseVideoPlayerState
{
	override function createVideo() {
		if (!Paths.exists(videoPath)){
			onComplete();
			
		}else{
			trace('Loading video: $videoPath');

			video = new VideoHandler();
			video.onEndReached.add(endVideo);
			FlxG.addChildBelowMouse(video);
			
			var loaded = video.load(videoPath);
			if (loaded)
				video.play();
			else {
				trace('Error loading video: $videoPath');
				endVideo();
			}
		}
	}

	override function pauseVideo() {
		video.pause();
	}

	override function destroyVideo() {
		video.stop();
		video.dispose();
		FlxG.removeChild(video);
	}
}

#elseif(hxCodec >= "3.0.0")
class VideoPlayerState extends BaseVideoPlayerState
{
	override function createVideo() {
		video = new VideoHandler();
		video.onEndReached.add(endVideo);
		video.play(videoPath);		
	}
	override function pauseVideo() {
		video.pause();
	}
	override function destroyVideo() {
		FlxG.game.removeChild(video);
	}
}

#elseif(hxCodec)
class VideoPlayerState extends BaseVideoPlayerState
{
	override function createVideo() {
		video = new VideoHandler();
		video.finishCallback = endVideo;
		video.playVideo(videoPath);
	}
	override function pauseVideo() {
		video.pause();
	}
}
#end

class BaseVideoPlayerState extends MusicBeatState
{  
	var videoPath:Location;
	var onComplete:Void -> Void;
	var isSkippable:Bool;

	public var ended:Bool = false;
	public var autoDestroy:Bool = true;
	public var video:VideoHandler;

	public function new(videoPath:Location, onComplete:Void -> Void, isSkippable:Bool = true)
	{
		super();

		this.videoPath = videoPath;
		this.isSkippable = isSkippable==true;
		this.onComplete = onComplete;
	}

	override public function create() {
		FlxG.camera.bgColor = 0xFF000000;
		super.create();
		createVideo();
	}

	private function createVideo() {
		trace("Video playback is unavailable");
		onComplete();
	}

	public function pauseVideo() {
	
	}

	public function destroyVideo() {
		
	}

	/**
		Destroys the VideoHandler if `autoDestroy` is `true` and calls the `onComplete` callback
	**/
	private function endVideo() {
		if (ended)
			return;
		
		ended = true;
		pauseVideo();
		
		if (autoDestroy) destroyVideo();
		if (onComplete != null) onComplete();
	}

	override public function update(e) {
		if (isSkippable && FlxG.keys.justPressed.ENTER) {
			endVideo();
		}

		super.update(e);
	}
}