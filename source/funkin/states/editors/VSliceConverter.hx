package funkin.states.editors;

import funkin.data.CharacterData;
import haxe.Json;
import haxe.io.Path;
import funkin.objects.Stage.StageData;
import openfl.events.Event;
import openfl.events.IOErrorEvent;
import openfl.net.FileReference;

using StringTools;

class VSliceConverter extends MusicBeatState
{
	private var menu:AlphabetMenu;

	var _file:FileReference;

	override function create() {
		FlxG.mouse.visible = false;
		menu = new AlphabetMenu();
		menu.controls = controls;
		menu.addTextOption("Back", {
			onAccept: (i:Int, a:Alphabet) -> {
				MusicBeatState.switchState(new MasterEditorMenu());
			}
		});

		var added:Array<String> = [];
		menu.addTextOption("Stages");
		for (folderPath in Paths.getFolders("stages")) {
			Paths.iterateDirectory(folderPath, (file:String)->{
				if (added.contains(file))return;

				added.push(file);
				if(file.endsWith("json")){
					var data: Dynamic = Paths.json('stages/$file', false);
					if(Reflect.field(data, "version") != null){
						menu.addTextOption(Path.withoutDirectory(Path.withoutExtension(file)), {
							onAccept: (i:Int, a:Alphabet) -> {
								_file = new FileReference();
								_file.addEventListener(Event.COMPLETE, onSaveComplete);
								_file.addEventListener(Event.CANCEL, onSaveCancel);
								_file.addEventListener(IOErrorEvent.IO_ERROR, onSaveError);
								_file.save(Json.stringify(StageData.convertVSlice(cast data), "\t"), file);
							}
						});
					}
				}
				//menu.addTextOption();
			});
		}

		menu.addTextOption("Characters");
		for (folderPath in Paths.getFolders("characters")) {
			Paths.iterateDirectory(folderPath, (file:String) -> {
				if (added.contains(file))
					return;
				added.push(file);
				if (file.endsWith("json")) {
					var data:Dynamic = Paths.json('characters/$file', false);
					if (Reflect.field(data, "version") != null) {
						var id:String = Path.withoutDirectory(Path.withoutExtension(file));
						menu.addTextOption(id, {
							onAccept: (i:Int, a:Alphabet) -> {
								var charFile:CharacterFile = CharacterData.getCharacterFile(id);
								trace(charFile);

								_file = new FileReference();
								_file.addEventListener(Event.COMPLETE, onCharSaveComplete);
								_file.addEventListener(Event.CANCEL, onSaveCancel);
								_file.addEventListener(IOErrorEvent.IO_ERROR, onSaveError);
								_file.save(Json.stringify(charFile, "\t"),  file);
							}
						});
					}
				}
				// menu.addTextOption();
			});
		}

		var bg = new funkin.objects.CoolMenuBG(Paths.image('menuDesat', null, false), 0xfffffb00);
		add(bg);

		add(menu);
		super.create();

		if (FlxG.sound.music == null || !FlxG.sound.music.playing)
			MusicBeatState.playMenuMusic();

		var curMusicVolume = FlxG.sound.music.volume;
		if (curMusicVolume < 0.8) {
			FlxG.sound.music.fadeIn((0.8 - curMusicVolume) * 2.0, curMusicVolume, 0.8);
		}
	}

	override function update(elapsed:Float) 
	{
		super.update(elapsed);
		if (controls.BACK) 
			MusicBeatState.switchState(new MasterEditorMenu());
		

	}

	function onCharSaveComplete(e): Void {
		var name: String = _file.name;

		trace(name);
		_file.removeEventListener(Event.COMPLETE, onCharSaveComplete);
		_file.removeEventListener(Event.CANCEL, onSaveCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		_file = null;

		_file = new FileReference();
		_file.addEventListener(Event.COMPLETE, onSaveComplete);
		_file.addEventListener(Event.CANCEL, onSaveCancel);
		_file.addEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		_file.save("
		function setupCharacter(){
			super();
			this.positionArray[0] -= this.width / 2;
			this.positionArray[1] -= this.height;
		}

		function getCamera(){
			return [
				x + width * 0.5 + cameraPosition[0] * xFacing,
				y + height * 0.5 + cameraPosition[1]
			];
		}
			
		", Path.withoutExtension(name)
			+ ".hscript"
		);

	}

	function onSaveComplete(e):Void {
		_file.removeEventListener(Event.COMPLETE, onSaveComplete);
		_file.removeEventListener(Event.CANCEL, onSaveCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		_file = null;
		FlxG.log.notice("Successfully saved LEVEL DATA.");
	}

	/**
	 * Called when the save file dialog is cancelled.
	 */
	function onSaveCancel(_):Void {
		_file.removeEventListener(Event.COMPLETE, onSaveComplete);
		_file.removeEventListener(Event.COMPLETE, onCharSaveComplete);
		_file.removeEventListener(Event.CANCEL, onSaveCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		_file = null;
	}

	/**
	 * Called if there is an error while saving the gameplay recording.
	 */
	function onSaveError(_):Void {
		_file.removeEventListener(Event.COMPLETE, onSaveComplete);
		_file.removeEventListener(Event.COMPLETE, onCharSaveComplete);
		_file.removeEventListener(Event.CANCEL, onSaveCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		_file = null;
		FlxG.log.error("Problem saving Level data");
	}

	
}