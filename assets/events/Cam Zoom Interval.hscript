function onTrigger(value1, value2, time)
{
    var beat = Std.parseInt(value1);
    if(beat == null || Math.isNaN(beat))beat = 4;
    var intensity = Std.parseFloat(value2);
    if(intensity == null || Math.isNaN(intensity))intensity = 1;

    game.zoomEveryBeat = beat;
    game.camZoomingMult = intensity;
}