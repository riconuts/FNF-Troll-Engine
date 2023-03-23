package;
import flixel.util.FlxColor;
import openfl.geom.Vector3D;
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
using StringTools;
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
	public var autoPlayed(default, set):Bool = false;
	function set_autoPlayed(aP:Bool){
		for (idx in 0...keysPressed.length)
			keysPressed[idx] = false;
		
		for(obj in strumNotes){
			obj.playAnim("static");
			obj.resetAnim = 0;
		}
		return autoPlayed = aP;
	}
	public var noteHitCallback:NoteCallback;
	public var grpNoteSplashes:FlxTypedGroup<NoteSplash>;
	public var strumAttachments:FlxTypedGroup<NoteObject>;

	public var noteMissed:Event<NoteCallback> = new Event<NoteCallback>();
	public var noteRemoved:Event<NoteCallback> = new Event<NoteCallback>();
	public var noteSpawned:Event<NoteCallback> = new Event<NoteCallback>();

	public var keysPressed:Array<Bool> = [false,false,false,false];

    public function new(modMgr:ModManager){
        super();
		this.modManager = modMgr;

		grpNoteSplashes = new FlxTypedGroup<NoteSplash>();
		add(grpNoteSplashes);

		strumAttachments = new FlxTypedGroup<NoteObject>();
		strumAttachments.visible = false;
		add(strumAttachments);

		var splash:NoteSplash = new NoteSplash(100, 100, 0);
		splash.handleRendering = false;
		grpNoteSplashes.add(splash);
		grpNoteSplashes.visible = false; // so they dont get drawn
		splash.alpha = 0.0;

		////
		noteField = new NoteField(this, modMgr);
		add(noteField);

		// idk what haxeflixel does to regenerate the frames
		// SO! this will be how we do it
		// lil guy will sit here and regenerate the frames automatically
		// idk why this seems to work but it does	
		// TODO: figure out WHY this works
		var retard:StrumNote = new StrumNote(400, 400, 0);
		retard.playAnim("static");
		retard.alpha = 1;
		retard.visible = true;
		retard.scale.set(0.002, 0.002);
		retard.handleRendering = true;
		retard.updateHitbox();
		retard.x = 400;
		retard.y = 400;
		@:privateAccess
		retard.draw();
		add(retard);
     }

	public function queue(note:Note){
		if(noteQueue[note.noteData]==null)
			noteQueue[note.noteData] = [];
		noteQueue[note.noteData].sort((a, b) -> Std.int(a.strumTime - b.strumTime));
		
		noteQueue[note.noteData].push(note);
	}

	public function unqueue(note:Note)
	{
		if (noteQueue[note.noteData] == null)
			noteQueue[note.noteData] = [];
		noteQueue[note.noteData].sort((a, b) -> Std.int(a.strumTime - b.strumTime));
		noteQueue[note.noteData].remove(note);
	}


	public function removeNote(daNote:Note){
		daNote.active = false;
		daNote.visible = false;

		noteRemoved.dispatch(daNote, this);

		daNote.kill();
		spawnedNotes.remove(daNote);
		if (noteQueue[daNote.noteData] != null)
			noteQueue[daNote.noteData].remove(daNote);

		if(daNote.tail.length > 0)
			for(tail in daNote.tail)
				removeNote(tail);
		

		if (daNote.parent != null && daNote.parent.tail.contains(daNote))
			daNote.parent.tail.remove(daNote);

		if (daNote.parent != null && daNote.parent.unhitTail.contains(daNote))
			daNote.parent.unhitTail.remove(daNote);

		noteQueue[daNote.noteData].sort((a, b) -> Std.int(a.strumTime - b.strumTime));
		remove(daNote);
		daNote.destroy();
	}

	public function spawnNote(note:Note){
		if (noteQueue[note.noteData]!=null)
			noteQueue[note.noteData].remove(note);
		noteQueue[note.noteData].sort((a, b) -> Std.int(a.strumTime - b.strumTime));

		noteSpawned.dispatch(note, this);
		spawnedNotes.push(note);
		note.handleRendering = false;
		note.spawned = true;

		insert(0, note);
	}

	public function getAllNotes(?dir:Int){
		var arr:Array<Note> = [];
		if(dir==null){
			for(queue in noteQueue){
				for(note in queue)
					arr.push(note);
				
			}
		}else{
			for (note in noteQueue[dir])
				arr.push(note);
		}
		for(note in spawnedNotes)
			arr.push(note);
		return arr;
	}
	
	public function hasNote(note:Note){

		return spawnedNotes.contains(note) || noteQueue[note.noteData]!=null && noteQueue[note.noteData].contains(note);
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
			babyArrow.alpha = 0;
			//add(babyArrow);
			insert(0, babyArrow);
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
		noteField.active = true;

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

		var garbage:Array<Note> = [];
		for (daNote in spawnedNotes)
		{
			if(!daNote.alive){
				spawnedNotes.remove(daNote);
				continue;
			}
			modManager.updateObject(curDecBeat, daNote, modNumber);

			// check for hold inputs
			if(!daNote.isSustainNote){
				if(daNote.holdingTime < daNote.sustainLength && inControl && !daNote.blockHit){
					if(!daNote.tooLate && daNote.wasGoodHit){
						var isHeld = autoPlayed || keysPressed[daNote.noteData];
						//if(daNote.isRoll)isHeld = false; // roll logic is done on press
						// TODO: write that logic tho
						var receptor = strumNotes[daNote.noteData];
						
						// should i do this??? idfk lol
						if(isHeld && receptor.animation.curAnim.name!="confirm")
							receptor.playAnim("confirm", true);

						daNote.holdingTime = Conductor.songPosition - daNote.strumTime;
						var regrabTime = daNote.isRoll?0.5:0.35;
						if(isHeld)
							daNote.tripTimer = 1;
						else
							daNote.tripTimer -= elapsed / regrabTime; // TODO: regrab time multiplier in options

						if(daNote.tripTimer <= 0){
							daNote.tripTimer = 0;
							daNote.tooLate=true;
							daNote.wasGoodHit=false;
							for(tail in daNote.tail){
								if(!tail.wasGoodHit){
									daNote.causedMiss = true;
									if (!daNote.ignoreNote)
										noteMissed.dispatch(daNote, this);
									continue;
									
								}
							}
						}else{
							for (tail in daNote.unhitTail)
							{
								if ((tail.strumTime - 25) <= Conductor.songPosition && !tail.wasGoodHit && !tail.tooLate){
									noteHitCallback(tail, this);
								}
							}

							if (daNote.holdingTime >= daNote.sustainLength)
							{
								trace("finished hold / roll successfully");
								daNote.holdingTime = daNote.sustainLength;
								
								if (!isHeld)
									receptor.playAnim("static", true);
							}

						}
					}
				}
			}
			// check for note deletion
			if (daNote.garbage)
			{
				//removeNote(daNote);
				garbage.push(daNote);
				continue;
			}
			else
			{

				if (daNote.tooLate && daNote.active && !daNote.causedMiss && !daNote.isSustainNote)
				{
					daNote.causedMiss = true;
					if (!daNote.ignoreNote && (daNote.tooLate || !daNote.wasGoodHit))
						noteMissed.dispatch(daNote, this);
				} 

				if((
					(daNote.holdingTime>=daNote.sustainLength || daNote.unhitTail.length==0 ) && daNote.sustainLength>0 ||
					daNote.isSustainNote && daNote.strumTime - Conductor.songPosition < -350 ||
					!daNote.isSustainNote && (daNote.sustainLength==0 || daNote.tooLate) && daNote.strumTime - Conductor.songPosition < -(200 + daNote.hitbox)) && (daNote.tooLate || daNote.wasGoodHit))
				{
					garbage.push(daNote);
				}
				
			}
		}

		for(note in garbage){
			removeNote(note);
		}

		if (inControl && autoPlayed)
		{
			for(i in 0...4){
				for (daNote in getNotes(i, (note:Note) -> !note.ignoreNote && !note.hitCausesMiss)){
					if (daNote.isSustainNote)
					{
						if (daNote.canBeHit)
							noteHitCallback(daNote, this);
					}
					else
					{
						if (daNote.strumTime <= Conductor.songPosition)
							noteHitCallback(daNote, this);
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
	var holdSubdivisions:Int = ClientPrefs.holdSubdivs + 1;
	var smoothHolds = true; //ClientPrefs.coolHolds;
	var optimizeHolds = ClientPrefs.optimizeHolds;

	public function new(field:PlayField, modManager:ModManager){
        super(0, 0);
        this.field = field;
		this.modManager = modManager;
    }

	/*
	* The Draw Distance Modifier
	* Multiplied by the draw distance to determine at what time a note will start being drawn
	* Set to ClientPrefs.drawDistanceModifier by default, which is an option to let you change the draw distance.
	* Best not to touch this, as you can set the drawDistance modifier to set the draw distance of a notefield.
	*/
	public var drawDistMod:Float = ClientPrefs.drawDistanceModifier;

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
		if(!visible)return; // dont draw if visible = false
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

		var notePos:Map<Note, Vector3> = [];
		var taps:Array<Note> = [];
		var holds:Array<Note> = [];
		var drawMod = modManager.get("drawDistance");
		var drawDist = drawMod==null?720:drawMod.getValue(modNumber); 
		drawDist *= drawDistMod;
		for (daNote in field.spawnedNotes){
			if(!daNote.alive)continue;

			if (songSpeed != 0)
			{
				var speed = songSpeed * daNote.multSpeed * modManager.getValue("xmod", modNumber);
				var visPos = modManager.getVisPos(Conductor.songPosition, daNote.strumTime , speed);
				if (visPos > drawDist)continue;
				var diff = daNote.strumTime - Conductor.songPosition;
				if(daNote.wasGoodHit && daNote.tail.length > 0 && daNote.unhitTail.length > 0){
					diff = 0;
					visPos = 0;
					continue; // stops it from drawing lol
				}
				if (daNote.isSustainNote){
					if (!smoothHolds){
						var pos = modManager.getPos(visPos, diff, curDecBeat, daNote.noteData,
							modNumber, daNote, ['perspectiveDONTUSE'],
							daNote.vec3Cache);
						notePos.set(daNote, pos);
					}
					holds.push(daNote);
				}else{
					var pos = modManager.getPos(visPos, diff, curDecBeat, daNote.noteData, modNumber,
						daNote, ['perspectiveDONTUSE'], daNote.vec3Cache); // perspectiveDONTUSE is excluded because its code is done in the modifyVert function
							// but the pos is still used by cool holds (For now? I'd like to make them use modified verts too lol)
					notePos.set(daNote, pos);
					taps.push(daNote);
				}
			}

		}

		taps.sort(function(Obj1:Note, Obj2:Note){
			if(!notePos.exists(Obj1))
				return 1;
			
			if (!notePos.exists(Obj2))
				return -1;

			return FlxSort.byValues(FlxSort.ASCENDING, notePos.get(Obj1).z + Obj1.zIndex, notePos.get(Obj2).z + Obj2.zIndex);
		});
		if (!smoothHolds){
			holds.sort(function(Obj1:Note, Obj2:Note)
			{
				if (!notePos.exists(Obj1))
					return 1;

				if (!notePos.exists(Obj2))
					return -1;

				return FlxSort.byValues(FlxSort.ASCENDING, notePos.get(Obj1).z + Obj1.zIndex, notePos.get(Obj2).z + Obj2.zIndex);
			});
		}


		// TODO: somehow determine the render order based on z axis for everything
		

		for (obj in field.strumNotes)
		{
			if (!obj.alive || !obj.visible)
				continue;
			var pos = modManager.getPos(0, 0, curDecBeat, obj.noteData, modNumber, obj, ['perspectiveDONTUSE'], obj.vec3Cache);
			drawNote(obj, pos);
		}

		for (note in holds)
		{
			if (!note.alive || !note.visible)
				continue;
			if (smoothHolds)
				drawHold(note);
		}

		for (note in taps){
			if (!note.alive || !note.visible)
				continue;
			drawNote(note, notePos.get(note));
		}

		for (obj in field.grpNoteSplashes.members)
		{
			if (!obj.alive || !obj.visible)
				continue;
			var pos = modManager.getPos(0, 0, curDecBeat, obj.noteData, modNumber, obj, ['perspectiveDONTUSE'], obj.vec3Cache);
			drawNote(obj, pos);
		}
		
		for (obj in field.strumAttachments.members)
		{
			if(obj==null)continue;
			if (!obj.alive || !obj.visible)
				continue;
			var pos = modManager.getPos(0, 0, curDecBeat, obj.noteData, modNumber, obj, ['perspectiveDONTUSE']);
			drawNote(obj, pos);
		}

        super.draw();
    }

	function getPoints(hold:Note, ?wid:Float, ?diff:Float){ // stolen from schmovin'
		var speed = songSpeed * hold.multSpeed * modManager.getValue("xmod", modNumber);
		if (wid == null)
			wid = hold.frameWidth * hold.scale.x;
		var p1 = modManager.getPos(modManager.getVisPosD(diff, speed), diff, curDecBeat, hold.noteData, modNumber, hold, []);
		var z:Float = p1.z;
		p1.z = 0;
		var quad = [
			new Vector3((-wid / 2)),
			new Vector3((wid / 2))
		];
		var scale:Float = 1;
		if (z != 0)
			scale = z;

		if(optimizeHolds){
			// less accurate, but higher FPS
			quad[0].scaleBy(1 / scale);
			quad[1].scaleBy(1 / scale);
			return [p1.add(quad[0]), p1.add(quad[1]), p1];
		}

		var p2 = modManager.getPos(modManager.getVisPosD(diff + 1, speed), diff + 1, curDecBeat, hold.noteData, modNumber, hold, []);
		p2.z = 0;
		var unit = p2.subtract(p1);
		unit.normalize();

		var w = (quad[0].subtract(quad[1]).length / 2) / scale;

		var off1 = new Vector3(unit.y, -unit.x);
		var off2 = new Vector3(-unit.y, unit.x);
		off1.scaleBy(w);
		off2.scaleBy(w);
		return [p1.add(off1), p1.add(off2), p1];
	}
	
	function drawHold(hold:Note, ?cameras:Array<FlxCamera>){
		if(hold.animation.curAnim==null)return;
		if(hold.scale==null)return; 
		if(cameras==null)cameras = this.cameras;
		
		var verts = [];
		var uv = [];
		
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
			return;
		
		var alpha = hold.alpha * modManager.getAlpha(curDecBeat, 1, hold, modNumber, hold.noteData);
		if(alpha==0)return;

		var lastMe = null;

		var tWid = hold.frameWidth * hold.scale.x;
		var bWid = (function(){
			if(hold.prevNote != null && hold.prevNote.scale!=null && hold.prevNote.isSustainNote)
				return hold.prevNote.frameWidth * hold.prevNote.scale.x;
			else
				return tWid;
		})();

		var speed = songSpeed * hold.multSpeed * modManager.getValue("xmod", modNumber);
		var crotchet = Conductor.getCrotchetAtTime(0) / 4;
		var basePos = modManager.getPos(modManager.getVisPosD(0, speed), 0, curDecBeat, hold.noteData, modNumber, hold, ['perspectiveDONTUSE']);
		// i have no other idea on how to fix the clipping being retarded
		// i'd like a better solution but this is best i've got atm
		var clipOffset = CoolUtil.scale(basePos.y, 50, FlxG.height - 150, crotchet, -crotchet);
		var strumDiff = (Conductor.songPosition - hold.strumTime) - clipOffset;

		for(sub in 0...holdSubdivisions){
			var prog = sub / (holdSubdivisions+1);
			var nextProg = (sub + 1) / (holdSubdivisions + 1);
			var strumSub = crotchet / holdSubdivisions;
			var strumOff = (strumSub * sub);
			var scale:Float = 1;
			var fuck = strumDiff + (clipOffset/2);

			if((hold.wasGoodHit || hold.parent.wasGoodHit) && !hold.tooLate){
				scale = 1 - ((fuck + crotchet) / crotchet);
				if(scale<0)scale=0;
				if(scale>1)scale=1;
				strumSub *= scale;
				strumOff *= scale;
			}
			
			var topWidth = FlxMath.lerp(tWid, bWid, prog);
			var botWidth = FlxMath.lerp(tWid, bWid, nextProg);

			var top = lastMe == null ? getPoints(hold, topWidth, strumDiff + strumOff) : lastMe;
			var bot = getPoints(hold, botWidth, strumDiff + strumOff + strumSub);
			for(vert in bot)
				vert.x += (hold.origin.x + hold.offsetX - hold.offset.x);
			
			
			if (lastMe==null){
				for (vert in top)
					vert.x += (hold.origin.x + hold.offsetX - hold.offset.x);
				
			}
			lastMe = bot;

			var quad:Array<Vector3> = [
				top[0],
				top[1],
				bot[0],
				bot[1]
			];



			verts = verts.concat([
				quad[0].x, quad[0].y,
				quad[1].x, quad[1].y,
				quad[3].x, quad[3].y,

				quad[0].x, quad[0].y,
				quad[2].x, quad[2].y,
				quad[3].x, quad[3].y
			]);
			uv = uv.concat(getUV(hold, false, sub));
		}
		if (verts.length>0){
			var vertices = new Vector<Float>(verts.length, false, cast verts);
			var uvData = new Vector<Float>(uv.length, false, uv);

			var shader = hold.shader != null ? hold.shader : hold.graphic.shader;

			shader.bitmap.input = hold.graphic.bitmap;
			shader.bitmap.filter = hold.antialiasing ? LINEAR : NEAREST;

			for (camera in cameras)
			{
				if (camera.alpha == 0)
					continue;
				shader.alpha.value = [alpha * camera.alpha];
				camera.canvas.graphics.beginShaderFill(shader);
				camera.canvas.graphics.drawTriangles(vertices, null, uvData);
				camera.canvas.graphics.endFill();
			}
			shader.alpha.value = [alpha];
		}
	}

	private function getUV(sprite:FlxSprite, flipY:Bool, sub:Int)
	{
		// i cant be bothered
		// code by 4mbr0s3 2 (Schmovin')
		var leftX = sprite.frame.frame.left / sprite.graphic.bitmap.width;
		var topY = sprite.frame.frame.top / sprite.graphic.bitmap.height;
		var rightX = sprite.frame.frame.right / sprite.graphic.bitmap.width;
		var height = sprite.frame.frame.height / sprite.graphic.bitmap.height;

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
		

		if (cameras == null)
			cameras = this.cameras;

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
			return;

		var width = sprite.frameWidth * sprite.scale.x;
		var height = sprite.frameHeight * sprite.scale.y;
		var alpha = sprite.alpha * modManager.getAlpha(curDecBeat, 1, sprite, modNumber, sprite.noteData);
		if(alpha==0)return;
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
			vert.x += sprite.origin.x;
			vert.y += sprite.origin.y;

			quad[idx] = vert;

		}
		

		pos.x += sprite.offsetX;
		pos.y += sprite.offsetY;

		pos.x -= sprite.offset.x;
		pos.y -= sprite.offset.y;



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
			pos.x + quad[0].x, pos.y + quad[0].y,
			pos.x + quad[1].x, pos.y + quad[1].y,
			pos.x + quad[3].x, pos.y + quad[3].y,

			pos.x + quad[0].x, pos.y + quad[0].y,
			pos.x + quad[2].x, pos.y + quad[2].y,
			pos.x + quad[3].x, pos.y + quad[3].y
		]);

		var uvtDat = new Vector<Float>(12, false, [
			 leftUV,    topUV,
			rightUV,    topUV,
			rightUV, bottomUV,

			 leftUV,    topUV,
			 leftUV, bottomUV,
			rightUV, bottomUV,
		]);

		var shader = sprite.shader != null ? sprite.shader : sprite.graphic.shader;

		shader.bitmap.input = sprite.graphic.bitmap;
		shader.bitmap.filter = sprite.antialiasing ? LINEAR : NEAREST;

		for (camera in cameras)
		{
			if(camera.alpha == 0)continue;
			shader.alpha.value = [alpha * camera.alpha];
			camera.canvas.graphics.beginShaderFill(shader);
			camera.canvas.graphics.drawTriangles(vertices, null, uvtDat);
			camera.canvas.graphics.endFill();
		}
		shader.alpha.value = [alpha];
		
	}

}