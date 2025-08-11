package funkin.states;

import funkin.states.PlayState;
import funkin.objects.cutscenes.Cutscene;
import flixel.tweens.FlxEase;
import flixel.util.FlxColor;
import flixel.tweens.FlxTween;
import funkin.data.PauseMenuOption;
import haxe.Constraints.Function;

typedef PauseOpt = {
	id: String,
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
		super(0xFF000000);
		this.associatedCutscene = cut;	
	}

	override function create(){
		var cam:FlxCamera = FlxG.cameras.list[FlxG.cameras.list.length - 1];
		this.cameras = [cam];
		prevTimeScale = FlxG.timeScale;
		FlxG.timeScale = 1;

		@:privateAccess
		this._bgSprite._cameras = this._cameras;
		_bgSprite.alpha = 0;
		FlxTween.tween(_bgSprite, {alpha: 0.4}, 1, {ease: FlxEase.quadInOut});

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
				id: "resume-cutscene",
				onAccept: () -> {
					close();
					associatedCutscene.resume();
				}
			},
			{
				id: "skip-cutscene",
				onAccept: () -> {
					close();
					associatedCutscene.onEnd.dispatch(true);
				}
			},
			{
				id: "restart-cutscene",
				onAccept: () -> {
					close();
					associatedCutscene.restart();
				}
			},
			{
				id: "exit-to-menu",
				onAccept: () -> {
					PlayState.instance != null ? PlayState.gotoMenus() : MusicBeatState.switchState(new funkin.states.MainMenuState());
				}
			}
		];
		for (opt in options)
			if (opt.filter == null || opt.filter())
				opt.button = menu.addTextOption(Paths.getString("pauseoption_" + opt.id) ?? opt.id);

	}

	public function onSelectedOption(id:Int, obj:Alphabet) {
		
	}

	public function unSelectedOption(id:Int, obj:Alphabet) {

	}

	public function onAcceptedOption(id:Int, obj:Alphabet) {
		options[id].onAccept();
	}
}