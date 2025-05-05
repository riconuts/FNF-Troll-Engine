package funkin.data;

#if !macro
import flixel.util.FlxSave;
using StringTools;
#end

enum abstract FCType(Int) from Int to Int
{
	var TIER4 = 4; // EFC
	var TIER3 = 3; // SFC
	var TIER2 = 2; // GFC
	var TIER1 = 1; // FC
	var NONE = 0; // NO FC
}

typedef ScoreRecord = {
	@:optional var scoreSystemV:Float; // version for the score system
	var score:Int; // score based on judgements
	var comboBreaks:Int;
	var accuracyScore:Float; // score based on accuracy. Judge-based on normal, MS-based on Wife3
	var maxAccuracyScore:Float; // score if you hit every note 100% accurately
	// accuracy = (notesHit / totalNotesHit) * 100 
	var judges:Map<String, Int>; // keeps track of the judgements you hit
	var noteDiffs:Array<Float>; // hit diffs for every note
	var npsPeak:Int; // peak notes-per-second
	@:optional var fcMedal:FCType;

	@:optional var rating:Float; // backwards compat, never saved for new scores, only migrated.
}

// TODO: maybe a score history?
// TODO: find a use for the noteHits (Maybe once we have score history we can make it so you can replay old scores?)
// Judges will be used for FC medals

class Highscore {
	static final accSystems:Map<String, String> = [
		"s" => "Simple",
		"Simple" => "s",
		"" => "Judgement",
		"Judgement" => "",
		"w3" => "Wife3",
		"Wife3" => "w3",
		"pb" => "PBot",
		"PBot" => "pb"
	];

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
			["AA:", 0.99],
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
			['SS+++', 1], // 4-star
			["SS++", 0.99], // 3-star
			["SS+", 0.98], // 2-star
			["SS", 0.96], // 1-star
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

	static final systemVersions:Map<String, Float> = [
		"w3" => 1, // wife3
		"pb" => 1, // pbot
		"s" => 1, // simple
		"" => 2 // judgement
	];
/* 	static var wifeVersion:Float = Wife3.version; // wife version. TECHNICALLY 3, but doing 1 for the sake of being easy
	static var pbotVersion:Float = 1; // PBot version.
	static var normVersion:Float = 2; // judgement acc version */

	#if !macro
	static var save:FlxSave = new FlxSave(); // high-score save file
	static var currentSongData:Map<String, ScoreRecord> = []; // all song score records
	static var currentWeekData:Map<String, Int> = []; // all week scores (might eventually change to its own WeekScoreRecord idk lol prob not tho)
	static var currentLoadedID:String = '';

	public static var accSystem:String = '';
	public static var hasEpic:Bool = false;
	public static var judgeDiff:String = 'J4';
	public static var version:Float = systemVersions.get("");


	public static var weekCompleted:Map<String, Bool> = new Map<String, Bool>(); // maybe move this to WeekData oops

	public static function getID()
	{
 		var idArray:Array<String> = [];


		idArray.push(hasEpic ? 't' : 'f');
		if (accSystem != '')
			idArray.push(accSystem);

		var windows = ['sick', 'good', 'bad', 'hit'];
		if (hasEpic)
			windows.insert(0, 'epic');
		if (judgeDiff != 'J4')
			idArray.push(judgeDiff);
		
		for (window in windows)
		{
			var realWindow = Reflect.field(ClientPrefs, window + "Window");
			idArray.push(Std.string(realWindow));
		}

		var gameplayModifierString:String = '';
		if (ClientPrefs.getGameplaySetting('opponentPlay', false))
			gameplayModifierString += 'o';

		if (gameplayModifierString.trim().length > 0)
			idArray.push(gameplayModifierString);

		return idArray.join("-"); 
	}

	static inline function formatSong(songId:String, chartId:String):String {
		// if (chartId == null || chartId.length == 0) chartId = "normal";
		return Paths.formatToSongPath(songId) + ':' + chartId;
	}

