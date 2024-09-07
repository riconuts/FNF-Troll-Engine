package funkin.objects;

import flixel.FlxSprite;

/* class SpriteFromSheet extends FlxSprite {
	var currentAnim:String = '';

	public function new(x:Float = 0, y:Float = 0, source:String, anim:String) {
		super(x, y);
		frames = Paths.getSparrowAtlas(source);
		animation.addByPrefix(anim, anim);
		animation.play(anim);
		currentAnim = anim;
		antialiasing = ClientPrefs.globalAntialiasing;
	}

	public function adjust(fps:Int = 24, loop:Bool = true, playNow:Bool = true) {
		animation.remove(currentAnim);
		animation.addByPrefix(currentAnim, currentAnim, fps, loop);
		if (playNow)
			animation.play(currentAnim, true);
	}

	public function play(forced:Bool = false, reversed:Bool = false, frame:Int = 0) {
		animation.play(currentAnim, reversed, frame);
	}
}
 */

class AltBGSprite extends FlxSprite
{
    public function new(x:Float = 0, y:Float = 0, image:String, ?anim:String, ?loop:Bool=false) {
		super(x, y);
		frames = Paths.getSparrowAtlas(image);
		animation.addByPrefix("anim", anim, 24, loop);
		animation.play("Anim");
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
