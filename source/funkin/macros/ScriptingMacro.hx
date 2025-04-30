package funkin.macros;

import haxe.macro.Type;
import haxe.macro.Type.ClassField;
import haxe.macro.Expr;
import haxe.macro.Expr.Field;
import haxe.macro.Expr.FieldType;
import haxe.macro.Context;

using funkin.macros.Sowy;
using haxe.macro.TypeTools;
using haxe.macro.ExprTools;
using haxe.macro.Tools;

class ScriptingMacro 
{
	//// https://code.haxe.org/category/macros/enum-abstract-values.html
	macro public static function createEnumWrapper(typePath:Expr):Array<Field>
	{
		var type = Context.getType(typePath.toString());
		var fields:Array<Field> = Context.getBuildFields();

		switch (type.follow()) {
			case TAbstract(_.get() => ab, _) if (ab.meta.has(":enum")):
				for (field in ab.impl.get().statics.get()) {
					var fieldName = field.name;

					if (fields.findByName(fieldName)==null && field.meta.has(":enum") && field.meta.has(":impl")) {
						fields.push({
							name: fieldName,
							pos: Context.currentPos(),
							access: [APublic, AStatic],
							kind: FVar(null, macro $typePath.$fieldName)
						});
					}
				}

			default:
				// The given type is not an abstract, or doesn't have @:enum metadata, show a nice error message.
				throw new Error(type.toString() + " should be @:enum abstract", typePath.pos);
		}
		
		return fields;		
	}

	// TODO: make a macro to add callbacks to scripted things (HScriptedModifier/state/etc)
	// And then add "override" as a thing to HScript

