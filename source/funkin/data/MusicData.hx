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
		var snd:FlxSound = loadFlxSound();
		snd.context = MUSIC;
		FlxG.sound.defaultMusicGroup.add(snd);
		return snd;
	}

	public function loadFlxSound(?snd:FlxSound):FlxSound {
		snd ??= new FlxSound();
		snd.loadEmbedded(Paths.returnSound(path), looped);
		snd.loopTime = loopTime;
		snd.endTime = endTime;
		return snd;
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