	public static inline function emptyRecord():ScoreRecord {
		return {
			scoreSystemV: version,
			score: 0,
			comboBreaks: 0,
			accuracyScore: 0,
			maxAccuracyScore: 0,
			judges: [
				"epic" => 0,
				"sick" => 0,
				"good" => 0,
				"bad" => 0,
				"shit" => 0,
				"miss" => 0
			],
			noteDiffs: [],
			npsPeak: 0,
			fcMedal: NONE
		};
	}
	public static inline function getRecord(song:String, chartName:String):ScoreRecord
	{
		var formattedSong:String = formatSong(song, chartName);
		//trace('get "$formattedSong"');
		var record:Null<ScoreRecord> = currentSongData.get(formattedSong);
		/*
		if(chartName == 'normal' && record == null){
			// look for one without a difficulty string
			var noDiff:String = formatSong(song, '');
			record = currentSongData.get(formattedSong);
		}
		*/
		return record == null ? emptyRecord() : record;
	}
	public static function isValidScoreRecord(record:ScoreRecord){
		if (record.scoreSystemV == null || record.scoreSystemV < version)
			return false;
		
		return true;
	}
	public inline static function hasValidScore(song:String, chartName:String)
		return isValidScoreRecord(getRecord(song, chartName));

	public static function getRatingRecord(scoreRecord:ScoreRecord):Float{
		if (scoreRecord.rating != null)
			return scoreRecord.rating;

		if (scoreRecord.accuracyScore == 0 || scoreRecord.maxAccuracyScore == 0)
			return 0;
		
		return (scoreRecord.accuracyScore / scoreRecord.maxAccuracyScore);
	}

	public inline static function getRating(song:String, chart:String):Float
		return getRatingRecord(getRecord(song, chart));
	
	public inline static function getScore(song:String, chart:String):Int
		return getRecord(song, chart).score;
	
	public inline static function getNotesHit(song:String, chart:String):Float
		return getRecord(song, chart).accuracyScore;

	public static function getWeekScore(week:String):Int
		return currentWeekData.exists(week) ? currentWeekData.get(week) : 0;

	@:deprecated("You should use saveScoreRecord in place of saveScore!")
	public static function saveScore(song:String, score:Int = 0, ?rating:Float = -1, ?notesHit:Float = 0):Void
	{
		var tNH:Float = notesHit / rating; // total notes hit
		return saveScoreRecord(song, '', {
			scoreSystemV: version,
			score: score,
			comboBreaks: 0, // since we cant detect the combo breaks from here
			accuracyScore: notesHit,
			maxAccuracyScore: tNH,
			judges: ["epic" => 0, "sick" => 0, "good" => 0, "bad" => 0, "shit" => 0, "miss" => 0],
			noteDiffs: [],
			npsPeak: 0,
			fcMedal: rating == 1 ? TIER4 : NONE
		});
	}

	public static function saveScoreRecord(song:String, chartName:String, scoreRecord:ScoreRecord, ?force:Bool = false)
	{
		if (scoreRecord.fcMedal == null){
			if(scoreRecord.comboBreaks > 0)
				scoreRecord.fcMedal = NONE; // no fc since you have a CB lol
			else{
				var ordering:Array<Array<Dynamic>> = [["miss",NONE],["shit",TIER1],["bad",TIER1],["good",TIER2],["sick",TIER3],["epic",TIER4]]; // just to make sure the order is correct
				var curMedal = NONE;
				for (data in ordering){
					if (scoreRecord.judges.get(data[0]) > 0){
						curMedal = data[1];
						break;
					}
				}
				scoreRecord.fcMedal = curMedal;
			}
		}
		if (scoreRecord.scoreSystemV==null)scoreRecord.scoreSystemV = version;

		var currentRecord = getRecord(song, chartName);
		var currentFC:Int = (currentRecord.fcMedal == null ? NONE : currentRecord.fcMedal);
		var savingFC:Int = (scoreRecord.fcMedal == null ? NONE : scoreRecord.fcMedal);
		var isFCHigher = currentFC < savingFC;

		if (force || !isValidScoreRecord(currentRecord) || currentRecord.accuracyScore < scoreRecord.accuracyScore || currentRecord.scoreSystemV < scoreRecord.scoreSystemV || isFCHigher){
			currentSongData.set(formatSong(song, chartName), scoreRecord);
			save.data.saveData.set(currentLoadedID, currentSongData);
			save.flush();
		}
	}

