package funkin.modchart.modifiers;

class AlphaModifier extends NoteModifier 
{
	override function getName()
		return 'stealth';

	override function ignorePos()
		return true;

	public static var fadeDistY = 120;

	public function getHiddenSudden(player:Int=-1, column:Int){
		return getWithColumnVariant("hidden", player, column) * getWithColumnVariant("sudden", player, column);
	}

	public function getHiddenEnd(player:Int = -1, column:Int){
		return (FlxG.height* 0.5) + fadeDistY * CoolUtil.scale(getHiddenSudden(player, column),0, 1, -1, -1.25) + (FlxG.height* 0.5) * getWithColumnVariant("hiddenOffset", player, column);
	}

	public function getHiddenStart(player:Int = -1, column:Int){
		return (FlxG.height* 0.5) + fadeDistY * CoolUtil.scale(getHiddenSudden(player, column), 0, 1, 0, -0.25) + (FlxG.height* 0.5) * getWithColumnVariant("hiddenOffset", player, column);
	}

	public function getSuddenEnd(player:Int = -1, column:Int){
		return (FlxG.height* 0.5) + fadeDistY * CoolUtil.scale(getHiddenSudden(player, column),0, 1, 1, 1.25) + (FlxG.height* 0.5) * getWithColumnVariant("suddenOffset", player, column);
	}

	public function getSuddenStart(player:Int = -1, column:Int){
		return (FlxG.height* 0.5) + fadeDistY * CoolUtil.scale(getHiddenSudden(player, column),0, 1, 0, 0.25) + (FlxG.height* 0.5) * getWithColumnVariant("suddenOffset", player, column);
	}

	inline function getWithColumnVariant(mod:String, player:Int, column:Int){
		return getSubmodValue(mod, player) + getSubmodValue('$mod$column', player);
	}

	function getVisibility(yPos:Float, player:Int, column: Int):Float{
		var distFromCenter = yPos - (FlxG.height * 0.5);
		var alpha:Float = 0;

		if(yPos<0 && getSubmodValue("stealthPastReceptors", player)==0)
			return 1.0;


		var time = Conductor.songPosition/1000;

		var hiddenValue = getWithColumnVariant("hidden", player, column);
		if(hiddenValue != 0){
			var hiddenAdjust = CoolUtil.clamp(CoolUtil.scale(yPos, getHiddenStart(player, column), getHiddenEnd(player, column), 0, -1), -1, 0);
			alpha += hiddenValue * hiddenAdjust;
		}

		var suddenValue = getWithColumnVariant("sudden", player, column);
		if (suddenValue != 0){
			var suddenAdjust = CoolUtil.clamp(CoolUtil.scale(yPos, getSuddenStart(player, column), getSuddenEnd(player, column), 0, -1), -1, 0);
			alpha += suddenValue * suddenAdjust;
		}

		if(getValue(player)!=0)
			alpha -= getValue(player);

		if (getSubmodValue('stealth$column', player) != 0)
			alpha -= getSubmodValue('stealth$column', player);

		if(getSubmodValue("blink",player)!=0){
			var f = CoolUtil.quantizeAlpha(FlxMath.fastSin(time*10),0.3333);
			alpha += CoolUtil.scale(f,0,1,-1,0);
		}

		if(getSubmodValue("vanish",player)!=0){
			var realFadeDist:Float = 120;
			alpha += CoolUtil.scale(Math.abs(distFromCenter),realFadeDist,2*realFadeDist,-1,0)*getSubmodValue("vanish",player);
		}

		return CoolUtil.clamp(alpha+1,0,1);
	}

	function getGlow(visible:Float){
		var glow = CoolUtil.scale(visible, 1, 0.5, 0, 1.3);
		return CoolUtil.clamp(glow,0,1);
	}

	function getRealAlpha(visible:Float){
		var alpha = CoolUtil.scale(visible, 0.5, 0, 1, 0);
		return CoolUtil.clamp(alpha,0,1);
	}

	override function shouldExecute(player:Int, val:Float)return true;
	override function isRenderMod()return true;

	override function getExtraInfo(diff:Float, tDiff:Float, beat:Float, info:RenderInfo, obj:NoteObject, player:Int, data:Int):RenderInfo
	{
		var alpha:Float = info.alpha;
		if (obj.objType == NOTE){
			var yPos:Float = 50 + diff;

			var alphaMod = 
			(1 - getSubmodValue("alpha",player)) * (1 - getSubmodValue('alpha${data}',player)) * (1 - getSubmodValue("noteAlpha", player))* (1 - getSubmodValue('noteAlpha${data}', player));
			var vis = getVisibility(yPos, player, data);

			if (getSubmodValue("hideStealthGlow", player) == 0)
			{
				alpha *= getRealAlpha(vis);
				info.glow = getGlow(vis);
			}
			else
				alpha *= vis;

			alpha *= alphaMod;	
		}else{
			alpha *= (1 - getSubmodValue("alpha",
				player)) * (1 - getSubmodValue('alpha${data}',
					player)) * (1 - getSubmodValue('receptorAlpha', player)) * (1 - getSubmodValue('receptorAlpha${data}', player));

			if (obj.objType == STRUM || getSubmodValue("darkSplashes", player) != 0){
				var darkness = (1 - getSubmodValue("dark", player)) * (1 - getSubmodValue('dark${data}', player));
				if (darkness != 1) {
					if (getSubmodValue("hideDarkGlow", player) == 0) {
						alpha *= getRealAlpha(darkness);
						info.glow = getGlow(darkness);
					} else
						alpha *= darkness;
				}
			}
		}
		

		info.alpha = alpha;

		return info;
	}

	override function getSubmods(){
		var subMods:Array<String> = [
			"darkSplashes",
			"noteAlpha",
			"alpha",
			"hidden",
			"hiddenOffset",
			"sudden",
			"suddenOffset",
			"blink",
			"vanish",
			"dark",
			"receptorAlpha", 
			"hideDarkGlow", 
			"hideStealthGlow", 
			"stealthPastReceptors"
		];

		for(i in 0...PlayState.keyCount){
			subMods.push('noteAlpha$i');
			subMods.push('receptorAlpha$i');
			subMods.push('alpha$i');

			subMods.push('dark$i');
			subMods.push('stealth$i');

			subMods.push('sudden$i');
			subMods.push('hidden$i');

			subMods.push('suddenOffset$i');
			subMods.push('hiddenOffset$i');
		}

		return subMods;
	}
}
