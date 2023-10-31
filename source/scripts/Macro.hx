package scripts;

import haxe.macro.Type;
import haxe.macro.Type.ClassField;
import haxe.macro.Expr;
import haxe.macro.Expr.Field;
import haxe.macro.Expr.FieldType;
import haxe.macro.Context;

using haxe.macro.Tools;

// TODO: make a macro to add callbacks to scripted things (HScriptedModifier/state/etc)
// And then add "override" as a thing to HScript

class Macro {
    macro public static function addScriptingCallbacks(?toInject:Array<String>, ?folder:String = 'states'):Array<Field>
    {
        var fields:Array<Field> = Context.getBuildFields();

        #if (!display && SCRIPTABLE_STATES)
		if (Sys.args().indexOf("--no-output") != -1)return fields; // code completion
 
		if (toInject==null)
			toInject = [ // this is like.. the bare minimum lol
                "create", 
                "update", 
                "destroy",
                "openSubState",
			    "closeSubState",
				"startOutro",
                "switchTo"
            ];
            

        var cl:ClassType = Context.getLocalClass().get();
		var classConstructor = cl.constructor == null ? null : cl.constructor.get();
		var className = cl.name;
		var clMeta = cl.meta == null ? [] : cl.meta.get();

		var superFields:Map<String, ClassField> = [];
		var superFieldNames:Array<String> = [];

		if (cl.superClass != null && cl.superClass.t != null)
		{
			var superduper = cl.superClass;
			while (superduper != null && superduper.t != null)
			{
				var scl = superduper.t.get();
				if (classConstructor == null && scl.constructor != null)
					classConstructor = scl.constructor.get();

				if (scl.fields != null)
				{
					for (field in scl.fields.get())
					{
						if (field.meta.has(":inject"))
							toInject.push(field.name);

						if (!superFieldNames.contains(field.name))
						{
							superFieldNames.push(field.name);
							superFields.set(field.name, field);
						}
					}
				}
				superduper = scl.superClass;
			}
		} 

		if (clMeta != null && clMeta.length > 0)
		{
			for (entry in clMeta)
			{
				if (entry.name == ':noScripting'){
					// only way i can think of to force-override canBeScripted to always be false
                    // makes it so that you can't use state overrides to script the state, either.
/* 					fields.push({
						name: "canBeScripted",
						access: [APublic],
						kind: FProp("get", "default", macro:Bool),
						pos: Context.currentPos()
					}); */

					var func:FieldType = FFun({
						expr: (macro
							{
								trace("got canbescripted");
								return false;
							}),
						ret: macro :Bool,
						args: []
					});

					var access = [AInline];
					if (superFieldNames.contains("get_canBeScripted"))
						access.push(AOverride);

                    for(field in fields){
                        if(field.name == 'get_canBeScripted'){
							field.kind = func;
							if (superFieldNames.contains("get_canBeScripted"))
								field.access.push(AOverride);
                            return fields;
                        }
                    }



					fields.push({
						name: "get_canBeScripted",
						access: access,
						kind: func,
						pos: Context.currentPos()
					});
					return fields;
                }
                

                else if(entry.name == ':injectFunctions'){
                    if(entry.params.length > 0)
                        toInject = entry.params[0].getValue();

                }else if (entry.name == ':injectMoreFunctions'){
                    if (entry.params.length > 0){
						var p:Array<String> = entry.params[0].getValue();
                        for (f in p)
                            if(!toInject.contains(f))
								toInject.push(f);
                    }
                }
			}
		}

        var constructor:Field;
		for (field in fields)
		{
			if (field.name == 'new')
			{
				constructor = field;
				continue;
			}
			if (field.meta != null && field.meta.length > 0)
			{
				for (entry in field.meta)
				{
					if (entry.name == ':inject')
						toInject.push(field.name);

					break;
				}
			}
		}

        var funcs:Map<String, Field> = [];

        for(field in fields){
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

        // used as "super" in scripts
		fields.push({
			name: "_scriptSuperObject",
			access: [], // no access modifiers
            meta: [
                {
					name: ":noCompletion",
					pos: Context.currentPos()
                }
            ],
			pos: Context.currentPos(),
			kind: FieldType.FVar(macro:{}, macro $v{{}}) // anonymous
		});

        
        var injected:Map<String, Field> = [];
        for(name in toInject){
            if(funcs.exists(name)){
                var field = funcs.get(name);
                switch (field.kind)
                {
                    case FieldType.FFun(fn):
                        var args = [for (arg in fn.args) macro $i{arg.name}];
                        var fname = field.name;
                        var expr:Array<Expr> = [];

						// main bulk of the injected code
						if (fn.ret==null || fn.ret.toString() == 'Void'){
							expr.push(macro
								{
									if (script!=null && script.exists($v{name}))
									{
										script.executeFunc($v{name}, $a{args}, null, [$v{'state$name'} => $i{fname}]);
										return;
									}
									$i{fname}($a{args});
								}
                            );
                        }else{
							expr.push(macro
								{
									if (script != null && script.exists($v{name}))
									{
										return script.executeFunc($v{name}, $a{args}, null, [$v{'state$name'} => $i{fname}]);
									}
									return $i{fname}($a{args});
								}
                            );
                        }

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

						var newField:Field = {
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
						}
                        fields.push(newField);
                        field.access.remove(AOverride);
                        field.access.remove(APublic);
                        field.access.push(APrivate);
						injected.set(name, newField);
                    default:
                        // nuffin
                }
            }else if(superFieldNames.contains(name)){
				var field = superFields.get(name);
                switch(field.type){
                    case TFun(daArgs, daRet):
						var daArgs:Array<{name:String, opt:Bool, t:Type}> = daArgs;

						var args = [for (arg in daArgs) macro $i{arg.name}];
						var expr:Array<Expr> = [];
						var superName = "_super_" + name;

						// main bulk of the injected code
						if (daRet.toString() == 'Void'){
							expr.push(macro
                            {
                                if (script!=null && script.exists($v{name}))
                                {
									script.executeFunc($v{name}, $a{args}, null, [$v{'state$name'} => $i{superName}]);
                                    return;
                                }
                                super.$name($a{args});
                            });
                        }else{
							expr.push(macro
                            {
                                if (script!=null && script.exists($v{name}))
                                {
									return script.executeFunc($v{name}, $a{args}, null, [$v{'state$name'} => $i{superName}]);
                                }
                                return super.$name($a{args});
                            });
                        }


                        // injections based on function
                        // TODO: make it a metadata thing or something??

                        switch (name)
                            {
                                case 'update':
                                    expr.insert(0,
                                        macro
                                        {
                                            if (FlxG.keys.justPressed.F7)
                                                FlxG.resetState();
                                        }); // add it to the verrryy start of the update function, so you can always F7 to escape the state
                                // (some day I'll come up with a proper key combo for it instead of only pressing F7)
                                default:
                        }
                        var fieldArgs:Array<FunctionArg> = [];
                        var defaultValues:Map<String, Dynamic> = [];
                        switch (field.expr().expr)
                        {
                            case TFunction(tfunc):
                                for(arg in tfunc.args){
                                    defaultValues.set(arg.v.name, arg.value);
                                }
                            default:
                                //
                        }
                        for(a in daArgs){

                            fieldArgs.push({
                                name: a.name,
                                opt: a.opt,
                                type: a.t.toComplexType(),
                                value: defaultValues.get(a.name)
                            });
                        }
                        
                        var newField:Field = {
                            name: name,
                            access: [AOverride],
                            pos: Context.currentPos(),
                            kind: FieldType.FFun({
								args: fieldArgs,
                                ret: daRet.toComplexType(),
                                expr: macro $b{expr}
                            })
                        }

                        fields.push(newField);

						injected.set(name, newField);
                    default:
                }

            }else{
                Context.warning("Cannot inject " + name + ". (Are you sure that's a valid function name for this class?)", Context.currentPos());
            }
        }


        // create the _super functions
        
		var superObject = {};


        for(name => injectedField in injected){
            // function _super_create()return super.create();
			if (superFieldNames.contains(name)){
                switch (injectedField.kind){
                    case FFun(f):
                        var args = [for (arg in f.args) macro $i{arg.name}];
                        var superName = "_super_" + name;
                        var feld:Field = {
                            name: superName,
                            access: [], // no access modifiers
                            meta: [
                                {
                                    name: ":noCompletion",
                                    pos: Context.currentPos()
                                }
                            ],
                            pos: Context.currentPos(),
                            kind: FieldType.FFun({
                                args: f.args,
                                ret: f.ret,
                                expr: macro return super.$name($a{args})
                            })
                        }
                        fields.push(feld);
                        Reflect.setField(superObject, name, macro $i{superName});
                        
                    default:
                }
            }
        }
        
		// inject code into the constructor to generate the _scriptSuperObject

        if(constructor == null && classConstructor != null){
			var type = classConstructor.type;

            // vv i hope this has no repurcussions :clueless:
            switch(type){
                case TLazy(t):
                    type = t();
                default:
                    // nuffin
            }
			switch (type)
			{
				case TFun(daArgs, daRet):
                    var daArgs:Array<{name:String, opt:Bool, t:Type}> = daArgs;

                    var args = [for (arg in daArgs) macro $i{arg.name}];
                    var expr:Array<Expr> = [];


                    var fieldArgs:Array<FunctionArg> = [];
                    var defaultValues:Map<String, Dynamic> = [];
/*                     switch (classConstructor.expr().expr)
                    {
                        case TFunction(tfunc):
                            for (arg in tfunc.args)
                            {
								defaultValues.set(arg.v.name, );
                            }
                        default:
                            //
                    } */ 
                    
                    // ^^ seems to be broken for some reason but just setting value to null seems to work fine so whatever
                    for (a in daArgs)
                    {
                        fieldArgs.push({
                            name: a.name,
                            opt: a.opt,
                            type: a.t.toComplexType(),
                            value: null
                        });
                    }


					expr.push(macro
                    {
                        super($a{args});
                    });

					constructor = {
						name: "new",
						access: [APublic],
						pos: Context.currentPos(),
						kind: FieldType.FFun({
							args: fieldArgs,
							expr: macro $b{expr}
						})
					}
					fields.push(constructor);
                    
                default:
                    // nuffin
            }
        }
        
		if (constructor!=null){
            switch (constructor.kind)
            {
                case FieldType.FFun(func):
                    var body:Array<Expr> = [];
                    switch (func.expr.expr)
                    {
                        case EBlock(exprs):
                            body = exprs;
                        default:
                            body = [func.expr];
                    }

                    // injects code *BEFORE* the existing class new() code
                    body.insert(0, macro
                        {
                            this._scriptSuperObject = $v{superObject}
                        }
                    );
                    

                    
                    // injects code AFTER the existing class new() code
                    body.push(macro
                        {
                            var defaultVars:Map<String, Dynamic> = [];
                            defaultVars.set("super", this._scriptSuperObject);
                            defaultVars.set("this", this);
                            defaultVars.set("add", add);
                            defaultVars.set("remove", remove);
                            defaultVars.set("insert", insert);
                            defaultVars.set("members", members);
                            defaultVars.set($v{className}, $i{className});

							for (filePath in Paths.getFolders($v{folder}))
                            {
                                var file = filePath + "extension/" + $v{className} + ".hscript";
                                if (Paths.exists(file))
                                {
                                    // TODO: make this an array so you can have mutliple extensions lol
                                    script = scripts.FunkinHScript.fromFile(file, $v{className}, defaultVars);
                                    script.call("new", []);
                                    break;
                                }
                            }


                        }
                    );
                        

                    func.expr = macro $b{body};
                default:
                    // nothing
            }
        }
        #end

		return fields;

    }
}