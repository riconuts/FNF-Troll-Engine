package funkin.objects;

import flixel.util.FlxSignal.FlxTypedSignal;

class FlxSignalHolder<T> extends FlxBasic {
	private final signal:FlxTypedSignal<T>;
	private final func:T;

	public function new(signal:FlxTypedSignal<T>, func:T) {
		(this.signal = signal).add(this.func = func);

		super();
		this.exists = false;
	}

	override public function destroy() {
		signal.remove(func);
		super.destroy();
	}
}