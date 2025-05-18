package funkin.objects.cutscenes;

// TODO: scripted cutscene and make this extend that

// Could do a TimelineCutscene/ScriptedTimelineCutscene
// but until we have a json format for this they should ALL be scripted lmao
// (tho could be hardcoded but ehh if theres no script for it then doesnt matter)

class TimelineCutscene extends ScriptedCutscene {
	public var timeline: Timeline;

	public override function createCutscene() {
		timeline = new Timeline();
		if (script != null)
			script.set("timeline", this.timeline);
		timeline.onFinish.addOnce(onEnd.dispatch.bind(false));
		add(timeline);

		onEnd.addOnce((s: Bool) -> {
			for(m in members)
				remove(m);
			
		});

		callScript("onCreateCutscene", []);
	}

	override public function pause() {
		timeline.active = false;
		callScript("onPause", []);
	}

	override public function resume() {
		timeline.active = true;
		callScript("onResume", []);
	}

	override public function restart() {
		for(m in members){
			remove(m);
			m.destroy();
		}

		createCutscene();

		callScript("onRestart", []);
	}

}