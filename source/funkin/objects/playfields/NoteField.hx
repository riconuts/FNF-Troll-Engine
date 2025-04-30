package funkin.objects.playfields;

import funkin.modchart.modifiers.ReverseModifier;
import funkin.modchart.Modifier;
import flixel.math.FlxMath;
import flixel.math.FlxAngle;
import flixel.math.FlxPoint;
import flixel.math.FlxMatrix;
import flixel.util.FlxSort;
import flixel.util.FlxDestroyUtil;
import flixel.graphics.FlxGraphic;
import flixel.graphics.frames.FlxFrame.FlxFrameAngle;
import flixel.system.FlxAssets.FlxShader;
import math.Vector3;
import math.VectorHelpers;
import openfl.Vector;
import openfl.geom.ColorTransform;
import funkin.modchart.ModManager;
import funkin.modchart.Modifier.RenderInfo;
import funkin.objects.shaders.NoteColorSwap;
import funkin.states.PlayState;
import funkin.states.MusicBeatState;
import haxe.ds.Vector as FastVector;
import funkin.objects.playfields.FieldBase;

using StringTools;



final scalePoint = new FlxPoint(1, 1);

class NoteField extends FieldBase
{
	// order should be LT, RT, RB, LT, LB, RB
	// R is right L is left T is top B is bottom
	// order matters! so LT is left, top because they're represented as x, y
	var NOTE_INDICES:Vector<Int> = new Vector<Int>(6, true, [
		0, 1, 3,
		0, 2, 3
	]);
	var HOLD_INDICES:Vector<Int> = new Vector<Int>(0, false);

	public var holdSubdivisions(default, set):Int;
	public var optimizeHolds = false; //ClientPrefs.optimizeHolds;
	public var defaultShader:FlxShader = new FlxShader();

	public function new(field:PlayField, modManager:ModManager)
	{
		super(0, 0);
		this.field = field;
		this.modManager = modManager;
		this.holdSubdivisions = Std.int(ClientPrefs.holdSubdivs);
	}
	override public function getNotefield() {return this;}

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

	final perspectiveArrDontUse:Array<String> = ['__perspective'];

	/**
	 * The position of every receptor for a given frame.
	 */
	public var strumPositions:Array<Vector3> = [];
	
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

	////
	static function drawQueueSort(Obj1:RenderObject, Obj2:RenderObject)
	{
		return FlxSort.byValues(FlxSort.ASCENDING, Obj1.zIndex, Obj2.zIndex);
	}

