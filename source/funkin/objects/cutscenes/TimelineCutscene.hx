package funkin.objects.cutscenes;

import funkin.objects.cutscenes.Timeline.SoundAction;


// Could do a TimelineCutscene/ScriptedTimelineCutscene
// but until we have a json format for this they should ALL be scripted lmao
// (tho could be hardcoded but ehh if theres no script for it then doesnt matter since the callScript will do nothing)


class TimelineCutscene extends ScriptedCutscene {
	public var timeline: Timeline;

	public function sound(frame:Int, path:String, obeysPitch:Bool=true) // for convenience, mainly
		timeline.addAction(new SoundAction(frame, newSound(path, obeysPitch)));
	

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
		super.pause();
	}

	override public function resume() {
		timeline.active = true;
		super.resume();
	}

	override public function restart() {
		for(m in members){
			remove(m);
			m.destroy();
		}
		
		members.resize(0);
		
		
		
		super.restart();
		createCutscene();

	}

}