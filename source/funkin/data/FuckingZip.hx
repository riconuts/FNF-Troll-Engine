package funkin.data;

import haxe.io.BytesOutput;
import haxe.io.Bytes;

/**
 * Barebones class to create a zip file

 * Based off:  
 - https://github.com/starburst997/haxe-zip/blob/master/src/zip/ZipWriter.hx
*/
class FuckingZip extends haxe.zip.Writer {
	var output:BytesOutput;
  
	public function new()
		super(output = new BytesOutput());

	public function addString(content:String, fileName:String)
		addBytes(Bytes.ofString(content), fileName);

	public function addBytes(bytes:Bytes, fileName:String) {		
		writeEntryHeader({
			fileName: fileName,
			fileSize: bytes.length,
			fileTime: Date.now(),
			compressed: false,
			dataSize: bytes.length,
			data: bytes,
			crc32: haxe.crypto.Crc32.make(bytes)
		});
		o.writeFullBytes(bytes, 0, bytes.length);
	}
	
	/**
		Writes this zip content to Bytes and returns it.

		This function should not be called more than once on a given instance.
	**/
	public function finalize():Bytes {
		writeCDR();
		return output.getBytes();
	}
}