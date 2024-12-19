package funkin.macros;

import haxe.macro.Expr.Field;
using StringTools;

// what DOES sowy mean
class Sowy
{
	public static macro function getBuildDate()
	{
		var daDate = Date.now();
		
		var monthsPassed = Std.string((daDate.getUTCFullYear() - 2023) * 12 + (daDate.getUTCMonth() + 1));
		if (monthsPassed.length == 1)
			monthsPassed = "0"+monthsPassed;

		var theDays = Std.string(daDate.getDate());
		if (theDays.length == 1)
			theDays = "0"+theDays;

		var daString = '$monthsPassed-$theDays';

		return macro $v{daString};
	}

	/**
	 * Returns a map of all conditional compilation flags that were set.
	 */
	public static macro function getDefines() 
	{
		return macro $v{haxe.macro.Context.getDefines()};	
	}

	public static function findByName(fields:Array<Field>, name:String):Null<Field>{
		for (field in fields){
			if (field.name == name)
				return field;
		}
		return null;
	}
}