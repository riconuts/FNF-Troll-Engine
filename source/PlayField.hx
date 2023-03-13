package;

import flixel.math.FlxPoint;
import flixel.math.FlxMath;
import math.Vector3;
import flixel.system.FlxAssets.FlxShader;
import modchart.ModManager;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.group.FlxSpriteGroup;
import lime.math.Vector2;
import lime.math.Vector4;
import openfl.Vector;
import flixel.tweens.FlxEase;
import flixel.util.FlxSort;
import flixel.tweens.FlxTween;
import lime.app.Event;
import flixel.math.FlxAngle;
// attempt 2 of playfield system lol!

/*
PlayField is seperated into 2 classes:

- NoteField
    - This is the rendering component.
    - This can be created seperately from a PlayField to duplicate the notes multiple times, for example.
    - Needs to be linked to a PlayField though, so it can keep track of what notes exist, when notes get hit (to update receptors), etc.

- PlayField
    - This is the gameplay component.
    - This keeps track of notes and updates them
    - This is typically per-player, and can control multiple characters, can be locked up, etc.
    - You can also swap which PlayField a player is actually controlling n all that
*/

typedef NoteCallback = (Note, PlayField) -> Void;
class PlayField extends FlxTypedGroup<FlxBasic>
{
	public var spawnedNotes:Array<Note> = []; // spawned notes
	public var noteQueue:Array<Array<Note>> = [[], [], [], []]; // unspawned notes
	public var strumNotes:Array<StrumNote> = []; // receptors
	public var characters:Array<Character> = []; // characters that sing when field is hit
	public var noteField:NoteField; // renderer
	public var modNumber:Int = 0;
	public var modManager:ModManager;
	public var isPlayer:Bool = false;
	public var inControl:Bool = true;
	public var autoPlayed:Bool = false;
	public var noteHitCallback:NoteCallback;
	public var grpNoteSplashes:FlxTypedGroup<NoteSplash>;

	public var noteMissed:Event<NoteCallback> = new Event<NoteCallback>();
	public var noteRemoved:Event<NoteCallback> = new Event<NoteCallback>();
	public var noteSpawned:Event<NoteCallback> = new Event<NoteCallback>();

    public function new(modMgr:ModManager){
        super();
		this.modManager = modMgr;
		noteField = new NoteField(this, modMgr);
		add(noteField);
		grpNoteSplashes = new FlxTypedGroup<NoteSplash>();
		add(grpNoteSplashes);
		var splash:NoteSplash = new NoteSplash(100, 100, 0);
		grpNoteSplashes.add(splash);
		grpNoteSplashes.visible = false; // so they dont get drawn
		splash.alpha = 0.0;
    }

	public function queue(note:Note){
		if(noteQueue[note.noteData]==null)
			noteQueue[note.noteData] = [];
		
		noteQueue[note.noteData].push(note);
	}

	public function removeNote(daNote:Note){
		daNote.active = false;
		daNote.visible = false;

		noteRemoved.dispatch(daNote, this);

		daNote.kill();
		spawnedNotes.remove(daNote);
		if (noteQueue[daNote.noteData] != null)
			noteQueue[daNote.noteData].remove(daNote);
		remove(daNote);
		daNote.destroy();
	}

	public function spawnNote(note:Note){
		if (noteQueue[note.noteData]!=null)
			noteQueue[note.noteData].remove(note);

		trace("spawned " + note);

		noteSpawned.dispatch(note, this);
		spawnedNotes.push(note);
		note.handleRendering = false;
		note.spawned = true;

		add(note);
	}

	public function input(data:Int){
		var noteList = getTapNotes(data);
		noteList.sort((a, b) -> Std.int(a.strumTime - b.strumTime));
		if (noteList.length > 0)
		{
			var note = noteList[0];
			noteHitCallback(note, this);
			return note;
		}
		return null;
	}
    
	public function generateStrums(){
		for(i in 0...4){
			var babyArrow:StrumNote = new StrumNote(0, 0, i);
		//	babyArrow.scale.scale(scale);
		//	babyArrow.updateHitbox();
			babyArrow.downScroll = ClientPrefs.downScroll;
			add(babyArrow);
			babyArrow.handleRendering = false; // NoteField handles rendering
			strumNotes.push(babyArrow);
			babyArrow.postAddedToGroup();
		}
	}

