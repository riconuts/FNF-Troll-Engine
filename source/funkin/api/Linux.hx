package funkin.api;

#if (linux && cpp)
@:buildXml('<include name="../../../../source/funkin/api/build.xml" />')
@:include("refreshrate.h")
extern class Linux {
    @:native("getMonitorRefreshRate")
	public static function getMonitorRefreshRate():Int;
}
#end