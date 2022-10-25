package modchart.modifiers;
import ui.*;
import modchart.*;
import flixel.math.FlxPoint;
import flixel.math.FlxMath;
import math.*;
import flixel.FlxG;
class AlphaModifier extends NoteModifier {
	override function getName()
		return 'stealth';

	override function ignorePos()
		return true;

  public static var fadeDistY = 120;

  public function getHiddenSudden(player:Int=-1){
    return getSubmodValue("hidden",player) * getSubmodValue("sudden",player);
  }

  public function getHiddenEnd(player:Int=-1){
    return (FlxG.height / 2) + fadeDistY * CoolUtil.scale(getHiddenSudden(player),0,1,-1,-1.25) + (FlxG.height / 2) * getSubmodValue("hiddenOffset",player);
  }

  public function getHiddenStart(player:Int=-1){
    return (FlxG.height / 2) + fadeDistY * CoolUtil.scale(getHiddenSudden(player),0,1,0,-0.25) + (FlxG.height / 2) * getSubmodValue("hiddenOffset",player);
  }

  public function getSuddenEnd(player:Int=-1){
    return (FlxG.height / 2) + fadeDistY * CoolUtil.scale(getHiddenSudden(player),0,1,1,1.25) + (FlxG.height / 2) * getSubmodValue("suddenOffset",player);
  }

  public function getSuddenStart(player:Int=-1){
    return (FlxG.height / 2) + fadeDistY * CoolUtil.scale(getHiddenSudden(player),0,1,0,0.25) + (FlxG.height / 2) * getSubmodValue("suddenOffset",player);
  }

  function getVisibility(yPos:Float,player:Int,note:Note):Float{
    var distFromCenter = yPos;
    var alpha:Float = 0;

    if(yPos<0 && getSubmodValue("stealthPastReceptors", player)==0)
      return 1.0;


    var time = Conductor.songPosition/1000;

    if(getSubmodValue("hidden",player)!=0){
      var hiddenAdjust = CoolUtil.clamp(CoolUtil.scale(yPos,getHiddenStart(player),getHiddenEnd(player),0,-1),-1,0);
      alpha += getSubmodValue("hidden",player)*hiddenAdjust;
    }

    if(getSubmodValue("sudden",player)!=0){
      var suddenAdjust = CoolUtil.clamp(CoolUtil.scale(yPos,getSuddenStart(player),getSuddenEnd(player),0,-1),-1,0);
      alpha += getSubmodValue("sudden",player)*suddenAdjust;
    }

    if(getValue(player)!=0)
      alpha -= getValue(player);


    if(getSubmodValue("blink",player)!=0){
      var f = CoolUtil.quantize(FlxMath.fastSin(time*10),0.3333);
      alpha += CoolUtil.scale(f,0,1,-1,0);
    }

    if(getSubmodValue("randomVanish",player)!=0){
      var realFadeDist:Float = 240;
      alpha += CoolUtil.scale(Math.abs(distFromCenter),realFadeDist,2*realFadeDist,-1,0)*getSubmodValue("randomVanish",player);
    }

    return CoolUtil.clamp(alpha+1,0,1);
  }

  function getGlow(visible:Float){
    var glow = CoolUtil.scale(visible, 1, 0.5, 0, 1.3);
    return CoolUtil.clamp(glow,0,1);
  }

  function getAlpha(visible:Float){
    var alpha = CoolUtil.scale(visible, 0.5, 0, 1, 0);
    return CoolUtil.clamp(alpha,0,1);
  }

  override function shouldExecute(player:Int, val:Float)return true;
	override function ignoreUpdateReceptor()return false;
	override function ignoreUpdateNote()return false;

	override function updateNote(beat:Float, note:Note, pos:Vector3, player:Int){
    var player = note.mustPress==true?0:1;
    @:privateAccess
		var pos = modMgr.getPos(note.strumTime, modMgr.getVisPos(Conductor.songPosition, note.strumTime, PlayState.instance.songSpeed),
			note.strumTime - Conductor.songPosition,
			PlayState.instance.curDecBeat, note.noteData,
			player, note, ["reverse"]);


    var alphaMod = 1 - getSubmodValue("alpha",player) * (1-getSubmodValue("noteAlpha",player));
    var alpha = getVisibility(pos.y,player,note);

    if(getSubmodValue("dontUseStealthGlow",player)==0){
			note.colorSwap.daAlpha = getAlpha(alpha);
			note.colorSwap.flash = getGlow(alpha);
    }else
			note.colorSwap.daAlpha = alpha;
    
		note.colorSwap.daAlpha *= alphaMod;	
    
  }

  override function updateReceptor(beat:Float, receptor:StrumNote, pos:Vector3, player:Int){
    var alpha = 1 - getSubmodValue("alpha",player);
    if(getSubmodValue("dark",player)!=0 || getSubmodValue('dark${receptor.direction}',player)!=0){
      alpha = alpha*(1-getSubmodValue("dark",player))*(1-getSubmodValue('dark${receptor.direction}',player));
    }
    @:privateAccess
		receptor.colorSwap.daAlpha = alpha;

  }

  override function getSubmods(){
    var subMods:Array<String> = ["noteAlpha", "alpha", "hidden","hiddenOffset","sudden","suddenOffset","blink","randomVanish","dark","useStealthGlow","stealthPastReceptors"];
    return subMods;
  }
}
