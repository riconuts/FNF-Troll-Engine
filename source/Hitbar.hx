package;

import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.util.FlxColor;
import flixel.group.FlxSpriteGroup;

class Hitmark extends FlxSprite
{
    var decayTime:Float = 0;
    override function update(elapsed:Float){
        decayTime += elapsed;
        if(decayTime >= 5){
			var decayScale = 1 - ((decayTime - 5) / 2); // 2 seconds to decay
            // based on how Schmovin' does its decay lol
			scale.y = decayScale;

			if (decayScale <= 0)
                kill();
        }
        super.update(elapsed);
    }
}
class Hitbar extends FlxSpriteGroup {
    public var mainBar:FlxSprite;
    public var averageIndicator:FlxSprite;

    var maxMarks:Int = 15;
    var markMS:Array<Float> = [];
	var markGroup:FlxTypedSpriteGroup<Hitmark> = new FlxTypedSpriteGroup<Hitmark>();
	var hitbarPxPerMs = 540 * (1 / ClientPrefs.hitWindow);
	var hitbarHeight = 20;

    var metronomeScale:Float = 1;
    var metronome:FlxSprite;

    @:isVar
    public var currentAverage(get, null):Float = 0;
    function get_currentAverage():Float{
		if (markMS.length==0)return 0.0;
        var avg:Float =0;
        for(ms in markMS)
            avg += ms;
        avg /= markMS.length;
        return avg;
    }

    public function new(?x:Float, ?y:Float){
        super(x, y);

		mainBar = new FlxSprite().makeGraphic(Std.int(hitbarPxPerMs * ClientPrefs.hitWindow), hitbarHeight, FlxColor.BLACK);
		mainBar.alpha = 0.5;
		add(mainBar);

		var epicWindow = new FlxSprite().makeGraphic(Std.int(hitbarPxPerMs * ClientPrefs.epicWindow), hitbarHeight, 0xFFE367E5);
		epicWindow.alpha = 0.6;
		var sickWindow = new FlxSprite().makeGraphic(Std.int(hitbarPxPerMs * ClientPrefs.sickWindow), hitbarHeight, 0xFF00A2E8);
		sickWindow.alpha = 0.6;
		var goodWindow = new FlxSprite().makeGraphic(Std.int(hitbarPxPerMs * ClientPrefs.goodWindow), hitbarHeight, 0xFFB5E61D);
		goodWindow.alpha = 0.6;
		var badWindow = new FlxSprite().makeGraphic(Std.int(hitbarPxPerMs * ClientPrefs.badWindow), hitbarHeight, FlxColor.BLACK);
		badWindow.alpha = 0.6;

		add(badWindow);
		add(goodWindow);
		add(sickWindow);
        if(ClientPrefs.useEpics)
		    add(epicWindow);
        
		epicWindow.x = mainBar.x + ((mainBar.width - epicWindow.width)) / 2;
		sickWindow.x = mainBar.x + ((mainBar.width - sickWindow.width)) / 2;
		goodWindow.x = mainBar.x + ((mainBar.width - goodWindow.width)) / 2;
		badWindow.x = mainBar.x + ((mainBar.width - badWindow.width)) / 2;

		averageIndicator = new FlxSprite().loadGraphic(Paths.image("hitbarAverage"));
		add(averageIndicator);
		averageIndicator.flipY = true;
		averageIndicator.y += hitbarHeight + 5;

		add(markGroup);
		metronome = new FlxSprite((mainBar.width / 2), 0).makeGraphic(10, 1, 0xC4FFFFFF);
		metronome.alpha = 0.85;
		metronome.scale.y = hitbarHeight / 4;
		metronomeScale = hitbarHeight / 4;
		add(metronome);
		metronome.x -= metronome.width / 2;
		metronome.x += ((hitbarPxPerMs / 2) * 0);
        metronome.y += hitbarHeight / 2;

    }

    public function beatHit(){
		metronomeScale = hitbarHeight;
    }

    override function update(elapsed:Float){
		var lerpVal = 0.2 * (elapsed / (1 / 60));
		averageIndicator.x = FlxMath.lerp(averageIndicator.x, (mainBar.x + (mainBar.width / 2)) + ((hitbarPxPerMs / 2) * -currentAverage) - averageIndicator.width / 2, lerpVal);
		metronomeScale = FlxMath.lerp(metronomeScale, hitbarHeight / 4, lerpVal);
		metronome.scale.y = scale.y * metronomeScale;

		markGroup.forEachDead(function(obj:Hitmark){
			markGroup.remove(obj, true);
        });
        super.update(elapsed);
    }

    public function addHit(time:Float){
        markMS.push(time);
		while (markMS.length > maxMarks)
			markMS.shift();

		var hitMark:Hitmark = new Hitmark((mainBar.width / 2), 0);
		hitMark.makeGraphic(6, hitbarHeight, FlxColor.WHITE);
		hitMark.x -= hitMark.width / 2;
		hitMark.x += ((hitbarPxPerMs / 2) * -time);
		markGroup.add(hitMark);
		while (markGroup.length > maxMarks)
		{
			var recent = markGroup.members[0];
			markGroup.remove(recent, true);
			recent.kill();
		}

		for (idx in 0...markGroup.length)
		{
			var m:FlxSprite = markGroup.members[idx];
			if (m != hitMark)
				m.color = FlxColor.RED;

			m.alpha = 1 - ((markGroup.length - idx) / maxMarks);
		}
    }
}