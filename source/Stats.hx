package;
/* hud.ratingFC = ratingFC;
hud.grade = ratingName;
hud.ratingPercent = ratingPercent;
hud.misses = songMisses;
hud.combo = combo;
hud.comboBreaks = comboBreaks;
hud.judgements.set("miss", songMisses);
hud.judgements.set("cb", comboBreaks);
hud.totalNotesHit = totalNotesHit;
hud.totalPlayed = totalPlayed;
hud.score = songScore; */
class Stats {
	public var gradeSet:Array<Array<Dynamic>> = [];

    public var score:Float = 0;
    public var totalPlayed:Float = 0;
	public var totalNotesHit:Float = 0;
    public var judgements:Map<String, Int> = [];
    public var clearType:String = '';
    public var grade:String = '';
    public var combo:Int = 0;
	public var ratingPercent:Float = 0;

    @:isVar
    public var comboBreaks(get, set):Int = 0;
    function get_comboBreaks()return judgements.get("cb");
	function set_comboBreaks(val:Int){judgements.set("cb", val); return val;}
	@:isVar
	public var misses(get, set):Int = 0;
	function get_misses()return judgements.get("miss");
	function set_misses(val:Int){judgements.set("miss", val);return val;}

	public function new(?gradeSet:Array<Array<Dynamic>>){
		if (gradeSet==null)
			gradeSet = Highscore.grades.get(ClientPrefs.gradeSet);

        this.gradeSet = gradeSet;
    }

    public function getGrade()
    {
        var grade = '?';
		if (totalPlayed < 1)
            return grade;

        
        return grade;
    }

    public function getClearType(){

    }

    public function updateVariables()
    {
        grade = getGrade();
    }
}