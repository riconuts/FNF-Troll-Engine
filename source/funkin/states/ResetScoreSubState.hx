package funkin.states;

import funkin.data.Highscore;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.util.FlxColor;

using StringTools;

@:noScripting
class ResetScoreSubState extends AlphabetPromptSubstate
{
	var id:String;
	var chartId:String;
	var displayName:String;
	var isStoryMode:Bool;
	
	public function new(id:String, chartId:String, ?isStoryMode:Bool, ?displayName:String)
	{
		this.id = id;
		this.chartId = chartId;
		this.displayName = displayName==null ? '$id ($chartId)' : displayName;
		this.isStoryMode = isStoryMode == true;

		super("Reset the score of", resetScore);	
	}

	override function create() {
		super.create();
		var tooLong:Float = (this.displayName.length > 18) ? 0.8 : 1; //Fucking Winter Horrorland

		var text:Alphabet = new Alphabet(0, messageTxt.y + 90, this.displayName + "?", true, false, 0.05, tooLong);
		text.scrollFactor.set();
		text.screenCenter(X);
		//if(!this.isStoryMode) text.x += 60 * tooLong;
		add(text);
	}

	function resetScore() {
		if(isStoryMode)
			Highscore.resetWeek(id);
		else
			Highscore.resetSong(id, chartId);
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);
	}
}