	// does all the drawing logic, best not to touch unless you know what youre doing
	override function preDraw()
	{
		drawQueue = [];
		if (field == null) return;
		if (!active || !exists) return;
		
		curDecStep = Conductor.curDecStep;
		curDecBeat = Conductor.curDecBeat;

		zoom = modManager.getFieldZoom(baseZoom, curDecBeat, (Conductor.songPosition - ClientPrefs.noteOffset), modNumber, this);
		var notePos:Map<Note, Vector3> = [];
		// can probably do orient a better way eventually buti m fuckinbg lazy rn
		var nextNotePos:Map<Note, Vector3> = []; // for orient
		var taps:Array<Note> = [];
		var holds:Array<Note> = [];

		inline function getModValue(name:String):Null<Float>
			return modManager.get(name)?.getValue(modNumber);

		var lookAheadTime:Float = getModValue("lookAheadTime");
		var alwaysDraw:Bool;
		var drawDist:Float;
		
		if ((getModValue("alwaysDraw") ?? 0) != 0) {
			// Force notes to draw, no matter the draw distance
			alwaysDraw = true;
			drawDist = Math.POSITIVE_INFINITY;
		}
		else{
			alwaysDraw = false;
			drawDist = getModValue("drawDistance") ?? FlxG.height;
			var dddm = getModValue("disableDrawDistMult");
			if (dddm == null || dddm == 0)
				drawDist *= drawDistMod;
		}		
		
		for (daNote in field.spawnedNotes)
		{
			if (!daNote.alive || !daNote.visible)
				continue;

			if (songSpeed != 0)
			{
				if (daNote.wasGoodHit && daNote.sustainLength > 0)
					continue;
				
				var speed:Float = modManager.getNoteSpeed(daNote, modNumber, songSpeed);
				var visPos:Float = (daNote.visualTime - Conductor.visualPosition) * speed;
				if (visPos > drawDist)
					continue; // don't draw

				if (!daNote.copyX && !daNote.copyY) {
					daNote.vec3Cache.setTo(
						daNote.x,
						daNote.y,
						0
					);
					notePos.set(daNote, daNote.vec3Cache);
					taps.push(daNote);
					continue;
				}
				
				else if (daNote.isSustainNote)
				{
					holds.push(daNote);
				}
				else
				{
					var diff = Conductor.songPosition - daNote.strumTime;
					var pos = modManager.getPos(visPos, diff, curDecBeat, daNote.column, modNumber, daNote, this, perspectiveArrDontUse,
						daNote.vec3Cache); // perspectiveDONTUSE is excluded because its code is done in the modifyVert function
					if (!daNote.copyX)
						pos.x = daNote.x;

					if (!daNote.copyY)
						pos.y = daNote.y;

					if (modManager.getValue("orient", modNumber) != 0){
						var nextPos = modManager.getPos(visPos + lookAheadTime, diff + lookAheadTime, curDecBeat, daNote.column, modNumber, daNote, this, perspectiveArrDontUse); // perspectiveDONTUSE is excluded because its code is done in the modifyVert function
						nextNotePos.set(daNote, nextPos);
					}
					
					notePos.set(daNote, pos);
					taps.push(daNote);
				}
			}
		}

		var lookupMap = new haxe.ds.ObjectMap<Dynamic, RenderObject>();

		// draw the receptors
		for (obj in field.strumNotes)
		{
			if (!obj.alive || !obj.visible)
				continue;
			// maybe add copyX and copyT to strums too???????

			var pos = modManager.getPos(0, 0, curDecBeat, obj.column, modNumber, obj, this, perspectiveArrDontUse, obj.vec3Cache);
			strumPositions[obj.column] = pos;
			var object = drawNote(obj, pos);
			if (object == null)
				continue;

			lookupMap.set(obj, object);
			drawQueue.push(object);
		}

		// draw tap notes
		for (note in taps)
		{
			var pos = notePos.get(note);
			var object = drawNote(note, pos, nextNotePos.get(note));
			if (object == null)
				continue;
			lookupMap.set(note, object);
			drawQueue.push(object);
		}

		// draw hold notes (credit to 4mbr0s3 2)
		for (note in holds)
		{
			var object = drawHold(note);
			if (object == null)
				continue;
			
			if (tryForceHoldsBehind)
				object.zIndex -= 1;

			lookupMap.set(note, object);
			drawQueue.push(object);
		}

		// draw notesplashes
		for (obj in field.grpNoteSplashes.members)
		{
			if (!obj.alive || !obj.visible)
				continue;

			var pos = modManager.getPos(0, 0, curDecBeat, obj.column, modNumber, obj, this, perspectiveArrDontUse, obj.vec3Cache);
			var object = drawNote(obj, pos);
			if (object == null)
				continue;
			object.zIndex += 0.5;
			lookupMap.set(obj, object);
			drawQueue.push(object);
		}

		// draw strumattachments
		for (obj in field.strumAttachments.members)
		{
			if (!obj.alive || !obj.visible)
				continue;
			var pos = modManager.getPos(0, 0, curDecBeat, obj.column, modNumber, obj, this, perspectiveArrDontUse, obj.vec3Cache);
			var object = drawNote(obj, pos);
			if (object == null)
				continue;
			object.zIndex += 0.5;
			lookupMap.set(obj, object);
			drawQueue.push(object);
		}

		if ((FlxG.state is PlayState))
			PlayState.instance.callOnHScripts("notefieldPreDraw", [this],
				["drawQueue" => drawQueue, "lookupMap" => lookupMap]); // lets you do custom rendering in scripts, if needed
		// one example would be reimplementing Die Batsards' original bullet mechanic
		// if you need an example on how this all works just look at the tap note drawing portion

		// No longer required since its done in the manager
		//drawQueue.sort(drawQueueSort);

		if (zoom != 1) {
			var centerX = FlxG.width * 0.5;
			var centerY = FlxG.height * 0.5;

			for (object in drawQueue) {
				var vertices = object.vertices;
				var currentVertexPosition:Int = 0;

				while (currentVertexPosition < vertices.length)
				{
					vertices[currentVertexPosition] = (vertices[currentVertexPosition] - centerX) * zoom + centerX;
					++currentVertexPosition;
					vertices[currentVertexPosition] = (vertices[currentVertexPosition] - centerY) * zoom + centerY;
					++currentVertexPosition;
				}
				object.vertices = vertices; // i dont think this is needed but its like, JUUUSST incase
			}
		}

	}

