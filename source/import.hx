#if !macro
import flixel.*;
import flixel.sound.FlxSound;

#if tgt
import tgt.MainMenuState;
import tgt.FreeplayState;
import tgt.StoryMenuState;
import tgt.*;
#else
import SongSelectState as FreeplayState;
import SongSelectState as StoryMenuState;
#end

#end