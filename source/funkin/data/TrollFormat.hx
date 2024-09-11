package funkin.data;

#if moonchart
import moonchart.backend.Timing;
import moonchart.formats.BasicFormat.BasicChart;
import moonchart.formats.BasicFormat.FormatDifficulty;
import moonchart.formats.fnf.legacy.FNFLegacy;
import moonchart.formats.fnf.legacy.FNFPsych;

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
	?metadata:Song.SongCreditdata,

    // deprecated
	?player3:String,
}

class TrollFormat extends FNFLegacyBasic<TrollJSONFormat> {
	override function fromBasicFormat(chart:BasicChart, ?diff:FormatDifficulty):TrollFormat {
        var chart:TrollFormat = cast super.fromBasicFormat(chart, diff);
        for(section in chart.data.song.notes){
			for (note in section.sectionNotes){
                if(note[2] > 0)
					note[2] += Timing.stepCrochet(chart.data.song.bpm, 4);

                if(note[3] == 'STEPMANIA_ROLL')
                    note[3] = 'Roll';
                else if(note[3] == ALT_ANIM)
                    note[3] = 'Alt Animation';
                else if(note[3] == HURT)
                    note[3] = 'Hurt Note'; // Replace witH Mine maybe?
            }
        }
        return chart;
    }
}
#else
class TrollFormat {}
#end