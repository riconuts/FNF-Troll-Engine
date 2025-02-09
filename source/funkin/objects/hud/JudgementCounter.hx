// @author Nebula_Zorua
// Makes it easier to keep judgement counters consistent across HUDs & makes it easier to do judgement counters in scripted HUDs

package funkin.objects.hud;

import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.group.FlxSpriteGroup.FlxTypedSpriteGroup;
import flixel.text.FlxText;

enum abstract JudgeLength(String) from String to String 
{
	var SHORTENED = 'Shortened';
	var FULL = 'Full';


	var __OFF__ = 'Off'; // do not use
}

@:structInit
class JudgeCounterSettings {
	public var textBorderSpacing:Float = 6;

	public var nameFont:String = 'vcr.ttf';
	public var numbFont:String = 'vcr.ttf';
	public var textLineSpacing:Float = 22;
	public var textSize:Int = 20;
	public var textBorderSize:Float = 1.5;
	public var textWidth:Float = 150;


	@:isVar
	public var length(get, set):JudgeLength = SHORTENED;
	function get_length()
		return textWidth < 200 ? SHORTENED : FULL;

	function set_length(v:JudgeLength){
		textWidth = (v == SHORTENED ? 150 : 200);
		return v;
	}

}

class JudgementCounter extends FlxTypedSpriteGroup<FlxText> 
{
    public var text:FlxText;
	public var numb:FlxText;
	public function new(x:Float, y:Float, judgeName:String, colour:FlxColor, counterSettings:JudgeCounterSettings) {
		super(x, y);
		var textWidth = counterSettings.textWidth;
		text = new FlxText(0, 0, textWidth, judgeName);
		text.setFormat(Paths.font(counterSettings.nameFont), counterSettings.textSize, colour, LEFT);
		text.setBorderStyle(OUTLINE, 0xFF000000, counterSettings.textBorderSize);
		text.scrollFactor.set();
		add(text);

		numb = new FlxText(0, 0, textWidth, "0");
		numb.setFormat(Paths.font(counterSettings.numbFont), counterSettings.textSize, 0xFFFFFFFF, RIGHT);
		numb.setBorderStyle(OUTLINE, 0xFF000000, counterSettings.textBorderSize);
		numb.scrollFactor.set();
		add(numb);
    }

	public function bump() {

		if (text != null) {
			FlxTween.cancelTweensOf(text.scale);
			text.scale.set(1.075, 1.075);
			FlxTween.tween(text.scale, {x: 1, y: 1}, 0.2);
		}
		if (numb != null) {
			FlxTween.cancelTweensOf(numb.scale);
			numb.scale.set(1.075, 1.075);
			FlxTween.tween(numb.scale, {x: 1, y: 1}, 0.2);
		}
	}

}

class JudgementCounters extends FlxTypedSpriteGroup<JudgementCounter>
{
	public var len:Int = 0;
	public var counters:Map<String, JudgementCounter> = [];

	public function new(x:Float, y:Float, displayNames:Map<String, String>, judgeColors:Map<String, FlxColor>, settings:JudgeCounterSettings, ?displayedJudges:Array<String>){
		super(x, y);
		var displayedJudges:Array<String> = displayedJudges ?? [for(i in displayNames.keys())i];

		var halfPoint = displayedJudges.length / 2;

		for (idx => id in displayedJudges){
			var cnt = new JudgementCounter(0, 0, displayNames.get(id), judgeColors.get(id), settings);
			counters.set(id, cnt);
			add(cnt);
			cnt.y = y + ((idx - halfPoint) * settings.textLineSpacing);
			len++;
		}
	}

	public function bump(judgeID:String){
		var counter = counters.get(judgeID);
		if(counter == null)return;
		counter.bump();
	}

	public function setCount(judgeID:String, count:Int){
		var counter = counters.get(judgeID);
		if(counter == null)return;
		counter.numb.text = Std.string(count);
	}
}