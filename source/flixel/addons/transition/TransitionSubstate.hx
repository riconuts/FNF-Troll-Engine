package flixel.addons.transition;

import flixel.FlxSubState;
import flixel.addons.transition.FlxTransitionSprite.TransitionStatus;

class TransitionSubstate extends FlxSubState
{
	public var finishCallback:Void->Void;

	public override function destroy():Void
	{
		super.destroy();
		finishCallback = null;
	}

	public function start(status: TransitionStatus){
		trace('transitioning $status');
	}
}
