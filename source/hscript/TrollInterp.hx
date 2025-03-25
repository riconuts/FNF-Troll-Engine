package hscript;

import hscript.module.ModuleInterp.ClassInterp as ScriptedClassInterp;
import funkin.data.ClassManager as ScriptedClassManager;

class TrollInterp extends hscript.Interp
{
	override function getImport(cl:String, ?field:String) {
		var ti:Dynamic = super.getImport(cl, field);

		if (ti == null) {
			var sc = ScriptedClassManager.resolveClass(cl);
			var interp = sc?.interp;

			if (sc == null) {
				// can't do shit
				trace("nf");
			}
			else {
				if (field != null) {
					// unsupported for now
				}else {
					ti = interp;
				}
			}
			trace(sc, ti, interp);
		}
		
		return ti;
	}

	override function get(o:Dynamic, f:String):Dynamic {
		if (o is ScriptedClassInterp) {
			var o:ScriptedClassInterp = cast o;
			return o.variables.get(f);
		}
		return super.get(o, f);
	}

	override function set(o:Dynamic, f:String, v:Dynamic):Dynamic {
		if (o is ScriptedClassInterp) {
			var o:ScriptedClassInterp = cast o;
			if (o.variables.exists(f))
				o.variables.set(f, v);
			return v;
		}
		return super.set(o, f, v);
	}

	override function cnew( cl : String, args : Array<Dynamic> ) : Dynamic {
		var c = Type.resolveClass(cl);
		if (c != null)
			return Type.createInstance(c,args);
		
		var sc = ScriptedClassManager.resolveClass(cl);
		if (sc != null)
			return sc.createInstance(args);
		
		var r = resolve(cl);
		if (r is ScriptedClassInterp) {
			var r:ScriptedClassInterp = cast r;
			return r.classInfo.createInstance(args);
		}
		
		return Type.createInstance(r, args);
	}
}