package funkin.modchart.modifiers;
import math.CoolMath;
using StringTools;

class DrunkModifier extends NoteModifier {
	override function getName()return 'drunk';

	inline function adjust(axis:String, val:Float, plr:Int):Float {
		if ((axis.startsWith("Z") || axis.startsWith("TanZ")) && getOtherValue("legacyZAxis", plr) > 0)
			return val / 1280;

		return val;
	}

	inline function applyDrunk(axis:String, player:Int, time:Float, visualDiff:Float, data:Float, ?mathFunc:Float->Float){
		if (mathFunc == null)
			mathFunc = FlxMath.fastCos;
		var perc = axis == '' ? getValue(player) : getSubmodValue('drunk${axis}', player);
		var speed = getSubmodValue('drunk${axis}Speed', player);
		var period = getSubmodValue('drunk${axis}Period', player);
		var offset = getSubmodValue('drunk${axis}Offset', player);

		if(perc!=0){
			var angle = time * (1 + speed) + data * ((offset * 0.2) + 0.2) + visualDiff * ((period * 10) + 10) / FlxG.height;
			return adjust(axis, perc * (mathFunc(angle) * Note.halfWidth), player);
		}
		return 0;
	}

	inline function applyTipsy(axis:String, player:Int, time:Float, visualDiff:Float, data:Float, ?mathFunc:Float->Float)
	{
		if(mathFunc == null)
			mathFunc = FlxMath.fastCos;

		var perc = getSubmodValue('tipsy${axis}', player);
		var speed = getSubmodValue('tipsy${axis}Speed', player);
		var offset = getSubmodValue('tipsy${axis}Offset', player);

		if (perc != 0)
			return adjust(axis, perc * (mathFunc((time * ((speed * 1.2) + 1.2) + data * ((offset * 1.8) + 1.8))) * Note.swagWidth * .4), player);
		
		return 0;
	}

	inline function applyBumpy(axis:String, player:Int, time:Float, visualDiff:Float, data:Float, ?mathFunc:Float->Float){
		if (mathFunc == null)
			mathFunc = FlxMath.fastSin;
		var perc = getSubmodValue('bumpy${axis}', player);
		var period = getSubmodValue('bumpy${axis}Period', player);
		var offset = getSubmodValue('bumpy${axis}Offset', player);
		if (perc != 0 && period != -1){
			var angle = (visualDiff + (100.0 * offset)) / ((period * 24.0) + 24.0);
			return adjust(axis, perc * 40 * mathFunc(angle), player);
		}
		return 0;
	}


	override function getPos( visualDiff:Float, timeDiff:Float, beat:Float, pos:Vector3, data:Int, player:Int, obj:FlxSprite, field:NoteField)
	{
		var time = (Conductor.songPosition/1000);
		pos.x += 
			applyDrunk("", player, time, visualDiff, data) 
			+ applyTipsy("X", player, time, visualDiff, data)
			+ applyBumpy("X", player, time, visualDiff, data);
		pos.y += 
			applyDrunk("Y", player, time, visualDiff, data) 
			+ applyTipsy("", player, time, visualDiff, data)
			+ applyBumpy("Y", player, time, visualDiff, data);
		pos.z += 
			applyDrunk("Z", player, time, visualDiff, data)
			+ applyTipsy("Z", player, time, visualDiff, data)
			+ applyBumpy("", player, time, visualDiff, data);

		// direction-specific
		pos.x += 
			applyDrunk('$data', player, time, visualDiff, data) 
			+ applyTipsy('X$data', player, time, visualDiff, data)
			+ applyBumpy('X$data', player, time, visualDiff, data);
		pos.y += 
			applyDrunk('Y$data', player, time, visualDiff, data) 
			+ applyTipsy('$data', player, time, visualDiff, data)
			+ applyBumpy('Y$data', player, time, visualDiff, data);
		pos.z += 
			applyDrunk('Z$data', player, time, visualDiff, data)
			+ applyTipsy('Z$data', player, time, visualDiff, data)
			+ applyBumpy('$data', player, time, visualDiff, data);

		// tangent

		pos.x += 
			applyDrunk("Tan", player, time, visualDiff, data, CoolMath.fastTan) + 
			applyTipsy("TanX", player, time, visualDiff, data, CoolMath.fastTan)
			+ applyBumpy("TanX", player, time, visualDiff, data, CoolMath.fastTan);
		pos.y += 
			applyDrunk("TanY", player, time, visualDiff, data, CoolMath.fastTan) 
			+ applyTipsy("Tan", player, time, visualDiff, data, CoolMath.fastTan)
			+ applyBumpy("TanY", player, time, visualDiff, data, CoolMath.fastTan);
		pos.z += 
			applyDrunk("TanZ", player, time, visualDiff, data, CoolMath.fastTan) 
			+ applyTipsy("TanZ", player, time, visualDiff, data, CoolMath.fastTan)
			+ applyBumpy("Tan", player, time, visualDiff, data, CoolMath.fastTan);

		// tangent column
		pos.x += 
			applyDrunk('Tan$data', player, time, visualDiff, data, CoolMath.fastTan) 
			+ applyTipsy('TanX$data', player, time, visualDiff, data, CoolMath.fastTan)
			+ applyBumpy('TanX$data', player, time, visualDiff, data, CoolMath.fastTan);
		pos.y += 
			applyDrunk('TanY$data', player, time, visualDiff, data, CoolMath.fastTan) 
			+ applyTipsy('Tan$data', player, time, visualDiff, data, CoolMath.fastTan)
			+ applyBumpy('TanY$data', player, time, visualDiff, data, CoolMath.fastTan);
		pos.z += 
			applyDrunk('TanZ$data', player, time, visualDiff, data, CoolMath.fastTan) 
			+ applyTipsy('TanZ$data', player, time, visualDiff, data, CoolMath.fastTan)
			+ applyBumpy('Tan$data', player, time, visualDiff, data, CoolMath.fastTan);
			
		return pos;
	}

	override function getAliases(){
		return [
			"tipZ" => "tipsyZ",
			"tipZSpeed" => "tipsyZSpeed",
			"tipZOffset" => "tipsyZOffset"
		];
	}

	override function getSubmods(){

		var axes = ["X", "Y", "Z"];
		var props = [
			["Speed", "Offset", "Period"],
			["Speed", "Offset"],
			["Offset", "Period"],
			["Speed", "Offset", "Period"],
			["Speed", "Offset"],
			["Offset", "Period"]
		];

		var shids:Array<String> = ["drunk","tipsy","bumpy","drunkTan","tipsyTan","bumpyTan"];
		var submods:Array<String> = [];

		
		for(i in 0...shids.length){
			var mod = shids[i];
			for(a in 0...axes.length){
				var axe = axes[a];
				if(a==(i % axes.length))axe='';
				submods.push('$mod$axe');
				var p = props[i];
				for(prop in p)submods.push('$mod$axe$prop');
				
				for(d in 0...PlayState.keyCount){
					submods.push('$mod$axe$d');
					for(prop in p)submods.push('$mod$axe$d$prop');
				}
			}
		}
		
		submods.remove("drunk");
		return submods;
	}

}