	var matrix:FlxMatrix = new FlxMatrix();
	
	override function draw(){
		// Drawing is handled by NotefieldManager now (maybe rename to NotefieldRenderer?)
		return;
	}

	function getPoints(hold:Note, ?wid:Float, speed:Float, vDiff:Float, diff:Float, spiralHolds:Bool = false, ?lookAhead:Float = 1):Array<Vector3>
	{ // stolen from schmovin'
		if (hold.frame == null)
			return [Vector3.ZERO, Vector3.ZERO];

		if (wid == null)
			wid = hold.frame.frame.width * hold.scale.x;

		var simpleDraw = !hold.copyX && !hold.copyY;

		var p1 = simpleDraw ? hold.vec3Cache : modManager.getPos(-vDiff * speed, diff, curDecBeat, hold.column, modNumber, hold, this, [], hold.vec3Cache);
		
		if(!hold.copyX)
			p1.x = hold.x;

		if(!hold.copyY)
			p1.y = hold.y;
		
		if (simpleDraw)
			p1.z = 0;

		var z:Float = p1.z;
		p1.z = 0.0;

		wid /= 2.0;
		var quad0 = new Vector3(-wid);
		var quad1 = new Vector3(wid);
		var scale:Float = (z!=0.0) ? (1.0 / z) : 1.0;

		if (!spiralHolds || simpleDraw) {
			// less accurate, but higher FPS
			quad0.scaleBy(scale);
			quad1.scaleBy(scale);
			return [p1.add(quad0, quad0), p1.add(quad1, quad1), p1];
		}

		var p2 = modManager.getPos(-(vDiff + lookAhead) * speed, diff + lookAhead, curDecBeat, hold.column, modNumber, hold, this, []);
		p2.z = 0;

		p2.decrementBy(p1);
		p2.normalize();
		var unit = p2;

		var w = (quad0.subtract(quad1, quad0).length / 2) * scale;
		var off1 = new Vector3(unit.y * w, 	-unit.x * w,	0.0);
		var off2 = new Vector3(-off1.x, 	-off1.y,		0.0);

		return [p1.add(off1, off1), p1.add(off2, off2), p1];
	}

