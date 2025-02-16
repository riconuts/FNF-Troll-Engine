package funkin.modchart.modifiers;

class BeatModifier extends NoteModifier {
	override function getName()return 'beat';
	override function doesUpdate(){
		return true;
	}

	var beatFactors:Array<Array<Float>> = [];

	override function update(elapsed:Float, beat:Float){
		for(pn => f in beatFactors){
			updateBeat(0, beat, pn, getSubmodValue('beatOffset', pn), getSubmodValue('beatMult', pn));
			updateBeat(1, beat, pn, getSubmodValue('beatYOffset', pn), getSubmodValue('beatYMult', pn));
			updateBeat(2, beat, pn, getSubmodValue('beatZOffset', pn), getSubmodValue('beatZMult', pn));
		}
	}

	function updateBeat(axis:Int, beat:Float, pn:Int, offset:Float, mult:Float){
		if (beatFactors[pn] == null)
			beatFactors[pn] = [];

		var accelTime:Float = 0.2;
		var totalTime:Float = 0.5;

		var beat = (beat + accelTime + offset) * (mult + 1);
		var evenBeat = Std.int(beat) % 2 != 0;

		if (beat < 0)
			return;

		beat -= Math.floor(beat);
		beat += 1;
		beat -= Math.floor(beat);
		
		if (beat >= totalTime)
			return;

		var amount:Float = 0;
		if (beat < accelTime)
		{
			amount = CoolUtil.scale(beat, 0, accelTime, 0, 1);
			amount *= amount;
		}
		else
		{
			amount = CoolUtil.scale(beat, accelTime, totalTime, 1, 0);
			amount = 1 - (1 - amount) * (1 - amount);
		}

		if (evenBeat)
			amount *= -1;

		beatFactors[pn][axis] = 40 * amount;


	}

	inline function adjust(val:Float, plr:Int):Float {
		if (getOtherValue("legacyZAxis", plr) > 0)
			return val / 1280;

		return val;
	}

	override function getPos( visualDiff:Float, timeDiff:Float, beat:Float, pos:Vector3, data:Int, player:Int, obj:FlxSprite, field:NoteField){
		if (beatFactors[player] == null){
			updateBeat(0, beat, player, getSubmodValue('beatOffset', player), getSubmodValue('beatMult', player));
			updateBeat(1, beat, player, getSubmodValue('beatYOffset', player), getSubmodValue('beatYMult', player));
			updateBeat(2, beat, player, getSubmodValue('beatZOffset', player), getSubmodValue('beatZMult', player));
		}

		pos.x += getValue(player) * (beatFactors[player][0] * FlxMath.fastSin((visualDiff / ((getSubmodValue('beatPeriod', player) * 30) + 30)) + Math.PI * 0.5));
		pos.y += getSubmodValue('beatY', player) * (beatFactors[player][1] * FlxMath.fastSin((visualDiff / ((getSubmodValue('beatYPeriod', player) * 30) + 30)) + Math.PI * 0.5));
		pos.z += adjust(getSubmodValue('beatZ', player) * (beatFactors[player][2] * FlxMath.fastSin((visualDiff / ((getSubmodValue('beatZPeriod', player) * 30) + 30)) + Math.PI * 0.5)), player);
		return pos;
	}

	override function getSubmods()
	{
		return [
			'beatOffset',
			'beatPeriod',
			'beatMult',
			
			'beatY',
			'beatYOffset',
			'beatYPeriod',
			'beatYMult',

			'beatZ',
			'beatZOffset',
			'beatZPeriod',
			'beatZMult'
		];
	}
}
