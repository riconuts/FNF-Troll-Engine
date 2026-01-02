package funkin.scripts;

import hscript.Interp;
import hscript.Expr;
import hscript.Tools.expr as getExpr;
import hscript.Tools.mk as mkExpr;
import funkin.macros.ScriptingMacro.SUPER_WRAPPER_PREFIX;

final superWrapperField:String = SUPER_WRAPPER_PREFIX + "wrapper";

@:autoBuild(funkin.macros.ScriptingMacro.setupScriptedClass())
interface IScriptedClass {
	function callOnScript(name:String, ?args:Array<Dynamic>):Dynamic;
	function existsOnScript(name:String):Bool;
}

/**
	HScript interpreter that can access the fields of a given object directly.  
	No more `this.field`, just `field`!!!
**/
class InstanceInterp extends Interp {
	var obj:Dynamic;
	var objFields:Array<String>;
	var hasSuper:Bool;
	
	public function new(obj:Dynamic) {
		this.obj = obj;
		this.objFields = Type.getInstanceFields(Type.getClass(obj));
		this.hasSuper = objFields.contains(superWrapperField);
		super();
	}

	/**
		Recursively replaces `super.method()` expressions to use the proper wrapper object.  
		References to `super` outside of method calls will not be replaced.
	**/
	/*
		Making this because I don't wanna define `super` as a script variable
		You probably can't make a field called `super` on the object anyway
		And also, constructors have `super()` and can also call `super.method()`
		so if i want to get accurate constructors working at some point I CAN'T define it as a variable anyways.
	*/
	static function superReplace(expr:Expr):Expr {
		if (expr == null)
			return null;

		return switch (getExpr(expr)) {
			case EBlock(eray): 
				var eray2 = [for (e in eray) superReplace(e)];
				mkExpr(EBlock(eray2), expr);

			case ECall(_, _):
				function replace(e) {
					return switch (getExpr(e)) {
						#if !hscriptPos // hscriptPos doesn't let me do sweet pattern matching :l gonna leave it because it's easy to read
						case ECall(EField(EIdent("super"), methodName), params): // super.method()
							var e2 = mkExpr(EIdent(superWrapperField), e);
							var e3 = mkExpr(EField(e2, methodName), e2);
							mkExpr(ECall(e3, params), expr);
						/* 
						TODO: check this on function new only!!!
						Also super() should be VOID, don't let it be used as a value!!!
						case ECall(EIdent("super"), methodName): // super()
							var e2 = mkExpr(EIdent("__super__constructor"), e);
							mkExpr(ECall(e2, []), expr);
						*/
						case ECall(e2, p):
							var e3 = replace(e2);
							var p2 = [for (p1 in p) replace(p1)];
							mkExpr(ECall(e3, p2), e2);
						#else
						case ECall(e2, p):
							var rexpr = switch(getExpr(e2)) {
								case EField(e3, methodName):
									switch(getExpr(e3)) {
										case EIdent("super"):
											// super.method()
											var e4 = mkExpr(EIdent(superWrapperField), e2);
											var e5 = mkExpr(EField(e4, methodName), e4);
											var p2 = [for (p1 in p) replace(p1)];
											mkExpr(ECall(e5, p2), expr);
										default: null;
									}
								default: null;
							}
							rexpr ?? {
								var e3 = replace(e2);
								var p2 = [for (p1 in p) replace(p1)];
								mkExpr(ECall(e3, p2), e2);
							}
						#end
						case EBlock(eray):
							var eray2 = [for (e in eray) replace(e)];
							mkExpr(EBlock(eray2), e);
						case EIdent(_):
							e;						
						default:
							e;
					}
				}

				replace(expr);
			case EReturn(e):
				var e2 = superReplace(e);
				mkExpr(EReturn(e2), expr);

			case EVar(n, t, e):
				var e2 = superReplace(e);
				mkExpr(EVar(n, t, e2), expr);

			case EField(e, f):
				var e2 = superReplace(e);
				mkExpr(EField(e2, f), expr);

			case EFunction(args, e, name, ret):
				var e2 = superReplace(e);
				mkExpr(EFunction(args, e2, name, ret), expr);

			default:
				expr;
		}	
	}

	override function execute(expr:Expr):Dynamic {
		if (hasSuper)
			expr = superReplace(expr);
		return super.execute(expr);
	}

	override function resetVariables() {
		super.resetVariables();
		variables.set("this", obj);
	}

	override function setVar(name:String, v:Dynamic) {
		if (objFields.contains(name))
			Reflect.setProperty(obj, name, v);
		else if (variables.exists(name))
			variables.set(name, v);
		else	
			error(EUnknownVariable(name));

		return v;
	}

	override function resolve(id:String):Dynamic {
		if (objFields.contains(id))
			return Reflect.getProperty(obj, id);
		else if (variables.exists(id))
			return variables.get(id);
		else	
			error(EUnknownVariable(id));

		return null;
	}
}