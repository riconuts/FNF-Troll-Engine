package;
import JudgmentManager.Judgment;
import openfl.display.Shader;
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
import PlayState.Wife3;

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

/*
	If you use this code, please credit me (Nebula) and 4mbr0s3 2
	Or ATLEAST credit 4mbr0s3 2 since he did the cool stuff of this system (hold note manipulation)

	Note that if you want to use this in other mods, you'll have to do some pretty drastic changes to a bunch of classes (PlayState, Note, Conductor, etc)
	If you can make it work in other engines then epic but its best to just use this engine tbh
 */
 
typedef RenderObject = {
	shader:Shader,
	alpha:Float,
	uvData:Vector<Float>,
	vertices:Vector<Float>,
	zIndex:Float,
}

typedef NoteCallback = (Note, PlayField) -> Void;
class PlayField extends FlxTypedGroup<FlxBasic>
{
	override function set_camera(to){
		for (strumLine in strumNotes)
			strumLine.camera = to;
		
		noteField.camera = to;

		return super.set_camera(to);
	}

	override function set_cameras(to){
		for (strumLine in strumNotes)
			strumLine.cameras = to;
		
		noteField.cameras = to;

		return super.set_cameras(to);
	}

	public var judgeManager(get, default):JudgmentManager;
	function get_judgeManager()
		return judgeManager == null ? PlayState.instance.judgeManager : judgeManager;
	public var spawnedNotes:Array<Note> = []; // spawned notes
	public var spawnedByData:Array<Array<Note>> = [[], [], [], []]; // spawned notes by data. Used for input
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
		if (spawnedByData[daNote.noteData] != null)
			spawnedByData[daNote.noteData].remove(daNote);

		if (noteQueue[daNote.noteData] != null)
			noteQueue[daNote.noteData].remove(daNote);

		if (daNote.unhitTail.length > 0)
			while (daNote.unhitTail.length > 0)
				removeNote(daNote.unhitTail.shift());
		

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
		if (spawnedByData[note.noteData]==null){
			if(note.noteData >= spawnedByData.length){
				for(i in spawnedByData.length-1...note.noteData)
					spawnedByData.push([]);
			}
		}

		spawnedByData[note.noteData].push(note);

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
	
	public function hasNote(note:Note)
		return spawnedNotes.contains(note) || noteQueue[note.noteData]!=null && noteQueue[note.noteData].contains(note);
	

	public function input(data:Int){
		var noteList = getNotesWithEnd(data, Conductor.songPosition + ClientPrefs.hitWindow, (note:Note) -> !note.isSustainNote); //getTapNotes(data);
		noteList.sort((a, b) -> Std.int(a.strumTime - b.strumTime));
		while (noteList.length > 0)
		{
			var note:Note = noteList.shift();
			var judge:Judgment = judgeManager.judgeNote(note);
			if (judge != UNJUDGED){
				note.hitResult.judgment = judge;
				note.hitResult.hitDiff = note.strumTime - Conductor.songPosition;
				noteHitCallback(note, this);
				return note;
			}
		}
		return null;
	}
    
