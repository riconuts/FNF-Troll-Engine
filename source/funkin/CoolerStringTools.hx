package funkin;

class CoolerStringTools {
	static public function isAlpha(s:String):Bool
		return s.toLowerCase() != s.toUpperCase();

	static public function capitalize(s:String):String {
		return switch(s.length) {
			case 0: "";
			case 1: s.toUpperCase();
			default:
				var buf = new StringBuf();
				var pc = " ";
				for (i in 0...s.length) {
					var c = s.charAt(i);
					buf.add(isAlpha(pc) ? c.toLowerCase() : c.toUpperCase());
					pc = c;
				}
				buf.toString();
		}

		/*
		var spaced = str.split(" ");
		for(i in 0...spaced.length)
			spaced[i] = spaced[i].substr(0, 1).toUpperCase() + spaced[i].substring(1).toLowerCase();
		

		return spaced.join(" ");
		*/
	}
}