	var crotchet:Float = Conductor.getCrotchetAtTime(0.0) / 4.0;
	function drawHold(hold:Note, ?prevAlpha:Float, ?prevGlow:Float):Null<RenderObject>
	{
		if (hold.animation.curAnim == null || hold.scale == null || hold.frame == null)
			return null;

		var render:Bool = false;
		for (camera in cameras) {
			if (camera.alpha > 0 && camera.visible) {
				render = true;
				break;
			}
		}
		if (!render)
			return null;

		var simpleDraw = !hold.copyX && !hold.copyY;
		// TODO: make simpleDraw reduce the amount of subdivisions used by the hold

		var vertices = new Vector<Float>(8 * holdSubdivisions, true);
		var uvData = new Vector<Float>(8 * holdSubdivisions, true);
		var alphas:Array<Float> = [];
		var glows:Array<Float> = [];
		var lastMe = null;

		var tWid = hold.frameWidth * hold.scale.x;
		var bWid = (
			if (hold.prevNote != null && hold.prevNote.scale != null && hold.prevNote.isSustainNote)
				hold.prevNote.frameWidth * hold.prevNote.scale.x
			else
				tWid
		);

		
		
		var strumDiff = (Conductor.songPosition - hold.strumTime);
		var visualDiff = (Conductor.visualPosition - hold.visualTime); // TODO: get the start and end visualDiff and interpolate so that changing speeds mid-hold will look better
		var sv = PlayState.instance.getSV(hold.strumTime).speed;


/* 		var basePos = simpleDraw ? hold.vec3Cache : modManager.getPos(visualDiff, strumDiff, curDecBeat, hold.column, modNumber, hold, this,
			perspectiveArrDontUse, hold.vec3Cache);

		// basePos been doing nothing for like 100 years time to mak eit do something
		var zIndex:Float = basePos.z;

		if (!hold.copyX)
			basePos.x = hold.x;

		if (!hold.copyY)
			basePos.y = hold.y;

		if (simpleDraw)
			basePos.z = 0; */
		// ^^ dOESNT WORK!!

		var zIndex:Float = 0;


		var lookAheadTime = modManager.getValue("lookAheadTime", modNumber);
		var useSpiralHolds = modManager.getValue("spiralHolds", modNumber) != 0;


		for (sub in 0...holdSubdivisions)
		{
			var prog = sub / (holdSubdivisions + 1);
			var nextProg = (sub + 1) / (holdSubdivisions + 1);
			var strumSub = (crotchet / holdSubdivisions);
			var strumOff = (strumSub * sub);
			strumSub *= sv;
			strumOff *= sv;
			
			if ((hold.wasGoodHit || hold.parent.wasGoodHit) && !hold.tooLate) {
				var scale:Float = 1 - ((strumDiff + crotchet) / crotchet);
				if (scale <= 0.0) {
					strumSub = 0;
					strumOff = 0;
				}else if (scale < 1) {
					strumSub *= scale;
					strumOff *= scale;
				}
			}

			scalePoint.set(1, 1);

			var speed:Float = modManager.getNoteSpeed(hold, modNumber, songSpeed);
			var info:RenderInfo = {
				alpha: hold.alpha,
				glow: 0,
				scale: scalePoint
			};

			if (hold.copyAlpha)
				info = modManager.getExtraInfo((visualDiff + ((strumOff + strumSub) * 0.45)) * -speed, strumDiff + strumOff + strumSub, curDecBeat, info, hold, modNumber, hold.column);

			var topWidth = scalePoint.x * FlxMath.lerp(tWid, bWid, prog);
			var botWidth = scalePoint.x * FlxMath.lerp(tWid, bWid, nextProg);

			var alphaMult = hold.baseAlpha;

			if (hold.parent.wasGoodHit && hold.holdGlow)
				alphaMult = FlxMath.lerp(0.3, 1, hold.parent.tripProgress);
			
			info.alpha *= FlxMath.lerp(alphaMult, 1, info.glow);

			if(lastMe == null) // first sexment
			{
				var basePos = modManager.getPos(-(visualDiff + ((strumOff + strumSub) * 0.45)) * speed, strumDiff + strumOff + strumSub, curDecBeat, hold.column, modNumber, hold, this,
					perspectiveArrDontUse, hold.vec3Cache);

				zIndex = basePos.z;
			}
			var top = lastMe ?? getPoints(hold, topWidth, speed, (visualDiff + (strumOff * 0.45)), strumDiff + strumOff, useSpiralHolds, lookAheadTime);
			var bot = getPoints(hold, botWidth, speed, (visualDiff + ((strumOff + strumSub) * 0.45)), strumDiff + strumOff + strumSub, useSpiralHolds, lookAheadTime);
			if (!hold.copyY) {
				var a:Float = (crotchet + 1) * 0.45 * speed;
				
				if (lastMe == null) {
					var a:Float = FlxMath.lerp(0, a, prog);
					top[0].y -= a;
					top[1].y -= a;
				}

				var a:Float = FlxMath.lerp(0, a, nextProg);
				bot[0].y -= a;
				bot[1].y -= a;
			}
			lastMe = bot;

			for (_ in 0...2) {
				alphas.push(info.alpha);
				glows.push(info.glow);
			}

			var ox = hold.offsetX + hold.typeOffsetX;
			top[0].x += ox;
			top[1].x += ox;
			bot[0].x += ox;
			bot[1].x += ox;

			var oy = hold.offsetY + hold.typeOffsetY;
			top[0].y += oy;
			top[1].y += oy;
			bot[0].y += oy;
			bot[1].y += oy;


			var subIndex = sub * 8;
			vertices[subIndex] = top[0].x;
			vertices[subIndex + 1] = top[0].y;
			vertices[subIndex + 2] = top[1].x;
			vertices[subIndex + 3] = top[1].y;
			vertices[subIndex + 4] = bot[0].x;
			vertices[subIndex + 5] = bot[0].y;
			vertices[subIndex + 6] = bot[1].x;
			vertices[subIndex + 7] = bot[1].y;

			appendUV(hold, uvData, false, sub);
		}

		var shader = hold.shader != null ? hold.shader : defaultShader;
		if (shader != hold.shader)
			hold.shader = shader;

		var graphic:FlxGraphic = hold.frame == null ? hold.graphic : hold.frame.parent;

		return {
			graphic: graphic,
			shader: shader,
			alphas: alphas,
			glows: glows,
			uvData: uvData,
			vertices: vertices,
			indices: HOLD_INDICES,
			zIndex: zIndex + hold.zIndex,
			colorSwap: hold.colorSwap,
			objectType: hold.objType,
			antialiasing: hold.antialiasing
		}
	}