	// NOTE: Not sure how well this works with states that extend another
	macro public static function addScriptingCallbacks(toInject:Array<String>, ?folder:String = 'states'):Array<Field>
	{
		var fields:Array<Field> = Context.getBuildFields();

		#if (!display && SCRIPTABLE_STATES)
		if (Sys.args().indexOf("--no-output") != -1) return fields; // code completion
		/*
		#if true
		*/

		/**
		 * Function name wrapper prefix for functions that are defined on the script super object
		 * For example 'state._super_create()' will be accessible via super.create() on the script.
		 */
		final SUPER_WRAPPER_PREFIX = '_super_'; 
		/**
		 * for the extending functions that are passed to the script on each function call. 
		 * Ex: 'stateupdate()'
		 */
		final FUNC_EXTENSION_PREFIX = 'state'; 

		////
		var localClass = Context.getLocalClass();
		var fullName:String = localClass.toString();
		var folderName:String = localClass.toString().split(".").join("/");
		var cl:ClassType = localClass.get();
		var className:String = cl.name;
		var classConstructor = cl.constructor == null ? null : cl.constructor.get();
		var clMeta = cl.meta == null ? [] : cl.meta.get();

		var superFields:Map<String, ClassField> = [];
		var superFieldNames:Array<String> = [];
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

		if (clMeta != null && clMeta.length > 0)
		{
			for (entry in clMeta)
			{
				if (entry.name == ':noScripting')
				{
					// only way i can think of to force-override canBeScripted to always be false
					// makes it so that you can't use state overrides to script the state, either.
					var func:FieldType = FFun({
						expr: (macro {
								//trace("state not scriptable");
								return false;
							}),
						ret: macro :Bool,
						args: []
					});

					var field = fields.findByName('get_canBeScripted');
					if (field != null){
						field.kind = func;
					}else {
						field = {
							name: "get_canBeScripted",
							access: [AInline],
							kind: func,
							pos: Context.currentPos()
						};
						fields.push(field);
					}

					if (superFieldNames.contains("get_canBeScripted"))
						field.access.push(AOverride);
					
					//trace(fullName, 'noScripting');
					return fields;
				}
				else if (entry.params.length == 0) {
				
				}
				else if(entry.name == ':injectFunctions'){
					toInject = entry.params[0].getValue();
				}
				else if (entry.name == ':injectMoreFunctions'){
					var p:Array<String> = entry.params[0].getValue();
					for (f in p) {
						if(!toInject.contains(f))
							toInject.push(f);
					}
				}
			}
		}

		////
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

		////
		var funcs:Map<String, Field> = [];

		for (field in fields) {
			var name = field.name;
			if (!toInject.contains(name))
				continue;

			var ignore = false;
			if (field.meta != null && field.meta.length > 0) {
				for (entry in field.meta) {
					if (entry.name == ':dontInject' || entry.name == ':hscriptGenerated') {
						ignore = true;
						break;
					}
				}
			}

			if (ignore)
				continue;

			if (field.access.contains(AStatic))
				continue;

			switch(field.kind){
				default:
				case FieldType.FFun(func):
					// insert it into the map
					funcs.set(field.name, field);
					
					// give it noCompletion
					(field.meta==null ? field.meta = [] : field.meta).push({
						name: ":noCompletion",
						pos: field.pos
					});
					
					// rename it
					field.name = '_OG$name';
			}
		} 

		////
		cl.findField("_scriptSuperObject", false) != null ? {} : fields.push({
			name: "_scriptSuperObject",
			doc: "Used as 'super' in scripts",
			access: [], // no access modifiers
			meta: [
				{
					name: ":noCompletion",
					pos: Context.currentPos()
				}
			],
			pos: Context.currentPos(),
			kind: FieldType.FVar(TypeTools.toComplexType(TDynamic(null)), macro $v{{}}) // anonymous
		});

		// TODO: make this an array so you can have mutliple extensions lol
		/*
		fields.push({
			name: "_extensionScript",
			doc: "The extension script instance",
			access: [],
			meta: [
				{
					name: ":noCompletion",
					pos: Context.currentPos()
				}
			],
			pos: Context.currentPos(),
			kind: FieldType.FVar(macro: funkin.scripts.FunkinHScript) 
		});
		*/

		fields.push({
			name: "_getScriptDefaultVars",
			pos: Context.currentPos(),
			access: [AOverride, APublic],
			meta: [
				{
					name: ":noCompletion",
					pos: Context.currentPos()
				}
			],
			kind: FFun({
				args: [],
				expr: macro {
					var defaultVars = new Map<String, Dynamic>();
					defaultVars.set($v{className}, $i{className});
					defaultVars.set("super", this._scriptSuperObject);
					defaultVars.set("this", this);
					return defaultVars;
				}
			})
		});

		fields.findByName("_startExtensionScript") != null ? {/*trace('$fullName yeehaw');*/} : fields.push({
			name: "_startExtensionScript",
			pos: Context.currentPos(),
			access: [AOverride, APublic],
			meta: [
				{
					name: ":noCompletion",
					pos: Context.currentPos()
				}
			],
			kind: FFun({
				args: [{name: "folder"}, {name: "scriptName"}],
				expr: macro {
					for(fileExt in Paths.HSCRIPT_EXTENSIONS){
						if (_extensionScript != null)break;
						var fileName = '$scriptName.$fileExt';
						for (filePath in Paths.getFolders(folder))
						{
							var path = filePath + fileName;
							if (Paths.exists(path))
							{
								_extensionScript = funkin.scripts.FunkinHScript.fromFile(path, path, _getScriptDefaultVars());
								_extensionScript.call("new", []);
								break;
							}
						}
					}
				}
			})
		});

		//////////
		// vv i hope this has no repurcussions :clueless:
		function lazyFuck(type){
			return switch(type){
				case TLazy(t): t();
				default: type;
			}
		}
		//////////

		/*
		function funcBasedInjection(name:String, expr:Array<Expr>){
			// injections based on function
			// TODO: make it a metadata thing or something??
			switch (name){
				case 'update':
					// add it to the verrryy start of the update function, so you can always F7 to escape the state
					// (some day I'll come up with a proper key combo for it instead of only pressing F7)
					expr.insert(0, macro {
						if (FlxG.keys.justPressed.F5)
							funkin.states.MusicBeatState.resetState();
					});
				case 'destroy':
					// important. stop the script so it doesn't stay on memory
					expr.push(macro {
						if (_extensionScript != null){ 
							_extensionScript.stop();
							_extensionScript = null;
						}
					});		
				default:
			}
		}
		*/

		var injected:Map<String, Field> = [];
		for (name in toInject) {
			if (funcs.exists(name)) 
			{
				var field = funcs.get(name);
				switch (field.kind)
				{
					case FieldType.FFun(fn):
						var args = [for (arg in fn.args) macro $i{arg.name}];
						var fname = field.name;
						var expr:Array<Expr> = [];

						var returnsVoid = fn.ret==null || switch(fn.ret){
							case TPath(sowy): sowy.name == "Void" || sowy.sub == "Void";
							default: false;
						};

						// main bulk of the injected code
						if (returnsVoid){
							expr.push(macro
								{
									//trace("void ret", $v{className}, $v{fname});
									if (_extensionScript!=null && _extensionScript.exists($v{name})) {
										_extensionScript.executeFunc($v{name}, $a{args}, null, [$v{FUNC_EXTENSION_PREFIX + name} => $i{fname}]);
										return;
									}
								}
							);
						}else{
							expr.push(macro
								{
									//trace("val ret", $v{className}, $v{fname});
									if (_extensionScript != null && _extensionScript.exists($v{name}))
										return _extensionScript.executeFunc($v{name}, $a{args}, null, [$v{FUNC_EXTENSION_PREFIX + name} => $i{fname}]);
								}
							);
						}

						//funcBasedInjection(name, expr);

						expr.push(macro {
							return $i{fname}($a{args});
						});

						////
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
						field.access.remove(AOverride);
						if (field.access.remove(APublic))
							field.access.push(APrivate);
						fields.push(newField);

						injected.set(name, newField);
					default:
						// nuffin
				}
			}
			else if (superFieldNames.contains(SUPER_WRAPPER_PREFIX + name))
			{

			}
			else if (superFieldNames.contains(name)) 
			{
				var field = superFields.get(name);

				switch (lazyFuck(field.type)) {
					case TFun(daArgs, daRet):
						var daArgs:Array<{name:String, opt:Bool, t:Type}> = daArgs;

						var args = [for (arg in daArgs) macro $i{arg.name}];
						var expr:Array<Expr> = [];
						var superName = SUPER_WRAPPER_PREFIX + name;

						var returnsVoid = daRet==null || switch(daRet){
							case TAbstract(t, params): t.get().name == "Void";
							default: false;
						};
						
						// main bulk of the injected code
						if (returnsVoid){
							expr.push(macro
							{
								//trace("super void ret", $v{className}, $v{name});
								if (_extensionScript!=null && _extensionScript.exists($v{name})) {
									_extensionScript.executeFunc($v{name}, $a{args}, null, [$v{FUNC_EXTENSION_PREFIX + name} => $i{superName}]);
									return;
								}
							});
						}else{
							expr.push(macro
							{
								//trace("super val ret", $v{className}, $v{name});
								if (_extensionScript!=null && _extensionScript.exists($v{name}))
									return _extensionScript.executeFunc($v{name}, $a{args}, null, [$v{FUNC_EXTENSION_PREFIX + name} => $i{superName}]);
							});
						}

						//funcBasedInjection(name, expr);

						expr.push(macro {
							return super.$name($a{args});
						});
						
						////
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
			// function _super_create() return super.create();
			if (superFieldNames.contains(name)){
				switch (injectedField.kind){
					case FFun(f):
						var args = [for (arg in f.args) macro $i{arg.name}];
						var superName = SUPER_WRAPPER_PREFIX + name;
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
						Reflect.setField(superObject, name, null);
						
					default:
				}
			}
		}
		
		// inject code into the constructor to generate the _scriptSuperObject

		if(constructor == null && classConstructor != null) 
		{
			switch (lazyFuck(classConstructor.type))
			{
				case TFun(daArgs, daRet):
					var daArgs:Array<{name:String, opt:Bool, t:Type}> = daArgs;

					var args = [for (arg in daArgs) macro $i{arg.name}];
					var expr:Array<Expr> = [];


					var fieldArgs:Array<FunctionArg> = [];
					var defaultValues:Map<String, Dynamic> = [];
/*					 switch (classConstructor.expr().expr)
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

					// inject code BEFORE the existing class new() code
					var superInit:Array<Expr> = [
						for (name in Reflect.fields(superObject))
							macro $p{['this', '_scriptSuperObject', name]} = $p{['this', SUPER_WRAPPER_PREFIX + name]}
					];
					body.unshift(macro $b{superInit});
					
					// inject code AFTER the existing class new() code
					body.push(macro {
						// TODO: Trim the funkin.states if that exists
						_startExtensionScript($v{folder}, $v{"extension/" + folderName});
						if(_extensionScript != null)
							_startExtensionScript($v{folder}, $v{"extension/" + fullName});
					});

					func.expr = macro $b{body};
				default:
					// nothing
			}
		}
		#end

		return fields;

	}
}
