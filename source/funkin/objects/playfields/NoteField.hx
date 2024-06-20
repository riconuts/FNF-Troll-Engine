package funkin.objects.playfields;

import flixel.math.FlxMath;
import flixel.math.FlxAngle;
import flixel.math.FlxPoint;
import flixel.math.FlxMatrix;
import flixel.util.FlxSort;
import flixel.util.FlxDestroyUtil;
import flixel.graphics.FlxGraphic;
import flixel.system.FlxAssets.FlxShader;
import math.Vector3;
import math.VectorHelpers;
import openfl.Vector;
import openfl.geom.ColorTransform;
import funkin.modchart.ModManager;
import funkin.modchart.Modifier.RenderInfo;
import funkin.states.PlayState;
import funkin.states.MusicBeatState;
import haxe.ds.Vector as FastVector;

using StringTools;

@:structInit
class RenderObject {
	public var graphic:FlxGraphic;
	public var shader:FlxShader;
	public var alphas:Array<Float>;
	public var glows:Array<Float>;
	public var uvData:Vector<Float>;
	public var vertices:Vector<Float>;
	public var zIndex:Float;
}

final scalePoint = new FlxPoint(1, 1);

class NoteField extends FieldBase
{
	var smoothHolds = true; // ClientPrefs.coolHolds;

	public var holdSubdivisions:Int = Std.int(ClientPrefs.holdSubdivs) + 1;
	public var optimizeHolds = ClientPrefs.optimizeHolds;
	public var defaultShader:FlxShader = new FlxShader();

	public function new(field:PlayField, modManager:ModManager)
	{
		super(0, 0);
		this.field = field;
		this.modManager = modManager;
	}

	/**
	 * The Draw Distance Modifier
	 * Multiplied by the draw distance to determine at what time a note will start being drawn
	 * Set to ClientPrefs.drawDistanceModifier by default, which is an option to let you change the draw distance.
	 * Best not to touch this, as you can set the drawDistance modifier to set the draw distance of a notefield.
	 */
	public var drawDistMod:Float = ClientPrefs.drawDistanceModifier;

	/**
	 * The ID used to determine how you apply modifiers to the notes
	 * For example, you can have multiple notefields sharing 1 set of mods by giving them all the same modNumber
	 */
	public var modNumber(default, set):Int = 0;
	function set_modNumber(d:Int){
		modManager.getActiveMods(d); // generate an activemods thing if needed
		return modNumber = d;
	}
	/**
	 * The ModManager to be used to get modifier positions, etc
	 * Required!
	 */
	public var modManager:ModManager;

	/**
	 * The song's scroll speed. Can be messed with to give different fields different speeds, etc.
	 */
	public var songSpeed:Float = 1.6;

	var curDecStep:Float = 0;
	var curDecBeat:Float = 0;

	final perspectiveArrDontUse:Array<String> = ['perspectiveDONTUSE'];

	/**
	 * The position of every receptor for a given frame.
	 */
	public var strumPositions:Array<Vector3> = [];
    
	/**
	 * Used by preDraw to store RenderObjects to be drawn
    */
	@:allow(funkin.objects.proxies.ProxyField)
    private var drawQueue:Array<RenderObject> = [];
	/**
	 * How zoomed this NoteField is without taking modifiers into account. 2 is 2x zoomed, 0.5 is half zoomed.
	 * If you want to modify a NoteField's zoom in code, you should use this!
	 */
	public var baseZoom:Float = 1;
    /**
     * How zoomed this NoteField is, taking modifiers into account. 2 is 2x zoomed, 0.5 is half zoomed.
	 * NOTE: This should not be set directly, as this is set by modifiers!
     */
	public var zoom:Float = 1;

