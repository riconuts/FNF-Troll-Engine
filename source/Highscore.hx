package;
#if !macro
import flixel.FlxG;
import flixel.util.FlxSave;
#end
using StringTools;

class Highscore
{
	public static var grades:Map<String, Array<Array<Dynamic>>> = [
		"Psych" => [
			["Perfect!!", 1],
			["Sick!", 0.9],
			["Great", 0.8],
			["Good", 0.7],
			["Nice", 0.69],
			["Okay", 0.6],
			["Meh", 0.5],
			["Bad", 0.4],
			["Bruh", 0.3],
			["You Suck!", 0.01],
			["Git Gud!!", -1],
			["YOU ARE FUCKING ATROCIOUS", -200], // if you somehow get BELOW -100, this is your prize! (Only applicable to Wife3)
		],
		"Etterna" => [
			["AAAAA", 0.999935],
			["AAAA:", 0.99980],
			["AAAA.", 0.99970],
			["AAAA", 0.99955],
			["AAA:", 0.999],
			["AAA.", 0.998],
			["AAA", 0.997],
			["AA:",0.99],
			["AA.", 0.9650],
			["AA", 0.93],
			["A:", 0.9],
			["A.", 0.85],
			["A", 0.8],
			["B", 0.7],
			["C", 0.6],
			["D", 0.01],
			["F", -1],
			["ULTRA F", -200], // if you somehow get BELOW -100, this is your prize! (Only applicable to Wife3)
		],
		"ITG-Like" => [
			// we cant do stars, so SS and everything beyond is a star lol (SS is 1 star, SS+ is 2, SS++ is 3 and Ss+++ is 4)
			// or we do asterisks? (*, **, *** and ****)
			// or we modify the font to allow for stars like i did in andromeda
			
			['SS+++', 1],
			["SS++", 0.99],
			["SS+", 0.98],
			["SS", 0.96],
			["S+", 0.94],
			["S", 0.92],
			["S-", 0.89],
			["A+", 0.86],
			["A", 0.83],
			["A-", 0.8],
			["B+", 0.76],
			["B", 0.72],
			["B-", 0.68],
			["C+", 0.64],
			["C", 0.6],
			["C-", 0.5],
			["D+", 0.5],
			["D", 0.45],
			["D-", 0.01],
			["F", -1],
			["ULTRA F", -200], // if you somehow get BELOW -100, this is your prize! (Only applicable to Wife3)
			
		]
	];
	#if (haxe >= "4.0.0")
	public static var weekScores:Map<String, Int> = new Map();
	public static var songScores:Map<String, Int> = new Map();
	public static var songRating:Map<String, Float> = new Map();
	#else
	public static var weekScores:Map<String, Int> = new Map();
	public static var songScores:Map<String, Int> = new Map<String, Int>();
	public static var songRating:Map<String, Float> = new Map<String, Float>();
	#end

	#if !macro
	static var loadedID:String = '';
	static var save:FlxSave = new FlxSave();
	static var defaultID:String = 'f-45-90-135-166'; // psych preset aka the default preset from old tgt
	// this is used to make sure if you're on psych preset, you get to keep your old high scores

	public static function getID(){
		var idArray:Array<String> = [];
		idArray.push(ClientPrefs.useEpics ? 't' : 'f');
		if (ClientPrefs.wife3)
			idArray.push("w3");
		var windows = ['sick', 'good', 'bad', 'hit'];
		if(ClientPrefs.useEpics)windows.insert(0, 'epic');
		if (ClientPrefs.judgeDiff!='J4')
			idArray.push(ClientPrefs.judgeDiff);
		
		for(window in windows){
			var realWindow = Reflect.field(ClientPrefs, window + "Window");
			idArray.push(Std.string(realWindow));
		}


		var id = idArray.join("-");

		return "scores" +  id;
	}

	public static function updateSave(){
		var id = getID();
		if(loadedID != id){
			loadedID = id;
			if(save.isBound){
				save.flush();
				save.close();
				save = new FlxSave();
			} // makes sure it all saved

			save.bind(id);
			save.flush();

			if (id == defaultID)
			{
				if (save.isEmpty()){
					save.mergeDataFrom("flixel", null, false, false);
					save.flush();
				}
			}
			loadData();
			
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

	static function loadData(){
		weekScores=[];
		songScores=[];
		songRating=[];
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
	public static function load():Void
	{
		updateSave();
		loadData();
	}
	#end
}