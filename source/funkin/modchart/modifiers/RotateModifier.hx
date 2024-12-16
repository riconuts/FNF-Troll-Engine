package funkin.modchart.modifiers;

class RotateModifier extends NoteModifier { // this'll be rotateX in ModManager
	override function getName()
		return '${prefix}rotateX';

	override function getOrder()
		return ModifierOrder.LAST + 2;

	var daOrigin:Vector3;
	var prefix:String;
	public function new(modMgr:ModManager, ?prefix:String = '', ?origin:Vector3, ?parent:Modifier){
		this.prefix=prefix;
		this.daOrigin=origin;
		super(modMgr, parent);

	}

	override function getPos( visualDiff:Float, timeDiff:Float, beat:Float, pos:Vector3, data:Int, player:Int, obj:FlxSprite, field:NoteField) {
		var origin:Vector3 = daOrigin ?? new Vector3(field.field.getBaseX(data), FlxG.height* 0.5);

		pos.decrementBy(origin); // diff
		VectorHelpers.rotateV3(pos, // out 
			FlxAngle.TO_RAD * (getValue(player) + getSubmodValue('${prefix}${data}rotateX', player)),
			FlxAngle.TO_RAD * (getSubmodValue('${prefix}rotateY', player) + getSubmodValue('${prefix}${data}rotateY', player)),
			FlxAngle.TO_RAD * (getSubmodValue('${prefix}rotateZ', player) + getSubmodValue('${prefix}${data}rotateZ', player)),
			pos
		);
		pos.incrementBy(origin);

		return pos;
	}

	override function getSubmods(){
		var shid:Array<String> = ['rotateX', 'rotateY', 'rotateZ'];

		var submods:Array<String> = [
			for (d in 0...PlayState.keyCount)
			{
				for (s in shid)
					'$prefix$d$s';
			}
		];

		submods.push('${prefix}rotateY');
		submods.push('${prefix}rotateZ');
		return submods;
	}
}
