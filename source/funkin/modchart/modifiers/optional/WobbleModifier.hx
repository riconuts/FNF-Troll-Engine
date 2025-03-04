package funkin.modchart.modifiers.optional;


@:keep

// Bopeebo Rumble "wobble"
// Resembles putting WiggleEffect on the holds + notes

class WobbleModifier extends NoteModifier {
	override function getName()
		return "wobble";
		
	override function getPos(visualDiff:Float, timeDiff:Float, beat:Float, pos:Vector3, column:Int, player:Int, obj:NoteObject, field:NoteField) {
		var val = getValue(player);
		if(obj.objType == NOTE){
			var note:Note = cast obj;
			if (note.isSustainNote)
				val += getSubmodValue("wobbleHolds", player);
		}
		pos.x += FlxMath.fastSin((visualDiff / FlxG.height) * Math.PI * 3) * (val * 250);
		return pos;
	}

	override function getSubmods()
		return ["wobbleHolds"];
	
}