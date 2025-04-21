package funkin.objects.playfields;

import funkin.objects.notes.StrumNote;
import funkin.objects.notes.NoteObject.ObjectType;
import haxe.exceptions.NotImplementedException;
import flixel.graphics.FlxGraphic;
import flixel.system.FlxAssets.FlxShader;
import funkin.objects.shaders.NoteColorSwap;
import haxe.ds.Vector as FastVector;
import openfl.Vector;
@:structInit
class RenderObject {
	public var graphic:FlxGraphic;
	public var shader:FlxShader;
	public var alphas:Array<Float>;
	public var glows:Array<Float>;
	public var uvData:Vector<Float>;
	public var vertices:Vector<Float>;
	public var indices:Vector<Int>;
	public var zIndex:Float;
	public var objectType:ObjectType;
	public var colorSwap:NoteColorSwap;
	public var antialiasing:Bool;
}

class FieldBase extends FlxObject {
	public function preDraw()throw new NotImplementedException();

	public var tryForceHoldsBehind:Bool = true; // Field tries to push holds behind receptors

	public var isProxy:Bool = false; // dumb and hardcoded but oh well
	
	/**
	 * Z-Index Modifier
	 * Used to push the field behind others or pull it infront of others.
	 */
	public var zIndexMod:Float = 0;

	/**
	 * Used by preDraw to store RenderObjects to be drawn
	 */
	public var drawQueue:Array<RenderObject> = [];

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

	public function getNotefield() {return null;}
}