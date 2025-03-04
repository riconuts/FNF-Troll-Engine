package funkin.modchart.modifiers.optional;


@:keep

// Bopeebo Rumble "wobble"
class WobbleModifier extends NoteModifier {
	override function getName()
		return "wobble";
		
	override function getPos(visualDiff:Float, timeDiff:Float, beat:Float, pos:Vector3, column:Int, player:Int, obj:FlxSprite, field:NoteField) {
		var val = getValue(player);
		pos.x += FlxMath.fastSin((visualDiff / FlxG.height) * Math.PI * 3) * (val * 250);
	}
}