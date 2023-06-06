package playfields;

import haxe.exceptions.NotImplementedException;

class FieldBase extends FlxObject {
    public function preDraw()throw new NotImplementedException();
    public var alpha:Float = 1;
}