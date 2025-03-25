package hscript.module;

import hscript.Expr;
import hscript.module.ModuleInterp;

class ModuleInfo
{
	public var classes = new Array<ClassInfo>();
	public var classMap = new Map<String, ClassInfo>();
	public var imported = new Map<String, Dynamic>();
	
	public var packageStr:String = "";

	public function new(moduleDecls:Array<ModuleDecl>, origin:String = "hscript", ?defaultPackage:String)
	{
		var position = -1;
		var curExpr = null;
		inline function next()
			return curExpr = moduleDecls[++position];
		inline function prev()
			return curExpr = moduleDecls[--position];

		////
		packageStr = switch(next()) {
			case DPackage(path):
				path.join('.');
			default:
				defaultPackage ?? throw 'Module should start with a package declaration';
		}

		while (next() != null) {
			switch(curExpr) {
				// wtf no support for parsing import aliases
				case DImport(path, everything):
					if (everything) throw 'wildcard imports not supported';

					var name:String = path[path.length-1];
					var path:String = path.join('.');
					var cl = Type.resolveClass(path);
		
					if (cl == null)
						trace('Class $path not found!');
					else
						imported.set(name, cl);

				default:
					prev(); // this is fucked
					break;	
			}
		}

		while (next() != null)
		{
			switch(curExpr) {
				case DClass(c):
					var info = ClassInfo.fromClassDecl(c);
					classes.push(info);
					classMap.set(info.name, info);
					imported.set(info.name, info.interp);
				
				case DTypedef(c):
				
				case DImport(path, everything):
					throw "import and using may not appear after a declaration";
				
				case DPackage(path): 
					throw "Unexpected package";
			}
		}
	}

	public function initClasses() {
		for (c in classes) {
			var interp = c.interp;
			for (k => v in this.imported)
				interp.imported.set(k, v);

			interp.initFieldDecls(c.staticDecls);
		}
	}
}

@:structInit
class ClassInfo
{
	public var name:String;
	public var interp:ClassInterp;

	public var staticDecls:Array<FieldDecl>;
	public var memberDecls:Array<FieldDecl>; // non-static
	public var constructorDecl:FieldDecl;

	public static function fromClassDecl(decl:ClassDecl):ClassInfo
	{
		var staticDeclsMap = new Map<String, Bool>();
		var memberDeclsMap = new Map<String, Bool>();

		var staticDecls = new Array<FieldDecl>();
		var memberDecls = new Array<FieldDecl>();
		var constructorDecl = null;

		inline function exprError(e:Expr, error:String):String {
			return e.origin + ":" + e.line + ": " + error;
		}

		inline function fieldError(field:FieldDecl, error:String):String {
			switch(field.kind) {
				case KVar(v): return exprError(v.expr, error);
				case KFunction(f): return exprError(f.expr, error);
			}
		}

		for (field in decl.fields) {
			final fn = field.name;

			if (staticDeclsMap.exists(fn) || memberDeclsMap.exists(fn))
				throw fieldError(field, 'Duplicate field "$fn"');
						
			final isStatic = field.access.contains(AStatic);
			
			if (field.name == "new") {
				if (constructorDecl != null)
					throw fieldError(field, 'Duplicate constructor');
				
				if (isStatic)
					throw fieldError(field, 'Invalid modifier: static on constructor');

				constructorDecl = field;
			}
			else if (isStatic) {
				staticDecls.push(field);
				staticDeclsMap.set(fn, true);
			}
			else {
				memberDecls.push(field);
				staticDeclsMap.set(fn, true);
			}
		}

		#if true
		for (field in memberDecls) {
			switch(field.kind) {
				case KVar(v):
					function check(e:Expr) {
						switch(e.e) {
							case EVar(n, t, e):
								if (n == 'this')
									throw exprError(e, 'Keyword this cannot be used as variable name');
								check(e);

							case EIdent(v): 
								if (v == 'this')
									throw fieldError(field, 'Cannot access this or other member field in variable initialization');
							
							case EField(e, f):
								check(e);

							case EBlock(e):
								for (e in e)
									check(e);

							default:
								
						}
					}
					check(v.expr);
				case KFunction(f):
			}
		}
		#end

		var info:ClassInfo = {
			name: decl.name,
			staticDecls: staticDecls,
			memberDecls: memberDecls,
			constructorDecl: constructorDecl,
			interp: null,
		}
		info.interp = new ClassInterp(info);
		return info;
	}

	public function createInstance(args:Array<Dynamic>):InstanceInterp
	{
		if (constructorDecl == null)
			throw '$name does not have a constructor';

		switch (constructorDecl.kind) {
			case KFunction(f):
				var instance = new InstanceInterp(this);
				instance.initFieldDecls(this.memberDecls);
				instance.imported.set("this", instance);

				var func = instance.makeFromFunctionDecl(f, constructorDecl.name);
				Reflect.callMethod(null, func, args);

				return instance;

			default:
				throw '$name does not have a constructor';				
		}

		return null;
	}

	public function toString()
		return 'ClassInfo($name)';
}