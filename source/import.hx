#if !macro
import flixel.*;
import flixel.sound.FlxSound;

#if tgt
import tgt.MainMenuState;
import tgt.FreeplayState;
import tgt.StoryMenuSelect;
import tgt.*;
#else
import SongSelectState as MainMenuState;
import SongSelectState as FreeplayState;
import SongSelectState as StoryMenuState;
#end

#end