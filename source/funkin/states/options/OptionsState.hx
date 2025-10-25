package funkin.states.options;

@:noScripting
class OptionsState extends funkin.states.base.SubstateState 
{
	var daSubstate:OptionsSubstate;

	override function create()
	{
		var bg = new funkin.objects.CoolMenuBG(Paths.image('menuDesat', null, false), 0xff7186fd);
		add(bg);

		daSubstate = new OptionsSubstate(true);
		daSubstate.goBack = (changedOptions:Array<String>) -> {
			MusicBeatState.switchState(new MainMenuState());
		};
		_create(daSubstate);
	}
}