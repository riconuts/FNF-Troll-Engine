package funkin.objects.notestyles;

class BaseNoteStyle 
{
	public final id:String;
	public var scale:Float = 1.0;

	public function new(id:String)
		this.id = id;

	public function getPreload():Array<funkin.data.Cache.AssetPreload>
		return [];
	
	public function update(elapsed:Float):Void
		return;

	public function optionsChanged(changed:Array<String>):Void
		return;

	public function destroy():Void 
		return;

	////

	/**@return Whether the style was applied or not*/
	public function loadNote(note:Note):Bool
		return true;
	
	public function unloadNote(note:Note):Void
		return;

	/**@return Whether the style was applied or not*/
	public function loadReceptor(strum:StrumNote):Bool
		return true;
	
	public function unloadReceptor(strum:StrumNote):Void
		return;

	/**@return Whether the style was applied or not*/
	public function loadNoteSplash(splash:NoteSplash, ?note:Note):Bool
		return true;

	public function unloadNoteSplash(splash:NoteSplash):Void
		return;

	public function updateObject(obj:NoteObject, dt:Float):Void
		return;
}