	// does all the drawing logic, best not to touch unless you know what youre doing
    override function preDraw()
    {
		drawQueue = [];
		if(field==null)return;
        if(!active || !exists)return;
		if ((FlxG.state is MusicBeatState))
		{
			var state:MusicBeatState = cast FlxG.state;
			@:privateAccess
			curDecStep = state.curDecStep;
		}
		else
		{
			var lastChange = Conductor.getBPMFromSeconds(Conductor.songPosition);
			var shit = ((Conductor.songPosition - ClientPrefs.noteOffset) - lastChange.songTime) / lastChange.stepCrochet;
			curDecStep = lastChange.stepTime + shit;
		}
		curDecBeat = curDecStep / 4;

		zoom = modManager.getFieldZoom(baseZoom, curDecBeat, (Conductor.songPosition - ClientPrefs.noteOffset), modNumber, this);
		var notePos:Map<Note, Vector3> = [];
		var taps:Array<Note> = [];
		var holds:Array<Note> = [];
		var drawMod = modManager.get("drawDistance");
		var multAllowed = modManager.get("disableDrawDistMult");
		var drawDist = drawMod == null ? FlxG.height : drawMod.getValue(modNumber);
		if (multAllowed == null || multAllowed.getValue(modNumber) == 0)
			drawDist *= drawDistMod;
		for (daNote in field.spawnedNotes)
		{
			if (!daNote.alive)
				continue;

			if (songSpeed != 0)
			{
				var speed = modManager.getNoteSpeed(daNote, modNumber, songSpeed);
				var diff = Conductor.songPosition - daNote.strumTime;
				var visPos = -((Conductor.visualPosition - daNote.visualTime) * speed);
				if (visPos > drawDist)
					continue;
				if (daNote.wasGoodHit && daNote.sustainLength > 0)
				{
					diff = 0;
					visPos = 0;
					continue; // stops it from drawing lol
				}
				if (!daNote.isSustainNote)
				{
					var pos = modManager.getPos(visPos, diff, curDecBeat, daNote.column, modNumber, daNote, this, perspectiveArrDontUse,
						daNote.vec3Cache); // perspectiveDONTUSE is excluded because its code is done in the modifyVert function
					notePos.set(daNote, pos);
					taps.push(daNote);
				}
				else
				{
					holds.push(daNote);
				}
			}
		}

		var lookupMap = new haxe.ds.ObjectMap<Dynamic, RenderObject>();

		// draw the receptors
		for (obj in field.strumNotes)
		{
			if (!obj.alive || !obj.visible)
				continue;
			var pos = modManager.getPos(0, 0, curDecBeat, obj.column, modNumber, obj, this, perspectiveArrDontUse, obj.vec3Cache);
			strumPositions[obj.column] = pos;
			var object = drawNote(obj, pos);
			if (object == null)
				continue;
			object.zIndex += (obj.animation != null && obj.animation.curAnim != null && obj.animation.curAnim.name == 'confirm') ? 1 : 0;

			lookupMap.set(obj, object);
			drawQueue.push(object);
		}

		// draw tap notes
		for (note in taps)
		{
			if (!note.alive || !note.visible)
				continue;
			var pos = notePos.get(note);
			var object = drawNote(note, pos);
			if (object == null)
				continue;
			object.zIndex = pos.z + note.zIndex;
			lookupMap.set(note, object);
			drawQueue.push(object);
		}

		// draw hold notes (credit to 4mbr0s3 2)
		for (note in holds)
		{
			if (!note.alive || !note.visible)
				continue;
			var object = drawHold(note);
			if (object == null)
				continue;
			object.zIndex -= 1;
			lookupMap.set(note, object);
			drawQueue.push(object);
		}

		// draw notesplashes
		for (obj in field.grpNoteSplashes.members)
		{
			if (!obj.alive || !obj.visible)
				continue;
			var pos = modManager.getPos(0, 0, curDecBeat, obj.column, modNumber, obj, this, perspectiveArrDontUse);
			var object = drawNote(obj, pos);
			if (object == null)
				continue;
			object.zIndex += 2;
			lookupMap.set(obj, object);
			drawQueue.push(object);
		}

		// draw strumattachments
		for (obj in field.strumAttachments.members)
		{
			if (obj == null)
				continue;
			if (!obj.alive || !obj.visible)
				continue;
			var pos = modManager.getPos(0, 0, curDecBeat, obj.column, modNumber, obj, this, perspectiveArrDontUse);
			var object = drawNote(obj, pos);
			if (object == null)
				continue;
			object.zIndex += 2;
			lookupMap.set(obj, object);
			drawQueue.push(object);
		}

		if ((FlxG.state is PlayState))
			PlayState.instance.callOnHScripts("notefieldPreDraw", [this],
				["drawQueue" => drawQueue, "lookupMap" => lookupMap]); // lets you do custom rendering in scripts, if needed
		// one example would be reimplementing Die Batsards' original bullet mechanic
		// if you need an example on how this all works just look at the tap note drawing portion

		drawQueue.sort(function(Obj1:RenderObject, Obj2:RenderObject)
		{
			return FlxSort.byValues(FlxSort.ASCENDING, Obj1.zIndex, Obj2.zIndex);
		});

		if(zoom != 1){
			for(object in drawQueue){
				var vertices = object.vertices;
				var i:Int = 0;
				var currentVertexPosition:Int = 0;

				var centerX = FlxG.width * 0.5;
				var centerY = FlxG.height * 0.5;
				while (i < vertices.length)
				{
					matrix.identity();
					matrix.translate(-centerX, -centerY);
					matrix.scale(zoom, zoom);
					matrix.translate(centerX, centerY);
					var xIdx = currentVertexPosition++;
					var yIdx = currentVertexPosition++;
					point.set(vertices[xIdx], vertices[yIdx]);
					point.transform(matrix);

					vertices[xIdx] = point.x;
					vertices[yIdx] = point.y;

					i += 2;
				}
				object.vertices = vertices; // i dont think this is needed but its like, JUUUSST incase
			}
		}

    }