	private function appendUV(sprite:FlxSprite, uv:Vector<Float>, flipY:Bool, sub:Int)
	{
		var subIndex = sub * 8;
		var frameRect = sprite.frame.uv;

		if (!flipY)
			sub = (holdSubdivisions - 1) - sub;
		var uvSub = 1.0 / holdSubdivisions;
		var uvOffset = uvSub * sub;

		var top = 0.0;
		var bottom = 0.0;
		switch (sprite.frame.angle) {
			case ANGLE_0:
				var height = frameRect.height - frameRect.y;
				top = frameRect.y + (uvSub + uvOffset) * height;
				bottom = frameRect.y + uvOffset * height;
			case ANGLE_90:
				var width = frameRect.width - frameRect.x;
				top = frameRect.x + (uvSub + uvOffset) * width;
				bottom = frameRect.x + uvOffset * width;
			case ANGLE_270:
				var width = frameRect.x - frameRect.width;
				top = frameRect.width + uvOffset * width;
				bottom = frameRect.width + (uvSub + uvOffset) * width;
		}

		if (flipY)
		{
			var ogTop = top;
			top = bottom;
			bottom = top;
		}

		switch (sprite.frame.angle) {
			case ANGLE_0:
				uv[subIndex] = uv[subIndex + 4] = frameRect.x;
				uv[subIndex + 2] = uv[subIndex + 6] = frameRect.width;
				uv[subIndex + 1] = uv[subIndex + 3] = top;
				uv[subIndex + 5] = uv[subIndex + 7] = bottom;
			case ANGLE_90:
				uv[subIndex] = uv[subIndex + 4] = top;
				uv[subIndex + 2] = uv[subIndex + 6] = bottom;
				uv[subIndex + 1] = uv[subIndex + 3] = frameRect.height;
				uv[subIndex + 5] = uv[subIndex + 7] = frameRect.y;
			case ANGLE_270:
				uv[subIndex] = uv[subIndex + 2] = bottom;
				uv[subIndex + 4] = uv[subIndex + 6] = top;
				uv[subIndex + 1] = uv[subIndex + 5] = frameRect.y;
				uv[subIndex + 3] = uv[subIndex + 7] = frameRect.height;
		}
	}

