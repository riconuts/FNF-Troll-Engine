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

	/**
	 * All of the strums in the playfield attached to this notefield
	 */
	@:isVar
	public var members(get, never):Array<StrumNote> = [];

	function get_members()
		return field.strumNotes;

}