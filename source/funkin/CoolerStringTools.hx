package funkin;

class CoolerStringTools {
    static public function capitalize(str:String){
        var spaced = str.split(" ");
        for(i in 0...spaced.length)
            spaced[i] = spaced[i].substr(0, 1).toUpperCase() + spaced[i].substring(1).toLowerCase();
        

		return spaced.join(" ");
    }
}