	var point:FlxPoint = FlxPoint.get(0, 0);
	
	var matrix:FlxMatrix = new FlxMatrix();
	override function draw()
	{
		if (!active || !exists || !visible)
			return; // dont draw if visible = false
		super.draw();

		if ((FlxG.state is PlayState))
			PlayState.instance.callOnHScripts("notefieldDraw", [this],
				["drawQueue" => drawQueue]); // lets you do custom rendering in scripts, if needed

		var glowR = modManager.getValue("flashR", modNumber);
		var glowG = modManager.getValue("flashG", modNumber);
		var glowB = modManager.getValue("flashB", modNumber);
		
		// actually draws everything
		if (drawQueue.length > 0)
		{
			for (object in drawQueue)
			{
				if (object == null)
					continue;
				var shader = object.shader;
				var graphic = object.graphic;
				var alphas = object.alphas;
				var glows = object.glows;
				var vertices = object.vertices;
				var uvData = object.uvData;
				var _indices = new FastVector<Int>(vertices.length);
				for(i in 0...vertices.length)
					_indices[i] = i;
				var indices = new Vector<Int>(vertices.length, false, cast _indices);
				var transforms:Array<ColorTransform> = []; // todo use fastvector
				var multAlpha = this.alpha * ClientPrefs.noteOpacity;
				for (n in 0... Std.int(vertices.length / 3)){
					var glow = glows[n];
					var transfarm:ColorTransform = new ColorTransform();
					transfarm.redMultiplier = 1 - glow;
					transfarm.greenMultiplier = 1 - glow;
					transfarm.blueMultiplier = 1 - glow;
					transfarm.redOffset = glowR * glow * 255;
					transfarm.greenOffset = glowG * glow * 255;
					transfarm.blueOffset = glowB * glow * 255;

					transfarm.alphaMultiplier = alphas[n] * multAlpha;
					transforms.push(transfarm);
				}

				for (camera in cameras)
				{
					if (camera != null && camera.canvas != null && camera.canvas.graphics != null)
					{
						if (camera.alpha == 0 || !camera.visible)
							continue;
						for(shit in transforms)
							shit.alphaMultiplier *= camera.alpha;
						getScreenPosition(point, camera);
						var drawItem = camera.startTrianglesBatch(graphic, shader.bitmap.filter == LINEAR, true, null, true, shader);

						@:privateAccess
						{
							drawItem.addTrianglesColorArray(vertices, indices, uvData, null, point, camera._bounds, transforms);
						}
						for (n in 0...transforms.length)
							transforms[n].alphaMultiplier = alphas[n] * multAlpha;
					}
				}
			}
		}
	}

