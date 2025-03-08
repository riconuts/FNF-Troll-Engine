package funkin.modchart.modifiers.optional;



// Bopeebo Rumble "wobble"
// Resembles putting WiggleEffect on the holds + notes

@:keep
class WiggleModifier extends NoteModifier {
	override function getName()
		return "wiggle";
		
	override function getPos(visualDiff:Float, timeDiff:Float, beat:Float, pos:Vector3, column:Int, player:Int, obj:NoteObject, field:NoteField) {
		var val = getValue(player);
		if(obj.objType == NOTE){
			var note:Note = cast obj;
			if (note.isSustainNote)
				val += getSubmodValue("wiggleHolds", player);
		}
		pos.x += FlxMath.fastSin((visualDiff / FlxG.height) * getSubmodValue("wiggleSpeed", player) ) * (val * 250);
		return pos;
	}

	override function getSubmods()
		return ["wiggleHolds", "wiggleSpeed"];

	override function getDefaultValues()
		return [
			"wiggleSpeed" => Math.PI * 3
		];


	
}