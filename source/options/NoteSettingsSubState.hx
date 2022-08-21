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
			'Changes how notes look. Quants change colour depending on the beat it\'s at, while vanilla is normal FNF', //Description
			'noteSkin', //Save data variable name
			'string', //Variable type
			'Vanilla',
			['Vanilla','Quants']
		); //Default value
		addOption(option);

		/*
		var option:Option = new Option('TGT Notes',
			"",
			'tgtNotes',
			'bool',
			true
		);
		addOption(option);
		*/

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

		/*
		var option:Option = new Option('Persistent Cached Data',
			'If checked, images loaded will stay in memory\nuntil the game is closed, this increases memory usage,\nbut basically makes reloading times instant.',
			'imagesPersist',
			'bool',
			false);
		option.onChange = onChangePersistentData; //Persistent Cached Data changes FlxGraphic.defaultPersist
		addOption(option);
		*/

		super();
	}

}
