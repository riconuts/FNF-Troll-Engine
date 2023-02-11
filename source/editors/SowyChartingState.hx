package editors;

import Song;

class SowyChartingState extends MusicBeatState
{


    override public function create()
    {
        if (PlayState.SONG == null){
            PlayState.SONG = {song: "unknown", bpm: 100, notes: []}; 
        }
    }
}