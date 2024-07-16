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

	static public function requestOverride(state:MusicBeatState):Null<HScriptOverridenState>
	{
		if (state == null || !state.canBeScripted)
			return null;

		var cl = Type.getClass(state);
		var fullName = Type.getClassName(cl);
		for (filePath in Paths.getFolders("states"))
		{
			var fileName = 'override/$fullName.hscript';
			var fullPath = filePath + fileName;
			if (Paths.exists(fullPath))
				return new HScriptOverridenState(cl, fullPath);
		}

		return null;
	}

	static public function fromAnother(state:HScriptOverridenState)
	{
		return new HScriptOverridenState(state.parentClass, state.scriptPath);
	}

	inline private static function getShortClassName(cl):String
		return Type.getClassName(cl).split('.').pop();
}