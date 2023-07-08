import OldMainMenuState.MainMenuButton;
import openfl.events.KeyboardEvent;
import sys.FileSystem;
import Github.Release;
import flixel.FlxG;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.addons.transition.FlxTransitionableState;
import flixel.input.keyboard.FlxKey;

#if discord_rpc
import Discord.DiscordClient;
import lime.app.Application;
#end

using StringTools;

// Loads the title screen, alongside some other stuff.

class StartupState extends FlxState
{
	public static var muteKeys:Array<FlxKey> = [FlxKey.ZERO];
	public static var volumeDownKeys:Array<FlxKey> = [FlxKey.NUMPADMINUS, FlxKey.MINUS];
	public static var volumeUpKeys:Array<FlxKey> = [FlxKey.NUMPADPLUS, FlxKey.PLUS];

	static var loaded = false;
	static var recentRelease:Release;

	static function clearTemps(dir:String){
		#if desktop
		for(file in FileSystem.readDirectory(dir)){
			var file = './$dir/$file';
			if(FileSystem.isDirectory(file))
				clearTemps(file);
			else if (file.endsWith(".tempcopy"))
				FileSystem.deleteFile(file);
		}
		#end
	}
	public static function load():Void
	{
		if (loaded)
			return;
		loaded = true;

		getRecentGithubRelease();
		clearTemps("./");

		#if html5
		Paths.initPaths();
		#end
		#if hscript
		scripts.FunkinHScript.init();
		#end
		
		#if MODS_ALLOWED
		Paths.pushGlobalContent();
		Paths.getModDirectories();
		Paths.loadRandomMod();
		#end
		
		PlayerSettings.init();
		
		Highscore.load();

		FlxTransitionableState.defaultTransIn = FadeTransitionSubstate;
		FlxTransitionableState.defaultTransOut = FadeTransitionSubstate;
		
		// this shit doesn't work
		#if desktop
		Paths.sound("cancelMenu");
		Paths.sound("confirmMenu");
		Paths.sound("scrollMenu");

		Paths.music('freakyIntro');
		Paths.music('freakyMenu');
		#end

		ClientPrefs.initialize();
		ClientPrefs.load();

		if (Main.fpsVar != null)
			Main.fpsVar.visible = ClientPrefs.showFPS;

		if (FlxG.save.data.weekCompleted != null)
			StoryMenuState.weekCompleted = FlxG.save.data.weekCompleted;
		
		#if discord_rpc
		if (!DiscordClient.isInitialized){
			DiscordClient.initialize();
			Application.current.onExit.add(function(exitCode)
			{
				DiscordClient.shutdown();
			});
		}
		#end
	}


	#if DO_AUTO_UPDATE
	// gets the most recent release and returns it
	// if you dont have download betas on, then it'll exclude prereleases
	public static function getRecentGithubRelease(){
		if (ClientPrefs.checkForUpdates)
		{
			var github:Github = new Github(); // leaving the user and repo blank means it'll derive it from the repo the mod is compiled from
			// if it cant find the repo you compiled in, it'll just default to troll engine's repo
			recentRelease = github.getReleases((release:Release) ->
			{
				return (Main.downloadBetas || !release.prerelease);
			})[0];
			if (FlxG.save.data.ignoredUpdates == null)
			{
				FlxG.save.data.ignoredUpdates = [];
				FlxG.save.flush();
			}
			if (recentRelease != null && FlxG.save.data.ignoredUpdates.contains(recentRelease.tag_name))
				recentRelease = null;
			Main.recentRelease = recentRelease;
			
		}else{
			Main.recentRelease = null;
			Main.outOfDate = false;
		}
		return Main.recentRelease;
	}
	#else
	public static function getRecentGithubRelease()
	{
		Main.recentRelease = null;
		Main.outOfDate = false;
		return null;
	}
	#end


	public function new(){
		super();

		persistentDraw = true;
		persistentUpdate = true;

		FlxG.fixedTimestep = false;

		#if (windows || linux) // I have no idea if this also applies to other targets
		FlxG.stage.addEventListener(
			KeyboardEvent.KEY_DOWN, 
			(e)->{
				// Prevent flixel from listening to key inputs when switching fullscreen mode
				if (e.keyCode == FlxKey.ENTER && e.altKey)
					e.stopImmediatePropagation();

				// Also add F11 to switch fullscreen mode :D
				if (e.keyCode == FlxKey.F11){
					FlxG.fullscreen = !FlxG.fullscreen;
					e.stopImmediatePropagation();
				}
			}, 
			false, 
			100
		);
		#end
	}

	private var warning:FlxSprite;
	private var step = 0;
	private var nextState = TitleState;

	override function update(elapsed)
	{
		// this is kinda stupid but i couldn't find any other way to display the warning while the title screen loaded 
		// could be worse lol
 		switch (step){
			case 0:
 				warning = new FlxSprite().loadGraphic(Paths.image("warning"));
				warning.scale.set(0.65, 0.65);
				warning.updateHitbox();
				warning.screenCenter();
				add(warning); 

				//MusicBeatState.switchState(new editors.StageBuilderState());
				step = 1;
			case 1:
 				load();
				if (Type.getClassFields(nextState).contains("load"))
					nextState.load();
				
				#if (sys && debug)
				var waitTime = 1.5 - Sys.cpuTime();
				if (waitTime > 0) Sys.sleep(waitTime);
				#end

				step = 2;
			case 2:
 				FlxTween.tween(warning, {alpha: 0}, 1, {ease: FlxEase.expoIn, onComplete: function(twn){
					#if DO_AUTO_UPDATE
					// this seems to work?
					if (Main.checkOutOfDate())
						MusicBeatState.switchState(new UpdaterState(recentRelease)); // UPDATE!!
					else
					#end
					{
						FlxTransitionableState.skipNextTransIn = true;
						FlxTransitionableState.skipNextTransOut = true;
						MusicBeatState.switchState(new TitleState());
					}	
				}});
				step = 3; 

		}

		super.update(elapsed);
	}
}