package;

import flixel.math.FlxMath;
import flixel.text.FlxText;
import FreeplayState.SongMetadata;

class SongSelectState extends MusicBeatState{
    
    var songMeta:Array<SongMetadata> = [];
    var songText:Array<FlxText> = [];
    var curSel(default, set):Int;
    function set_curSel(sowy){
        if (sowy < 0 || sowy >= songMeta.length)
            sowy = sowy % songMeta.length;
        if (sowy < 0)
            sowy = songMeta.length + sowy;
        
        ////
        var prevText = songText[curSel];
        if (prevText != null)
            prevText.color = 0xFFFFFFFF;

        var selText = songText[sowy];
        if (selText != null)
            selText.color = 0xFFFFFF00;

        ////
        curSel = sowy;
        return curSel;
    }
    

    var verticalLimit:Int;

    override public function create() 
    {
        StartupState.load();

        if (FlxG.sound.music == null)
            MusicBeatState.playMenuMusic(1);

		#if MODS_ALLOWED
		for (modDir in Paths.getModDirectories()){
            Paths.iterateDirectory(Paths.mods('$modDir/songs/'), function(path:String){
                songMeta.push(new SongMetadata(path, modDir));
            });
		}
		#end

        var border = 5;
        var spacing = 2;
        var textSize = 16;
        var width = 16*textSize;

        var ySpace = (textSize+spacing);

        verticalLimit = Math.floor((FlxG.height - border*2)/ySpace);

        for (id in 0...songMeta.length)
        {
            var text = new FlxText(
                border + (Math.floor(id/verticalLimit) * width), 
                border + (ySpace*(id%verticalLimit)), 
                width, 
                songMeta[id].songName,
                textSize
            );
            songText.push(text);
            add(text);
        }

        curSel = 0;

        super.create();
    }

    var xSecsHolding = 0.0;
    var ySecsHolding = 0.0; 

    override public function update(e)
    {
        var speed = 1;

		if (controls.UI_DOWN_P){
			curSel += speed;
			ySecsHolding = 0;
		}
		if (controls.UI_UP_P){
			curSel -= speed;
			ySecsHolding = 0;
		}

		if (controls.UI_UP || controls.UI_DOWN){
			var checkLastHold:Int = Math.floor((ySecsHolding - 0.5) * 10);
			ySecsHolding += e;
			var checkNewHold:Int = Math.floor((ySecsHolding - 0.5) * 10);

			if(ySecsHolding > 0.35 && checkNewHold - checkLastHold > 0)
				curSel += (checkNewHold - checkLastHold) * (controls.UI_UP ? -speed : speed);
		}

		if (controls.UI_RIGHT_P){
			curSel += verticalLimit;
			ySecsHolding = 0;
		}
		if (controls.UI_LEFT_P){
			curSel -= verticalLimit;
			ySecsHolding = 0;
		}

		if (controls.UI_LEFT || controls.UI_RIGHT){
			var checkLastHold:Int = Math.floor((ySecsHolding - 0.5) * 10);
			ySecsHolding += e;
			var checkNewHold:Int = Math.floor((ySecsHolding - 0.5) * 10);

			if(ySecsHolding > 0.35 && checkNewHold - checkLastHold > 0)
				curSel += (checkNewHold - checkLastHold) * (controls.UI_UP ? -verticalLimit : verticalLimit);
		}

        if (controls.ACCEPT)
            FreeplayState.playSong(songMeta[curSel]);

        super.update(e);
    }
}