	public function fadeIn(skip:Bool = false)
	{
		for (data in 0...strumNotes.length)
		{
			var babyArrow:StrumNote = strumNotes[data];
			if (skip)
				babyArrow.alpha = 1;
			else
			{
				babyArrow.alpha = 0;
				var daY = babyArrow.downScroll ? -10 : 10;
				babyArrow.offsetY -= daY;
				FlxTween.tween(babyArrow, {offsetY: babyArrow.offsetY + daY, alpha: 1}, 1, {ease: FlxEase.circOut, startDelay: 0.5 + (0.2 * data)});
			}
		}
	}

	function sortByOrderNote(Obj1:Note, Obj2:Note):Int
	{
		return FlxSort.byValues(FlxSort.ASCENDING, Obj1.zIndex, Obj2.zIndex);
	}

	override public function update(elapsed:Float){
		noteField.modNumber = modNumber;
		noteField.cameras = cameras;

		for(char in characters)
			char.controlled = isPlayer;
		
		var curDecStep:Float = 0;

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
		var curDecBeat = curDecStep / 4;

		for (data => column in noteQueue)
		{
			if (column[0] != null)
			{
				var dataSpawnTime = modManager.get("noteSpawnTime" + data); 
				var noteSpawnTime = (dataSpawnTime != null && dataSpawnTime.getValue(modNumber)>0)?dataSpawnTime:modManager.get("noteSpawnTime");
				var time:Float = noteSpawnTime == null ? 2000 : noteSpawnTime.getValue(modNumber); // no longer averages the spawn times
				while (column.length > 0 && column[0].strumTime - Conductor.songPosition < time)
					spawnNote(column[0]);
			}
		}

		super.update(elapsed);

		for(obj in strumNotes)
			modManager.updateObject(curDecBeat, obj, modNumber);

		//spawnedNotes.sort(sortByOrderNote);

		for (daNote in spawnedNotes)
		{
			if(!daNote.alive){
				spawnedNotes.remove(daNote);
				continue;
			}
			modManager.updateObject(curDecBeat, daNote, modNumber);

			// check for note deletion
			if (daNote.garbage)
			{
				removeNote(daNote);
				continue;
			}
			else
			{
				if (Conductor.songPosition > 350 + daNote.strumTime && daNote.active)
				{
					if (!daNote.ignoreNote && (daNote.tooLate || !daNote.wasGoodHit))
						noteMissed.dispatch(daNote, this);


					removeNote(daNote);
					continue;
				}
			}
		}

		if (inControl && autoPlayed)
		{
			for(i in 0...4){
				var daNote = getNotes(i)[0];
				if(daNote==null)continue;
				if (!daNote.wasGoodHit && !daNote.ignoreNote)
				{
					if (daNote.isSustainNote)
					{
						if (daNote.canBeHit)
							noteHitCallback(daNote, this);
					}
					else
					{
						if (daNote.strumTime <= Conductor.songPosition)
							input(i);
					}
				}
			}
		}
	}

	public function getNotes(dir:Int, ?filter:Note->Bool):Array<Note>
	{
		var collected:Array<Note> = [];
		for (note in spawnedNotes)
		{
			if (note.alive && note.noteData == dir && !note.wasGoodHit && !note.tooLate && note.canBeHit)
			{
				if (filter == null || filter(note))
					collected.push(note);
			}
		}
		return collected;
	}

	function sortByShit(Obj1:Note, Obj2:Note):Int
	{
		return FlxSort.byValues(FlxSort.ASCENDING, Obj1.strumTime, Obj2.strumTime);
	}

	public function getTapNotes(dir:Int):Array<Note>
		return getNotes(dir, (note:Note) -> !note.isSustainNote);

	public function getHoldNotes(dir:Int):Array<Note>
		return getNotes(dir, (note:Note) -> note.isSustainNote);
	
	public function forEachQueuedNote(callback:Note->Void)
	{
		for(column in noteQueue){
			var i:Int = 0;
			var note:Note = null;

			while (i < column.length)
			{
				note = column[i++];

				if (note != null && note.exists && note.alive)
					callback(note);
			}
		}
	}

	public function clearDeadNotes(){
		var dead:Array<Note> = [];
		for(note in spawnedNotes){
			if(!note.alive)
				dead.push(note);
			
		}
		for(column in noteQueue){
			for(note in column){
				if(!note.alive)
					dead.push(note);
			}
			
		}

		for(note in dead)
			removeNote(note);
	}


