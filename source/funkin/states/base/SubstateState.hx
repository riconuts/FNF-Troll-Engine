package funkin.states.base;

import flixel.addons.transition.TransitionSubstate;

@:noScripting // RIP
class SubstateState extends MusicBeatState {
	var transCamera:FlxCamera; // JUST for the transition
	var _subState:FlxSubState;

	private function _create(daSubstate) {
		persistentUpdate = true;
		persistentDraw = true;

		_subState = daSubstate;
		openSubState(daSubstate);
		super.create();

		subStateOpened.addOnce((_) -> {
			transCamera = new FlxCamera();
			transCamera.bgColor = 0;
			FlxG.cameras.add(transCamera, false);

			if (_transSubState != null)
				_transSubState.camera = transCamera;
		});
	}

	override function openTransitionSubState(ts:TransitionSubstate) {
		ts.camera = transCamera;
		if (_subState != null)
			_subState.openSubState(ts);
	}
}