package funkin.objects.playfields;

import haxe.exceptions.NotImplementedException;

class FieldBase extends FlxObject {
    public function preDraw()throw new NotImplementedException();
    public var alpha:Float = 1;
    /*
	 * The PlayField used to determine the notes to render
	 * Required!
	 */
	public var field:PlayField;
}