	public static function saveWeekScore(week:String, score:Int = 0, ?force:Bool=false){
		if (force || currentWeekData.get(week) < score){
			weekCompleted.set(week, true);
			save.data.weekCompleted = weekCompleted;

			currentWeekData.set(week, score);
 			save.data.weekSaveData.set(currentLoadedID, currentWeekData);
			
			save.flush(); 
		}
	}
	public static function resetWeek(week:String){
		currentWeekData.set(week, 0);
		save.data.weekSaveData.set(currentLoadedID, currentWeekData);
		save.flush(); 
	}
	public static function resetSong(song:String, chartName:String){
		var formattedSong:String = formatSong(song, chartName);
		trace('reset song score "$formattedSong"');

		currentSongData.remove(formattedSong);
		save.data.saveData.set(currentLoadedID, currentSongData);
		save.flush();
	}

	public static function loadData(?ID:String, ?shouldMigrate:Bool=true)
	{
		if (ID==null){
			accSystem = accSystems.get(ClientPrefs.accuracyCalc);
			hasEpic = ClientPrefs.useEpics;
			judgeDiff = ClientPrefs.judgeDiff;
			ID = getID();
			if (currentLoadedID == ID)
				return;
		}else{
			if (currentLoadedID == ID)
				return;
			var idData = ID.split("-");
			accSystem = accSystems.exists(idData[1]) ? accSystems.get(idData[1]) : '';
			hasEpic = idData[0] == 't';
			judgeDiff = accSystem == '' ? idData[2] : idData[1];
			if (!Math.isNaN(Std.parseFloat(judgeDiff)))
				judgeDiff = 'J4';
		}
		
		version = systemVersions.get(accSystem);

		currentLoadedID = ID;
		currentSongData = [];
		currentWeekData = [];

		var songSaveData:Map<String, Map<String, ScoreRecord>> = [];
		var weekSaveData:Map<String, Map<String, Int>> = [];
		var saveNeedsFlushing:Bool = false;

		if (save.data.saveData == null)
		{
			save.data.saveData = songSaveData;
			saveNeedsFlushing = true;
		}else
			songSaveData = save.data.saveData;

		if(save.data.weekSaveData == null)
		{
			save.data.weekSaveData = weekSaveData;
			saveNeedsFlushing = true;
		}else
			weekSaveData = save.data.weekSaveData;
		
		if (songSaveData.exists(ID + "songs")){
			songSaveData.set(ID, songSaveData.get(ID + "songs"));
			songSaveData.remove(ID + "songs");
		}

		if (!songSaveData.exists(ID)){
			songSaveData.set(ID, []);
			save.data.saveData = songSaveData;
			saveNeedsFlushing = true;
		}else
			currentSongData = songSaveData.get(ID);

		if (!weekSaveData.exists(ID))
		{
			weekSaveData.set(ID, []);
			save.data.weekSaveData = weekSaveData;
			saveNeedsFlushing = true;
		}else
			currentWeekData = weekSaveData.get(ID); 
		

		if (shouldMigrate)
			if(migrateSave(false))
				saveNeedsFlushing = true;
		
		if (saveNeedsFlushing)
			save.flush();
	}
	
