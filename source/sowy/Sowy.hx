package sowy;

class Sowy
{
    public static macro function getBuildDate()
    {
        var daDate = Date.now();
        
        var monthsPassed = (daDate.getUTCFullYear() - 2023) * 12 + (daDate.getUTCMonth() + 1);

        var daString = '$monthsPassed-${daDate.getDate()}';

        return macro $v{daString};
    }
}