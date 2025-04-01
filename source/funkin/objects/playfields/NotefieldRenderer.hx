package funkin.objects.playfields;
/* 
			if ((FlxG.state is PlayState))
				PlayState.instance.callOnHScripts("notefieldDraw", [this], ["drawQueue" => drawQueue]); // lets you do custom rendering in scripts, if needed

			var glowR = modManager.getValue("flashR", modNumber);
			var glowG = modManager.getValue("flashG", modNumber);
			var glowB = modManager.getValue("flashB", modNumber);
 */

import flixel.util.FlxDestroyUtil;
import flixel.math.FlxPoint;
import openfl.geom.ColorTransform;
import flixel.util.FlxColor;
import funkin.objects.playfields.NoteField;
import funkin.objects.playfields.FieldBase;
import funkin.objects.proxies.ProxyField;
import flixel.util.FlxSort;
@:structInit
class FinalRenderObject extends RenderObject {
	public var sourceField:FieldBase;
	public var glowColour:FlxColor;
	public var cameras:Array<FlxCamera>;

}

class NotefieldRenderer extends FlxBasic {
	public var members:Array<FieldBase> = [];

	public function add(field:FieldBase){
		if(members.contains(field))return;
		members.push(field);
	}
	public function remove(field:FieldBase){
		if (members.contains(field))
			members.remove(field);
	}
	
	static inline function zindexSort(Order:Int, Obj1:FinalRenderObject, Obj2:FinalRenderObject):Int {
		var result:Int = 0;
		var Value1:Float = Obj1.zIndex;
		var Value2:Float = Obj2.zIndex;

		if (Value1 < Value2) {
			result = Order;
		} else if (Value1 > Value2) {
			result = -Order;
		}

/* 		if(result == 0){
			var isObj1Note = Obj1.objectType == NOTE;
			var isObj2Note = Obj2.objectType == NOTE;
			if (isObj1Note && !isObj2Note)
				result = -Order;
			else if(isObj2Note)
				result = Order;
		} */

		return result;
	}

	static function drawQueueSort(Obj1:FinalRenderObject, Obj2:FinalRenderObject) {
		return zindexSort(FlxSort.ASCENDING, Obj1, Obj2);
	}
	
	var point:FlxPoint = FlxPoint.get(0, 0);
	
	override function draw(){
		var finalDrawQueue:Array<FinalRenderObject> = [];

		// Get all the drawing stuff from the fields
		for(field in members){
			if (!field.active || !field.exists || !field.visible)
				continue; // Ignore it

			field.preDraw(); // Collects all the drawing information
		}
		
		// Now that the main draw queues should have been populated, it's time to push them into the final draw queue for sorting
		
		
		for (field in members){
			field.draw(); // Just incase they want to do something before gathering happens (i.e ProxyFields grabbing their host's draw queue) 

			if(!field.visible || !field.active || !field.exists)
				continue;
			
			var realField:NoteField = field.getNotefield();

			var glowColour = realField.modManager == null ? FlxColor.WHITE : FlxColor.fromRGBFloat(realField.modManager.getValue("flashR",
				realField.modNumber), realField.modManager.getValue("flashG", realField.modNumber),
				realField.modManager.getValue("flashB", realField.modNumber));

			var queue:Array<RenderObject> = field.drawQueue;
			for (object in queue){
				finalDrawQueue.push({
					graphic: object.graphic,
					shader: object.shader,
					alphas: object.alphas,
					glows: object.glows,
					uvData: object.uvData,
					vertices: object.vertices,
					indices: object.indices,
					zIndex: object.zIndex + field.zIndexMod,
					colorSwap: object.colorSwap,
					objectType: object.objectType,
					antialiasing: object.antialiasing,
					sourceField: field,
					glowColour: glowColour,  // Maybe this should be part of the regular RenderObject?
					cameras: field.cameras
				});
			}
		}

		finalDrawQueue.sort(drawQueueSort); // TODO: Sort the *individual vertices* for better looking z-sorting

		// Now that it's all sorted, it's rendering time!

		// TODO: Put a callback here to allow us to use scripts to fuck w/ the final draw queue

		for (object in finalDrawQueue) {
			if (object == null)
				continue;
			var shader = object.shader;
			var graphic = object.graphic;
			var alphas = object.alphas;
			var glows = object.glows;
			var vertices = object.vertices;
			var uvData = object.uvData;
			var indices = object.indices;
			var colorSwap = object.colorSwap;
			var transforms:Array<ColorTransform> = []; // todo use fastvector
			var multAlpha = object.sourceField.alpha * ClientPrefs.noteOpacity;
			for (n in 0...Std.int(vertices.length / 2)) {
				var glow = glows[n];
				var transfarm:ColorTransform = new ColorTransform();
				transfarm.redMultiplier = 1 - glow;
				transfarm.greenMultiplier = 1 - glow;
				transfarm.blueMultiplier = 1 - glow;
				transfarm.redOffset = object.glowColour.red * glow;
				transfarm.greenOffset = object.glowColour.green * glow;
				transfarm.blueOffset = object.glowColour.blue * glow;
				transfarm.alphaMultiplier = alphas[n] * multAlpha;
				transforms.push(transfarm);
			}
			for (camera in object.cameras) {
				if (camera != null && camera.canvas != null && camera.canvas.graphics != null) {
					if (camera.alpha == 0 || !camera.visible)
						continue;
					for (shit in transforms)
						shit.alphaMultiplier *= camera.alpha;
					
					object.sourceField.getScreenPosition(point, camera);
					var drawItem = camera.startTrianglesBatch(graphic, object.antialiasing, true, null, true, shader);
					@:privateAccess
					{
						drawItem.addTrianglesColorArray(vertices, indices, uvData, null, point, camera._bounds, transforms, colorSwap);
					}
					for (n in 0...transforms.length)
						transforms[n].alphaMultiplier = alphas[n] * multAlpha;
				}
			}
		}

	}

	override function update(elapsed:Float){
		super.update(elapsed);
		
		for(field in members)
			field.update(elapsed);
	}
	override function destroy()
	{
		point = FlxDestroyUtil.put(point);
		super.destroy();

		while (members.length > 0)
			members.pop().destroy(); 
		
		members = null;
	}
}