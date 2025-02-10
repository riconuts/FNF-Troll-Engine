//// all of this for what

package funkin.objects;

import flixel.graphics.FlxGraphic;
import flixel.tweens.FlxTween;
import flixel.group.FlxGroup.FlxTypedGroup;
using StringTools;

class RatingSprite extends FlxSprite
{
	public var tween:FlxTween;

	override public function updateHitbox(){
		width = Math.abs(scale.x) * frameWidth;
		height = Math.abs(scale.y) * frameHeight;
		offset.set(
			frameWidth * 0.5, 
			frameHeight * 0.5
		);
		centerOrigin();
	}

	public function cancelTween(){
		if (tween != null){
			tween.cancelChain();
			tween.destroy();
			tween = null;
		}
	}

	override public function kill(){
		cancelTween();
		return super.kill();
	}
}

@:allow(funkin.states.PlayState)
class RatingGroup extends FlxTypedGroup<RatingSprite>
{
	public var comboPadding:Int = 3;
	public var x:Float = FlxG.width * 0.5;
	public var y:Float = FlxG.height * 0.5;
	
	//// make this a sprite group (?)
	public var moveSprites:Bool = false; 
	public function setPosition(x:Float=0.0, y:Float=0.0){
		this.x = x;
		this.y = y;
	}

	var comboSprs:Array<RatingSprite> = [];
	var judgeSprs:Array<RatingSprite> = [];

	public var lastJudge:RatingSprite = null;
	public var lastCombo:Array<RatingSprite> = null;

	var comboTemplate:RatingSprite = {
		var graphic = Paths.image("comboNums");
		var spr = new RatingSprite();

		spr.loadGraphic(graphic, true, Math.floor(graphic.width / 12), graphic.height);
		for (n in 0...10) spr.animation.add(Std.string(n), [n], 0, false);
		
		spr.animation.add("-", [10], 0, false);
		spr.animation.add(".", [11], 0, false);
		
		spr.scale.set(.5, .5);
		spr.updateHitbox();
		spr;
	}

	var judgeTemplate:RatingSprite = {
		var spr = new RatingSprite();		
		spr.scale.set(.7, .7);
		spr.updateHitbox();
		spr;
	}

	public function new() {
		super();
		for (_ in 0...3) getSprite(comboSprs, comboTemplate);
		lastJudge = getSprite(judgeSprs, judgeTemplate);
	}

	override function destroy() {
		comboTemplate.destroy();
		super.destroy();
	}

	override function recycle(?objectClass:Class<RatingSprite>, ?objectFactory:Void->RatingSprite, force = false, revive = true):RatingSprite
		return null;

	private inline function getComboSpr(char:String):RatingSprite {
		var spr = getSprite(comboSprs, comboTemplate);
		spr.animation.play(char);
		return spr;
	}

	public static inline function setJudgementSprite(char:String, spr:FlxSprite){
		var judgementGraphic = Paths.image(char);
		if (judgementGraphic != null) {
			spr.loadGraphic(judgementGraphic);
			spr.animation.add(char, [0], 0);
		} else {
			// TODO: JudgeManager should hold indices into the judgement graphic and also point to which graphic to use, maybe?

			var judgementsGraphic:FlxGraphic = Paths.image("judgements");
			spr.loadGraphic(judgementsGraphic, true, judgementsGraphic.width, Math.floor(judgementsGraphic.height / 6));

			spr.animation.add("epic", [0], 0);
			spr.animation.add("sick", [1], 0);
			spr.animation.add("good", [2], 0);
			spr.animation.add("bad", [3], 0);
			spr.animation.add("shit", [4], 0);
			spr.animation.add("miss", [5], 0);
		}
	}
	
	private inline function getJudgeSpr(char:String):RatingSprite {
		var spr = getSprite(judgeSprs, judgeTemplate);

		setJudgementSprite(char, spr);

		spr.animation.play(char);
		return spr;
	}

	private function addOnTop(spr:RatingSprite){
		spr.cameras = this.cameras;
		members.remove(spr);
		length = members.push(spr);
		return spr;
	}

	public function displayJudgment(name:String, offsetX:Float=0.0, offsetY:Float=0.0):RatingSprite  {
		var spr:RatingSprite = getJudgeSpr(name);
		addOnTop(spr);

		spr.active = true;
		spr.alive = true;
		spr.exists = true;

		spr.x = this.x + offsetX;
		spr.y = this.y + offsetY;
		spr.updateHitbox();

		lastJudge = spr;
		return spr;
	}

	public function displayCombo(combo:Int, offsetX:Float=0.0, offsetY:Float=0.0):Array<RatingSprite> 
	{	
		var str:String = Std.string(Math.abs(combo)).lpad("0", comboPadding);
		var x:Float = this.x + offsetX;
		var y:Float = this.y + offsetY;
		
		if (combo < 0) {
			str = '-$str';
			x -= comboTemplate.width * str.length * 0.5;
		}else{
			x -= comboTemplate.width * (str.length-1) * 0.5;
		}

		var numbs = new Array<RatingSprite>();
		for (i in 0...str.length){
			var spr:RatingSprite = getComboSpr(str.charAt(i));
			addOnTop(spr);
			
			spr.active = true;
			spr.alive = true;
			spr.exists = true;

			spr.x = x + i *	comboTemplate.width;
			spr.y = y;

			numbs[i] = spr;
		}

		lastCombo = numbs;
		return numbs;
	}

	public function regenerateCaches()
	{
		while(comboSprs.length > 0){
			var spr = comboSprs.pop();
			spr.destroy();
		}
		
		while (judgeSprs.length > 0) {
			var spr = judgeSprs.pop();
			spr.destroy();
		}

		for (_ in 0...3)
			getSprite(comboSprs, comboTemplate);
		lastJudge = getSprite(judgeSprs, judgeTemplate);

	}
	

	////
	private static function getSprite(array:Array<RatingSprite>, ?template:RatingSprite):RatingSprite {
		var spr:RatingSprite; 

		for (i in 0...array.length){
			spr = array[i];

			if (!spr.alive){
				spr.revive();
				return spr;
			}
		}

		spr = clone(template);
		array.push(spr);
		return spr;
	}

	private static function clone(Sprite:RatingSprite):RatingSprite {
		var spr = new RatingSprite();
		spr.frames = Sprite.frames;
		
		@:privateAccess
		for (anim in Sprite.animation._animations)
			spr.animation.add(anim.name, anim.frames, anim.frameRate, anim.looped, anim.flipX, anim.flipY);
		
		spr.useDefaultAntialiasing = Sprite.useDefaultAntialiasing;
		spr.antialiasing = Sprite.antialiasing;

		spr.width = Sprite.width;
		spr.height = Sprite.height;
		
		spr.scale.copyFrom(Sprite.scale);
		spr.offset.copyFrom(Sprite.offset);
		spr.origin.copyFrom(Sprite.origin);
		
		spr.clipRect = Sprite.clipRect;

		return spr;
	}
}