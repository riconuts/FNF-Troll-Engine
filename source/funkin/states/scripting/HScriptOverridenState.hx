#if SCRIPTABLE_STATES
package funkin.states.scripting;

class HScriptOverridenState extends HScriptedState 
{
	public var parentClass:Class<MusicBeatState> = null;

	override function _startExtensionScript(folder:String, scriptName:String) 
		return;

	private function new(parentClass:Class<MusicBeatState>, scriptFullPath:String) 
	{
		if (parentClass == null || scriptFullPath == null) {
			trace("Uh oh!", parentClass, scriptFullPath);
			return;
		}

		this.parentClass = parentClass;
		
		super(scriptFullPath, [getShortClassName(parentClass) => parentClass]);
	}

	static public function findClassOverride(cl:Class<MusicBeatState>):Null<HScriptOverridenState> 
	{
		var fullName = Type.getClassName(cl);
		for (filePath in Paths.getFolders("states"))
		{
			var folderedName = 'override/${fullName.split(".").join("/")}';
			var fileName = 'override/$fullName'; // deprecated
			for(ext in Paths.HSCRIPT_EXTENSIONS){
				var fullPath = filePath + fileName + '.$ext';
				var fullFolderPath = filePath + folderedName + '.$ext';
				// TODO: Trim off the funkin.states and check that, too.
				
				if (Paths.exists(fullFolderPath))
					return new HScriptOverridenState(cl, fullFolderPath);
				else if (Paths.exists(fullPath))
					return new HScriptOverridenState(cl, fullPath);
			}
		}

		return null;
	}

	static public function requestOverride(state:MusicBeatState):Null<HScriptOverridenState>
	{
		if (state != null && state.canBeScripted)
			return findClassOverride(Type.getClass(state));
		
		return null;
	}

	static public function fromAnother(state:HScriptOverridenState):Null<HScriptOverridenState>
	{
		return Paths.exists(state.scriptPath) ? new HScriptOverridenState(state.parentClass, state.scriptPath) : null;
	}

	inline private static function getShortClassName(cl):String
		return Type.getClassName(cl).split('.').pop();
}
#end