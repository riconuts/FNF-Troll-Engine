package gallery;

import gallery.*;
import TitleState;

class TitleGalleryState extends MusicBeatState
{
    var title:RandomTitleLogo;

    override public function create()
    {
        super.create();
    }

    override public function update(e) 
    {
        if (controls.BACK) MusicBeatState.switchState(new GalleryMenuState());
        super.update(e);
    }
}