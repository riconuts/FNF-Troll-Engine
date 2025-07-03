package funkin.api;

import cpp.SizeT;

/**
 * Gets the accurate memory counter
 * Original C code by David Robert Nadeau
 * @see https://web.archive.org/web/20190716205300/http://nadeausoftware.com/articles/2012/07/c_c_tip_how_get_process_resident_set_size_physical_memory_use
 */
@:buildXml('<include name="../../../../source/funkin/api/build.xml" />')
@:include("memory.hpp")
extern class Memory {
    @:native("getPeakRSS")
    static function getPeakRSS():SizeT;

    @:native("getCurrentRSS")
    static function getCurrentRSS():SizeT;
}