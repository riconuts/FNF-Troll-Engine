package;

import openfl.text.TextFormat;
import sys.FileSystem;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxSort;
import sys.io.File;
import haxe.Json;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.util.FlxColor;
import flixel.text.FlxText;

// loosely based on how lullaby's works

typedef SubtitleFile = {
	var subtitles:Array<SubData>;
    @:optional var highlightColor:String;
    @:optional var font:String;
	@:optional var fontSize:Int;
}

typedef SubData = {
    var sub:String;
    var steps:Array<Float>;
    @:optional var seperator:String;
	@:optional var highlightColor:String;
	@:optional var font:String;
	@:optional var fontSize:Int;
}

class SubtitleDisplay extends FlxTypedGroup<FlxText> {
    public inline static function fromFile(path:String){
		return new SubtitleDisplay(Json.parse(File.getContent(path)));
    }
    

	public inline static function fromSong(song:String){
		//var jason = Paths.songJson(Paths.formatToSongPath(song) + '/subtitles');
		var jason = Paths.songJson(Paths.formatToSongPath(song) + '/subtitles');
		if (!FileSystem.exists(jason))
			jason = Paths.modsSongJson(Paths.formatToSongPath(song) + '/subtitles');
        if(!FileSystem.exists(jason)){
            trace(song + " doesnt have subtitles!");
            return null;
        }
		return new SubtitleDisplay(Json.parse(File.getContent(jason)));
    }
	
    public var y:Float = 0;
	var subData:SubData;
    var seperated:Array<String> = [];
    var currentIdx:Int = 0;
    var defaultHighlightColour:FlxColor = FlxColor.RED;
    var defaultFont:String = 'vcr';
    var defaultSize:Int = 28;
    var subs:Array<SubData> = [];
    public function new(subtitles:SubtitleFile) {
        super();
        subs = subtitles.subtitles;
        subs.sort(function(a:SubData, b:SubData){
			return FlxSort.byValues(FlxSort.ASCENDING, a.steps[0], b.steps[0]);
        });
        if(subtitles.highlightColor!=null)
			defaultHighlightColour = FlxColor.fromString(subtitles.highlightColor);
        if(subtitles.font!=null)
			defaultFont = subtitles.font;
        if(subtitles.fontSize!=null)
			defaultSize = subtitles.fontSize;
        
    }

    function clearText(){
		currentIdx = -1;
		seperated = [];
        subData = null;
        for(obj in members){
            remove(obj);
			FlxTween.cancelTweensOf(obj);
            obj.kill();
            obj.destroy();
        }
        clear();
    }

	function updateText(step:Float){
		// wish i could do this with formatting instead :pensive: but i can only set colour w/ that
		// might end up rewriting this to use OpenFL functions to get the positions exactly correct
		var len:Float = (function()
		{
			var k:Float = 0;
			for (obj in members)
				k += obj.fieldWidth;

			return k;
		})();

		for (idx in 0...members.length)
		{
			var obj = members[idx];
            if(!obj.alive)continue;
			obj.updateHitbox();
			obj.screenCenter(X);
			obj.x -= len / 2;
			if (idx > 0)
				obj.x = members[idx - 1].x + members[idx - 1].fieldWidth;
		}

        var steps = subData.steps;
        var cIdx = 0;
        for(i in 0...steps.length){
			if (step >= steps[i])
                cIdx = i;
            else
                break;
            
        }
		if (cIdx <= currentIdx)return;
		currentIdx = cIdx;

		var highlight = defaultHighlightColour;
		if (subData.highlightColor != null)
			highlight = FlxColor.fromString(subData.highlightColor);

        if(cIdx >= members.length){
            clearText();
        }else{
			for (idx in 0...members.length){
                var text = members[idx];
                @:privateAccess
                if(!text.alive || text._defaultFormat == null)
					continue;
                text.color = FlxColor.WHITE;
                
                if(idx==cIdx){
                    FlxTween.tween(text, {y: y - 8}, 0.2, {ease: FlxEase.quadOut });
                    FlxTween.color(text, 0.2, FlxColor.WHITE, highlight, {ease: FlxEase.quadOut});
                }else if(idx < cIdx){
                    FlxTween.cancelTweensOf(text);
					text.color = highlight;
					FlxTween.tween(text, {alpha: 0.9, y: y}, 0.2, {ease: FlxEase.quadOut });
                }else
                    text.y = y;
            }
            
        }
    }

    function generateText(d:SubData){
		clearText();
        subData = d;
        var seperator = subData.seperator==null?"/":subData.seperator;
        seperated = subData.sub.split(seperator);
		var fontName = d.font==null?defaultFont:d.font;
        var fontSize = d.fontSize==null?defaultSize:d.fontSize;
		for (daText in seperated){
			var texObj = new FlxText(0, y, 0, daText, fontSize);
            if(!texObj.alive)continue;
			texObj.setFormat(Paths.font(fontName + ".ttf"), fontSize, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			texObj.scrollFactor.set();
			texObj.borderSize = 1.25;
			texObj.text = daText;
            texObj.updateHitbox();
			texObj.screenCenter(X);
            add(texObj);
        }
		if (members.length > 0)
			updateText(curDecStep);


    }

    function getStep(){
		var lastChange = Conductor.getBPMFromSeconds(Conductor.songPosition);

		var shit = ((Conductor.songPosition - ClientPrefs.noteOffset) - lastChange.songTime) / lastChange.stepCrochet;
		return lastChange.stepTime + shit;
    }

    var curDecStep:Float = 0;
    override function update(elapsed:Float)
    {
		super.update(elapsed);
		curDecStep = getStep();
		if (members.length > 0)
			updateText(curDecStep);
		if (subs[0] != null)
			if (curDecStep >= subs[0].steps[0])generateText(subs.shift());
        

		//updateText(curDecStep);
    }

}