	function getPoints(hold:Note, ?wid:Float, speed:Float, vDiff:Float, diff:Float):Array<Vector3>
	{ // stolen from schmovin'
		if (wid == null)
			wid = hold.frameWidth * hold.scale.x;

		var p1 = modManager.getPos(-(vDiff) * speed, diff, curDecBeat, hold.column, modNumber, hold, this, []);
		var z:Float = p1.z;
		p1.z = 0.0;

		wid /= 2.0;
		var quad0 = new Vector3(-wid);
		var quad1 = new Vector3(wid);
		var scale:Float = z!=0.0 ? z : 1.0;

		if (optimizeHolds)
		{
			// less accurate, but higher FPS
			scale = 1.0 / scale;
			quad0.scaleBy(scale);
			quad1.scaleBy(scale);
			return [p1.add(quad0, quad0), p1.add(quad1, quad1), p1];
		}

		var p2 = modManager.getPos(-(vDiff + 1) * speed, diff + 1, curDecBeat, hold.column, modNumber, hold, this, []);
		p2.z = 0;

		var unit = p2.subtract(p1);
		unit.normalize();

		var w = (quad0.subtract(quad1).length / 2) / scale;
		var off1 = new Vector3(unit.y * w, 	-unit.x * w,	0.0);
		var off2 = new Vector3(-off1.x, 	-off1.y,		0.0);

		return [p1.add(off1, off1), p1.add(off2, off2), p1];
	}

    
    var crotchet = Conductor.getCrotchetAtTime(0) / 4;
	function drawHold(hold:Note, ?prevAlpha:Float, ?prevGlow:Float):Null<RenderObject>
    {
		if (hold.animation.curAnim == null)
			return null;
		if (hold.scale == null)
			return null;

		var render = false;
		for (camera in cameras)
		{
			if (camera.alpha > 0 && camera.visible)
			{
				render = true;
				break;
			}
		}
		if (!render)
			return null;

		var verts:Array<Float> = [];
		var uv:Array<Float> = [];
		var alphas:Array<Float> = [];
		var glows:Array<Float> = [];

		inline function addVert(vert:Float) {
			verts.push(vert);
		}
		inline function addVert2(vert:Float, vert2:Float) {
			verts.push(vert);
			verts.push(vert2);
		}

		var lastMe = null;

		var tWid = hold.frameWidth * hold.scale.x;
		var bWid = (
			if (hold.prevNote != null && hold.prevNote.scale != null && hold.prevNote.isSustainNote)
				hold.prevNote.frameWidth * hold.prevNote.scale.x
			else
				tWid
		);

		var basePos = modManager.getPos(0, 0, curDecBeat, hold.column, modNumber, hold, this, perspectiveArrDontUse);

		var strumDiff = (Conductor.songPosition - hold.strumTime);
		var visualDiff = (Conductor.visualPosition - hold.visualTime); // TODO: get the start and end visualDiff and interpolate so that changing speeds mid-hold will look better
		var zIndex:Float = basePos.z;
		var sv = PlayState.instance.getSV(hold.strumTime).speed;

		for (sub in 0...holdSubdivisions)
		{
			var prog = sub / (holdSubdivisions + 1);
			var nextProg = (sub + 1) / (holdSubdivisions + 1);
			var strumSub = (crotchet / holdSubdivisions);
			var strumOff = (strumSub * sub);
			strumSub *= sv;
            strumOff *= sv;
			var scale:Float = 1;
			var fuck = strumDiff;

			if ((hold.wasGoodHit || hold.parent.wasGoodHit) && !hold.tooLate)
			{
				scale = 1 - ((fuck + crotchet) / crotchet);
				if (scale < 0)
					scale = 0;
				if (scale > 1)
					scale = 1;
				strumSub *= scale;
				strumOff *= scale;
			}

			scalePoint.set(1, 1);

			var speed = modManager.getNoteSpeed(hold, modNumber, songSpeed);

			var info:RenderInfo = modManager.getExtraInfo((visualDiff + ((strumOff + strumSub) * 0.45)) * -speed, strumDiff + strumOff + strumSub, curDecBeat,
			{
				alpha: hold.alpha,
				glow: 0,
				scale: scalePoint
			}, hold, modNumber, hold.column);

			var topWidth = FlxMath.lerp(tWid, bWid, prog) * scalePoint.x;
			var botWidth = FlxMath.lerp(tWid, bWid, nextProg) * scalePoint.x;

			for (_ in 0...4)
			{
				alphas.push(info.alpha);
				glows.push(info.glow);
			}

			var top = lastMe == null ? getPoints(hold, topWidth, speed, (visualDiff + (strumOff * 0.45)), strumDiff + strumOff) : lastMe;
			var bot = getPoints(hold, botWidth, speed, (visualDiff + ((strumOff + strumSub) * 0.45)), strumDiff + strumOff + strumSub);

			lastMe = bot;

			//var quad:Array<Vector3> = [top[0], top[1], bot[0], bot[1]];

			addVert2(top[0].x, top[0].y);
			addVert2(top[1].x, top[1].y);
			addVert2(bot[1].x, bot[1].y);
			addVert2(top[0].x, top[0].y);
			addVert2(bot[0].x, bot[0].y);
			addVert2(bot[1].x, bot[1].y);

			/*verts = verts.concat([
				quad[0].x, quad[0].y,
				quad[1].x, quad[1].y,
				quad[3].x, quad[3].y,

				quad[0].x, quad[0].y,
				quad[2].x, quad[2].y,
				quad[3].x, quad[3].y
			]);*/
			uv = uv.concat(getUV(hold, false, sub)); // TODO: optimize this
		}

		var vertices = new Vector<Float>(verts.length, false, cast verts);
		var uvData = new Vector<Float>(uv.length, false, uv);

		var shader = hold.shader != null ? hold.shader : defaultShader;
		if (shader != hold.shader)
			hold.shader = shader;

		shader.bitmap.input = hold.graphic.bitmap;
		shader.bitmap.filter = hold.antialiasing ? LINEAR : NEAREST;

		return {
			graphic: hold.graphic,
			shader: shader,
			alphas: alphas,
			glows: glows,
			uvData: uvData,
			vertices: vertices,
			zIndex: zIndex
		}
	}

