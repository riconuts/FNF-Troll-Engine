package funkin.macros;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Expr.Field;

using funkin.macros.Sowy;

class FlxTextFormatDataMacro
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
					if (f.name == "font") {
						setupExpressions.push(macro {
							if (textFormat.font != null)
								textObject.font = Paths.font(textFormat.font);
						});
					}else {
						setupExpressions.push(macro 
							if ($p{["textFormat", f.name]} != $v{null}){
								$p{["textObject", f.name]} = $p{["textFormat", f.name]}
							}
						);					
					}

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