	override function destroy(){
		noteSpawned.removeAll();
		noteSpawned.cancel();
		noteMissed.removeAll();
		noteMissed.cancel();
		noteRemoved.removeAll();
		noteRemoved.cancel();

		return super.destroy();
	}
}

class Perspective
{
	static var fov = Math.PI / 2;
	static var near = 0;
	static var far = 2;

	static function FastTan(rad:Float) // thanks schmoovin
	{
		return FlxMath.fastSin(rad) / FlxMath.fastCos(rad);
	}

	public static function getVector(curZ:Float, pos:Vector3):Vector3
	{
		var halfOffset = new Vector3(FlxG.width / 2, FlxG.height / 2);
		pos = pos.subtract(halfOffset);
		var oX = pos.x;
		var oY = pos.y;

		// should I be using a matrix?
		// .. nah im sure itll be fine just doing this manually
		// instead of doing a proper perspective projection matrix

		// var aspect = FlxG.width/FlxG.height;
		var aspect = 1;

		var shit = curZ - 1;
		if (shit > 0)
			shit = 0; // thanks schmovin!!

		var ta = FastTan(fov / 2);
		var x = oX  / ta;
		var y = oY / ta;
		var a = (near + far) / (near - far);
		var b = 2 * near * far / (near - far);
		var z = (a * shit + b);
		// trace(shit, curZ, z, x/z, y/z);
		var returnedVector = new Vector3(x / z, y / z, z).add(halfOffset);

		return returnedVector;
	}

}
class NoteField extends FlxObject
{
	public function new(field:PlayField, modManager:ModManager){
        super(0, 0);
        this.field = field;
		this.modManager = modManager;
    }

    /*
    * The ID used to determine how you apply modifiers to the notes
    * For example, you can have multiple notefields sharing 1 set of mods by giving them all the same modNumber
    */
    public var modNumber:Int = 0;

    /*
    * The PlayField used to determine the notes to render
	* Required!
    */
	public var field:PlayField;

	/*
	* The ModManager to be used to get modifier positions, etc
	* Required!
	*/
	public var modManager:ModManager;

	/*
	* The song's scroll speed. Can be messed with to give different fields different speeds, etc.
	*/
	public var songSpeed:Float = 1.6;
	
	var curDecStep:Float = 0;
	var curDecBeat:Float = 0;

    override function draw(){
		if((FlxG.state is MusicBeatState)){
			var state:MusicBeatState = cast FlxG.state;
			@:privateAccess
			curDecStep = state.curDecStep;
		}else{
			var lastChange = Conductor.getBPMFromSeconds(Conductor.songPosition);
			var shit = ((Conductor.songPosition - ClientPrefs.noteOffset) - lastChange.songTime) / lastChange.stepCrochet;
			curDecStep = lastChange.stepTime + shit;
		}
		curDecBeat = curDecStep / 4;


		for (obj in field.strumNotes){
			var pos = modManager.getPos(0, 0, 0, curDecBeat, obj.noteData, modNumber, obj, [], obj.vec3Cache);
			drawNote(obj, pos);
		}

		for (obj in field.grpNoteSplashes.members){
			if(!obj.alive)continue;
			var pos = modManager.getPos(0, 0, 0, curDecBeat, obj.noteData, modNumber, obj, [], obj.vec3Cache);
			pos.x = pos.x - Note.swagWidth * 0.95;
			pos.y = pos.y - Note.swagWidth;
			drawNote(obj, pos);
		}

		var notePos:Map<Note, Vector3> = [];
		var rendering:Array<Note> = [];
		for (daNote in field.spawnedNotes){
			if(!daNote.alive)continue;
			if (songSpeed != 0)
			{
				var speed = songSpeed * daNote.multSpeed;
				var pos = modManager.getPos(daNote.strumTime, modManager.getVisPos(Conductor.songPosition, daNote.strumTime, speed),
					daNote.strumTime - Conductor.songPosition, curDecBeat, daNote.noteData, modNumber, daNote, [], daNote.vec3Cache);
				if(pos.y > FlxG.height || pos.y < -daNote.frameHeight * daNote.scale.y)
					continue; // shouldnt be rendered
				
				notePos.set(daNote, pos);

				// TODO: rewrite hold rendering to bend n shit a-la schmovin'
/* 				if (daNote.isSustainNote)
				{
					var futureSongPos = Conductor.songPosition + 75;
					var diff = daNote.strumTime - futureSongPos;
					var vDiff = modManager.getVisPos(futureSongPos, daNote.strumTime, speed);

					var nextPos = modManager.getPos(daNote.strumTime, vDiff, diff, Conductor.getStep(futureSongPos) * 0.25, daNote.noteData, modNumber, daNote, [],
						daNote.vec3Cache);
					nextPos.x += daNote.offsetX;
					nextPos.y += daNote.offsetY;
					var diffX = (nextPos.x - pos.x);
					var diffY = (nextPos.y - pos.y);
					var rad = Math.atan2(diffY, diffX);
					var deg = rad * (180 / Math.PI);
					if (deg != 0)
						daNote.mAngle = (deg + 90);
					else
						daNote.mAngle = 0;
				} */

			}
			rendering.push(daNote);
		}

		rendering.sort(function(Obj1:Note, Obj2:Note){
			if(!notePos.exists(Obj1))
				return 1;
			
			if (!notePos.exists(Obj2))
				return -1;

			return FlxSort.byValues(FlxSort.ASCENDING, notePos.get(Obj1).z + Obj1.zIndex, notePos.get(Obj2).z + Obj2.zIndex);
		});
		for(note in rendering)
			drawNote(note, notePos.get(note));
		
		
        super.draw();
    }

