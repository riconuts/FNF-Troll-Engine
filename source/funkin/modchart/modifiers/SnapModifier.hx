package funkin.modchart.modifiers;

class SnapModifier extends NoteModifier
{
	override function getOrder()
		return Modifier.ModifierOrder.LAST; // Go after almost all modifiers

	override function getPos(visualDiff:Float, timeDiff:Float, beat:Float, pos:Vector3, data:Int, player:Int, obj:FlxSprite, field:NoteField)
	{
		pos.x = FlxMath.lerp(pos.x, CoolUtil.snap(pos.x, getSubmodValue("snapXInterval", player)), getValue(player));
		pos.y = FlxMath.lerp(pos.y, CoolUtil.snap(pos.y, getSubmodValue("snapYInterval", player)), getSubmodValue("snapY", player));
		pos.z = FlxMath.lerp(pos.z, CoolUtil.snap(pos.z, getSubmodValue("snapZInterval", player)), getSubmodValue("snapZ", player));
		return pos;
	}
	
	override function getName(){
		return "snapX";
	}
	
	override function getSubmods(){
		return ["snapXInterval", "snapYInterval", "snapZInterval", "snapY", "snapZ"];
	}
}