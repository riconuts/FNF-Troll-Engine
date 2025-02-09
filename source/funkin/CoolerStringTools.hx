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
	}
}