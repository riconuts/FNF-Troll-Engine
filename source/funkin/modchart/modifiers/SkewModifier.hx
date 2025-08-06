package funkin.modchart.modifiers;

class SkewModifier extends NoteModifier {
	override function getName()
		return "skewX";

	override function isRenderMod()
		return true;

	// all the hard work was done by Srt

	private function getFieldCenterX(field:NoteField):Float {
		final field = field.field;
		final FKC = field.keyCount;
		return (field.getBaseX(0) + field.getBaseX(FKC - 1)) * 0.5;

	}

	override function modifyVert(beat:Float, vert:Vector3, idx:Int, obj:NoteObject, pos:Vector3, player:Int, data:Int, field:NoteField):Vector3 
	{
		final centerX:Float = getFieldCenterX(field);

		vert.x -= centerX;
		vert.y -= FlxG.height * 0.5;

		vert.x += vert.y * getValue(player);
		vert.y += FlxG.height * vert.x / (Note.swagWidth * field.field.keyCount) * getSubmodValue('skewY', player);

		vert.x += centerX;
		vert.y += FlxG.height * 0.5;

		final width: Float = obj.frameWidth * obj.scale.x;
		final height:Float = obj.frameHeight * obj.scale.y;
		
		if(obj.objType != NOTE || !(cast(obj, Note)).isSustainNote){
			switch(idx % 4){
				case 0 | 1:
					vert.x -= width * 0.5 * (getSubmodValue("noteSkewX", player) + getSubmodValue('noteSkewX$data', player));
					vert.y -= height * 0.5 * (getSubmodValue("noteSkewY", player) + getSubmodValue('noteSkewY$data', player));
				case 2 | 3:	
					vert.x += width * 0.5 * (getSubmodValue("noteSkewX", player) + getSubmodValue('noteSkewX$data', player));
					vert.y += height * 0.5 * (getSubmodValue("noteSkewY", player) + getSubmodValue('noteSkewY$data', player));
				default:

			}
		}
		/*vert.x += vert.y * getSubmodValue("noteSkewX") * getSubmodValue('noteSkewX$data');
		vert.y += vert.x * getSubmodValue("noteSkewY") * getSubmodValue('noteSkewY$data');*/

		return vert;
	}

	override function getSubmods(){
		var submods:Array<String> = ["skewY", "noteSkewX", "noteSkewY"];
		for (i in 0...4){
			submods.push('noteSkewX$i');
			submods.push('noteSkewY$i');
		}
		return submods;
	}
}