package funkin.objects.notestyles;

class BaseNoteStyle 
{
	public var scale:Float = 1;
	
	public final id:String;

	public function new(id:String) {
		this.id = id;
	}
	
	public function update(elapsed:Float):Void {
		
	}

	public function optionsChanged(changed:Array<String>):Void {
		
	}
	
	public function destroy():Void {
		
	}

	////

	public function loadNote(note:Note):Bool {
		return true; // Whether the style was applied or not
	}
	
	public function unloadNote(note:Note):Void {

	}

	public function loadReceptor(note:Note):Bool {
		return true; 
	}
	
	public function unloadReceptor(note:Note):Void {

	}

	public function loadNoteSplash(splash:NoteSplash):Bool {
		return true;
	}

	public function unloadNoteSplash(splash:NoteSplash):Void {
		
	}

	public function noteUpdate(note:Note, dt:Float):Void {

	}
}