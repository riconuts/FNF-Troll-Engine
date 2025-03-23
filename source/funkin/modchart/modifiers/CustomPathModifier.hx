package funkin.modchart.modifiers;

typedef PathInfo = {
	var position:Vector3;
	var dist:Float;
	var start:Float;
	var end:Float;
}

class CustomPathModifier extends NoteModifier {
	var moveSpeed:Float;
	var pathData:Array<Array<PathInfo>> = [];
	var totalDists:Array<Float> = [];

	override function getName() 
		return 'basePath';

	public function getMoveSpeed()
		return 5000;

	public function getPath():Array<Array<Vector3>>
		return [];

	public function new(modMgr:ModManager, ?parent:Modifier){
		super(modMgr, parent);
		moveSpeed = getMoveSpeed();

		for (col => points in getPath()) {
			var dirPath:Array<PathInfo> = [];
			var totalDist:Float = 0.0;
			
			for (idx => pos in points) {
				if (idx != 0) {
					var last = dirPath[idx-1];
					totalDist += Vector3.distance(last.position, pos);
					last.end = totalDist;
					last.dist = last.start - totalDist; // used for interpolation
				}

				dirPath.push({
					position: pos,
					start: totalDist,
					end: 0,
					dist: 0
				});
			}

			totalDists[col] = totalDist;
			pathData[col] = dirPath;
		}

		if (Main.showDebugTraces) {
			for(col in 0...totalDists.length) {
				trace(col, totalDists[col]);
			}
		}
	}


	override function getPos(visualDiff:Float, timeDiff:Float, beat:Float, pos:Vector3, data:Int, player:Int, obj:FlxSprite, field:NoteField)
	{
		var value:Float = getValue(player);
		if (value == 0) return pos;

		//var vDiff = Math.abs(timeDiff);
		var vDiff = timeDiff;
		// tried to use visualDiff but didnt work :(
		// will get it working later

		var progress = (vDiff / -moveSpeed) * totalDists[data];
		var daPath = pathData[data];

		if (progress <= 0) return pos.lerp(daPath[0].position, value, pos);
		var outPos = pos.clone();

		for (idx in 0...daPath.length){
			var cData = daPath[idx];
			var nData = daPath[idx+1];
			if (nData != null && cData != null){
				if (progress > cData.start && progress < cData.end){
					var alpha = (cData.start - progress) / cData.dist;
					var interpPos:Vector3 = cData.position.lerp(nData.position,alpha);
					pos.lerp(interpPos, value, outPos);
				}
			}
		}
		return outPos;
	}
}
