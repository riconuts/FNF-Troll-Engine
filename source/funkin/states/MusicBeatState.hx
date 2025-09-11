package funkin.states;

import funkin.data.MusicData;
import flixel.math.FlxMath;
import funkin.input.Controls;
import flixel.addons.transition.FlxTransitionableState;
import flixel.addons.ui.FlxUIState;
import openfl.media.Sound;
import openfl.ui.MouseCursor;
import openfl.ui.Mouse;
import haxe.io.Path;

#if HSCRIPT_ALLOWED
import funkin.scripts.FunkinHScript;
import funkin.states.scripting.*;
#end

#if SCRIPTABLE_STATES
import funkin.states.scripting.HScriptOverridenState;
#end

enum abstract SongSyncMode(String) to String {
	var DIRECT = "Direct";
	var LEGACY = "Legacy";
	var PSYCH_1_0 = "Psych 1.0";
	var LAST_MIX = "Last Mix";
	var SYSTEM_TIME = "System Time";
	
	public static function fromString(str:String):SongSyncMode {
		return switch (str) {
			case "Direct": DIRECT;
			case "Legacy": LEGACY;
			case "Psych 1.0": PSYCH_1_0;
			case "System Time": SYSTEM_TIME;
			//case "Last Mix": LAST_MIX;
			default: LAST_MIX;
		}
	} 
}
#if SCRIPTABLE_STATES
@:autoBuild(funkin.macros.ScriptingMacro.addScriptingCallbacks([
	"create",
	"update",
	"draw",
	"destroy",
	"openSubState",
	"closeSubState",
	"stepHit",
	"beatHit",
	"sectionHit"
]))
#end
class MusicBeatState extends FlxUIState
{
	public var updateSongPos:Bool = true;
	
	private var curSection:Int = 0;
	private var stepsToDo:Int = 0;

	#if true
	private var curStep(get, set):Int;
	private var curBeat(get, set):Int;
	private var curDecStep(get, set):Float;
	private var curDecBeat(get, set):Float;
	@:noCompletion inline function get_curStep() return Conductor.curStep;
	@:noCompletion inline function get_curBeat() return Conductor.curBeat;
	@:noCompletion inline function get_curDecStep() return Conductor.curDecStep;
	@:noCompletion inline function get_curDecBeat() return Conductor.curDecBeat;
	@:noCompletion inline function set_curStep(v) return Conductor.curStep=v;
	@:noCompletion inline function set_curBeat(v) return Conductor.curBeat=v;
	@:noCompletion inline function set_curDecStep(v) return Conductor.curDecStep=v;
	@:noCompletion inline function set_curDecBeat(v) return Conductor.curDecBeat=v;
	#end

	private var songSyncMode(default, set):SongSyncMode;
	private function set_songSyncMode(v:SongSyncMode):SongSyncMode {
		songSyncMode = v;
		Conductor.useAccPosition = songSyncMode == SYSTEM_TIME;
		return songSyncMode;
	}

	private var controls(get, never):Controls;

	public var canBeScripted(get, default):Bool = false;
	@:noCompletion function get_canBeScripted() return canBeScripted;

	//// To be defined by the scripting macro
	@:noCompletion public var _extensionScript:FunkinHScript;

	@:noCompletion public function _getScriptDefaultVars() 
		return new Map<String, Dynamic>();
	
	@:noCompletion public function _startExtensionScript(folder:String, scriptName:String) 
		return;

	////
	public function new(canBeScripted:Bool = true) {
		super();
		this.canBeScripted = canBeScripted;
		this.songSyncMode = LAST_MIX;
	}

	override public function destroy() 
	{
		super.destroy();
		
		if (_extensionScript != null) {
			_extensionScript.stop();
			_extensionScript = null;
		}
	}

	inline function get_controls():Controls
		return funkin.input.Controls.firstActive;

	override function create() 
	{
		FlxG.autoPause = ClientPrefs.autoPause;
		
		super.create();
	}

	override public function onFocus():Void
	{
		super.onFocus();
	}

	override public function onFocusLost():Void
	{
		super.onFocusLost();
	}
	
	private var lastMixTimer:Float = 0;
	private var lastMixPos:Float = 0;

	private function updateSongPosition(?inst:FlxSound):Void {
		inst ??= Conductor.tracks[0];
		if (inst == null) return;

		@:privateAccess
		var elapsedMS:Float = FlxG.game._elapsedMS * inst.pitch;

		switch (songSyncMode)
		{
			case DIRECT:
				// Ludem Dare sync
				// Jittery and retarded, but works maybe
				Conductor.songPosition = inst.time;

			case LEGACY:
				// Resync Vocals
				// FUCKING SUCKS DONT USE LMFAO! It's here just incase though
				Conductor.songPosition += elapsedMS;
				
			case PSYCH_1_0:
				// Psych 1.0 method
				// Since this works better for Rico so might work better for some other machines too
				Conductor.songPosition += elapsedMS;
				Conductor.songPosition = FlxMath.lerp(inst.time, Conductor.songPosition, Math.exp(-elapsedMS * 0.005));
				var timeDiff:Float = Math.abs(inst.time - Conductor.songPosition);
				if (timeDiff > 1000)
					Conductor.songPosition = Conductor.songPosition + 1000 * FlxMath.signOf(timeDiff);

			case SYSTEM_TIME:
				Conductor.songPosition = Conductor.getAccPosition();
			
			case LAST_MIX:
				// Stepmania method
				// Works for most people it seems??
				if (lastMixPos != inst.time) {
					lastMixPos = inst.time;
					lastMixTimer = 0;
				}else {
					lastMixTimer += elapsedMS;
				}
				
				Conductor.songPosition = lastMixPos + lastMixTimer;

		}
	}

