package funkin.data;

class MusicData 
{
	////
	public var path:String;
	/** Whether or not this sound should loop. **/
	public var looped:Bool; 
	/** In case of looping, the point (in milliseconds) from where to restart the sound when it loops back **/
	public var loopTime:Null<Float>;
	/** At which point to stop playing the sound, in milliseconds. If not set / null, the sound completes normally. **/
	public var endTime:Null<Float>;

	public var bpm:Float;

	public function new(path:String) {
		this.path = path;
	}

	public function makeFlxSound():FlxSound {
		var snd = Paths.returnSound(path);
		var snd = FlxG.sound.load(snd, 1.0, looped);
		snd.loopTime = loopTime;
		snd.endTime = endTime; 
		snd.context = MUSIC;

		return FlxG.sound.list.add(snd);
	}

	////
	public static function fromFilePaths(soundPath:String, jsonPath:String):Null<MusicData> {
		if (!Paths.exists(soundPath))
			return null;

		var jsonData:MusicDataJSON = Paths.getJson(jsonPath);
		if (jsonData == null)
			return null;
		
		var md = new MusicData(soundPath);
		md.looped = jsonData.looped!=false;
		md.loopTime = jsonData.loopTime;
		md.endTime = jsonData.endTime;
		md.bpm = jsonData.bpm ?? 100;
		return md;
	}

	public static function fromName(name:String):Null<MusicData>
	{
		var soundPath:String = Paths.getPath('music/$name.${Paths.SOUND_EXT}');
		var jsonPath:String = {
			var p = new haxe.io.Path(soundPath);
			p.ext = 'json';
			p.toString();
		}

		return fromFilePaths(soundPath, jsonPath);
	}
}

typedef MusicDataJSON = {
	var bpm:Float;
	var looped:Bool;
	var endTime:Float;
	var loopTime:Float;
	//var bpmChangeMap:Array<Dynamic>;
}