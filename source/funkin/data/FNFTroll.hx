package funkin.data;

#if USING_NEW_MOONCHART
import moonchart.formats.fnf.FNFGlobal.FNFLegacyNoteType;
import moonchart.formats.fnf.FNFGlobal;
#end
import funkin.data.Song.SongTracks;
#if USING_MOONCHART
import haxe.Json;
import moonchart.backend.Util;
import moonchart.backend.Timing;
import moonchart.backend.FormatData;
import moonchart.formats.BasicFormat.BasicEvent;
import moonchart.formats.BasicFormat.BasicMetaData;
import moonchart.formats.BasicFormat.BasicNoteType;
import moonchart.formats.BasicFormat.BasicChart;
import moonchart.formats.BasicFormat.FormatDifficulty;
import moonchart.formats.fnf.legacy.FNFLegacy;
import moonchart.formats.fnf.legacy.FNFPsych;
import moonchart.formats.fnf.legacy.FNFPsych.PsychEvent;

typedef TrollJSONFormat = FNFLegacyFormat & {
	// Psych 0.6
	?events:Array<PsychEvent>,
	?gfVersion:String,
	stage:String,
	?arrowSkin:String,
	?splashSkin:String,

	// Troll-specific
	?hudSkin:String,
	?info:Array<String>,
	?metadata:Song.SongMetadata,
	?offset:Float,
	?tracks: SongTracks,
	?keyCount: Int,
	
	// deprecated
	?extraTracks: Array<String>,
	?player3:String,
}

#if USING_NEW_MOONCHART
enum abstract FNFTrollNoteType(String) from String to String
{
	var TROLL_MINE = "Mine";
	var TROLL_ROLL = "Roll";
	// Psych ones, because Haxe sucks
	var TROLL_ALT_ANIM = "Alt Animation";
	var TROLL_NO_ANIM = "No Animation";
	var TROLL_GF_SING = "GF Sing";
}
#end

class FNFTroll extends FNFLegacyBasic<TrollJSONFormat> {
	// From Psych Engine
	public static function __getFormat():FormatData {
		return {
			ID: "FNF_TROLL",
			name: "FNF (Troll Engine)",
			description: "",
			extension: "json",
			hasMetaFile: POSSIBLE,
			metaFileExtension: "json",
			specialValues: ['"tracks":', '"hudSkin":'],
			handler: FNFTroll
		}
	}

	public function new(?data:{song:TrollJSONFormat}) {
		super(data);
		this.formatMeta.supportsEvents = true;
	}

	function resolveTrollEvent(event:BasicEvent):PsychEvent {
		if(event.name == 'SLIDER_VELOCITY'){
			return [
				event.time,
				[
					[
						"Mult SV",
						Std.string(event.data.MULTIPLIER),
						""
					]
				]
			];
		}

		var values:Array<Dynamic> = Util.resolveEventValues(event);

		var value1:Dynamic = values[0] ?? "";
		var value2:Dynamic = values[1] ?? "";

		return [event.time, [[event.name, Std.string(value1), Std.string(value2)]]];
	}


	override function getEvents():Array<BasicEvent> {
		var events = super.getEvents();

		// Push GF section events
		var lastGfSection:Bool = false;
		forEachSection(data.song.notes, (section, startTime, endTime) -> {
			var psychSection:PsychSection = cast section;

			var gfSection:Bool = (psychSection.gfSection ?? false);
			if (gfSection != lastGfSection) {
				events.push(makeGfSectionEvent(startTime, gfSection));
				lastGfSection = gfSection;
			}
		});

		// Push normal psych events
		for (baseEvent in data.song.events) {
			var time:Float = baseEvent[0];
			var pack:Array<Array<String>> = baseEvent[1];
			for (event in pack) {
				events.push({
					time: time,
					name: event[0],
					data: {
						VALUE_1: event[1],
						VALUE_2: event[2]
					}
				});
			}
		}

		Timing.sortEvents(events);
		return events;
	}

