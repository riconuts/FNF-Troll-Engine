package sowy;

// what DOES sowy mean
using StringTools;

class Sowy
{
    public static macro function getBuildDate()
    {
        var daDate = Date.now();
        
        var monthsPassed = Std.string((daDate.getUTCFullYear() - 2023) * 12 + (daDate.getUTCMonth() + 1));
        if (monthsPassed.length == 1)
            monthsPassed = "0"+monthsPassed;

        var theDays = Std.string(daDate.getDate());
        if (theDays.length == 1)
            theDays = "0"+theDays;

        var daString = '$monthsPassed-$theDays';

        return macro $v{daString};
    }

    public static macro function getDefines() 
    {
        return macro $v{haxe.macro.Context.getDefines()};    
    }
}