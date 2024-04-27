package sowy;

import flash.ui.Mouse;
import flash.ui.MouseCursor;
import flixel.ui.FlxButton;

class SowyBaseButton extends FlxButton{
	public function new(X:Float = 0, Y:Float = 0, ?OnClick:Void->Void)
	{
		super(X, Y, OnClick);

		onOver.callback = function(){
			onover();
		}
		onOut.callback = function(){
			onout();
		}
	}

	// wtf it works
	function onover():Void{
		Mouse.cursor = MouseCursor.BUTTON;
	}
	function onout():Void{
		Mouse.cursor = MouseCursor.AUTO;
	}
}