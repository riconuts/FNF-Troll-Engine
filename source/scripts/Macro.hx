package scripts;

import haxe.macro.Expr;
import haxe.macro.Expr.Field;
import haxe.macro.Expr.FieldType;
import haxe.macro.Context;

using haxe.macro.Tools;

// TODO: make a macro to add callbacks to scripted things (HScriptedModifier/state/etc)
// And then add "override" as a thing to HScript

class Macro {
    macro public static function addScriptingCallbacks(?toInject:Array<String>):Array<Field>{
		if (toInject==null)
			toInject = [
                "create", 
                "update", 
                "destroy",
                "openSubState",
			    "closeSubState"
            ];

        var fields:Array<Field> = Context.getBuildFields();
        var cl = Context.getLocalClass().get();

		// TODO: recursively go thru the superclasses and add all the methods that should be injected
/* 		for (field in cl.superClass.t.get().fields.get())
            trace(field.name); */

        var clMeta = cl.meta.get();
        
		if (clMeta != null && clMeta.length > 0){
			for (entry in clMeta)
			{
				if (entry.name == ':noScripting')
                    return fields;
				
			}
        }
        var funcs:Map<String, Field> = [];

            
        for(field in fields){
            if(field.name == 'new')continue;
			if(!toInject.contains(field.name))continue;

            var name = field.name;
			var shouldAffect = true;
            
			if (field.meta != null && field.meta.length > 0)
			{
				for (entry in field.meta)
				{
                    if(entry.name == ':dontInject' || entry.name == ':hscriptGenerated')shouldAffect=false;

                    if(!shouldAffect)continue;
				}
			}

			if (!shouldAffect)continue;

            if(field.access.contains(AStatic))continue;
            
            switch(field.kind){
                case FieldType.FFun(func):
                    // insert it into the map
                    funcs.set(field.name, field);
                    // give it noCompletion
                    if(field.meta != null)
                        field.meta.push({
                            name: ":noCompletion",
                            pos: field.pos
                        });
                    else
						field.meta = [
                            {
                                name: ":noCompletion",
                                pos: field.pos
                            }
                        ];
					// rename it
					field.name = '_OG$name';

                    // code injection but im not doin that.. atleast, not here LOL (i am for the new func tho)
/*                     var body:Array<Expr> = [];
                    switch (func.expr.expr)
                    {
                        case EBlock(exprs):
                            body = exprs;
                        default:
                            body = [func.expr];
                    } */

                default:
                    // NUFFIN
            }
        } 
        
        for(name => field in funcs){
			switch (field.kind)
			{
				case FieldType.FFun(fn):
                    var args = [for (arg in fn.args) macro $i{arg.name}];
					var fname = field.name;
					var expr:Array<Expr> = [
						// main bulk of the injected code
						macro
						{
							if (script.exists($v{name}))
							{
								return script.call($v{name}, $a{args}, [$v{'state$name'} => $i{fname}]);
							}
							return $i{fname}($a{args});
						}
                    ];

                    // injections based on function
                    // TODO: make it a metadata thing or something??

                    switch(name){
                        case 'update':
                            expr.insert(0, macro {
                                if (FlxG.keys.justPressed.F7)
                                    FlxG.resetState();
                            }); // add it to the verrryy start of the update function, so you can always F7 to escape the state
                                // (some day I'll come up with a proper key combo for it instead of only pressing F7)
                        default:
                    }

                    fields.push({
                        name: name,
                        access: field.access.copy(),
                        meta: field.meta.copy(),
                        pos: Context.currentPos(),
                        kind: FieldType.FFun({
                            args: fn.args,
                            params: fn.params,
                            ret: fn.ret,
                            expr: macro $b{expr}
                        })
                    });
                    field.access.remove(AOverride);
                    field.access.remove(APublic);
                    field.access.push(APrivate);
                default:
                    // nuffin
            }
        }

		return fields;
    }
}