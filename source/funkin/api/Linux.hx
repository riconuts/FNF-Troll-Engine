package funkin.api;

#if (linux && cpp)
import cpp.Int16;
@:buildXml('<include name="../../../../source/funkin/api/build.xml" />')
@:include("refreshrate.hpp")
extern class Linux {
    @:native("getMonitorRefreshRate")
	static function getMonitorRefreshRate():Int16;
}
#end