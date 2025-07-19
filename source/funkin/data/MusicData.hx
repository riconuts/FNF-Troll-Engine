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

	public function new(path:String, ?looped:Bool, ?loopTime:Float, ?endTime:Float) {
		this.path = path;
		this.looped = looped==true;
		this.loopTime = loopTime;
		this.endTime = endTime;
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
	public static function fromPath(filePath:String):Null<MusicData> 
	{
		var jsonPath:String = '$filePath.json';
		if (!Paths.exists(jsonPath))
			return null;
		
		var soundPath:String = '$filePath.${Paths.SOUND_EXT}';
		if (!Paths.exists(soundPath))
			return null;

		var jsonData:MusicDataJSON = Paths.getJson(jsonPath);
		if (jsonData == null)
			return null;
		
		return new MusicData(soundPath, jsonData.looped, jsonData.loopTime, jsonData.endTime);
	}

	public static function fromName(name:String):Null<MusicData>
	{
		var bp:String = 'music/$name';
		var jsonPath = Paths.getPath('$bp.json');
		return Paths.exists(jsonPath) ? fromPath(jsonPath.substr(0, jsonPath.length - 5)) : null;
	}
}

typedef MusicDataJSON = {
	var bpm:Float;
	var looped:Bool;
	var endTime:Float;
	var loopTime:Float;
	//var bpmChangeMap:Array<Dynamic>;
}