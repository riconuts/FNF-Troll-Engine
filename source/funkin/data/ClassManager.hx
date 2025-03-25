package funkin.data;

import hscript.module.ModuleInfo;
import hscript.Parser;
import hscript.Expr;

class ClassManager 
{
	public static var parser:Parser = new Parser();
	public static var classMap = new Map<String, ClassInfo>();

	public static function resolveClass(name:String):Null<ClassInfo>
		return classMap.get(name);

	public static function registerClass(name:String, cl:ClassInfo)
		classMap.set(name, cl);

	public static function fromModuleFile(path:String, ?defaultPackage:String):ModuleInfo {
		var parsed:Array<ModuleDecl> = null;

		parser.line = 1;
		parsed = parser.parseModule(funkin.Paths.getContent(path), path);

		return new ModuleInfo(parsed, path, defaultPackage);
	}
}