	public static function migrateSave(?id:String, ?shouldFlush:Bool = false)
	{
		if (id == null)
			id = currentLoadedID;

		var oldID = currentLoadedID;
		var needsFlush:Bool = false;

		loadData(id, false);

		var migrationSave:FlxSave = new FlxSave();
		
		migrationSave.bind('scores$id');
		

		if (!migrationSave.isEmpty()){
			var backupSave = new FlxSave();
			backupSave.bind('scores${id}_BAK');
			backupSave.mergeData(migrationSave.data, true);
			backupSave.close();
		}

		var scores:Map<String, Int> = migrationSave.isEmpty() ? null : migrationSave.data.songScores;
		if (migrationSave.data.songOldScores != null){
			var oldScores:Map<String, Int> = migrationSave.data.songOldScores;
			for (song => score in oldScores){
				scores.set(song, score);
				oldScores.remove(song);
			}
			//migrationSave.data.songOldScores = null;
		}
		if (scores == null){  // doesnt matter since theres no scores here TO migrate
 			if (!migrationSave.isEmpty())
				migrationSave.erase(); 

			migrationSave.close();
			return false;
		}
		trace("migrating " + id);
		var wifeScores:Map<String, Float> = [];
		var songRatings:Map<String, Float> = [];
		var weekScores:Map<String, Int> = [];

		if (migrationSave.data.songWifeScore != null)
			wifeScores = migrationSave.data.songWifeScore;
		if (migrationSave.data.songRating != null)
			songRatings = migrationSave.data.songRating;

		if (migrationSave.data.weekScores != null)
			weekScores = migrationSave.data.weekScores;

/* 		var idData = id.split("-");
		var wife3 = idData[1] == 'w3'; */

		for (song => wScore in wifeScores)
		{
			if (!scores.exists(song))
				scores.set(song, 0); // for some reason if it has a wife score but not a judge score then i guess just make it 0
			// could PROBABLY do some math to approximate it but /shrug i dont care enough imma b real
		}

		for (song => rating in songRatings){
			if(!scores.exists(song))
				scores.set(song, 0); // same as above
		}


		var successfulMigrations:Int = 0;
		var count:Int = 0;
		for(song => score in scores){
			count++;
			try{
				if (!currentSongData.exists(song)){
					var newRecord:ScoreRecord = emptyRecord();
					newRecord.score = score;
					if (songRatings.exists(song)){
						var rating = songRatings.get(song);
						if (wifeScores.exists(song)){
							var notesHit = wifeScores.get(song);
							newRecord.accuracyScore = notesHit;
							newRecord.maxAccuracyScore = notesHit / rating;	
						}else
							newRecord.rating = rating;
						newRecord.scoreSystemV = 1.0;
						newRecord.fcMedal = rating == 1 ? TIER4 : NONE; // since we cant really detect it from here lol
					}
					
					wifeScores.remove(song);
					songRatings.remove(song);
					scores.remove(song);
					currentSongData.set(song, newRecord);
				}
				successfulMigrations++;
				
			}
			catch(e:Dynamic){
				trace("error migrating scores: " + e);
			}
		}

		save.data.saveData.set(id, currentSongData);
		needsFlush = true;

		if (migrationSave.data.songRatings != null)
			migrationSave.data.songRatings = songRatings;

		if (migrationSave.data.songWifeScores != null)
			migrationSave.data.songWifeScores = wifeScores;

		migrationSave.data.songScores = scores;
		
		trace('successfully migrated $successfulMigrations/$count saved scores');
		if (weekScores!=null){
			for (week => score in weekScores){
				currentWeekData.set(week, score);
				weekScores.remove(week);
			}
			migrationSave.data.weekScores = weekScores;
			save.data.weekSaveData.set(id, currentWeekData);
			needsFlush = true;
		}

		if (shouldFlush && needsFlush)
			save.flush();
		
		if (successfulMigrations == count){
			trace("successfully migrated shit, erasing save");
			migrationSave.erase(); // erase the old data since it has been migrated successfully
			migrationSave.destroy();
		}else{
			trace("not everything successfully migrated so the save is being kept");
			migrationSave.close();
		}


		loadData(oldID, false);

		return needsFlush;
	}

	public static function load():Void
	{
		save.bind("highscores2");
		loadData();

		if (FlxG.save.data.weekCompleted != null)
			Highscore.weekCompleted = FlxG.save.data.weekCompleted;
	}
	#end
}