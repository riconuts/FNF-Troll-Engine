package funkin.objects.cutscenes;

import flixel.system.FlxAssets.FlxSoundAsset;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.util.FlxSignal.FlxTypedSignal;
import flixel.tweens.FlxTween;

class Cutscene extends FlxTypedGroup<FlxBasic> {
	public var onEnd:FlxTypedSignal<Bool->Void> = new FlxTypedSignal<Bool->Void>(); // (wasSkipped:Bool)->{}
	public var sounds: Array<FlxSound> = [];
	public var music:FlxSound;

	public function newSound(path:String, obeysBitch:Bool = true){
		var newSound = new FlxSound().loadEmbedded(Paths.sound(path));
		newSound.exists = true;
		if(obeysBitch)
			newSound.pitch = FlxG.timeScale;

		FlxG.sound.list.add(newSound);
		sounds.push(newSound);
		return newSound;
	}

	public function playMusic(path:FlxSoundAsset, volume:Float = 1, fadeIn:Float = 0, fadeOut:Float = 0.25){
	
		if(music != null){
			if (fadeOut > 0) {
				var oldMusic:FlxSound = music;
				music.fadeOut(fadeOut, 0, (twn:FlxTween)->{
					oldMusic.stop();
					FlxG.sound.list.remove(oldMusic);
					sounds.remove(oldMusic);

					oldMusic.destroy();
				});
				music = new FlxSound();
			}
		}else{
			music = new FlxSound();
		}

		FlxG.sound.list.add(music);
		if(!sounds.contains(music))
			sounds.push(music);

		music.stop();
		music.context = MUSIC;
		music.loadEmbedded(path, true);
		music.volume = volume;
		music.play(true);
		if (fadeIn > 0)
			music.fadeIn(fadeIn, 0, volume);

		return music;
		
	}

	public function pause() {
		for (s in sounds)
			s.pause();
	}

	public function resume() {
		for(s in sounds)
			s.resume();

	}

	public function restart() 
		clearSounds();

	function clearSounds()
	{
		for (s in sounds) {
			FlxG.sound.list.remove(s);
			s.destroy();
		}
		sounds.resize(0);
	}
	

	public function createCutscene() // gets called by state or w/e
	{
		
	}

	public function new(){
		super();
		onEnd.addOnce((_:Bool) -> {
			clearSounds();
		});
	}
}