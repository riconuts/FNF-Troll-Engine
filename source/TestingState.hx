package;

import flixel.text.FlxText;
import flixel.util.FlxColor;
import scripts.FunkinHScript;

// this is still heavy WIP
// to use just add a folder named "states" in a global mod (either contents/global or a mod marked as global in its metadata.json)
// and add a script called TestingState.hscript in that
// that will let you modify this state!! rn you can only modify 'create' and 'update'
// code should look a lil like this

/*
function create(){
    // anything to be done before the state create code
    statecreate();
    // anything after
}

function update(elapsed:Float){
    // before state update
    stateupdate(elapsed);
    // after state update
}
*/

// statecreate/stateupdate can be replaced with super.create or super.update, if you dont want the code from the original state to be ran
// they can also only be called in the relevant function, so you cant call stateupdate in create or statecreate in update
// this is all a heavy WIP

class TestingState extends MusicBeatState {
    override function create(){
		trace("the original create function yeah");
		var text = new FlxText(0, 100);
		text.text = "TESTING STATE\nPRESS F7 TO RESET STATE";
		text.setFormat(Paths.font("calibri.ttf"), 32, FlxColor.WHITE, FlxTextAlign.CENTER, FlxTextBorderStyle.NONE, FlxColor.WHITE);
		text.screenCenter(X);
		add(text);

        super.create();
    }

    override function update(elapsed:Float) {
        trace("Calling update from TestingState: " + elapsed);
        super.update(elapsed);
    }
}