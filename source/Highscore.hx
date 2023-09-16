package;
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
}

// TODO: maybe a score history?
// TODO: find a use for the noteHits (Maybe once we have score history we can make it so you can replay old scores?)
// Judges will be used for FC medals

class Highscore {
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

    static var wifeVersion:Float = 1; // wife version. TECHNICALLY 3, but doing 1 for the sake of being easy
    static var normVersion:Float = 2; // normal acc version
	#if !macro
	static var save:FlxSave = new FlxSave(); // high-score save file
    static var currentSongData:Map<String, ScoreRecord> = []; // all song score records
	static var currentWeekData:Map<String, Int> = []; // all week scores (might eventually change to its own WeekScoreRecord idk lol prob not tho)
    static var currentLoadedID:String = '';

    public static var isWife3:Bool = false;
	public static var hasEpic:Bool = false;
	public static var judgeDiff:String = 'J4';

	public static function getID()
	{
 		var idArray:Array<String> = [];


		idArray.push(hasEpic ? 't' : 'f');
		if (isWife3)
			idArray.push("w3");

		var windows = ['sick', 'good', 'bad', 'hit'];
		if (hasEpic)
			windows.insert(0, 'epic');
		if (judgeDiff != 'J4')
			idArray.push(judgeDiff);

        var gameplayModifierString:String = '';
        if(ClientPrefs.getGameplaySetting('opponentPlay', false))
            gameplayModifierString += 'o';

        if(gameplayModifierString.trim().length > 0)idArray.push(gameplayModifierString);
        
		for (window in windows)
		{
			var realWindow = Reflect.field(ClientPrefs, window + "Window");
			idArray.push(Std.string(realWindow));
		}
		return idArray.join("-"); 
	}

	public static function floorDecimal(value:Float, decimals:Int):Float
	{
		if (decimals < 1)
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

	static var formatSong = Paths.formatToSongPath;

    public static function getRecord(song:String):ScoreRecord
    {
        var formattedSong:String = formatSong(song);
		return currentSongData.exists(formattedSong) ? currentSongData.get(formattedSong) : {
            scoreSystemV: isWife3 ? wifeVersion : normVersion,
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
    public static function hasValidScore(song:String)return true;
    public static function getRating(song:String):Float{
		var scoreRecord = getRecord(song);
		if (scoreRecord.accuracyScore == 0 || scoreRecord.maxAccuracyScore == 0)return 0;
		return (scoreRecord.accuracyScore / scoreRecord.maxAccuracyScore);
    }
    public inline static function getScore(song:String)return getRecord(song).score;
    
	public inline static function getNotesHit(song:String)return getRecord(song).accuracyScore;

	public static function getWeekScore(week:String)return currentWeekData.get(week);

    @:deprecated("You should use saveScoreRecord in place of saveScore!")
	public static function saveScore(song:String, score:Int = 0, ?rating:Float = -1, ?notesHit:Float = 0):Void
	{
        var tNH:Float = notesHit / rating; // total notes hit
        return saveScoreRecord(song, {
			scoreSystemV: isWife3 ? wifeVersion : normVersion,
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

	public static function saveScoreRecord(song:String, scoreRecord:ScoreRecord){
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
		if (scoreRecord.scoreSystemV==null)scoreRecord.scoreSystemV = isWife3 ? wifeVersion : normVersion;

        var currentRecord = getRecord(song);
		var currentFC:Int = (currentRecord.fcMedal == null ? NONE : currentRecord.fcMedal);
		var savingFC:Int = (scoreRecord.fcMedal == null ? NONE : scoreRecord.fcMedal);
		var isFCHigher = currentFC < savingFC;

		if (currentRecord.accuracyScore < scoreRecord.accuracyScore || currentRecord.scoreSystemV < scoreRecord.scoreSystemV || isFCHigher){
            currentSongData.set(formatSong(song), scoreRecord);
			save.data.saveData.set(currentLoadedID + "songs", currentSongData);
            save.flush();
        }
    }

	public static function saveWeekScore(week:String, score:Int = 0){
		if (currentWeekData.get(week) < score){
            currentWeekData.set(week, score);
/* 			save.data.saveData.set(currentLoadedID + "weeks", currentWeekData);
			save.flush(); */
        }
    }
	public static function resetWeek(week:String){}
	public static function resetSong(week:String){}

	public static function loadData()
	{
		isWife3 = ClientPrefs.wife3;
		hasEpic = ClientPrefs.useEpics;
		judgeDiff = ClientPrefs.judgeDiff;
        var ID = getID();
        if(currentLoadedID == ID)return;

        currentLoadedID = ID;
		currentSongData = [];
		var saveData:Map<String, Map<String, ScoreRecord>> = [];
		var saveNeedsFlushing:Bool = false;

		if (save.data.saveData == null)
		{
			save.data.saveData = saveData;
			saveNeedsFlushing = true;
		}else
			saveData = save.data.saveData;
        
        if(!saveData.exists(ID + "songs")){
            saveData.set(ID + "songs", []);
			save.data.saveData = saveData;
			saveNeedsFlushing = true;
        }else
			currentSongData = saveData.get(ID + "songs");

/* 		if (!saveData.exists(ID + "weeks"))
		{
			saveData.set(ID + "weeks", []);
			save.data.saveData = saveData;
			saveNeedsFlushing = true;
		}else
			currentWeekData = saveData.get(ID + "weeks"); */
		
		if (saveNeedsFlushing)
            save.flush();
    }
    
    public static function migrateSave(oldID:String)
    {
        
    }

	public static function load():Void
	{
		save.bind("highscores2");
		loadData();
	}
    #end
}