	function drawSpritePos(sprite:FlxSprite, pos:Vector3, ?cameras:Array<FlxCamera>, ?width:Float, ?height:Float)
	{
		//if(pos.z<0)pos.z = 1;
		//var m = 1 / pos.z;
		//var newPos = Perspective.getVector(pos.z, pos);
		if(!sprite.visible)return;

		//width *= m;
		//height *= m;
		drawSpriteDirectly(sprite, pos.x, pos.y, cameras, width, height);
	}

	// thanks schmoovin'
	function rotateV3(vec:Vector3, xA:Float, yA:Float, zA:Float):Vector3
	{
		var rotateZ = CoolUtil.rotate(vec.x, vec.y, zA);
		var offZ = new Vector3(rotateZ.x, rotateZ.y, vec.z);

		var rotateX = CoolUtil.rotate(offZ.z, offZ.y, xA);
		var offX = new Vector3(offZ.x, rotateX.y, rotateX.x);

		var rotateY = CoolUtil.rotate(offX.x, offX.z, yA);
		var offY = new Vector3(rotateY.x, offX.y, rotateY.y);

		rotateZ.putWeak();
		rotateX.putWeak();
		rotateY.putWeak();

		return offY;
	}

	function drawNote(sprite:NoteObject, pos:Vector3, ?cameras:Array<FlxCamera>)
	{
		if (!sprite.visible || !sprite.alive)
			return;

		var x:Float = pos.x + sprite.offsetX;
		var y:Float = pos.y + sprite.offsetY;

		if (cameras == null)
			cameras = this.cameras;

		var width = sprite.frameWidth * sprite.scale.x;
		var height = sprite.frameHeight * sprite.scale.y;
		var alpha = sprite.alpha * modManager.getAlpha(curDecBeat, 1, sprite, modNumber, pos, sprite.noteData);

		@:privateAccess 
		{
			if (sprite.checkFlipX())
				width = -width;
			if (sprite.checkFlipY())
				height = -height;
		}

		var quad = [
			new Vector3(-width / 2, -height / 2, 0), // top left
			new Vector3(width / 2, -height / 2, 0), // top right
			new Vector3(-width / 2, height / 2, 0), // bottom left
			new Vector3(width / 2, height / 2, 0) // bottom right
		];

		for (idx => vert in quad)
		{
			var vert = rotateV3(vert, 0, 0, FlxAngle.TO_RAD * sprite.angle);
			vert = modManager.modifyVertex(curDecBeat, vert, idx, sprite, pos, modNumber, sprite.noteData);
			quad[idx] = vert;
		}

		var frameRect = sprite.frame.frame;
		var sourceBitmap = sprite.graphic.bitmap;

		var leftUV = frameRect.left / sourceBitmap.width;
		var rightUV = frameRect.right / sourceBitmap.width;
		var topUV = frameRect.top / sourceBitmap.height;
		var bottomUV = frameRect.bottom / sourceBitmap.height;

		x -= sprite.offset.x;
		y -= sprite.offset.y;

		x += sprite.origin.x;
		y += sprite.origin.y;

		// order should be LT, RT, RB, LT, LB, RB
		// R is right L is left T is top B is bottom
		// order matters! so LT is left, top because they're represented as x, y
		var vertices = new Vector<Float>(12, false, [
			x + quad[0].x, y + quad[0].y,
			x + quad[1].x, y + quad[1].y,
			x + quad[3].x, y + quad[3].y,

			x + quad[0].x, y + quad[0].y,
			x + quad[2].x, y + quad[2].y,
			x + quad[3].x, y + quad[3].y
		]);

		var uvtDat = new Vector<Float>(12, false, [
			 leftUV,    topUV,
			rightUV,    topUV,
			rightUV, bottomUV,

			 leftUV,    topUV,
			 leftUV, bottomUV,
			rightUV, bottomUV,
		]);

		if (sprite.shader == null){
			sprite.shader = new FlxShader();
			trace("fuck");
		}

		if (sprite.shader != null)
		{
			sprite.shader.bitmap.input = sprite.graphic.bitmap;
			sprite.shader.bitmap.filter = sprite.antialiasing ? LINEAR : NEAREST;
			sprite.shader.alpha.value = [alpha];
		}

		for (camera in cameras)
		{
			camera.canvas.graphics.beginShaderFill(sprite.shader);
			camera.canvas.graphics.drawTriangles(vertices, null, uvtDat);
			camera.canvas.graphics.endFill();
		}
	}

