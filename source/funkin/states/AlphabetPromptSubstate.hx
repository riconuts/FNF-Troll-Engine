package funkin.states;

import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.util.FlxColor;

using StringTools;

class AlphabetPromptSubstate extends MusicBeatSubstate
{
	public var messageStr:String;
	public var acceptStr:String;
	public var cancelStr:String;
	
	public var acceptCallback:() -> Void;
	public var cancelCallback:() -> Void;
	public var changeCallback:(Bool) -> Void;
	
	////
	public var curSelected:Null<Bool>;

	private var messageTxt:Alphabet;
	private var acceptTxt:Alphabet;
	private var cancelTxt:Alphabet;
	
	public function new(messageStr:String = "", ?acceptCallback:() -> Void)
	{	
		this.messageStr = messageStr;
		this.acceptCallback = acceptCallback;
		
		////
		super(0xFF000000);
		_bgSprite.alpha = 0;
	}

	override function create()
	{
		acceptStr ??= Paths.getString("yes") ?? "yes";
		cancelStr ??= Paths.getString("no") ?? "yes";

		super.create();

		////
		@:privateAccess
		this._bgSprite._cameras = this._cameras;
		FlxTween.tween(_bgSprite, {alpha: 0.6}, 1, {ease: FlxEase.quadOut});

		////
		messageTxt = new Alphabet(0, 180, "", true);
		messageTxt.scrollFactor.set();
		messageTxt.cameras = cameras;
		messageTxt.alignment = CENTER;
		messageTxt.fieldWidth = FlxG.width;
		messageTxt.text = messageStr;
		add(messageTxt);
		
		var divSize:Float = FlxG.width / 2;
		var optionsY:Float = messageTxt.y + messageTxt.height + 180;

		acceptTxt = new Alphabet(0, optionsY, acceptStr, true);
		acceptTxt.scrollFactor.set();
		acceptTxt.cameras = cameras;
		acceptTxt.x = (divSize - acceptTxt.width) / 2;
		add(acceptTxt);

		cancelTxt = new Alphabet(0, optionsY, cancelStr, true);
		cancelTxt.scrollFactor.set();
		cancelTxt.cameras = cameras;
		cancelTxt.x = divSize + (divSize - cancelTxt.width) / 2;
		add(cancelTxt);

		acceptTxt.alpha = 0.6;
		acceptTxt.scale.set(0.75, 0.75);
		cancelTxt.alpha = 0.6;
		cancelTxt.scale.set(0.75, 0.75);
	}

	function changeSelected(val:Bool)
	{
		if (curSelected == val)
			return;
		
		curSelected = val;
		FlxG.sound.play(Paths.sound('scrollMenu'));

		if (curSelected == true) {
			acceptTxt.alpha = 1.0;
			acceptTxt.scale.set(1.0, 1.0);
			cancelTxt.alpha = 0.6;
			cancelTxt.scale.set(0.75, 0.75);
		}else if (curSelected == false) {
			cancelTxt.alpha = 1.0;
			cancelTxt.scale.set(1.0, 1.0);
			acceptTxt.alpha = 0.6;
			acceptTxt.scale.set(0.75, 0.75);
		}

		if (changeCallback != null)
			changeCallback(curSelected);
	}

	function acceptSelected()
	{
		switch(curSelected) {
			case null:

			case true:
				if (acceptCallback != null)
					acceptCallback();
				close();
			
			case false:
				FlxG.sound.play(Paths.sound('cancelMenu'), 1);
				if (cancelCallback != null)
					cancelCallback();
				close();
		}
	}

	override function update(elapsed:Float)
	{
		if (controls.UI_LEFT_P)
			changeSelected(true);
		
		if (controls.UI_RIGHT_P)
			changeSelected(false);
		
		if (controls.ACCEPT)
			acceptSelected();

		super.update(elapsed);
	}
}