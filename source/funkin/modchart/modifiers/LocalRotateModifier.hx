package funkin.modchart.modifiers;

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

	private var origin = new Vector3();
	override function getPos( visualDiff:Float, timeDiff:Float, beat:Float, pos:Vector3, data:Int, player:Int, obj:FlxSprite, field:NoteField){
		var x:Float = (FlxG.width* 0.5) - Note.swagWidth - 54 + Note.swagWidth * 1.5;
		switch (player)  {
			case 0:  x += FlxG.width* 0.5 - Note.swagWidth * 2 - 100;
			case 1:  x -= FlxG.width* 0.5 - Note.swagWidth * 2 - 100;
		}
		origin.x = x - 56;
		origin.y = FlxG.height * 0.5;
		var scale = FlxG.height;

		pos.decrementBy(origin); // diff
		pos.z *= scale;

		VectorHelpers.rotateV3(pos, // out 
			(getValue(player) + getSubmodValue('${prefix}${data}rotateX', player)) * FlxAngle.TO_RAD,
			(getSubmodValue('${prefix}rotateY', player) + getSubmodValue('${prefix}${data}rotateY', player)) * FlxAngle.TO_RAD,
			(getSubmodValue('${prefix}rotateZ', player) + getSubmodValue('${prefix}${data}rotateZ', player)) * FlxAngle.TO_RAD,
		pos);
		
		pos.z /= scale;
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
