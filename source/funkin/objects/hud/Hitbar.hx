package funkin.objects.hud;

import flixel.graphics.frames.FlxFrame.FlxFrameType;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.util.FlxColor;
import flixel.group.FlxSpriteGroup;

class Hitmark extends FlxSprite
{
	public var baseAlpha:Float = 1.0;
	var decayTime:Float = 0.0;

	public function new(?x:Float, ?y:Float){
		super(x, y);
		active = false;
	}
	
	override function draw()
	{
		decayTime += FlxG.elapsed;

		var s = Conductor.crochet * 0.001;
		var decayScale = 1 - (decayTime / (s * 8)); // 8 beats to decay
		
		scale.y = decayScale;
		alpha = baseAlpha * decayScale;
		
		if (decayScale <= 0){
			decayTime = 0.0;
			kill();
		}


		checkEmptyFrame();

		if (alpha == 0 || _frame.type == FlxFrameType.EMPTY)
			return;

		if (dirty) // rarely
			calcFrame(useFramePixels);

		for (camera in cameras)
		{
			if (!camera.visible || !camera.exists || !isOnScreen(camera))
				continue;

			if (isSimpleRender(camera))
				drawSimple(camera);
			else
				drawComplex(camera);

			#if FLX_DEBUG
			FlxBasic.visibleCount++;
			#end
		}

		#if FLX_DEBUG
		if (FlxG.debugger.drawDebug)
			drawDebug();
		#end
	}
}

class Hitbar extends FlxSpriteGroup
{
	static var hitbarPxPerMs = 540 * (1 / 180);
	static var hitmarkHeight = 20;
	static var hitbarHeight = 10;
	
	
	public var mainBar:FlxSprite;
	public var averageIndicator:FlxSprite;

	var maxMarks:Int = 30;
	var markMS:Array<Float> = [];
	var markGroup:FlxTypedSpriteGroup<Hitmark> = new FlxTypedSpriteGroup<Hitmark>();

	var metronomeScale:Float = 1;
	var metronome:FlxSprite;

	public var judgeManager:funkin.data.JudgmentManager;

	@:isVar
	public var currentAverage(get, null):Float = 0;

	function get_currentAverage():Float
	{
		if (markMS.length == 0)
			return 0.0;

		var avg:Float = 0;
		for (ms in markMS)
			avg += ms;
		avg /= markMS.length;
		return avg;
	}

	public function new(?x:Float, ?y:Float)
	{
		super(x, y);

		judgeManager = PlayState.instance.judgeManager;

		mainBar = new FlxSprite().makeGraphic(Std.int(hitbarPxPerMs * ClientPrefs.hitWindow), hitbarHeight, FlxColor.BLACK);
		mainBar.alpha = 0.6;
		add(mainBar);

		inline function makeBar(width:Float, color:Int){
			var bar = new FlxSprite((mainBar.width - width) / 2).makeGraphic(1, 1);
			bar.scale.set(width, hitbarHeight);
			bar.updateHitbox();
			bar.color = color;
			bar.alpha = 0.6;
			add(bar);
		}

		// bad window
		makeBar(hitbarPxPerMs * judgeManager.getWindow(TIER2), 0xFF000000);
		// good window
		makeBar(hitbarPxPerMs * judgeManager.getWindow(TIER3), 0xFFB5E61D);
		// sick window
		makeBar(hitbarPxPerMs * judgeManager.getWindow(TIER4), 0xFF00A2E8);
		#if USE_EPIC_JUDGEMENT
		if (ClientPrefs.useEpics)
			makeBar(hitbarPxPerMs * judgeManager.getWindow(TIER5), 0xFFE367E5);
		#end

		averageIndicator = new FlxSprite(mainBar.width / 2, hitbarHeight + 5, Paths.image("hitbarAverage"));
		averageIndicator.scale.set(0.5, 0.5);
		averageIndicator.updateHitbox();
		averageIndicator.flipY = true;
		add(averageIndicator);
		averageIndicator.offset.x += averageIndicator.width / 2;

		add(markGroup);

		metronome = new FlxSprite().makeGraphic(1, 1, 0xFFFFFFFF);
		metronome.color = 0x3C00A3;
		metronome.alpha = 0.85;
		metronome.scale.set(10, metronomeScale = hitbarHeight / 4);
		metronome.updateHitbox();
		metronome.x = (mainBar.width - metronome.width) / 2; // will be off centered on some resolutions because there's no sub-pixel rendering afaik
		metronome.y = (hitbarHeight - metronome.height) / 2;
		add(metronome);
	}

	public function beatHit()
	{
		metronomeScale = hitbarHeight;
	}

	override function update(elapsed:Float)
	{
		var lerpVal = Math.exp(-elapsed * 12);
		
		averageIndicator.x = FlxMath.lerp(
			(mainBar.x + mainBar.width/2) + (hitbarPxPerMs/2 * -currentAverage), 
			averageIndicator.x,
			lerpVal
		);

		metronomeScale = FlxMath.lerp(hitbarHeight / 4, metronomeScale, lerpVal);

		markGroup.forEachAlive(function(obj:Hitmark){
			obj.baseAlpha = alpha;
			obj.visible = visible;
		});

		super.update(elapsed);

		metronome.scale.y = scale.y * metronomeScale;
		averageIndicator.scale.set(scale.x * 0.5, scale.y * 0.5);
	}
	

	public function addHit(time:Float)
	{
		markMS.push(time);
		while (markMS.length > maxMarks)
			markMS.shift();

		for (m in markGroup.members)
			m.color = FlxColor.WHITE;

		////
		var hitMark:Hitmark = markGroup.recycle(Hitmark, ()->{
			var hitMark = new Hitmark();
			hitMark.makeGraphic(6, hitmarkHeight, FlxColor.WHITE);
			hitMark.exists = false;
			@:privateAccess // bullshit
			hitMark.cameras = markGroup._cameras;
			return hitMark;
		});
		
		if (hitMark.exists){
			markGroup.group.remove(hitMark, true);
			markGroup.group.add(hitMark);
		}else
			hitMark.exists = true;

		hitMark.baseAlpha = alpha;
		hitMark.color = FlxColor.RED;
		hitMark.visible = visible;
		hitMark.x = mainBar.x + ((mainBar.width - hitMark.width) / 2);
		hitMark.x += ((hitbarPxPerMs / 2) * -time);
		hitMark.y = mainBar.y + ((mainBar.height - hitMark.height) / 2);
	}
}