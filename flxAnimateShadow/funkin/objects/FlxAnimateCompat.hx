package funkin.objects;
#if USING_FLXANIMATE
using StringTools;

import flxanimate.FlxAnimate;

class FlxAnimateCompat extends FlxAnimate {
	public function new(X:Float = 0, Y:Float = 0, ?Path:String, ?Settings:Settings){
		var newPath = Path;

		if(newPath.startsWith("assets/")) // Trim the "assets/"
			newPath = newPath.substr(7);

		
		newPath = Paths.getPath(newPath);

		if (!Paths.isDirectory(newPath) || newPath.endsWith(".zip") && !Paths.exists(newPath))
			newPath = Path;

		super(X, Y, newPath, Settings);
	}
}
#else
class FlxAnimateCompat{}
#end