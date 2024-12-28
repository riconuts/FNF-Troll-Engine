package funkin.macros;

import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Expr.Field;
import haxe.macro.Type.ClassType;
import haxe.macro.Type.ClassField;
using StringTools;

class SowyUtil
{
	public static function findByName(fields:Array<Field>, name:String):Null<Field>{
		for (field in fields){
			if (field.name == name)
				return field;
		}
		return null;
	}

	public static function getFieldDoc(c:ClassType, name:String):Null<String> {
		var fields = c.fields.get();

		for (field in fields) {
			if (field.name == name)
				return field.doc;
		}

		return null;
	}
}