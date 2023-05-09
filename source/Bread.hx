package;
import openfl.display.Bitmap;
class Bread extends Bitmap {
    public function new() {
		super(Paths.image("Garlic-Bread-PNG-Images").bitmap);

		#if flash
		addEventListener(Event.ENTER_FRAME, function(e)
		{
			var time = Lib.getTimer();
			__enterFrame(time - currentTime);
		});
		#end
    }

	@:noCompletion
	private #if !flash override #end function __enterFrame(deltaTime:Float):Void
	{
		x = (stage.stageWidth - width) / 2;
		y = (stage.stageHeight - height) / 2;
        visible = ClientPrefs.bread;
	}
}