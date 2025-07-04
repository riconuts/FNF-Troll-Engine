package funkin.macros;

#if macro
import funkin.ClientPrefs;

import haxe.macro.Context;
import haxe.macro.Expr;

using funkin.macros.Sowy;

class OptionMacro
{
	public static macro function build():Array<Field>
	{
		////
		var fields:Array<Field> = Context.getBuildFields();
		var pos = Context.currentPos();

		var definitions:Map<String, OptionData> = ClientPrefs.getOptionDefinitions(); // gets all the option definitions
		var optionNames:Array<String> = [];

		for(option => key in definitions){
			var optionField:Null<Field> = fields.findByName(option);
			if (optionField != null){
				// if (optionField.access.contains(AStatic))
					continue;
			}
			optionNames.push(option);

			var fieldDesc:String = key.display + '  \n' + key.desc;

			switch(key.type){
				case Toggle:
					var defVal:Bool = key.value == null ? false : key.value;
					fields.push({
						name: option,
						access: [APublic, AStatic],
						kind: FVar(macro :Bool, macro $v{defVal}),
						pos: pos,
						doc: fieldDesc,
					});
				case Dropdown:
					var defVal:String = key.value == null ? key.data.get("options")[0] : key.value;
					fields.push({
						name: option,
						access: [APublic, AStatic],
						kind: FVar(macro :String, macro $v{defVal}),
						pos: pos,
						doc: fieldDesc,
					});
				case Number:
					var defVal:Float = key.value == null ? 0 : key.value;
					fields.push({
						name: option,
						access: [APublic, AStatic],
						kind: FVar(macro:Float, macro $v{defVal}),
						pos: pos,
						doc: fieldDesc,
					});

				default:
					// nothing
			}
		}

		fields.push({
			name: 'options',
			access: [APublic, AStatic],
			kind: FVar(macro :Array<String>, macro $v{optionNames}),
			pos: pos
		});

		return fields;
	}
}
#end