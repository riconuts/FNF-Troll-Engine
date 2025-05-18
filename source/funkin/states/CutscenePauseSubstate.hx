package funkin.states;

import funkin.objects.cutscenes.Cutscene;
import flixel.tweens.FlxEase;
import flixel.util.FlxColor;
import flixel.tweens.FlxTween;
import funkin.data.PauseMenuOption;
import haxe.Constraints.Function;

typedef PauseOpt = {
	?text: String,
	?localizationKey: String,
	?button: Alphabet,
	?filter: Void->Bool,
	onAccept:Function
}

class CutscenePauseSubstate extends MusicBeatSubstate {
	var menu: AlphabetMenu;
	var options: Array<PauseOpt> = [];
	var associatedCutscene: Cutscene;
	var prevTimeScale:Float;

	override function close(){
		FlxG.timeScale = prevTimeScale;
		super.close();
	}

	public function new(cut: Cutscene){
		super();
		this.associatedCutscene = cut;	
	}

	override function create(){
		var cam:FlxCamera = FlxG.cameras.list[FlxG.cameras.list.length - 1];
		this.cameras = [cam];
		prevTimeScale = FlxG.timeScale;
		FlxG.timeScale = 1;

		var bg:FlxSprite = new FlxSprite();
		bg.makeGraphic(1, 1, FlxColor.BLACK);
		bg.scrollFactor.set(0, 0);
		bg.scale.set(1280, 720);
		bg.updateHitbox();
		bg.alpha = 0;
		FlxTween.tween(bg, {alpha: 0.4}, 1, {ease: FlxEase.quadInOut});
		add(bg);

		menu = new AlphabetMenu();
		menu.callbacks.onSelect = onSelectedOption;
		menu.callbacks.unSelect = unSelectedOption;
		menu.callbacks.onAccept = onAcceptedOption;
		menu.controls = controls;
		menu.cameras = cameras;
		generateMenus();
		add(menu);
	}

	function generateMenus(){
		menu.clear();

		options = [
			{
				localizationKey: "resume",
				onAccept: () -> {
					close();
					associatedCutscene.resume();
				}
			},
			{
				text: "Skip Cutscene",
				onAccept: () -> {
					close();
					associatedCutscene.onEnd.dispatch(true);
				}
			},
			{
				text: "Restart Cutscene",
				onAccept: () -> {
					close();
					associatedCutscene.restart();
				}
			},
			{
				localizationKey: "exit-to-menu",
				onAccept: () -> {
					MusicBeatState.switchState(new funkin.states.MainMenuState());
				}
			}
		];
		for (opt in options)
			if (opt.filter == null || opt.filter())
				opt.button = menu.addTextOption(opt.localizationKey == null ? opt.text ?? "UNKNOWN" : Paths.getString("pauseoption_" + opt.localizationKey,
					opt.text ?? "UNKNOWN"));

	}

	public function onSelectedOption(id:Int, obj:Alphabet) {
		
	}

	public function unSelectedOption(id:Int, obj:Alphabet) {

	}

	public function onAcceptedOption(id:Int, obj:Alphabet) {
		options[id].onAccept();
	}
}