	override function filterEvents(events:Array<BasicEvent>):Array<BasicEvent> {
		return super.filterEvents(events).filter((event) -> return event.name != GF_SECTION);
	}

	function makeGfSectionEvent(time:Float, gfSection:Bool):BasicEvent {
		return {
			time: time,
			name: GF_SECTION,
			data: {
				gfSection: gfSection
			}
		}
	}

	override function getChartMeta():BasicMetaData {
		var meta = super.getChartMeta();
		meta.extraData.set(PLAYER_3, data.song.gfVersion ?? data.song.player3);
		meta.extraData.set(STAGE, data.song.stage);
		return meta;
	}

	override function fromJson(data:String, ?meta:String, ?diff:FormatDifficulty):FNFTroll {
		super.fromJson(data, meta, diff);
		updateEvents(this.data.song, meta != null ? Json.parse(meta).song : null);
		return this;
	}

	override function sectionBeats(?section:FNFLegacySection):Float {
		var psychSection:Null<PsychSection> = cast section;
		return psychSection?.sectionBeats ?? super.sectionBeats(section);
	}

	// Merge the events meta file and convert -1 lane notes to events
	function updateEvents(song:TrollJSONFormat, ?events:TrollJSONFormat):Void {
		var songNotes:Array<FNFLegacySection> = song.notes;
		song.events ??= [];

		if (events != null) {
			songNotes = songNotes.concat(events.notes ?? []);
			song.events = song.events.concat(events.events ?? []);
		}

		for (section in songNotes) {
			var eventNotes:Array<FNFLegacyNote> = [];

			for (note in section.sectionNotes) {
				if (note.lane == -1) {
					song.events.push([note.time, [[note[2], note[3], note[4]]]]);
					eventNotes.push(note);
				}
			}

			for (eventNote in eventNotes) {
				section.sectionNotes.remove(eventNote);
			}
		}
	}

	// Troll Engine shit
	override function fromBasicFormat(chart:BasicChart, ?diff:FormatDifficulty):FNFTroll {
		var basic = super.fromBasicFormat(chart, diff);
		var data = basic.data;

		data.song.events = [];
		for (basicEvent in chart.data.events) {
			data.song.events.push(resolveTrollEvent(basicEvent));
		}

		data.song.gfVersion = chart.meta.extraData.get(PLAYER_3) ?? "gf";
		data.song.stage = chart.meta.extraData.get(STAGE) ?? "stage";
		var offset:Float = chart.meta.offset;
		data.song.offset = offset;

		for (section in data.song.notes){
			for (note in section.sectionNotes){
				if(note[2] > 0)
					note[2] += Timing.stepCrochet(data.song.bpm, 4) * 2;

			}
		}

		data.song.metadata ??= {};
		data.song.metadata.songName = chart.meta.title;
		data.song.metadata.artist = chart.meta.extraData.get("SONG_ARTIST");
		data.song.metadata.charter = chart.meta.extraData.get("SONG_CHARTER");

		return cast basic;
	}
	/* #if(moonchart > "0.4.0") */ // WHY DOES THIS NOT WORK???
	#if USING_NEW_MOONCHART
	override function resolveBasicNoteType(type:String):FNFLegacyNoteType {
		return cast switch (type) {
			case MINE: TROLL_MINE;
			case ALT_ANIM: TROLL_ALT_ANIM;
			case ROLL: TROLL_ROLL;
			default: type;
		}
	}
	#else
	override function prepareNote(note:FNFLegacyNote, offset:Float):FNFLegacyNote {
		if (note.type is String) {
			note[3] = switch (cast(note.type, String)) {
				case MINE:
					"StepmaniaMine";
				case ALT_ANIM:
					PSYCH_ALT_ANIM;
				case ROLL:
					"Roll";
				
				default: cast note.type;
			}
		}

		return note;
	}
	#end
	
}

#else
class FNFTroll {}
#end