	private function getUV(sprite:FlxSprite, flipY:Bool, sub:Int)
	{
		// i cant be bothered
		// code by 4mbr0s3 2 (Schmovin')
		var frameRect = sprite.frame.frame;
		var sourceBitmap = sprite.graphic.bitmap;

		var leftX = frameRect.left / sourceBitmap.width;
		var topY = frameRect.top / sourceBitmap.height;
		var rightX = frameRect.right / sourceBitmap.width;
		var height = frameRect.height / sourceBitmap.height;

		if (!flipY)
			sub = (holdSubdivisions - 1) - sub;
		var uvSub = 1.0 / holdSubdivisions;
		var uvOffset = uvSub * sub;
		if (flipY)
		{
			return [
				 leftX,           topY + uvOffset * height,
				rightX,           topY + uvOffset * height,
				rightX, topY + (uvOffset + uvSub) * height,
				 leftX,           topY + uvOffset * height,
				 leftX, topY + (uvOffset + uvSub) * height,
				rightX, topY + (uvOffset + uvSub) * height
			];
		}
		return [
			 leftX, topY + (uvSub + uvOffset) * height,
			rightX, topY + (uvSub + uvOffset) * height,
			rightX,           topY + uvOffset * height,
			 leftX, topY + (uvSub + uvOffset) * height,
			 leftX,           topY + uvOffset * height,
			rightX,           topY + uvOffset * height
		];
	}

