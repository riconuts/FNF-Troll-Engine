package hud;

import PlayState.Wife3;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.util.FlxColor;
import flixel.group.FlxSpriteGroup;

class Hitmark extends FlxSprite
{
    var decayTime:Float = 0;
	public var baseAlpha:Float = 1;
    override function update(elapsed:Float){
        super.update(elapsed);
		decayTime += elapsed;
		var s = Conductor.crochet * 0.001;

		var decayScale = 1 - (decayTime / (s * 8)); // 8 beats to decay
		scale.y = decayScale;
		alpha = baseAlpha * decayScale;
		if (decayScale <= 0)
			kill();
    }
}
class Hitbar extends FlxSpriteGroup {
    public var mainBar:FlxSprite;
    public var averageIndicator:FlxSprite;

	var maxMarks:Int = 30;
    var markMS:Array<Float> = [];
	var markGroup:FlxTypedSpriteGroup<Hitmark> = new FlxTypedSpriteGroup<Hitmark>();
	var hitbarPxPerMs = 540 * (1 / 180);
	var hitbarHeight = 10;
	var hitmarkHeight = 20;

    var metronomeScale:Float = 1;
    var metronome:FlxSprite;

	public var judgeManager:JudgmentManager;

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

		judgeManager = PlayState.instance.judgeManager;
		mainBar = new FlxSprite().makeGraphic(Std.int(hitbarPxPerMs * ClientPrefs.hitWindow), hitbarHeight, FlxColor.BLACK);
		mainBar.alpha = 0.5;
		add(mainBar);

		var epicWindow = new FlxSprite().makeGraphic(Std.int(hitbarPxPerMs * judgeManager.getWindow(TIER5)), hitbarHeight, 0xFFE367E5);
		epicWindow.alpha = 0.6;
		var sickWindow = new FlxSprite().makeGraphic(Std.int(hitbarPxPerMs * judgeManager.getWindow(TIER4)), hitbarHeight, 0xFF00A2E8);
		sickWindow.alpha = 0.6;
		var goodWindow = new FlxSprite().makeGraphic(Std.int(hitbarPxPerMs * judgeManager.getWindow(TIER3)), hitbarHeight, 0xFFB5E61D);
		goodWindow.alpha = 0.6;
		var badWindow = new FlxSprite().makeGraphic(Std.int(hitbarPxPerMs * judgeManager.getWindow(TIER2)), hitbarHeight, FlxColor.BLACK);
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
		averageIndicator.scale.set(0.5, 0.5);
		averageIndicator.updateHitbox();
		averageIndicator.flipY = true;
		averageIndicator.y += hitbarHeight + 5;

		add(markGroup);
		metronome = new FlxSprite((mainBar.width / 2), 0).makeGraphic(10, 1, 0xFFFFFFFF);
		metronome.color = 0x3C00A3;
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

		markGroup.forEachAlive(function(obj:Hitmark){
			obj.baseAlpha = alpha;
			obj.visible = visible;
		});

		markGroup.forEachDead(function(obj:Hitmark){
			markGroup.remove(obj, true);
        });
        super.update(elapsed);
		metronome.scale.y = scale.y * metronomeScale;
		averageIndicator.scale.set(scale.x * 0.5, scale.y * 0.5);
    }

    public function addHit(time:Float){
        markMS.push(time);
		while (markMS.length > maxMarks)
			markMS.shift();

		for (m in markGroup.members)m.color = FlxColor.WHITE;
		var hitMark:Hitmark = new Hitmark((mainBar.width / 2), 0);
		hitMark.makeGraphic(6, hitmarkHeight, FlxColor.WHITE);
		hitMark.baseAlpha = alpha;
		hitMark.color = FlxColor.RED;
		markGroup.add(hitMark);
		hitMark.visible = visible;
		hitMark.x = mainBar.x + ((mainBar.width - hitMark.width)/2);
		hitMark.x += ((hitbarPxPerMs / 2) * -time);
		hitMark.y = mainBar.y + ((mainBar.height - hitMark.height)/2);
    }
}