	private var quad0 = new Vector3(); // top left
	private var quad1 = new Vector3(); // top right
	private var quad2 = new Vector3(); // bottom left
	private var quad3 = new Vector3(); // bottom right
	function drawNote(sprite:NoteObject, pos:Vector3, ?nextPos:Vector3):Null<RenderObject>
	{
		if (!sprite.visible || !sprite.alive)
			return null;

		if (sprite.frame == null)
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

		var isNote = (sprite.objType == NOTE);
		var note:Note = isNote ? cast sprite : null;

		var width = (sprite.frame.angle != FlxFrameAngle.ANGLE_0) ? sprite.frame.frame.height * sprite.scale.x : sprite.frame.frame.width * sprite.scale.x;
		var height = (sprite.frame.angle != FlxFrameAngle.ANGLE_0) ? sprite.frame.frame.width * sprite.scale.y : sprite.frame.frame.height * sprite.scale.y;
		scalePoint.set(1, 1);
		var diff:Float =0;
		var visPos:Float = 0;
		if(isNote) {
			var speed = modManager.getNoteSpeed(note, modNumber, songSpeed);
			diff = Conductor.songPosition - note.strumTime;
			visPos = -((Conductor.visualPosition - note.visualTime) * speed);
		}

		var info:RenderInfo = {
			alpha: sprite.alpha,
			glow: 0,
			scale: scalePoint
		};

		if(!isNote || note.copyAlpha)
			info = modManager.getExtraInfo(visPos, diff, curDecBeat, info, sprite, modNumber, sprite.column);

		var alpha = info.alpha;
		var glow = info.glow;

		final QUAD_SIZE = 4;
		final halfWidth = sprite.frameWidth * sprite.scale.x * 0.5;
		final halfHeight = sprite.frameHeight * sprite.scale.y * 0.5;
		final xOff = sprite.frame.offset.x * sprite.scale.x;
		final yOff = sprite.frame.offset.y * sprite.scale.y;

		quad0.setTo(xOff - halfWidth, 			yOff - halfHeight, 			0); // top left
		quad1.setTo(width + xOff - halfWidth, 	yOff - halfHeight, 			0); // top right
		quad2.setTo(xOff - halfWidth, 			height + yOff - halfHeight,	0); // bottom left
		quad3.setTo(width + xOff - halfWidth, 	height + yOff - halfHeight,	0); // bottom right

		for (idx in 0...QUAD_SIZE)
		{
			var quad = switch(idx) {
				case 0: quad0;
				case 1: quad1;
				case 2: quad2;
				case 3: quad3;
				default: null;
			};
			var angle = sprite.angle;
			var radAngles:Float = 0;

			if (nextPos != null){
				var diffX = nextPos.x - pos.x;
				var diffY = nextPos.y - pos.y;
				var orient = modManager.getValue("orient", modNumber);

				radAngles += Math.atan2(diffY, diffX) * orient;
				var reverse:ReverseModifier = cast modManager.register.get("reverse");
				angle -= 90 * orient * FlxMath.lerp(1, -1, reverse.getReverseValue(sprite.column, modNumber));
			}

			if(isNote)
				angle += note.typeOffsetAngle;
			
			var vert = VectorHelpers.rotateV3(quad, 0, 0, (FlxAngle.TO_RAD * angle) + radAngles, quad);
			vert.x = vert.x + sprite.offsetX;
			vert.y = vert.y + sprite.offsetY;

			if (isNote)
			{
				vert.x = vert.x + note.typeOffsetX;
				vert.y = vert.y + note.typeOffsetY;
			}

			if (isNote && !note.copyVerts){
				// still should have perspective, even if not copying verts!
				// Maybe we should move perspective stuff out of a modifier???
				var mod:Modifier = modManager.register.get("__perspective");
				if (mod != null && mod.isRenderMod())
					vert = mod.modifyVert(curDecBeat, vert, idx, sprite, pos, modNumber, sprite.column, this);
			}else
				vert = modManager.modifyVertex(curDecBeat, vert, idx, sprite, pos, modNumber, sprite.column, this);

			vert.x = vert.x * scalePoint.x;
			vert.y = vert.y * scalePoint.y;

/* 			vert.x *= zoom;
			vert.y *= zoom; */
			if (sprite.flipX)
				vert.x = -vert.x;
			if (sprite.flipY)
				vert.y = -vert.x;
			
			//quad.setTo(vert.x, vert.y, vert.z);
		}

		var frameRect = sprite.frame.uv;

		var vertices = switch (sprite.frame.angle) {
			case ANGLE_0:
				new Vector<Float>(8, false, [
					pos.x + quad0.x, pos.y + quad0.y,
					pos.x + quad1.x, pos.y + quad1.y,
					pos.x + quad2.x, pos.y + quad2.y,
					pos.x + quad3.x, pos.y + quad3.y
				]);
			case ANGLE_90:
				new Vector<Float>(8, false, [
					pos.x + quad1.x, pos.y + quad1.y,
					pos.x + quad3.x, pos.y + quad3.y,
					pos.x + quad0.x, pos.y + quad0.y,
					pos.x + quad2.x, pos.y + quad2.y
				]);
			case ANGLE_270:
				new Vector<Float>(8, false, [
					pos.x + quad2.x, pos.y + quad2.y,
					pos.x + quad0.x, pos.y + quad0.y,
					pos.x + quad3.x, pos.y + quad3.y,
					pos.x + quad1.x, pos.y + quad1.y
				]);
		}
		var uvData = new Vector<Float>(8, false, [
			frameRect.x,		frameRect.y,
			frameRect.width,	frameRect.y,
			frameRect.x,		frameRect.height,
			frameRect.width,	frameRect.height
		]);
		var shader = sprite.shader != null ? sprite.shader : defaultShader;
		if (shader != sprite.shader)
			sprite.shader = shader;

		var graphic:FlxGraphic = sprite.frame == null ? sprite.graphic : sprite.frame.parent;

		final totalTriangles = Std.int(vertices.length / 2);
		var alphas = new FastVector<Float>(totalTriangles);
		var glows = new FastVector<Float>(totalTriangles);
		for (i in 0...totalTriangles)
		{
			alphas[i] = alpha;
			glows[i] = glow;
		}

		return {
			graphic: graphic,
			shader: shader,
			alphas: cast alphas,
			glows: cast glows,
			uvData: uvData,
			vertices: vertices,
			indices: NOTE_INDICES,
			zIndex: pos.z + sprite.zIndex,
			colorSwap: sprite.colorSwap,
			objectType: sprite.objType,
			antialiasing: sprite.antialiasing
		}
	}

	function set_holdSubdivisions(to:Int)
	{
		HOLD_INDICES.length = (to * 6);
		for (sub in 0...to)
		{
			var vertIndex = sub * 4;
			var intIndex = sub * 6;

			HOLD_INDICES[intIndex] = HOLD_INDICES[intIndex + 3] = vertIndex; // LT
			HOLD_INDICES[intIndex + 2] = HOLD_INDICES[intIndex + 5] = vertIndex + 3; // RB
			HOLD_INDICES[intIndex + 1] = vertIndex + 1; // RT
			HOLD_INDICES[intIndex + 4] = vertIndex + 2; // LB
		}
		return holdSubdivisions = to;
	}
}