	private function updateSteps() {	
		var oldStep:Int = Conductor.curStep;
		Conductor.updateSteps();
		var curStep:Int = Conductor.curStep;

		if (oldStep != curStep) {
			if (curStep > 0)
				stepHit();

			if (PlayState.SONG != null)
			{
				if (oldStep < curStep)
					updateSection();
				else
					rollbackSection();
			}
		}
	}

	override function update(elapsed:Float)
	{
		updateSteps();
		if(updateSongPos){
			if (FlxG.sound.music != null)
				Conductor.songPosition = FlxG.sound.music.time;
			else
				Conductor.songPosition += elapsed * 1000;

		}
		super.update(elapsed);
	}

	private function updateSection():Void
	{
		if(stepsToDo < 1) stepsToDo = Math.round(getBeatsOnSection() * 4);
		while(curStep >= stepsToDo)
		{
			curSection++;
			var beats:Float = getBeatsOnSection();
			stepsToDo += Math.round(beats * 4);
			sectionHit();
		}
	}


	private function rollbackSection():Void
	{
		if(curStep < 0) return;

		var lastSection:Int = curSection;
		curSection = 0;
		stepsToDo = 0;
		for (i in 0...PlayState.SONG.notes.length)
		{
			if (PlayState.SONG.notes[i] != null)
			{
				stepsToDo += Math.round(getBeatsOnSection() * 4);
				if(stepsToDo > curStep) break;
				
				curSection++;
			}
		}

		if(curSection > lastSection) sectionHit();
	}

	public static function switchState(nextState:FlxState)
	{
		FlxG.autoPause = false;
		FlxG.mouse.visible = false;
		Mouse.cursor = MouseCursor.AUTO;

		FlxG.switchState(nextState); // just because im too lazy to goto every instance of switchState and change it to a FlxG call
	}

	public static function resetState(?skipTrans:Bool = false) {
		if (skipTrans) {
			FlxTransitionableState.skipNextTransIn = true;
			FlxTransitionableState.skipNextTransOut = true;
		}

		#if HSCRIPT_ALLOWED
		if (FlxG.state is OldHScriptedState){
			var state:OldHScriptedState = cast FlxG.state;
			FlxG.switchState(OldHScriptedState.fromPath(state.scriptPath));
		}
		#if SCRIPTABLE_STATES
		else if (FlxG.state is HScriptOverridenState) {
			var state:HScriptOverridenState = cast FlxG.state;
			var overriden = HScriptOverridenState.fromAnother(state);

			if (overriden!=null) {
				FlxG.switchState(overriden);
			}else {
				trace("State override script file is gone!", "Switching to", state.parentClass);
				FlxG.switchState(Type.createInstance(state.parentClass, []));
			}
		}
		#end
		else if (FlxG.state is HScriptedState) {
			var state:HScriptedState = cast FlxG.state;

			if (Paths.exists(state.scriptPath))
				FlxG.switchState(new HScriptedState(state.scriptPath));
			else{
				trace("State script file is gone!", "Switching to", MainMenuState);
				FlxG.switchState(new MainMenuState());
			}
		}
		#end
		else
			FlxG.resetState();
	}

	public static function getState():MusicBeatState
	{
		return cast FlxG.state;
	}

	function resyncTracks() {
		Conductor.resyncTracks();
		lastMixPos = Conductor.songPosition;
	}

	public function stepHit():Void
	{
		if (curStep % 4 == 0)
			beatHit();

		if (Conductor.playing) {
			for (track in Conductor.tracks) {
				if (Math.abs(track.time - Conductor.getAccPosition()) > 30) {
					trace('sus track resync');
					resyncTracks();
					break;
				}
			}	
		}		
	}

	public function beatHit():Void
	{
		//trace('Beat: ' + curBeat);
	}

	public function sectionHit():Void
	{
		//trace('Section: ' + curSection + ', Beat: ' + curBeat + ', Step: ' + curStep);
	}

	function getBeatsOnSection():Float
	{		
		var section = PlayState?.SONG.notes[curSection];
		return section==null ? 4 : Conductor.sectionBeats(section);
	}

	public static var menuVox:FlxSound; // jukebox

	public static function stopMenuMusic(){
		if (FlxG.sound.music != null){
			FlxG.sound.music.stop();
			FlxG.sound.music.destroy();
			FlxG.sound.music = null;
		}

		if (MusicBeatState.menuVox != null)
		{
			MusicBeatState.menuVox.stop();
			MusicBeatState.menuVox.destroy();
			MusicBeatState.menuVox = null;
		}
	}

	public static function playMusic(key:String, volume:Float = 1, looped:Bool = true) {
		MusicBeatState.stopMenuMusic();
		
		var md = MusicData.fromName(key);
		if (md != null) {
			FlxG.sound.music = md.loadFlxSound(FlxG.sound.music);
			FlxG.sound.music.volume = volume;
			FlxG.sound.music.looped = looped;
			FlxG.sound.music.persist = true;
			FlxG.sound.music.play();
			Conductor.changeBPM(md.bpm);
			Conductor.songPosition = FlxG.sound.music.time;
		}else {
			FlxG.sound.playMusic(Paths.music(key), volume, looped);
		}
	}

	// TODO: check the jukebox selection n shit and play THAT instead? idk lol
	public static function playMenuMusic(volume:Float=1, force:Bool = false){				
		if (force != true && FlxG.sound.music != null && FlxG.sound.music.playing)
			return;

		MusicBeatState.stopMenuMusic();
		MusicBeatState.playMusic('freakyMenu', volume, force);
	}	
}