	function drawNote(sprite:NoteObject, pos:Vector3):Null<RenderObject>
	{
		if (!sprite.visible || !sprite.alive)
			return null;

		var render = false;
		for (camera in cameras)
		{
			if (camera.alpha > 0 && camera.visible)
			{
				render = true;
				break;
			}
		}
		if (!render)
			return null;

		var isNote = (sprite is Note);
		var note:Note = isNote ? cast sprite : null;

		var width = sprite.frameWidth * sprite.scale.x;
		var height = sprite.frameHeight * sprite.scale.y;
		scalePoint.set(1, 1);
		var diff:Float =0;
		var visPos:Float = 0;
		if(isNote) {
			var speed = modManager.getNoteSpeed(note, modNumber, songSpeed);
			diff = Conductor.songPosition - note.strumTime;
			visPos = -((Conductor.visualPosition - note.visualTime) * speed);
		}

		var info:RenderInfo = modManager.getExtraInfo(visPos, diff, curDecBeat, {
			alpha: sprite.alpha,
			glow: 0,
			scale: scalePoint
		}, sprite, modNumber, sprite.column);

		var alpha = info.alpha;
		var glow = info.glow;

		final QUAD_SIZE = 4;
		var quad0 = new Vector3(-width / 2, -height / 2, 0); // top left
		var quad1 = new Vector3(width / 2, -height / 2, 0); // top right
		var quad2 = new Vector3(-width / 2, height / 2, 0); // bottom left
		var quad3 = new Vector3(width / 2, height / 2, 0); // bottom right

		for (idx in 0...QUAD_SIZE)
		{
			var quad = switch(idx) {
				case 0: quad0;
				case 1: quad1;
				case 2: quad2;
				case 3: quad3;
				default: null;
			};
			var vert = VectorHelpers.rotateV3(quad, 0, 0, FlxAngle.TO_RAD * sprite.angle);
			vert.x = vert.x + sprite.offsetX;
			vert.y = vert.y + sprite.offsetY;

			if (isNote)
			{
				vert.x = vert.x + note.typeOffsetX;
				vert.y = vert.y + note.typeOffsetY;
			}

			vert = modManager.modifyVertex(curDecBeat, vert, idx, sprite, pos, modNumber, sprite.column, this);

			vert.x = vert.x * scalePoint.x;
			vert.y = vert.y * scalePoint.y;

/* 			vert.x *= zoom;
			vert.y *= zoom; */
			if (sprite.flipX)
				vert.x = -vert.x;
			if (sprite.flipY)
				vert.y = -vert.x;
			//quad[idx] = vert;
			quad.setTo(vert.x, vert.y, vert.z);
		}

		var frameRect = sprite.frame.frame;
		var sourceBitmap = sprite.graphic.bitmap;

		var leftUV = frameRect.left / sourceBitmap.width;
		var rightUV = frameRect.right / sourceBitmap.width;
		var topUV = frameRect.top / sourceBitmap.height;
		var bottomUV = frameRect.bottom / sourceBitmap.height;

		// order should be LT, RT, RB, LT, LB, RB
		// R is right L is left T is top B is bottom
		// order matters! so LT is left, top because they're represented as x, y
		var vertices = new Vector<Float>(12, false, [
			pos.x + quad0.x, pos.y + quad0.y,
			pos.x + quad1.x, pos.y + quad1.y,
			pos.x + quad3.x, pos.y + quad3.y,

			pos.x + quad0.x, pos.y + quad0.y,
			pos.x + quad2.x, pos.y + quad2.y,
			pos.x + quad3.x, pos.y + quad3.y
		]);

		var uvData = new Vector<Float>(12, false, [
			 leftUV,    topUV,
			rightUV,    topUV,
			rightUV, bottomUV,

			 leftUV,    topUV,
			 leftUV, bottomUV,
			rightUV, bottomUV,
		]);

		var shader = sprite.shader != null ? sprite.shader : defaultShader;
		if (shader != sprite.shader)
			sprite.shader = shader;

		shader.bitmap.input = sprite.graphic.bitmap;
		shader.bitmap.filter = sprite.antialiasing ? LINEAR : NEAREST;

		final totalTriangles = Std.int(vertices.length / 3);
		var alphas = new FastVector<Float>(totalTriangles);
		var glows = new FastVector<Float>(totalTriangles);
		for (i in 0...totalTriangles)
		{
			alphas[i] = alpha;
			glows[i] = glow;
		}

		return {
			graphic: sprite.graphic,
			shader: shader,
			alphas: cast alphas,
			glows: cast glows,
			uvData: uvData,
			vertices: vertices,
			zIndex: pos.z
		}
	}

	override function destroy()
	{
		point = FlxDestroyUtil.put(point);
		super.destroy();
	}
}