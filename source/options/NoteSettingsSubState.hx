package options;

#if desktop
import Discord.DiscordClient;
#end
import Controls;
import flash.text.TextField;
import flash.text.TextField;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxSprite;
import flixel.FlxSubState;
import flixel.addons.display.FlxGridOverlay;
import flixel.graphics.FlxGraphic;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.input.keyboard.FlxKey;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxSave;
import flixel.util.FlxTimer;
import haxe.Json;
import lime.utils.Assets;
import openfl.Lib;

using StringTools;

class NoteSettingsSubState extends BaseOptionsMenu
{
	public function new()
	{
		title = 'Notes';
		//rpcTitle = 'Note Settings Menu'; //for Discord Rich Presence

		var option:Option = new Option('Note Skin', //Name
			'Changes how notes look. Quant sets the colour based on the note\'s beat, while Column has it based on the note\'s direction/column.', //Description
			'noteSkin', //Save data variable name
			'string', //Variable type
			'Column',
			['Column','Quants']
		); //Default value
		addOption(option);
/* 		var option:Option = new Option('Smooth Holds',
			"If checked, holds will be ALOT smoother, being able to bend to fit modcharts, etc. Turn off if you have a potato PC.", 'coolHolds', 'bool', true);
		addOption(option); */
		// smooth holds are optimized enough, probably
		// + too much work to keep support for both janky and smooth holds
		// people with PCs who cant handle smooth holds will have to take the L

		var option:Option = new Option(
			'Optimized Holds', 
			"If checked, smooth holds will have fewer calls to the modchart system for position info.\nBest to leave this on, unless you have a high-end PC and require the highest accuracy rendering for, some reason.", 
			'optimizeHolds', 
			'bool', 
			true
		);
		addOption(option);
		
		var option:Option = new Option('Hold Subdivisons',
			"How many divisions are in a hold note with smooth holds.\nMore means smoother holds, but more of a performance hit.", 
			'holdSubdivs', 
			'int', 
			2
		);
		option.displayFormat = '%v';
		option.changeValue = 1;
		option.minValue = 1;
		option.maxValue = 8;
		addOption(option);

		var option:Option = new Option('Draw Dist. Mult',
			"A multiplier to note's draw distance. Higher number means notes can be seen from further away, less means closer.\nNote that with higher numbers, draw distance is still capped by the spawn distance (which is only modifiable by modcharts) so it's only recommended to lower this value for low-end PCs.", 
			'drawDistanceModifier', 
			'float', 
			1);
		option.displayFormat = 'x%v';
		option.decimals = 1;
		option.changeValue = 0.1;
		option.minValue = 0.1;
		option.maxValue = 2;
		addOption(option);


		var option:Option = new Option('Customize',
			'Change your note colours\n[Press Enter]',
			'',
			'button',
			true);
		option.callback = function(){
			switch(ClientPrefs.noteSkin){
				case 'Quants':
					openSubState(new QuantNotesSubState());
				default:
					openSubState(new NotesSubState());
			}
		}
		addOption(option);

		super();
	}

}
