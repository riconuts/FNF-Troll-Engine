package;

import haxe.Constraints.Function;
import haxe.ds.StringMap;
import hscript.Parser;
import hscript.Expr.ModuleDecl;
import hscript.Expr.ClassDecl;
import hscript.Expr.FieldDecl;
import hscript.Expr.FunctionDecl;
import hscript.Expr.VarDecl;
import hscript.Interp;

@:structInit
class ClassDecls
{
	public var staticDecls:Array<FieldDecl>;
	public var memberDecls:Array<FieldDecl>; // non-static
	public var constructorDecl:FieldDecl; // cannot be accessed

	public static function fromClassDecl(decl:ClassDecl):ClassDecls
	{
		var fieldDecls = new Map<String, Bool>();
		var staticDecls = new Array<FieldDecl>();
		var memberDecls = new Array<FieldDecl>();
		var constructorDecl = null;

		for (field in decl.fields) {
			final fn = field.name;

			if (fieldDecls.exists(fn)) {
				throw 'Duplicate field "$fn"';
				continue;
			}else 
				fieldDecls.set(fn, true);
			
			var isStatic = false;
			for (fa in field.access) {
				if (fa == AStatic) {
					isStatic = true;
					break;
				}
			}

			if (isStatic)
				staticDecls.push(field);
			else if (field.name == "new")
				constructorDecl = field;
			else
				memberDecls.push(field);
		}

		return {staticDecls: staticDecls, memberDecls: memberDecls, constructorDecl: constructorDecl};
	}
}

class ScriptedClassManager 
{
	public static var parser:Parser = new Parser();
	public static var classMap = new Map<String, ScriptedClass>();

	public static function resolveScriptedClass(name:String):Null<ScriptedClass>
		return classMap.get(name);

	public static function resolveClass(name:String):Null<Dynamic> {
		var c = Type.resolveClass(name);
		return (c!=null) ? c : resolveScriptedClass(name);
	}

	public static function fromModuleFile(path:String):Array<ScriptedClass> {
		var parsed:Array<ModuleDecl> = null;

		parser.line = 1;
		parsed = parser.parseModule(funkin.Paths.getContent(path), path);

		var position = -1;
		var curExpr = null;
		inline function next()
			return curExpr = parsed[++position];
		inline function back()
			position--;

		var packagePath:Array<String> = [];
		switch (next()) {
			case DPackage(path): packagePath = path;
			default: throw "Module should start with a package declaration";
		}
		var packageStr:String = packagePath.join('.');

		var imported = new Map<String, Dynamic>();
		inline function doImport(path:Array<String>, everything:Bool) {
			if (everything) throw 'wildcard imports not supported';

			var name:String = path[path.length-1];
			var path:String = path.join('.');
			var cl = resolveClass(path);

			if (cl == null)
				trace('Class $path not found!');
			else {
				imported.set(name, cl);
			}
		}

		var classDecls:Array<ClassDecl> = [];
		while (next() != null)
		{
			switch(curExpr) {
				case DClass(c): classDecls.push(c);
				case DTypedef(c):
				case DImport(path, everything): 
					if (classDecls.length==0)
						doImport(path, everything);
					else 
						throw "import and using may not appear after a declaration";
					// wtf no support for parsing import aliases

				case DPackage(path): throw "Unexpected package";
			}
		}

		var classes = new Array<ScriptedClass>();
		for (decl in classDecls) {
			var obj = new ScriptedClass();
			obj.name = decl.name;
			classes.push(obj);

			classMap.set(packageStr + '.' + obj.name, obj);
			imported.set(obj.name, obj);
		}

		for (i => decl in classDecls) {
			var cl = classes[i];
			for (k => v in imported)
				cl.imported.set(k, v);

			var cd = ClassDecls.fromClassDecl(decl);
			cl.setupClassDecls(cd);
		}

		return classes;
	}
}

class ScriptedModuleInterp extends hscript.TrollInterp
{
	public var name:String;
	public function new(name:String = "Unknown")
	{
		this.name = name;
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

	////
	inline function fromFunctionDecl(f:hscript.Expr.FunctionDecl, name:String="unk")
	{
		final interp = this;
		var exprDef:hscript.Expr.ExprDef = EFunction(f.args, f.expr, name, f.ret);
		var funcExpr = hscript.Tools.mk(exprDef, {pmin:0, pmax:0, origin:"sowy", line:0, e:null});
		var func = interp.expr(funcExpr);
		return func;
	}

	public function setupFieldDecls(decls:Array<FieldDecl>)
	{
		final interp = this;

		// variables will be evaluated after functions
		var varNames = new Array<String>();
		var varExprs = new Array<hscript.Expr>();

		for (field in decls) 
		{
			switch (field.kind) {
				case KFunction(f):
					var func = fromFunctionDecl(f, field.name);
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

class ScriptedClass extends ScriptedModuleInterp
{
	public function toString()
		return 'ScriptedClass<$name>';

	var classDecls:ClassDecls;
	public function setupClassDecls(classDecls:ClassDecls) {
		this.classDecls = classDecls;
		this.setupFieldDecls(classDecls.staticDecls);
	}

	public function createInstance(args:Array<Dynamic>):ScriptedClassInstance
	{
		// TODO
		if (classDecls.constructorDecl == null)
			throw '$name does not have a constructor';

		switch (classDecls.constructorDecl.kind) {
			case KFunction(f):
				var instance = new ScriptedClassInstance(this);
				instance.setupFieldDecls(classDecls.memberDecls);

				var func = fromFunctionDecl(f, classDecls.constructorDecl.name);
				Reflect.callMethod(null, func, args);

				return instance;

			default:
				throw '$name does not have a constructor';				
		}

		return null;
	}
}

class ScriptedClassInstance extends ScriptedModuleInterp
{
	var parentClass:ScriptedClass;
	public function new(parentClass) {
		super();
		this.parentClass = parentClass;
		this.name = parentClass.name;
	}

	override function resetImports() {
		super.resetImports();
		imported.set("this", this);
	}

	override function resolve( id : String ) {
		var v:Dynamic; 

		if (variables.exists(id)) 
			v = variables.get(id);
		else if (parentClass.variables.exists(name))
			v = parentClass.variables.get(id);
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
		else if (parentClass.variables.exists(name))
			parentClass.variables.set(name, v);
		else // Can't define new variables!
			error(EUnknownVariable(name));
		
		return v;
	}

	////
	public function toString() 
		return 'ScriptedClassInstance<$name>';
}