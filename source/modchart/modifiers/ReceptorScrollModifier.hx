package modchart.modifiers;

import ui.*;
import modchart.*;
import flixel.math.FlxPoint;
import flixel.math.FlxMath;
import flixel.FlxG;
import math.*;

class ReceptorScrollModifier extends NoteModifier {
  inline function lerp(a:Float,b:Float,c:Float){
    return a+(b-a)*c;
  }
  //var moveSpeed:Float = 800;
  var moveSpeed:Float = Conductor.crochet * 3; // gotta keep da sustain segments together so it doesnt look so shit
	override function getName()
		return 'receptorScroll';

  override function getPos( visualDiff:Float, timeDiff:Float, beat:Float, pos:Vector3, data:Int, player:Int, obj:FlxSprite)
  {
    var diff = timeDiff;
    var sPos = Conductor.songPosition;
    var vDiff = -(diff - sPos) / moveSpeed;
    var reversed = Math.floor(vDiff)%2 == 0;

    var startY = pos.y;
    var revPerc = reversed ? 1-vDiff%1 : vDiff%1;
    // haha perc 30
    var upscrollOffset = 50;
    var downscrollOffset = FlxG.height - 150;

    var endY = upscrollOffset + ((downscrollOffset - Note.swagWidth * 0.5) * revPerc);

    pos.y = lerp(startY, endY, getValue(player));

    return pos;
  }

	override function updateNote(beat:Float, daNote:Note, player:Int)
  {
    if(getValue(player)==0)return;
		var speed = PlayState.instance.songSpeed * daNote.multSpeed;
		
		var timeDiff = (Conductor.songPosition - daNote.strumTime);

		var diff = timeDiff;
		var sPos = Conductor.songPosition;

    var songPos = sPos / moveSpeed;
		var notePos = -(diff - sPos) / moveSpeed;

    if(Math.floor(songPos)!=Math.floor(notePos)){
			daNote.alphaMod *= .5;
			daNote.zIndex++;
    }
		if (daNote.wasGoodHit)daNote.garbage=true;

  }
}
