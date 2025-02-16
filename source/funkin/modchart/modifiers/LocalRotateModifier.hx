package funkin.modchart.modifiers;

// Rotates notes and receptors on each axis with the origin at the middle of the player's receptors
class LocalRotateModifier extends NoteModifier { // this'll be rotateX in ModManager
	override function getName()
		return '${prefix}rotateX';

	override function getOrder()
		return Modifier.ModifierOrder.POST_REVERSE;

	var prefix:String;
	public function new(modMgr:ModManager, ?prefix:String = '', ?parent:Modifier){
		this.prefix=prefix;
		super(modMgr, parent);

	}

	private var origin = new Vector3(0.0, FlxG.height * 0.5, 0.0);
	private function getFieldOrigin(field:NoteField):Vector3 {
		final field = field.field;
		final FKC = field.keyCount;

		#if true
		origin.x = (field.getBaseX(0) + field.getBaseX(FKC-1)) * 0.5;
		#else
		if (FKC % 2 == 0) {
			final RKN = Math.floor(FKC / 2);	final LKN = RKN - 1;
			origin.x = (field.getBaseX(LKN) + field.getBaseX(RKN)) * 0.5;
		}else {
			origin.x = field.getBaseX(Math.floor(FKC / 2));
		}
		#end

		return origin;
	}

	override function getPos( visualDiff:Float, timeDiff:Float, beat:Float, pos:Vector3, data:Int, player:Int, obj:FlxSprite, field:NoteField):Vector3 {
		var origin = getFieldOrigin(field);
		origin.x+=Note.halfWidth;

		pos.decrementBy(origin); // diff

		VectorHelpers.rotateV3(pos, // out 
			(getValue(player) + getSubmodValue('${prefix}${data}rotateX', player)) * FlxAngle.TO_RAD,
			(getSubmodValue('${prefix}rotateY', player) + getSubmodValue('${prefix}${data}rotateY', player)) * FlxAngle.TO_RAD,
			(getSubmodValue('${prefix}rotateZ', player) + getSubmodValue('${prefix}${data}rotateZ', player)) * FlxAngle.TO_RAD,
		pos);
		
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
