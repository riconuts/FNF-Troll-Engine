package funkin.states.editors;

import flixel.addons.transition.FlxTransitionableState;
#if DISCORD_ALLOWED
import funkin.api.Discord.DiscordClient;
#end

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;

using StringTools;

class MasterEditorMenu extends MusicBeatState
{
	var options:Array<String> = [
		'Song Select',
		'Character Editor',
		'Chart Editor',
		'Test Stage',
		/*
		'Stage Editor',
		'Stage Builder',
		*/
		/*
		'Week Editor',
		'Menu Character Editor',
		*/
	];
	private var menu:AlphabetMenu;
	private var directories:Array<String> = [null];

	private var curDirectory = 0;
	private var directoryTxt:FlxText;

	override function create()
	{
		super.create();
		FlxG.mouse.visible = false;
		FlxTransitionableState.skipNextTransOut = true;
		FlxG.camera.bgColor = FlxColor.BLACK;

		#if DISCORD_ALLOWED
		// Updating Discord Rich Presence
		DiscordClient.changePresence("Editors Menu", null);
		#end

		var bg:FlxSprite = new FlxSprite(0, 0, Paths.image('menuDesat'));
		bg.scrollFactor.set();
		bg.color = 0xFF353535;
		add(bg);

		menu = new AlphabetMenu();
		menu.controls = controls;
		menu.callbacks.onAccept = function(i, _){
			switch(options[i]) {
				case 'Song Select': MusicBeatState.switchState(new SongSelectState()); return;
				case 'Character Editor': MusicBeatState.switchState(new CharacterEditorState(Character.DEFAULT_CHARACTER, false));
				case 'Chart Editor': LoadingState.loadAndSwitchState(new ChartingState(), false);
				/*
				case 'Stage Editor': MusicBeatState.switchState(new StageEditorState());
				case 'Stage Builder': MusicBeatState.switchState(new StageBuilderState());
				*/
				case "Test Stage": MusicBeatState.switchState(new TestState());
				default: return;
			}
			
			FlxG.sound.music.volume = 0;
			menu.controls = null;
		}
		for (name in options) menu.addTextOption(name);
		menu.curSelected = 0;
		add(menu);
		
		
		#if MODS_ALLOWED
		var textBG:FlxSprite = new FlxSprite(0, FlxG.height - 42).makeGraphic(FlxG.width, 42, 0xFF000000);
		textBG.alpha = 0.6;
		add(textBG);

		directoryTxt = new FlxText(textBG.x, textBG.y + 4, FlxG.width, '', 32);
		directoryTxt.setFormat(Paths.font("calibri.ttf"), 32, FlxColor.WHITE, CENTER);
		directoryTxt.scrollFactor.set();
		add(directoryTxt);
		
		for (folder in Paths.getModDirectories())
		{
			directories.push(folder);
		}

		var found:Int = directories.indexOf(Paths.currentModDirectory);
		if(found > -1) curDirectory = found;
		changeDirectory();
		#end
	}

	override function update(elapsed:Float)
	{
		#if MODS_ALLOWED
		if(controls.UI_LEFT_P)
			changeDirectory(-1);
		if(controls.UI_RIGHT_P)
			changeDirectory(1);
		#end

		if (controls.BACK) {
			menu.controls = null;
			FlxG.sound.play(Paths.sound('cancelMenu'));
			MusicBeatState.switchState(new MainMenuState());
		}
		
		super.update(elapsed);
	}

	#if MODS_ALLOWED
	function changeDirectory(change:Int = 0)
	{
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.4 );

		curDirectory += change;

		if(curDirectory < 0)
			curDirectory = directories.length - 1;
		if(curDirectory >= directories.length)
			curDirectory = 0;
	
		Paths.currentModDirectory = '';
		if(directories[curDirectory] == null || directories[curDirectory].length < 1)
			directoryTxt.text = '< No Mod Directory Loaded >';
		else
		{
			Paths.currentModDirectory = directories[curDirectory];
			directoryTxt.text = '< Loaded Mod Directory: ' + Paths.currentModDirectory + ' >';
		}
		directoryTxt.text = directoryTxt.text.toUpperCase();
	}
	#end
}