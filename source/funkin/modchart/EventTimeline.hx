package funkin.modchart;

import funkin.modchart.events.ModEvent;
import funkin.modchart.events.BaseEvent;

class EventTimeline {
	public var modEvents:Map<String, Array<ModEvent>> = [];
	public var events:Array<BaseEvent> = [];
	public function new() {}

	public function addMod(modName:String)
		modEvents.set(modName, []);
	

	public function addEvent(event:BaseEvent){
		event.parent = this;
		event.addedToTimeline();
		if((event is ModEvent)){
			var modEvent:ModEvent = cast event;
			var name = modEvent.modName;
			if (!modEvents.exists(name))
				addMod(name);
			
			if (!modEvents.get(name).contains(modEvent))
				modEvents.get(name).push(modEvent);

			// TODO: figure out why this is different on newer haxe versions vs older haxe versions
			modEvents.get(name).sort((a, b) -> Std.int(a.executionStep - b.executionStep));

		}else
			if(!events.contains(event)){
				events.push(event);
				events.sort((a, b) -> Std.int(a.executionStep - b.executionStep));
			}
		
	}

	@:allow(funkin.modchart.ModManager)
	function updateMods(step:Float){
		for (modName in modEvents.keys())
		{
			var garbage:Array<ModEvent> = [];
			var schedule = modEvents.get(modName);
			for (eventIndex in 0...schedule.length)
			{
				var event:ModEvent = schedule[eventIndex];
				if (event.finished)
					garbage.push(event);
				
				if (event.ignoreExecution || event.finished)
					continue;
				
				if (step >= event.executionStep)
					event.run(step);
				
				else
					break;
			}

			for (trash in garbage)
				schedule.remove(trash);
		}
	}

	@:allow(funkin.modchart.ModManager)
	function updateFuncs(step:Float){
		var garbage:Array<BaseEvent> = [];
		for (event in events)
		{
			if (event.finished)
				garbage.push(event);
			
			if(event.ignoreExecution || event.finished)
				continue;

			
			if (step >= event.executionStep)
				event.run(step);
			else
				break;

		}

		for (trash in garbage)
			events.remove(trash);
	}
}