package funkin.objects;

import funkin.data.CharacterData;
import funkin.states.PlayState;
import funkin.states.PlayState.instance as game;
import funkin.data.Song.EventNote;

function fromName(name:String):SongEvent {
	return switch (name) {
		case "Change Character": new ChangeCharacterEvent();
		default: new SongEvent();
	}
}

class PPPP extends SongEvent 
{
	
}

class ChangeCharacterEvent extends SongEvent 
{
	override function getPreload(eventNote:EventNote) {
		return CharacterData.returnCharacterPreload(eventNote.value2);
	}

	override function onPush(eventNote:EventNote) {
		var charType = PlayState.getCharacterTypeFromString(eventNote.value1);
		if (charType != -1) game.addCharacterToList(eventNote.value2, charType);
	}

	override function onTrigger(eventNote:EventNote) {
		var charType:CharacterType = PlayState.getCharacterTypeFromString(eventNote.value1);
		if (charType != -1) game.changeCharacter(eventNote.value2, charType);
	}
}

class SongEvent 
{
	public function new() {
		
	}

	function getPreload(eventNote:EventNote):Array<funkin.data.Cache.AssetPreload> {
		return [];
	}
	
	function shouldPush(eventNote:EventNote):Bool {
		return true;
	}
	
	function getOffset(eventNote:EventNote):Float {
		return 0;
	}
	
	function onPush(eventNote:EventNote) {
		
	}
	
	function onTrigger(eventNote:EventNote) {
		
	}

	function update(elapsed:Float) {
	
	}
}