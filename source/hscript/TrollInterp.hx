package hscript;

import ScriptedClass.ScriptedClassManager;

class TrollInterp extends hscript.Interp
{
	override function cnew( cl : String, args : Array<Dynamic> ) : Dynamic {
		var c:Dynamic = ScriptedClassManager.resolveClass(cl);
		if( c == null )
			c = resolve(cl);
		
		return if (c is ScriptedClass)
			(c:ScriptedClass).createInstance(args);
		else switch (Type.typeof(c)) {
			case TClass(c): return Type.createInstance(c,args);
			default: null;
		}
	}
}