package funkin.states.editors;

import funkin.data.StageData;
import funkin.data.CharacterData;
import haxe.Json;
import haxe.io.Path;

using StringTools;

class VSliceConverter extends MusicBeatState
{
	private var menu:AlphabetMenu;

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
								CoolUtil.showSaveDialog(Json.stringify(StageData.convertVSlice(cast data), "\t"), "Save Stage Data", file, ["JSON file", "*.json"], onSaveComplete, onSaveCancel);
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
								CoolUtil.showSaveDialog(Json.stringify(charFile, "\t"), "Save Character Data", file, ["JSON file", "*.json"], onCharSaveComplete, onSaveCancel);
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

	function onCharSaveComplete(f:String): Void {
		trace(f);
		CoolUtil.showSaveDialog("
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
			
		", "Save Character Script", Path.withoutExtension(f) + ".hscript", ["HScript File", "*.hscript", "*.hxs"], onSaveComplete, onSaveCancel);
	}

	function onSaveComplete(e):Void {
		FlxG.log.notice("Successfully saved LEVEL DATA.");
	}

	/**
	 * Called when the save file dialog is cancelled.
	 */
	function onSaveCancel():Void {
		FlxG.log.notice("Save file dialog cancelled.");
	}
}