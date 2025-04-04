package funkin.states.options;

import flixel.text.FlxText;
import openfl.geom.Rectangle;
import flixel.addons.ui.FlxUI9SliceSprite;

class KeyboardNavHelper<BindButton> {
	public var bg:FlxSprite; // for camera
	public var text:FlxText; // to highlight
	public var onTextPress:Dynamic; // for reset to defaults text
	public var bindButtons:Null<Array<BindButton>>;

	public function new(text:FlxText, bg:FlxSprite, ?bindButtons:Array<BindButton>, ?onTextPress:Dynamic)
	{
		this.text = text;
		this.bg = bg;
		this.bindButtons = bindButtons;
		this.onTextPress = onTextPress;
	}
}

class BindButton<T:Int> extends FlxUI9SliceSprite
{
	public var textObject:FlxText;
	public var bind(default, set):T;

	function _getBindedName(id:T)
		return Std.string("Sowy"+id);

	public function new(?x:Float, ?y:Float, ?rect:Rectangle, ?bind:T){
		super(x, y, Paths.image("optionsMenu/backdrop"), rect, [22, 22, 89, 89]);

		if (bind == null)
			bind = cast -1; // FUCK YOU

		textObject = new FlxText(x, y, 0, _getBindedName(bind), 16);
		textObject.setFormat(Paths.font("quantico.ttf"), 24, 0xFFFFFFFF, CENTER);
		textObject.updateHitbox();
		textObject.y += (height - textObject.height) / 2;
		this.bind = bind;
	}

	function set_bind(key:T){
		textObject.text = _getBindedName(key);
		return bind = key;
	}

	override function draw(){
		super.draw();
		textObject.draw();
	}

	override function kill()
	{
		super.kill();
		textObject.kill();
	}

	override function revive()
	{
		super.revive();
		textObject.revive();
	}

	override function destroy()
	{
		super.destroy();
		textObject.destroy();
	}

	override function set_active(val:Bool)
	{
		textObject.active = val;
		return active = val;
	}

	override function set_visible(val:Bool)
	{
		textObject.visible = val;
		return visible = val;
	}

	override function set_cameras(val:Array<FlxCamera>)
	{
		textObject.cameras = val;
		return super.set_cameras(val);
	}

	override function set_x(val:Float)
	{
		if (textObject!=null)
			textObject.x += val - x;
		return x = val;
	}

	override function set_y(val:Float)
	{
		if (textObject != null)
			textObject.y += val - y;

		return y = val;
	}

	override function update(elapsed:Float){
		textObject.fieldWidth = width;
		super.update(elapsed);
		textObject.update(elapsed);
	}
}