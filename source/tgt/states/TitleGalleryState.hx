package tgt.gallery;

import openfl.events.MouseEvent;
import flixel.addons.display.FlxBackdrop;
import tgt.gallery.*;
import TitleState.TitleLogo;
import flixel.text.FlxText;
import flixel.util.FlxColor;

class TitleGalleryState extends MusicBeatState
{
    var title:TitleLogo;
    var titulos:Array<String>;

    static var curSelected:Int = 0;

    var left:FlxSprite;
    var right:FlxSprite;

    override public function create()
    {
        persistentUpdate = true;
        persistentDraw = true;

        FlxG.mouse.visible = true;

        // found it.
        var bg = new FlxBackdrop();
        bg.frames = Paths.getSparrowAtlas("jukebox/space");
        bg.animation.addByPrefix("space", "space", 50, true);
        bg.animation.play("space");
        bg.screenCenter();
        add(bg);

        if (FlxG.width > FlxG.height)
            add(new FlxSprite().makeGraphic(FlxG.height, FlxG.height, 0xFF000000).screenCenter(X));
        else
            add(new FlxSprite().makeGraphic(FlxG.width, FlxG.width, 0xFF000000).screenCenter(Y));

        left = new FlxSprite(10, 0, Paths.image("tgtmenus/selectionArrow"));
        left.color = 0xFFF4CC34;
        left.angle = -90;
        left.scale.set(2,2);
        left.updateHitbox();
        left.screenCenter(Y);
        add(left);

        right = new FlxSprite(0, 0, Paths.image("tgtmenus/selectionArrow"));
        right.color = 0xFFF4CC34;
        right.angle = 90;
        right.scale.set(2,2);
        right.updateHitbox();
        right.screenCenter(Y);
        right.x = FlxG.width - right.width - 10;
        add(right);

        //
        titulos = TitleLogo.getTitlesList();
        changeSelected(curSelected, true);

        super.create();

		var cornerLeftText = tgt.TGTMenuShit.newBackTextButton(goBack);
		add(cornerLeftText);

        FlxG.stage.addEventListener(MouseEvent.MOUSE_UP, onMouseUp);
    }

    override public function destroy() {
        FlxG.stage.removeEventListener(MouseEvent.MOUSE_UP, onMouseUp);
        super.destroy();
    }

    function onMouseUp(e) 
    {
        if (FlxG.mouse.overlaps(left))
            changeSelected(-1);
        if (FlxG.mouse.overlaps(right))
            changeSelected(1);
        if (FlxG.mouse.overlaps(title))
            title.time = 0;
    }

    function changeSelected(value:Int = 0, ?absolute:Bool)
    {
        if (absolute == true)
            curSelected = value;
        else
            curSelected += value;

        if (curSelected < 0)
            curSelected = titulos.length + curSelected;
        else if (curSelected >= titulos.length)
            curSelected = curSelected - titulos.length;

        updateTitle();
    }

    function updateTitle()
    {
        if (title != null){
            remove(title);
            title.destroy();
            title = null;
        }

        title = new TitleLogo(0,0, titulos[curSelected]);
        title.screenCenter();
        add(title);
    }

    // this shit don't work bruh
    override function beatHit()
    {
        if (title != null)
            title.time = 0;

        super.beatHit();
    }

	var doingTrans = false;
	function goBack() {
		if (doingTrans) return;
		doingTrans = true;
        FlxG.sound.play(Paths.sound('cancelMenu'));
        MusicBeatState.switchState(new GalleryMenuState());
    }

    override public function update(e) 
    {
        if (controls.UI_LEFT_P)
            changeSelected(-1);
        
        if (controls.UI_RIGHT_P)
            changeSelected(1);

        if (controls.BACK)
            goBack();
        
        super.update(e);
    }
}