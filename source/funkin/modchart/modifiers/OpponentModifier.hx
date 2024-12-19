package funkin.modchart.modifiers;

class OpponentModifier extends NoteModifier {
	override function getName()
		return 'opponentSwap';

	inline function sign(x:Int)
		return x == 0 ? 0 : (x <= -1 ? -1 : 1);

	override function getPos(diff:Float, tDiff:Float, beat:Float, pos:Vector3, data:Int, player:Int, obj:FlxSprite, field:NoteField)
	{
		var distX = FlxG.width / modMgr.playerAmount;

		pos.x += distX * sign((player + 1) * 2 - 3) * getValue(player);
		// any pN > 0 should go right whereas any pN < 0 should go left 
		return pos;
	}
}