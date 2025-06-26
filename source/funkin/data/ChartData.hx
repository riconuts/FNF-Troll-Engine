package funkin.data;

import funkin.data.BaseSong;

class ChartData {
	public static function updateChart(song:SwagSong) 
	{
		var keyCount:Int = song.keyCount;

		for (section in song.notes) {
			if (section.notes != null)
				continue;
			
			section.notes = [];

			for (lnote in section.sectionNotes) {
				var daNoteData:Int = Std.int(lnote[1]);
				var mustPress:Bool = section.mustHitSection ? (daNoteData < keyCount) : (daNoteData >= keyCount);
				
				var daStrumTime:Float = lnote[0];
				var daColumn:Int = daNoteData % keyCount;
				var fieldIndex:Int = mustPress ? 0 : 1;
				var susLength:Float = lnote[2] ?? 0;
				var daType:String = lnote[3] ?? '';

				var wnote:NoteData = {
					time: daStrumTime,
					column: daColumn,
					fieldIndex: fieldIndex,
					length: susLength,
					type: daType,
				}
				section.notes.push(wnote);
			}

			section.sectionNotes = null;
			Reflect.deleteField(section, 'sectionNotes');
		}
	}
}