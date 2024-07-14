package funkin.macros;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Expr.Field;

using funkin.macros.Sowy;

class FlxTextFormatterMacro
{
	//// https://code.haxe.org/category/macros/build-value-objects.html
	public static function build()
	{
		var fields:Array<Field> = Context.getBuildFields();
		var setupExpressions = [];

		for (f in fields) {
			switch (f.kind) {
				default:
				case FVar(t,_):
					// wow it really is just that fucking simple
					setupExpressions.push(macro 
						if ($p{["textFormat", f.name]} != $v{null}){
							$p{["textObject", f.name]} = $p{["textFormat", f.name]}
						}
					);
			}
		}

		switch (fields.findByName("applyFormat").kind){
			default: 
			case FFun(f): f.expr = macro $b{setupExpressions};
		}

		return fields;
	}
}
#end