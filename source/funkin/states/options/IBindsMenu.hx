package funkin.states.options;

import flixel.input.gamepad.FlxGamepadInputID;
import flixel.input.keyboard.FlxKey;
import haxe.extern.EitherType;

typedef Key_T = EitherType<FlxKey, FlxGamepadInputID>;

interface IBindsMenu<T:Key_T> {
    var changedBind:(String, Int, T) -> Void;
}