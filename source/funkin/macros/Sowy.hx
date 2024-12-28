package funkin.macros;

import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Expr.Field;
import haxe.macro.Type.ClassType;
import haxe.macro.Type.ClassField;

using funkin.macros.SowyUtil;
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

	macro public static function inheritFieldDocs():Array<Field> {
		var localClass:ClassType = Context.getLocalClass().get();
		var buildFields:Array<Field> = Context.getBuildFields();
		
		var superClass:ClassType = localClass?.superClass.t.get();
		if (superClass == null) return buildFields; // shouldn't have been called in the first place wtf
		
		for (field in buildFields) {
			if (field.doc != null) 
				continue;

			var superClass:ClassType = superClass;
			while (superClass != null && field.doc == null) {
				field.doc = superClass.getFieldDoc(field.name);
				
				var superShit = superClass.superClass;
				superClass = (superShit == null) ? null : superShit.t.get();
			}
		}

		return buildFields;
	}
}