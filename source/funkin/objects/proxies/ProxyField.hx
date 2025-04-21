package funkin.objects.proxies;

import openfl.geom.ColorTransform;
import openfl.Vector;
import flixel.math.FlxPoint;
import flixel.graphics.FlxGraphic;
import funkin.objects.playfields.FieldBase;
import funkin.objects.playfields.NoteField;
import funkin.states.PlayState;

/* 
	I'm gonna have to do some changes to NoteField to allow this to happen, but
	The idea is that ProxyField would be more optimized to use en masse compared to NoteFields, as this'd just copy what the field draws, rather than getting every pos etc itself
	Just need to figure out how I'm gonna write it tho
	chances are what i'd have to do is have some sorta "NotefieldRenderer" which'd handle drawing notefields in specific
	and it'd be put into 2 phases
	pre-draw and draw
	pre-draw grabs all the notes from the playfield its linked to, gets the position they'd be drawn at, etc. This'd store all the drawing info into an array in the notefield
	draw goes through the list of every NoteField and ProxyField and draws them. for ProxyFields, it just grabs the info from its linked NoteField, and for NoteFields it just uses its own info
	this shouldnt be too bad? esp. since PlayFields/NoteFields should only be used in PlayState
*/

class ProxyField extends FieldBase {
	@:allow(funkin.objects.playfields.NotefieldRenderer)
	var proxiedField:NoteField;

	public function new(field:NoteField){
		super(0,0);
		proxiedField = field;
	}

	override public function getNotefield() {return proxiedField;}

	override function preDraw(){} // hopefully no more crashes

	override function draw()
		drawQueue = proxiedField.drawQueue; // Just use the host field's queue
	
	
	override function update(elapsed:Float){
		field = proxiedField.field;
		super.update(elapsed);
	}
}