	function drawSpriteDirectly(sprite:FlxSprite, ?x:Float, ?y:Float, ?alpha:Float, ?cameras:Array<FlxCamera>, ?width:Float, ?height:Float)
	{
		if (!sprite.visible)
			return;

		if(x == null)
			x = sprite.x;

		if(y == null)
			y = sprite.y;
		
		if (cameras == null)
			cameras = this.cameras;

		if (width == null)
			width = sprite.frameWidth * sprite.scale.x;

		if (height == null)
			height = sprite.frameHeight * sprite.scale.y;

		if(alpha == null)
			alpha = sprite.alpha;

		@:privateAccess{
		if(sprite.checkFlipX())width = -width;
		if(sprite.checkFlipY())height = -height;
		}

		var quad = [
			[-width / 2, -height / 2], // top left
			[width / 2, -height / 2], // top right
			[-width / 2, height / 2], // bottom left
			[width / 2, height / 2] // bottom right
		];


		for (idx => side in quad)
		{
			var vert = rotateV3(new Vector3(side[0], side[1], 0), 0, 0, FlxAngle.TO_RAD * sprite.angle);
			side[0] = vert.x;
			side[1] = vert.y;
		}


		var frameRect = sprite.frame.frame;
		var sourceBitmap = sprite.graphic.bitmap;

		var leftUV = frameRect.left / sourceBitmap.width;
		var rightUV = frameRect.right / sourceBitmap.width;
		var topUV = frameRect.top / sourceBitmap.height;
		var bottomUV = frameRect.bottom / sourceBitmap.height;

		x -= sprite.offset.x;
		y -= sprite.offset.y;

		x += sprite.origin.x;
		y += sprite.origin.y;

		// order should be LT, RT, RB, LT, LB, RB
		// R is right L is left T is top B is bottom
		// order matters! so LT is left, top because they're represented as x, y
		var vertices = new Vector<Float>(12, false, [
			x + quad[0][0], y + quad[0][1],
			x + quad[1][0], y + quad[1][1],
			x + quad[3][0], y + quad[3][1],

			x + quad[0][0], y + quad[0][1],
			x + quad[2][0], y + quad[2][1],
			x + quad[3][0], y + quad[3][1]
		]);


		var uvtDat = new Vector<Float>(12, false, [
			 leftUV,    topUV,
			rightUV,    topUV,
			rightUV, bottomUV,

			 leftUV,    topUV,
			 leftUV, bottomUV,
			rightUV, bottomUV,
		]);

		
		if(sprite.shader==null)
			sprite.shader = new FlxShader();
		
		if(sprite.shader!=null){
			sprite.shader.bitmap.input = sprite.graphic.bitmap;
			sprite.shader.bitmap.filter = sprite.antialiasing ? LINEAR : NEAREST;
			sprite.shader.alpha.value = [alpha];
		}

		for (camera in cameras)
		{
			camera.canvas.graphics.beginShaderFill(sprite.shader);
			camera.canvas.graphics.drawTriangles(vertices, null, uvtDat);
			camera.canvas.graphics.endFill();
		}
	}

}