package;

import haxe.Constraints.Function;

#if (!no_traces && (js || lua || sys))
private inline function _printStr(str){
	#if js
	if (js.Syntax.typeof(untyped console) != "undefined" && (untyped console).log != null)
		(untyped console).log(str);
	#elseif lua
	untyped __define_feature__("use._hx_print", _hx_print(str));
	#elseif sys
	Sys.println(str);
	#end
}
private function _printArgsArray(args:Array<Dynamic>)
	_printStr(args.join(', '));

final print:Function = Reflect.makeVarArgs(_printArgsArray);
#else
final print:Function = ()->{};
#end