package hscript.module;

// a lil spaghetti yeah i know
import funkin.data.ClassManager as ScriptedClassManager;

import hscript.module.ModuleInfo;
#if true
import hscript.TrollInterp as Interp;
#else
import hscript.Interp;
#end
import hscript.Expr;

class ModuleInterp extends Interp
{
	public final classInfo:ClassInfo;
	public function new(classInfo:ClassInfo) {
		this.classInfo = classInfo;
		super();
	}

	////
	public var imported:Map<String, Dynamic>; // imported classes aren't defined as variables
	public var extraData:Map<String, Dynamic>; // taking advantage of t-hscript for now lolol

	private function resetImports()
	{
		imported = new Map<String, Dynamic>();
		imported.set("null",null);
		imported.set("true",true);
		imported.set("false",false);
		imported.set("trace", Reflect.makeVarArgs(function(el) {
			var inf = posInfos();
			var v = el.shift();
			if( el.length > 0 ) inf.customParams = el;
			haxe.Log.trace(Std.string(v), inf);
		}));
	}

	override function resetVariables() 
	{
		variables = new Map<String,Dynamic>();
		extraData = variables;
		resetImports();
	}

	override function resolve( id : String ) {
		var v:Dynamic;
		
		if (variables.exists(id))
			v = variables.get(id);
		else if (imported.exists(id))
			v = imported.get(id);
		else
			error(EUnknownVariable(id));
		
		return v;
	}

	override function setVar(name:String, v:Dynamic)
	{
		if (variables.exists(name))
			variables.set(name, v);
		else // expressions can't define new variables!
			error(EUnknownVariable(name));
		
		return v;
	}

	override function cnew(cl:String, args:Array<Dynamic>) {
		var im = imported.get(cl);
		if (im is ClassInterp) {
			var im:ClassInterp = cast im;
			return im.classInfo.createInstance(args);
		}
		else if (im != null) {
			return Type.createInstance(im,args);
		}
		
		var c = Type.resolveClass(cl);
		if (c != null)
			return Type.createInstance(c,args);
		
		var sc = ScriptedClassManager.resolveClass(cl);
		if (sc != null)
			return sc.createInstance(args);

		error(EInvalidType(cl));
		// error(ECustom("Type not found : " + cl));
		return null;
	}

	////
	public function makeFromFunctionDecl(f:hscript.Expr.FunctionDecl, name:String="unk")
	{
		var params = f.args;
		var fexpr = f.expr;

		var capturedLocals = duplicate(locals);
		var me = this;
		var hasOpt = false, minParams = 0;
		for( p in params )
			if( p.opt )
				hasOpt = true;
			else
				minParams++;
		var f = function(args:Array<Dynamic>) {
			if( ( (args == null) ? 0 : args.length ) != params.length ) {
				if( args.length < minParams ) {
					var str = "Invalid number of parameters. Got " + args.length + ", required " + minParams;
					if( name != null ) str += " for function '" + name+"'";
					error(ECustom(str));
				}
				// make sure mandatory args are forced
				var args2 = [];
				var extraParams = args.length - minParams;
				var pos = 0;
				for( p in params )
					if( p.opt ) {
						if( extraParams > 0 ) {
							args2.push(args[pos++]);
							extraParams--;
						} else
							args2.push(null);
					} else
						args2.push(args[pos++]);
				args = args2;
			}
			var old = me.locals, depth = me.depth;
			me.depth++;
			me.locals = me.duplicate(capturedLocals);
			for( i in 0...params.length )
				me.locals.set(params[i].name,{ r : args[i] });
			var r = null;
			var oldDecl = declared.length;
			if( inTry )
				try {
					r = me.exprReturn(fexpr);
				} catch( e : Dynamic ) {
					restore(oldDecl);
					me.locals = old;
					me.depth = depth;
					#if neko
					neko.Lib.rethrow(e);
					#else
					throw e;
					#end
				}
			else
				r = me.exprReturn(fexpr);
			restore(oldDecl);
			me.locals = old;
			me.depth = depth;
			return r;
		};
		return Reflect.makeVarArgs(f);
	}

	public function initFieldDecls(decls:Array<FieldDecl>)
	{
		final interp = this;

		// variables will be evaluated after functions
		var varNames = new Array<String>();
		var varExprs = new Array<hscript.Expr>();

		for (field in decls) 
		{
			switch (field.kind) {
				case KFunction(f): // generate functions
					var func = makeFromFunctionDecl(f, field.name);
					interp.variables.set(field.name, func);
				
				case KVar(v):
					varNames.push(field.name);
					varExprs.push(v.expr);
					interp.variables.set(field.name, null);
			}
		}

		if (interp.variables.exists('__init__'))
			interp.variables.get('__init__')();
		
		for (i in 0...varExprs.length) 
		{
			var name = varNames[i];
			var expr = varExprs[i];
			var eval = this.expr(expr);

			this.variables.set(name, eval);
		}
	}
}

class ClassInterp extends ModuleInterp
{
	public function toString()
		return 'ClassInterp(${classInfo.name})';
}

class InstanceInterp extends ModuleInterp
{
	override function resolve( id : String ) {
		var v:Dynamic; 

		if (variables.exists(id)) 
			v = variables.get(id);
		else if (classInfo.interp.variables.exists(id))
			v = classInfo.interp.variables.get(id);
		else if (imported.exists(id))
			v = imported.get(id);
		else
			error(EUnknownVariable(id));
			
		return v;
	}

	override function setVar(name:String, v:Dynamic)
	{
		if (variables.exists(name))
			variables.set(name, v);
		else if (classInfo.interp.variables.exists(name))
			classInfo.interp.variables.set(name, v);
		else // Can't define new variables!
			error(EUnknownVariable(name));
		
		return v;
	}

	public function toString()
		return 'InstanceInterp(${classInfo.name})';
}