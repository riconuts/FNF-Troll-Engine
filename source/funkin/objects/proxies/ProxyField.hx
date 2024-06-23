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
    chances are what i'd have to do is have some sorta "NotefieldManager" which'd handle drawing notefields in specific
    and it'd be put into 2 phases
    pre-draw and draw
    pre-draw grabs all the notes from the playfield its linked to, gets the position they'd be drawn at, etc. This'd store all the drawing info into an array in the notefield
    draw goes through the list of every NoteField and ProxyField and draws them. for ProxyFields, it just grabs the info from its linked NoteField, and for NoteFields it just uses its own info
    this shouldnt be too bad? esp. since PlayFields/NoteFields should only be used in PlayState
*/

class ProxyField extends FieldBase {
    var proxiedField:NoteField;
	var transfarm:ColorTransform = new ColorTransform();

	public function new(field:NoteField){
        super(0,0);
		proxiedField = field;
    }

    override function preDraw(){
        // does nothing, since this uses info from its linked notefield
    }
	
	override function update(elapsed:Float){
		field = proxiedField.field;
		super.update(elapsed);
	}
	var point = FlxPoint.get(0, 0);
    override function draw(){
		if (!active || !exists || !visible || !proxiedField.exists || !proxiedField.active)
			return; // dont draw if visible = false

		var drawQueue = proxiedField.drawQueue;
		super.draw();

		if ((FlxG.state is PlayState))
			PlayState.instance.callOnHScripts("playfieldDraw", [this], ["drawQueue" => drawQueue]); // lets you do custom rendering in scripts, if needed

		var glowR = proxiedField.modManager.getValue("flashR", proxiedField.modNumber);
		var glowG = proxiedField.modManager.getValue("flashG", proxiedField.modNumber);
		var glowB = proxiedField.modManager.getValue("flashB", proxiedField.modNumber);


		// actually draws everything
		if (drawQueue.length > 0)
		{
			for (object in drawQueue)
			{
				if (object == null)
					continue;
				var shader:Dynamic = object.shader;
				var graphic:FlxGraphic = object.graphic;
				var alphas = object.alphas;
				var glows = object.glows;
				var vertices = object.vertices;
				var uvData = object.uvData;
				var indices = new Vector<Int>(vertices.length, false, cast [for (i in 0...vertices.length) i]);
				var transforms:Array<ColorTransform> = [];
				for (n in 0...Std.int(vertices.length / 3))
				{
					var glow = glows[n];
					var transfarm:ColorTransform = new ColorTransform();
					transfarm.redMultiplier = 1 - glow;
					transfarm.greenMultiplier = 1 - glow;
					transfarm.blueMultiplier = 1 - glow;
					transfarm.redOffset = glowR * glow * 255;
					transfarm.greenOffset = glowG * glow * 255;
					transfarm.blueOffset = glowB * glow * 255;
					transfarm.alphaMultiplier = alphas[n] * this.alpha * ClientPrefs.noteOpacity;
					transforms.push(transfarm);
				}

				for (camera in cameras)
				{
					if (camera != null && camera.canvas != null && camera.canvas.graphics != null)
					{
						if (camera.alpha == 0 || !camera.visible)
							continue;
						for (shit in transforms)
							shit.alphaMultiplier *= camera.alpha;

						getScreenPosition(point, camera);
						var drawItem = camera.startTrianglesBatch(graphic, shader.bitmap.filter == 4, true, null, true, shader);
						@:privateAccess
						{
							drawItem.addTrianglesColorArray(vertices, indices, uvData, null, point, camera._bounds, transforms);
						}
						for (n in 0...transforms.length)
							transforms[n].alphaMultiplier = alphas[n];
					}
				}
			}
		}
    }
}