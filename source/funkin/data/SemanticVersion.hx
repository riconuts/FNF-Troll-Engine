package funkin.data;

using StringTools;

abstract SemanticVersion(String) from String to String
{
	public var major(get, set):Int;
	public var minor(get, set):Int;
	public var patch(get, set):Int;
	public var prerelease_id(get, set):String;
	inline function get_prerelease_id(){
		var shit = this.split("-");
		shit.shift();
		return shit.join("-");
	}

	inline function set_prerelease_id(id:String)
	{
		var shit = this.split("-");
		var prefix = shit.shift();
		this = prefix + "-" + id;
		return id;
	}

	inline function strip_prerelease(){
		return this.split("-").shift();
	}

	inline function get_major()
		return Std.parseInt(strip_prerelease().split(".")[0]);
	

	inline function get_minor()
		return Std.parseInt(strip_prerelease().split(".")[1]);
	

	inline function get_patch()
		return Std.parseInt(strip_prerelease().split(".")[2]);

	inline function set_major(i:Int)
	{
		var s = Std.string(i);
		this = '${s}.${minor}.${patch}-${prerelease_id}';
		return i;
	}

	inline function set_minor(i:Int)
	{
		var s = Std.string(i);
		this = '${major}.${s}.${patch}-${prerelease_id}';
		return i;
	}

	inline function set_patch(i:Int)
	{
		var s = Std.string(i);
		this = '${major}.${minor}.${s}-${prerelease_id}';
		return i;
	}

	// operators
	@:op(A==B)
	static function eq(A:SemanticVersion, B:SemanticVersion)return A.major == B.major && A.minor == B.minor && A.patch == B.patch && A.prerelease_id == B.prerelease_id;
	
	@:op(A >= B)
	static function gte(A:SemanticVersion, B:SemanticVersion):Bool
	{
		if (A.major >= B.major || A.minor >= B.minor || A.patch >= B.patch)
		{
			return true;
		}
		else
		{
			if (A.prerelease_id.trim() == '' && B.prerelease_id.trim() != '')
			{
				return true;
			}
			else if (B.prerelease_id.trim() != '' && A.prerelease_id >= B.prerelease_id)
			{
				return true;
			}
			else
				return false;
		}

		return false;
	}

	@:op(A > B)
	static function gt(A:SemanticVersion, B:SemanticVersion):Bool{
		if(A.major > B.major || A.minor > B.minor || A.patch > B.patch){
			return true;
		}else{
			if(A.prerelease_id.trim() == '' && B.prerelease_id.trim() != ''){
				return true;
			}
			else if (B.prerelease_id.trim() != '' && A.prerelease_id > B.prerelease_id){
				return true;
			}
			else
				return false;
		}

		return false;
	}
}