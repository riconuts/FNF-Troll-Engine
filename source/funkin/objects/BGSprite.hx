package funkin.objects;

import flixel.FlxSprite;

class AltBGSprite extends FlxSprite
{
	public function new(x:Float = 0, y:Float = 0, image:String, ?anim:String, ?loop:Bool=false) {
		super(x, y);
		frames = Paths.getSparrowAtlas(image);
		animation.addByPrefix("idle", anim, 24, loop);
		animation.play("idle");
	}
}

class BGSprite extends FlxSprite
{
	private var idleAnim:String;
	
	public function new(image:String, x:Float = 0, y:Float = 0, ?scrollX:Float = 1, ?scrollY:Float = 1, ?animArray:Array<String> = null, ?loop:Bool = false) {
		super(x, y);

		if (animArray != null) {
			frames = Paths.getSparrowAtlas(image);
			for (i in 0...animArray.length) {
				var anim:String = animArray[i];
				animation.addByPrefix(anim, anim, 24, loop);
				if(idleAnim == null) {
					idleAnim = anim;
					animation.play(anim);
				}
			}
		} else {
			if(image != null) {
				loadGraphic(Paths.image(image));
			}
			active = false;
		}
		scrollFactor.set(scrollX, scrollY);
	}

	public function dance(?forceplay:Bool = false) {
		if(idleAnim != null) {
			animation.play(idleAnim, forceplay);
		}
	}
}
