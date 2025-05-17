package funkin.objects;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup;

import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;

import flixel.util.FlxTimer;

import funkin.states.PlayState;
import funkin.scripts.Globals;

/**
 * @author crowplexus
 * Handles Gameplay countdown, also optionally used in the Pause Menu if `ClientPrefs.countUnpause` is set to true.
**/
class Countdown {
	public var sprite:Null<FlxSprite>;
	public var sound:Null<FlxSound>;
	public var timer:FlxTimer;
	public var tween:FlxTween;

	public var introAlts:Array<Null<String>> = ["onyourmarks", 'ready', 'set', 'go'];
	public var introSnds:Array<Null<String>> = ["intro3", 'intro2', 'intro1', 'introGo'];
	public var introSoundsSuffix:String = "";

	public var onTick:(counter:Int)->Void;
	public var onComplete:()->Void;

	public var position:Int = 0; // originally swagCounter

	public var active(get, never):Bool;
	public var finished(get, never):Bool;

	@:noCompletion function get_active() return timer!=null && timer.active;
	@:noCompletion function get_finished() return timer==null || timer.finished;

	private var parent:FlxGroup;
	private var game:PlayState;

	public function new(parent:FlxGroup = null):Void {
		if (parent == null) parent = FlxG.state;
		if (parent is PlayState) game = cast(parent, PlayState);
		this.parent = parent;
	}

	public function destroy():Void {
		deleteTween();
		deleteTimer();
		sprite = null;
		sound = null;
		position = 0;
		parent = null;
		game = null;
	}

	public function start(?time:Float = -1):Countdown {
		if (time == -1) time = Conductor.crochet * 0.001;
		timer = new FlxTimer();
		timer.start(time, (_)->{
			tick(position);
			if (timer.loopsLeft == 0 && onComplete != null) {
				onComplete();
				// not sure how much this helps the GC, if this causes issues remove it!!!
				this.destroy();
			}
			position++;
		}, 5);
		return this;
	}

	public function tick(curPos:Int):Void
	{
		var sprImage:Null<flixel.graphics.FlxGraphic> = Paths.image(introAlts[curPos]);
		if (sprImage != null)
		{
			var defaultTransition:Bool = true;
			if (tween != null)
				tween.cancel();

			if (sprite != null) deleteSprite();

			// ↓ I had no idea how to make script calls not weird, so I just did this
			// you might wanna replace it with something else and stuff @crowplexus
			var ret:Dynamic = Globals.Function_Continue;
			if (game != null && game.hudSkinScript != null)
				ret = game.callScript(game.hudSkinScript, "makeCountdownSprite", [sprImage, curPos, timer]);

			if (ret != Globals.Function_Continue)
			{
				if ((ret is FlxSprite))
				{
					sprite = cast ret; // returned a sprite, so use it as the countdown sprite (use default transition etc)
				}
				else
					defaultTransition = false; // didnt return a sprite and didnt return Function_Continue, so dont do any code related to sprite
			}
			else
			{
				// default behaviour, create sprite w/ the specified sprImage
				sprite = new FlxSprite(0, 0, sprImage);
				sprite.scrollFactor.set();
				sprite.updateHitbox();
				if (game != null) sprite.cameras = [game.camHUD];
				else sprite.cameras = [FlxG.cameras.list[FlxG.cameras.list.length - 1]];
				sprite.screenCenter();
			}

			if (defaultTransition)
			{
				if (game == null) parent.insert(parent.members.length-1,sprite);
				else game.insert(game.members.indexOf(game.notes),sprite); // how it was layered originally
				tween = FlxTween.tween(sprite, {alpha: 0}, Conductor.crochet * 0.001, {
					ease: FlxEase.cubeInOut,
					onComplete: function(twn)
					{
						deleteSprite();
						deleteTween();
					}
				});
			}

			if (game != null) {
				game.callOnHScripts('onCountdownSpritePost', [sprite, curPos, timer]);
				if (game.hudSkinScript != null)
					game.hudSkinScript.call("onCountdownSpritePost", [sprite, curPos, timer]);
			}
		}

		var soundName:Null<String> = introSnds[curPos];
		if (soundName != null)
		{
			var ret:Dynamic = Globals.Function_Continue;
			if (game != null && game.hudSkinScript != null)
				ret = game.callScript(game.hudSkinScript, "playCountdownSound", [soundName, introSoundsSuffix, curPos, timer]);

			if (ret == Globals.Function_Continue)
			{
				// default behaviour
				var snd:FlxSound = null;
				snd = FlxG.sound.play(Paths.sound(soundName + introSoundsSuffix), 0.6, false, null, true, () ->
				{
					if (sound == snd)
						sound = null;
				});
				#if tgt
				if (game != null && game.sndEffect != null && ClientPrefs.ruin)
					snd.effect = game.sndEffect;
				#end
				sound = snd;
			}
		}

		if (game != null) {
			game.callOnHScripts('onCountdownTick', [curPos, timer]);
			if (game.hudSkinScript != null)
				game.hudSkinScript.call("onCountdownTick", [curPos, timer]);
		}
		if (onTick != null) onTick(curPos);
	}

	function deleteTimer():Void {
		if (timer != null){
			timer.cancel();
			timer.destroy();
			timer = null;
		}
	}

	function deleteSprite():Void {
		final papa = (game!=null ? game : parent);
		sprite.destroy();
		papa.remove(sprite);
		sprite = null;
	}

	function deleteTween():Void {
		if (tween != null) {
			tween.cancel();
			tween.destroy();
			tween = null;
		}
	}
}