	public function generateStrums(){
		for(i in 0...4){
			var babyArrow:StrumNote = new StrumNote(0, 0, i);
			babyArrow.downScroll = ClientPrefs.downScroll;
			babyArrow.alpha = 0;
			insert(0, babyArrow);
			babyArrow.handleRendering = false; // NoteField handles rendering
			babyArrow.cameras = cameras;
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

	public function spawnSplash(data:Int, splashSkin:String, ?note:Note){
		var skin:String = splashSkin;
		var hue:Float = ClientPrefs.arrowHSV[data % 4][0] / 360;
		var sat:Float = ClientPrefs.arrowHSV[data % 4][1] / 100;
		var brt:Float = ClientPrefs.arrowHSV[data % 4][2] / 100;

		if (note != null)
		{
			skin = note.noteSplashTexture;
			hue = note.noteSplashHue;
			sat = note.noteSplashSat;
			brt = note.noteSplashBrt;
		}

		var splash:NoteSplash = grpNoteSplashes.recycle(NoteSplash);
		splash.setupNoteSplash(0, 0, data, skin, hue, sat, brt);
		splash.handleRendering = false;
		grpNoteSplashes.add(splash);
		return splash;
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
				var time:Float = noteSpawnTime == null ? 3000 : noteSpawnTime.getValue(modNumber); // no longer averages the spawn times
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
						var regrabTime = (daNote.isRoll?0.5:0.25) * judgeManager.judgeTimescale;
						if(isHeld)
							daNote.tripTimer = 1;
						else
							daNote.tripTimer -= elapsed / regrabTime; // TODO: regrab time multiplier in options

						if(daNote.tripTimer <= 0){
							daNote.tripTimer = 0;
							daNote.tooLate=true;
							daNote.wasGoodHit=false;
							for(tail in daNote.unhitTail){
								tail.tooLate = true;
								tail.blockHit = true;
								tail.ignoreNote = true;
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
					!daNote.isSustainNote && (daNote.sustainLength==0 || daNote.tooLate) && daNote.strumTime - Conductor.songPosition < -(200 + judgeManager.getWindow(TIER1))) && (daNote.tooLate || daNote.wasGoodHit))
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
					if (!daNote.isSustainNote){
						var hitDiff = daNote.strumTime - Conductor.songPosition;
						if ((hitDiff + ClientPrefs.ratingOffset) <= (5 * Wife3.timeScale)){
							daNote.hitResult.judgment = judgeManager.useEpics ? TIER5 : TIER4;
							daNote.hitResult.hitDiff = (hitDiff < -5) ? -5 : hitDiff; 
							noteHitCallback(daNote, this);
						}
					}
					
				}
			}
		}
	}

	public function getNotes(dir:Int, ?filter:Note->Bool):Array<Note>
	{
		if (spawnedByData[dir]==null)
			return [];

		var collected:Array<Note> = [];
		for (note in spawnedByData[dir])
		{
			if (note.alive && note.noteData == dir && !note.wasGoodHit && !note.tooLate)
			{
				if (filter == null || filter(note))
					collected.push(note);
			}
		}
		return collected;
	}

	public function getNotesWithEnd(dir:Int, end:Float, ?filter:Note->Bool):Array<Note>
	{
		if (spawnedByData[dir] == null)
			return [];
		var collected:Array<Note> = [];
		for (note in spawnedByData[dir])
		{
			if (note.strumTime>end)break;
			if (note.alive && note.noteData == dir && !note.wasGoodHit && !note.tooLate)
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



class NoteField extends FlxObject
{
	var smoothHolds = true; //ClientPrefs.coolHolds;
	public var holdSubdivisions:Int = Std.int(ClientPrefs.holdSubdivs) + 1;
	public var optimizeHolds = ClientPrefs.optimizeHolds;

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

	public var strumPositions:Array<Vector3> = [];

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
		var drawDist = drawMod==null ? FlxG.height : drawMod.getValue(modNumber); 
		drawDist *= drawDistMod;
		for (daNote in field.spawnedNotes){
			if(!daNote.alive)continue;

			if (songSpeed != 0)
			{
				var speed = songSpeed * daNote.multSpeed * modManager.getValue("xmod", modNumber);
				var diff = Conductor.songPosition - daNote.strumTime;
				var visPos = -((Conductor.visualPosition - daNote.visualTime) * speed);
				if (visPos > drawDist)continue;
				if(daNote.wasGoodHit && daNote.tail.length > 0 && daNote.unhitTail.length > 0){
					diff = 0;
					visPos = 0;
					continue; // stops it from drawing lol
				}
				if (!daNote.isSustainNote){
					var pos = modManager.getPos(visPos, diff, curDecBeat, daNote.noteData, modNumber,
						daNote, ['perspectiveDONTUSE'], daNote.vec3Cache); // perspectiveDONTUSE is excluded because its code is done in the modifyVert function
					notePos.set(daNote, pos);
					taps.push(daNote);
				}else{
					holds.push(daNote);
				}
			}

		}
		
		var drawing:Array<RenderObject> = []; // stuff to render
		var lookupMap:Map<Any, RenderObject> = [];

		for (obj in field.strumNotes)
		{
			if (!obj.alive || !obj.visible)
				continue;
			var pos = modManager.getPos(0, 0, curDecBeat, obj.noteData, modNumber, obj, ['perspectiveDONTUSE'], obj.vec3Cache);
			strumPositions[obj.noteData] = pos;
			var object = drawNote(obj, pos);
			if(object==null)continue;
			object.zIndex += (obj.animation!=null && obj.animation.curAnim != null && obj.animation.curAnim.name == 'confirm')?1:0;

			lookupMap.set(obj, object);
			drawing.push(object);
		}

		for (note in taps){
			if (!note.alive || !note.visible)
				continue;
			var object = drawNote(note, notePos.get(note));
			if(object==null)continue;
			object.zIndex = notePos.get(note).z + note.zIndex;
			lookupMap.set(note, object);
			drawing.push(object);
		}

		for (note in holds)
		{
			if (!note.alive || !note.visible)
				continue;
			var object = drawHold(note);
			if (object == null)
				continue;
			object.zIndex -= 1;
			lookupMap.set(note, object);
			drawing.push(object);
		}

		for (obj in field.grpNoteSplashes.members)
		{
			if (!obj.alive || !obj.visible)
				continue;
			var pos = modManager.getPos(0, 0, curDecBeat, obj.noteData, modNumber, obj, ['perspectiveDONTUSE']);
			var object = drawNote(obj, pos);
			if (object == null)
				continue;
			object.zIndex += 2;
			lookupMap.set(obj, object);
			drawing.push(object);
		}
		
		for (obj in field.strumAttachments.members)
		{
			if(obj==null)continue;
			if (!obj.alive || !obj.visible)
				continue;
			var pos = modManager.getPos(0, 0, curDecBeat, obj.noteData, modNumber, obj, ['perspectiveDONTUSE']);
			var object = drawNote(obj, pos);
			if (object == null)
				continue;
			object.zIndex += 2;
			lookupMap.set(obj, object);
			drawing.push(object);
		}

		if((FlxG.state is PlayState))
			PlayState.instance.callOnHScripts("playfieldDraw", [this], ["drawing" => drawing, "lookupMap" => lookupMap]); // lets you do custom rendering in scripts, if needed
		// one example would be reimplementing Die Batsards' original bullet mechanic

		drawing.sort(function(Obj1:RenderObject, Obj2:RenderObject)
		{
			return FlxSort.byValues(FlxSort.ASCENDING, Obj1.zIndex, Obj2.zIndex);
		});

		super.draw();

		if(drawing.length>0){
			for (object in drawing)
			{
				if (object == null)
					continue;
				var shader:Dynamic = object.shader;
				var alpha = object.alpha;
				var vertices = object.vertices;
				var uvData = object.uvData;
				shader.alpha.value = [alpha];
				for (camera in cameras)
				{
					if (camera!=null && camera.canvas!=null && camera.canvas.graphics != null){
						if (camera.alpha == 0 || !camera.visible)
							continue;
						shader.alpha.value = [alpha * camera.alpha];
						// maybe some optimization so that it'll only do a beginShaderFill/endFill if the previous drawn shader != this shader
						camera.canvas.graphics.beginShaderFill(shader);
						camera.canvas.graphics.drawTriangles(vertices, null, uvData);
						camera.canvas.graphics.endFill();
					}
				}
			}
		}

        
    }

	function getPoints(hold:Note, ?wid:Float, vDiff:Float, diff:Float){ // stolen from schmovin'
		if (wid == null)
			wid = hold.frameWidth * hold.scale.x;
		var speed = songSpeed * hold.multSpeed * modManager.getValue("xmod", modNumber);

		var p1 = modManager.getPos(-(vDiff) * speed, diff, curDecBeat, hold.noteData, modNumber, hold, []);
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

		var p2 = modManager.getPos(-(vDiff + 1) * speed, diff + 1, curDecBeat, hold.noteData, modNumber, hold, []);
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
	
	var crotchet = Conductor.getCrotchetAtTime(0) / 4;
	function drawHold(hold:Note):Null<RenderObject>
	{
		if(hold.animation.curAnim==null)return null;
		if(hold.scale==null)return null; 

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
			return null;
		
		var alpha = modManager.getAlpha(curDecBeat, hold.alpha, hold, modNumber, hold.noteData);
		if(alpha==0)return null;

		var lastMe = null;

		var tWid = hold.frameWidth * hold.scale.x;
		var bWid = (function(){
			if(hold.prevNote != null && hold.prevNote.scale!=null && hold.prevNote.isSustainNote)
				return hold.prevNote.frameWidth * hold.prevNote.scale.x;
			else
				return tWid;
		})();
		
		var basePos = modManager.getPos(0, 0, curDecBeat, hold.noteData, modNumber, hold, ['perspectiveDONTUSE']);
		
		var strumDiff = (Conductor.songPosition - hold.strumTime);
		var visualDiff = (Conductor.visualPosition - hold.visualTime); // TODO: get the start and end visualDiff and interpolate so that changing speeds mid-hold will look better
		var zIndex:Float = basePos.z;
		var sv = PlayState.instance.getSV(hold.strumTime).speed;
		for(sub in 0...holdSubdivisions){
			var prog = sub / (holdSubdivisions+1);
			var nextProg = (sub + 1) / (holdSubdivisions + 1);
			var strumSub = crotchet / holdSubdivisions;
			var strumOff = (strumSub * sub);
			strumOff *= sv;
			strumSub *= sv;
			var scale:Float = 1;
			var fuck = strumDiff;

			if((hold.wasGoodHit || hold.parent.wasGoodHit) && !hold.tooLate){
				scale = 1 - ((fuck + crotchet) / crotchet);
				if(scale<0)scale=0;
				if(scale>1)scale=1;
				strumSub *= scale;
				strumOff *= scale;
			}
			
			var topWidth = FlxMath.lerp(tWid, bWid, prog);
			var botWidth = FlxMath.lerp(tWid, bWid, nextProg);

			
			var top = lastMe == null ? getPoints(hold, topWidth, (visualDiff + (strumOff * 0.45)), strumDiff + strumOff) : lastMe;
			var bot = getPoints(hold, botWidth, (visualDiff + ((strumOff + strumSub) * 0.45)), strumDiff + strumOff + strumSub);

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

		var vertices = new Vector<Float>(verts.length, false, cast verts);
		var uvData = new Vector<Float>(uv.length, false, uv);

		var shader = hold.shader != null ? hold.shader : new FlxShader();
		if (shader != hold.shader)
			hold.shader = shader;
		
		shader.bitmap.input = hold.graphic.bitmap;
		shader.bitmap.filter = hold.antialiasing ? LINEAR : NEAREST;

		return {
			shader: shader,
			alpha: alpha, 
			uvData: uvData,
			vertices: vertices,
			zIndex: zIndex
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

		var width = sprite.frameWidth * sprite.scale.x;
		var height = sprite.frameHeight * sprite.scale.y;
		var alpha = modManager.getAlpha(curDecBeat, sprite.alpha, sprite, modNumber, sprite.noteData);
		if(alpha==0)return null;
		var quad = [
			new Vector3(-width / 2, -height / 2, 0), // top left
			new Vector3(width / 2, -height / 2, 0), // top right
			new Vector3(-width / 2, height / 2, 0), // bottom left
			new Vector3(width / 2, height / 2, 0) // bottom right
		];

		for (idx => vert in quad)
		{
			var vert = VectorHelpers.rotateV3(vert, 0, 0, FlxAngle.TO_RAD * sprite.angle);
			vert.x += sprite.offsetX;
			vert.y += sprite.offsetY;

			if ((sprite is Note))
			{
				var n:Note = cast sprite;
				vert.x += n.typeOffsetX;
				vert.y += n.typeOffsetY;
			}
			vert = modManager.modifyVertex(curDecBeat, vert, idx, sprite, pos, modNumber, sprite.noteData);
			quad[idx] = vert;

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
			pos.x + quad[0].x, pos.y + quad[0].y,
			pos.x + quad[1].x, pos.y + quad[1].y,
			pos.x + quad[3].x, pos.y + quad[3].y,

			pos.x + quad[0].x, pos.y + quad[0].y,
			pos.x + quad[2].x, pos.y + quad[2].y,
			pos.x + quad[3].x, pos.y + quad[3].y
		]);

		var uvData = new Vector<Float>(12, false, [
			 leftUV,    topUV,
			rightUV,    topUV,
			rightUV, bottomUV,

			 leftUV,    topUV,
			 leftUV, bottomUV,
			rightUV, bottomUV,
		]);

		var shader = sprite.shader != null ? sprite.shader : new FlxShader();
		if(shader!=sprite.shader)sprite.shader = shader;

		shader.bitmap.input = sprite.graphic.bitmap;
		shader.bitmap.filter = sprite.antialiasing ? LINEAR : NEAREST;
		
		return {
			shader: shader,
			alpha: alpha,
			uvData: uvData,
			vertices: vertices,
			zIndex: pos.z
		}
		
	}

}