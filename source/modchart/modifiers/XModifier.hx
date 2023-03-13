package modchart.modifiers;

import math.Vector3;

class XModifier extends NoteModifier {
	override function getName()
		return 'xmod';

	override function shouldExecute(player:Int, val:Float)
		return true;
    
	override function updateNote(beat:Float, daNote:Note, player:Int)
	{
        daNote.multSpeed = getValue(player) * getSubmodValue('xmod' + daNote.noteData, player);
    }

	override function getSubmods()
	{
		var subMods:Array<String> = [];
		for (i in 0...4)
			subMods.push('xmod$i');
		
		return subMods;
	}

}