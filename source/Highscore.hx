package;

import flixel.FlxG;
import flixel.util.FlxSave;
using StringTools;

class Highscore
{
	#if (haxe >= "4.0.0")
	public static var weekScores:Map<String, Int> = new Map();
	public static var songScores:Map<String, Int> = new Map();
	public static var songRating:Map<String, Float> = new Map();
	#else
	public static var weekScores:Map<String, Int> = new Map();
	public static var songScores:Map<String, Int> = new Map<String, Int>();
	public static var songRating:Map<String, Float> = new Map<String, Float>();
	#end

	static var loadedID:String = '';
	static var save:FlxSave = new FlxSave();
	static var defaultID:String = 'f-45-90-135-166'; // psych preset aka the default preset from old tgt
	// this is used to make sure if you're on psych preset, you get to keep your old high scores

	public static function getID(){
		var idArray:Array<String> = [];
		idArray.push(ClientPrefs.useEpics ? 't' : 'f');
		var windows = ['sick', 'good', 'bad', 'hit'];
		if(ClientPrefs.useEpics)windows.insert(0, 'epic');
		for(window in windows){
			var realWindow = Reflect.field(ClientPrefs, window + "Window");
			idArray.push(Std.string(realWindow));
		}

		var id = idArray.join("-");
		
		
		return "scores" +  id;
	}

	static function updateSave(){
		var id = getID();
		if(loadedID != id){
			loadedID = id;
			if(save.isBound)save.flush(); // makes sure it all saved

			save.bind(id);

			if (id == defaultID)
			{
				if (save.isEmpty()){
					save.mergeDataFrom("flixel", null, false, false);
					save.flush();
				}
			}
		}
	}

	public static function resetSong(song:String):Void
	{
		updateSave();
		var daSong:String = formatSong(song);
		setScore(daSong, 0);
		setRating(daSong, 0);
	}

	public static function resetWeek(week:String):Void
	{
		updateSave();
		var daWeek:String = formatSong(week);
		setWeekScore(daWeek, 0);
	}

	public static function floorDecimal(value:Float, decimals:Int):Float
	{
		if(decimals < 1)
		{
			return Math.floor(value);
		}

		var tempMult:Float = 1;
		for (i in 0...decimals)
		{
			tempMult *= 10;
		}
		var newValue:Float = Math.floor(value * tempMult);
		return newValue / tempMult;
	}

	public static function saveScore(song:String, score:Int = 0, ?rating:Float = -1):Void
	{
		updateSave();
		var daSong:String = formatSong(song);

		if (songScores.exists(daSong)) {
			if (songScores.get(daSong) < score) {
				setScore(daSong, score);
				if(rating >= 0) setRating(daSong, rating);
			}
		}
		else {
			setScore(daSong, score);
			if(rating >= 0) setRating(daSong, rating);
		}
	}

	public static function saveWeekScore(week:String, score:Int = 0):Void
	{
		updateSave();
		var daWeek:String = formatSong(week);

		if (weekScores.exists(daWeek))
		{
			if (weekScores.get(daWeek) < score)
				setWeekScore(daWeek, score);
		}
		else
			setWeekScore(daWeek, score);
	}

	/**
	 * YOU SHOULD FORMAT SONG WITH formatSong() BEFORE TOSSING IN SONG VARIABLE
	 */
	static function setScore(song:String, score:Int):Void
	{
		updateSave();
		// Reminder that I don't need to format this song, it should come formatted!
		songScores.set(song, score);
		save.data.songScores = songScores;
		save.flush();
	}
	static function setWeekScore(week:String, score:Int):Void
	{
		updateSave();
		// Reminder that I don't need to format this song, it should come formatted!
		weekScores.set(week, score);
		save.data.weekScores = weekScores;
		save.flush();
	}

	static function setRating(song:String, rating:Float):Void
	{
		updateSave();
		// Reminder that I don't need to format this song, it should come formatted!
		songRating.set(song, rating);
		save.data.songRating = songRating;
		save.flush();
	}

	static var formatSong = Paths.formatToSongPath;

	public static function getScore(song:String):Int
	{
		updateSave();
		var daSong:String = formatSong(song);
		if (!songScores.exists(daSong))
			setScore(daSong, 0);

		return songScores.get(daSong);
	}

	public static function getRating(song:String):Float
	{
		updateSave();
		var daSong:String = formatSong(song);
		if (!songRating.exists(daSong))
			setRating(daSong, 0);

		return songRating.get(daSong);
	}

	public static function getWeekScore(week:String):Int
	{
		updateSave();
		var daWeek:String = formatSong(week);
		if (!weekScores.exists(daWeek))
			setWeekScore(daWeek, 0);

		return weekScores.get(daWeek);
	}

	public static function load():Void
	{
		updateSave();
		if (save.data.weekScores != null)
		{
			weekScores = save.data.weekScores;
		}
		if (save.data.songScores != null)
		{
			songScores = save.data.songScores;
		}
		if (save.data.songRating != null)
		{
			songRating = save.data.songRating;
		}
	}
}