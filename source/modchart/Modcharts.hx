package modchart;

import flixel.math.FlxAngle;
import modchart.events.CallbackEvent;
import modchart.*;

class Modcharts {
    static function numericForInterval(start, end, interval, func){
        var index = start;
        while(index < end){
            func(index);
            index += interval;
        }
    }

    static var songs = ["endless"];
	public static function isModcharted(songName:String){
		if (songs.contains(songName.toLowerCase()))
            return true;

        // add other conditionals if needed
        
        //return true; // turns modchart system on for all songs, only use for like.. debugging
        return false;
    }
    
    public static function loadModchart(modManager:ModManager, songName:String){
        switch (songName.toLowerCase()){
            case 'endless':

                modManager.setPercent('tipZOffset', 100);
                modManager.setPercent("unboundedReverse", 1);
                modManager.setPercent("dark", 100);
                modManager.setPercent("alpha", 100);
                modManager.setPercent("stealth", 10, 1);
                modManager.setPercent("opponentSwap", 50);

                modManager.queueSetP(16, "dark", 0, 1);
                modManager.queueSetP(16, "alpha", 25, 1);
                modManager.queueSetP(16, "alpha", 0, 0);

                modManager.queueSetP(80, "dark", 0, 0);
                modManager.queueSetP(80, "squish", 75);
                modManager.queueEaseP(80, 84, "squish", 0, "cubeOut");
                modManager.queueEaseP(80, 84, "opponentSwap", 0, "quadOut");
                modManager.queueEaseP(80, 84, "stealth", 0, "quadOut", 1);
                modManager.queueEaseP(80, 84, "alpha", 0, "quadOut", 1);

                modManager.queueSetP(144, "beat", 75);
                modManager.queueSetP(392, "beat", 0);
                modManager.queueSetP(408, "beat", 75);
                modManager.queueSetP(912, "beat", 0);

                // early drums
                
                var kicks = [
                    16,
                    80,
                    90,
                    96,
                    106,
                    112,
                    120,
                    128,
                    132,
                    136,
                    140,
                    140.5,
                    141,
                    141.5,
                    142,
                    142.5,
                    143,
                    143.5,
                ];

                var m = 1;
                for(i in 0...kicks.length){
                    m = m * -1;
                    var step = kicks[i];
                    if(step >= 140){
                        var wow = i % 2;
                        if (wow==0) {
                            modManager.queueEaseP(step, step + 0.5, 'invert', 100, 'quadOut');
                        }else if(wow == 1){
                            modManager.queueEaseP(step, step + 0.5, 'invert', 0, 'quadOut');
                        }
					}
					else
					{
						modManager.queueSet(step, 'transformX', 50 * m);
						modManager.queueSetP(step, 'tipsy', 100 * m);
						modManager.queueEaseP(step, step + 6, 'tipsy', 0, 'cubeOut');
						modManager.queueEase(step, step + 6, 'transformX', 0, 'quartOut');
					}
                }

                modManager.queueEaseP(144, 146, 'flip', 0, 'quadOut');
                modManager.queueEaseP(144, 146, 'invert', 0, 'quadOut');
                // most of the early part of the modchart w/ the drums
                

                var kicks = [];
                var snares = [];
                /*for i = 144, 392, 8 do
                    table.insert(kicks, i)
                end

                for i = 408, 904, 8 do
                    table.insert(kicks, i)
                end
                

                for i = 144 + 4, 904 + 4, 8 do
                    table.insert(snares, i)
                end*/
                numericForInterval(144, 392, 8, function(i){
                    kicks.push(i);
                });
                numericForInterval(408, 904, 8, function(i){
                    kicks.push(i);
                });

                 numericForInterval(144+4, 904+4, 8, function(i){
                    snares.push(i);
                });


                for (i in 0...kicks.length){
                    var step = kicks[i];
                    modManager.queueSetP(step, 'tipsy', 125);
                    modManager.queueSetP(step, 'tipsyOffset', 25);
                    modManager.queueSet(step, 'transformX', -75);
                    modManager.queueSetP(step, 'mini', -25);
                    modManager.queueEase(step, step + 4, 'transformX', 0, 'cubeOut');
                    modManager.queueEaseP(step, step + 4, 'tipsy', 0, 'cubeOut');
                    modManager.queueEaseP(step, step + 4, 'tipsyOffset', 0, 'cubeOut');
                    modManager.queueEaseP(step, step + 4, "mini", 0, "quadOut");
                }


                for (i in 0...snares.length){
                    var step = snares[i];
                    modManager.queueSet(step, 'transformX', -150);
                    modManager.queueSetP(step, 'mini', -25);
                    modManager.queueEase(step, step + 4, 'transformX', 0, 'cubeOut');
                    modManager.queueEaseP(step, step + 4, "mini", 0, "quadOut");
                }

                

                modManager.queueEaseP(268, 272, "alpha", 75, "cubeOut", 1);


                // making the receptors move left/right
                /*var a = 0.5;
                var lCD;
                modManager.queueFunc(272, 400, function(cDS)
                    if(lCD == nil)then
                        lCD = cDS
                    end
                    a = a + (cDS - lCD);
                    lCD = cDS;
                    var val = math.cos(a / 4);
                    modManager.set("opponentSwap", 50 - (50 * val))
                end)*/

                // detected
                modManager.queueFunc(272, 400, function(event:CallbackEvent, cDS:Float){
                    var pos = (cDS - 272) / 4;

                    for(pn in 1...3){
                        for(col in 0...4){
                            var cPos = col * -112;
                            if (pn == 2) cPos = cPos - 620;
                            var c = (pn - 1) * 4 + col;
                            var mn = pn == 2?0:1;


                            var cSpacing = 112;

                            var newPos = (((col * cSpacing + (pn - 1) * 640 + pos * cSpacing) % (1280))) - 176;
                            modManager.setValue("transform" + col + "X", cPos + newPos, mn);
                        }
                    }
                });

                for(i in 0...4)
                    modManager.queueEase(400, 402, "transform" + i + "X", 0, "quadOut");
                
                
                // taking turns
                modManager.queueSetP(400, "squish", 75, 0);
                modManager.queueSetP(400, "squish", 125, 1);
                modManager.queueEaseP(400, 402, "squish", 0, "cubeOut");
                modManager.queueEaseP(400, 402, "alpha", 0, "cubeOut", 1);
                modManager.queueEaseP(400, 402, "opponentSwap", 50, "quadOut", 0);
                modManager.queueEaseP(400, 402, "opponentSwap", -125, "quadOut", 1);

                // elastic 1
                modManager.queueEaseP(424, 428, "reverse", -50, "quartIn", 0);
                modManager.queueEaseP(428, 430, "reverse", 500, "quadIn", 0);
                modManager.queueSetP(430, "reverse", -250, 0);
                modManager.queueEaseP(430, 432, "reverse", 0, "backOut", 0);

                // elastic 2
                modManager.queueEase(456, 460, "centerrotateY", FlxAngle.asRadians(85), "quadIn", 0);
                modManager.queueEase(460, 470, "centerrotateY", FlxAngle.asRadians(-360)*3, "elasticOut", 0);
                modManager.queueSet(470, "centerrotateY", 0, 0);

                // elastic 3
                modManager.queueEase(488, 492, "centerrotateX", FlxAngle.asRadians(-25), "quadIn", 0);
                modManager.queueEase(492, 500, "centerrotateX", FlxAngle.asRadians(180), "elasticOut", 0);
                modManager.queueSet(500, "centerrotateX", 0, 0);
                modManager.queueSetP(500, "reverse", 100, 0);

                // elastic 4
                modManager.queueEaseP(520, 524, "flip", 25, "quadIn", 0);
                modManager.queueEaseP(520, 524, "opponentSwap", 100, "quadIn", 0);
                modManager.queueEaseP(524, 532, "opponentSwap", -125, "elasticOut", 0);

                modManager.queueEaseP(524, 532, "flip", 0, "elasticOut", 0);
                modManager.queueSetP(524, "squish", 175, 0);
                modManager.queueSetP(524, "squish", 125, 1);
                modManager.queueEaseP(524, 526, "squish", 0, "cubeOut");
                modManager.queueEaseP(524, 526, "opponentSwap", 50, "quadOut", 1);

                modManager.queueSetP(528, 'reverse', 100, 0);

                // elastic 1 tenma
                modManager.queueEaseP(552, 556, "reverse", -50, "quartIn", 1);
                modManager.queueEaseP(556, 558, "reverse", 500, "quadIn", 1);
                modManager.queueSetP(558, "reverse", -250, 1);
                modManager.queueEaseP(558, 560, "reverse", 0, "backOut", 1);

                // elastic 2 tenma
                modManager.queueEase(584, 588, "centerrotateY", FlxAngle.asRadians(85), "quadIn", 1);
                modManager.queueEase(588, 598, "centerrotateY", FlxAngle.asRadians(-360) * 3, "elasticOut", 1);
                modManager.queueSet(598, "centerrotateY", 0, 1);

                // elastic 3 tenma
                modManager.queueEase(616, 620, "centerrotateX", FlxAngle.asRadians(-25), "quadIn", 1);
                modManager.queueEase(620, 628, "centerrotateX", FlxAngle.asRadians(180), "elasticOut", 1);
                modManager.queueSet(628, "centerrotateX", 0, 1);
                modManager.queueSetP(628, "reverse", 100, 1);

                // elastic 4 tenma
                modManager.queueEaseP(648, 652, "flip", 25, "quadIn", 1);
                modManager.queueEaseP(648, 652, "opponentSwap", 100, "quadIn", 1);
                modManager.queueEaseP(652, 660, "opponentSwap", -125, "elasticOut", 1);

                modManager.queueEaseP(652, 660, "flip", 0, "elasticOut", 1);
                modManager.queueSetP(652, "squish", 175, 1);
                modManager.queueSetP(652, "squish", 125, 0);
                modManager.queueEaseP(652, 654, "squish", 0, "cubeOut");
                modManager.queueEaseP(652, 654, "opponentSwap", 50, "quadOut", 0);
                modManager.queueEaseP(652, 654, "opponentSwap", -125, "quadOut", 1);

                /*
                modManager.queueSetP(652, 'reverse', 100, 0)
                modManager.queueSetP(652, "squish", 125)
                modManager.queueEaseP(652, 654, "squish", 0, "cubeOut")
                modManager.queueEaseP(652, 654, "opponentSwap", 50, "quadOut", 0)
                modManager.queueEaseP(652, 654, "opponentSwap", -125, "quadOut", 1)

                modManager.queueSetP(652, 'reverse', 100, 1)*/
                modManager.queueSetP(784, "squish", 125);
                modManager.queueEaseP(784, 786, "squish", 0, "cubeOut");
                modManager.queueEaseP(784, 786, "opponentSwap", -125, "quadOut", 0);
                modManager.queueEaseP(784, 786, "opponentSwap", 50, "quadOut", 1);


                modManager.queueSetP(844, 'reverse', 0, 0);
                modManager.queueSetP(844, "squish", 75);
                modManager.queueEaseP(844, 848, "reverse", 0, "quadOut", 1);
                modManager.queueEaseP(844, 846, "squish", 0, "cubeOut");
                modManager.queueEaseP(844, 846, "opponentSwap", 0, "quadOut");

                modManager.queueSetP(912, "squish", 65);
                //modManager.queueSetP(912, "opponentSwap", 12.5, 0)
                //modManager.queueSetP(912, "opponentSwap", -25, 1)
                modManager.queueEaseP(912, 914, "opponentSwap", 12.5, "cubeOut", 0);
                modManager.queueEaseP(912, 914, "opponentSwap", -25, "cubeOut", 1);
                modManager.queueEaseP(912, 914, "squish", 0, "cubeOut");
                modManager.queueEase(912, 914, "centerrotateZ", FlxAngle.asRadians(-5), "cubeOut", 0);

                // 1
                modManager.queueSetP(916, "squish", 65);
                //modManager.queueSetP(916, "opponentSwap", 25, 0)
                //modManager.queueSetP(916, "opponentSwap", -50, 1)
                modManager.queueEaseP(916, 918, "flip", 100, "quadOut", 0);
                modManager.queueEaseP(916, 918, "opponentSwap", 25, "cubeOut", 0);
                modManager.queueEaseP(916, 918, "opponentSwap", -50, "cubeOut", 1);
                modManager.queueEaseP(916, 918, "squish", 0, "cubeOut");
                modManager.queueEase(916, 918, "centerrotateZ", FlxAngle.asRadians(10), "cubeOut", 0);


                // 2
                modManager.queueEaseP(920, 922, "flip", 0, "quadOut", 0);
                modManager.queueEaseP(920, 922, "invert", 100, "quadOut", 0);
                modManager.queueSetP(920, "squish", 65);
                //modManager.queueSetP(920, "opponentSwap", 37.5, 0)
                //modManager.queueSetP(920, "opponentSwap", -75, 1)
                modManager.queueEaseP(920, 922, "opponentSwap", 37.5, "cubeOut", 0);
                modManager.queueEaseP(920, 922, "opponentSwap", -75, "cubeOut", 1);
                modManager.queueEaseP(920, 922, "squish", 0, "cubeOut");

                modManager.queueEase(920, 922, "centerrotateZ", FlxAngle.asRadians(-15), "cubeOut", 0);

                // 3, hit it
                modManager.queueSetP(924, "squish", 65);
                //modManager.queueSetP(924, "opponentSwap", 50, 0)
                //modManager.queueSetP(924, "opponentSwap", -100, 1)
                modManager.queueEaseP(924, 926, "opponentSwap", 50, "cubeOut", 0);
                modManager.queueEaseP(924, 926, "opponentSwap", -100, "cubeOut", 1);
                modManager.queueEaseP(924, 926, "squish", 0, "cubeOut");
                modManager.queueEase(924, 926, "centerrotateZ", FlxAngle.asRadians(0), "cubeOut", 0);
                modManager.queueEaseP(924, 926, "flip", 0, "quadOut", 0);
                modManager.queueEaseP(924, 926, "invert", 0, "quadOut", 0);


                // bounce :)
                modManager.queueFunc(928, 1312, function(event:CallbackEvent, cDS:Float){
                    var s = cDS - 928;
                    var beat = s / 4;
                    modManager.setValue("transformY-a", -60 * Math.abs(Math.sin(Math.PI * beat)));
                    modManager.setValue("transformX-a", 30 * Math.cos(Math.PI * beat));
                    
                });

                modManager.queueEaseP(1312, 1316, "transformY-a", 0, 'quadOut');
                modManager.queueEase(1312, 1316, "transformX-a", 0, 'quadOut');
                // taking turns again, tenma singing
                modManager.queueEaseP(928, 936, "opponentSwap", 50, "quadOut", 1);
                modManager.queueEaseP(928, 936, "opponentSwap", -25, "quadOut", 0);

                modManager.queueEaseP(928, 936, "transformY", 75, "quadOut", 0);
                modManager.queueEase(928, 936, "transform0X", 0, "quadOut", 0);
                modManager.queueEase(928, 936, "transform1X", -32, "quadOut", 0);
                modManager.queueEase(928, 936, "transform2X", -32*2, "quadOut", 0);
                modManager.queueEase(928, 936, "transform3X", -32*3, "quadOut", 0);
                modManager.queueEaseP(928, 936, "mini", 25, "quadOut", 0);
                modManager.queueEaseP(928, 936, "alpha", 50, "quadOut", 0);

                // taking turns again, bf singing
                modManager.queueEaseP(992, 1000, "opponentSwap", 50, "quadOut", 0);
                modManager.queueEaseP(992, 1000, "opponentSwap", -25, "quadOut", 1);

                modManager.queueEaseP(992, 1000, "transformY", 0, "quadOut", 0);
                modManager.queueEase(992, 1000, "transform0X", 0, "quadOut", 0);
                modManager.queueEase(992, 1000, "transform1X", 0, "quadOut", 0);
                modManager.queueEase(992, 1000, "transform2X", 0, "quadOut", 0);
                modManager.queueEase(992, 1000, "transform3X", 0, "quadOut", 0);
                modManager.queueEaseP(992, 1000, "mini", 0, "quadOut", 0);
                modManager.queueEaseP(992, 1000, "alpha", 0, "quadOut", 0);

                modManager.queueEaseP(992, 1000, "transformY", 75, "quadOut", 1);
                modManager.queueEase(992, 1000, "transform0X", 32 * 3, "quadOut", 1);
                modManager.queueEase(992, 1000, "transform1X", 32 * 2, "quadOut", 1);
                modManager.queueEase(992, 1000, "transform2X", 32, "quadOut", 1);
                modManager.queueEase(992, 1000, "transform3X", 0, "quadOut", 1);
                modManager.queueEaseP(992, 1000, "mini", 25, "quadOut", 1);
                modManager.queueEaseP(992, 1000, "alpha", 50, "quadOut", 1);

                // taking turns again, tenma singing

                modManager.queueEaseP(1056, 1064, "opponentSwap", 50, "quadOut", 1);
                modManager.queueEaseP(1056, 1064, "opponentSwap", -25, "quadOut", 0);

                modManager.queueEaseP(1056, 1064, "transformY", 0, "quadOut", 1);
                modManager.queueEase(1056, 1064, "transform0X", 0, "quadOut", 1);
                modManager.queueEase(1056, 1064, "transform1X", 0, "quadOut", 1);
                modManager.queueEase(1056, 1064, "transform2X", 0, "quadOut", 1);
                modManager.queueEase(1056, 1064, "transform3X", 0, "quadOut", 1);
                modManager.queueEaseP(1056, 1064, "mini", 0, "quadOut", 1);
                modManager.queueEaseP(1056, 1064, "alpha", 0, "quadOut", 1);

                modManager.queueEaseP(1056, 1064, "transformY", 75, "quadOut", 0);
                modManager.queueEase(1056, 1064, "transform0X", 0, "quadOut", 0);
                modManager.queueEase(1056, 1064, "transform1X", -32, "quadOut", 0);
                modManager.queueEase(1056, 1064, "transform2X", -32 * 2, "quadOut", 0);
                modManager.queueEase(1056, 1064, "transform3X", -32 * 3, "quadOut", 0);
                modManager.queueEaseP(1056, 1064, "mini", 25, "quadOut", 0);
                modManager.queueEaseP(1056, 1064, "alpha", 50, "quadOut", 0);

                modManager.queueEaseP(1056, 1064, "opponentSwap", 50, "quadOut", 1);
                modManager.queueEaseP(1056, 1064, "opponentSwap", -25, "quadOut", 0);

                // taking turns again, bf singing
                modManager.queueEaseP(1184, 1192, "opponentSwap", 50, "quadOut", 0);
                modManager.queueEaseP(1184, 1192, "opponentSwap", -25, "quadOut", 1);

                modManager.queueEaseP(1184, 1192, "transformY", 0, "quadOut", 0);
                modManager.queueEase(1184, 1192, "transform0X", 0, "quadOut", 0);
                modManager.queueEase(1184, 1192, "transform1X", 0, "quadOut", 0);
                modManager.queueEase(1184, 1192, "transform2X", 0, "quadOut", 0);
                modManager.queueEase(1184, 1192, "transform3X", 0, "quadOut", 0);
                modManager.queueEaseP(1184, 1192, "mini", 0, "quadOut", 0);
                modManager.queueEaseP(1184, 1192, "alpha", 0, "quadOut", 0);

                modManager.queueEaseP(1184, 1192, "transformY", 75, "quadOut", 1);
                modManager.queueEase(1184, 1192, "transform0X", 32 * 3, "quadOut", 1);
                modManager.queueEase(1184, 1192, "transform1X", 32 * 2, "quadOut", 1);
                modManager.queueEase(1184, 1192, "transform2X", 32, "quadOut", 1);
                modManager.queueEase(1184, 1192, "transform3X", 0, "quadOut", 1);
                modManager.queueEaseP(1184, 1192, "mini", 25, "quadOut", 1);
                modManager.queueEaseP(1184, 1192, "alpha", 50, "quadOut", 1);

                modManager.queueEaseP(1312, 1316, "alpha", 0, "quadOut", 0);
                modManager.queueEaseP(1312, 1316, "infinite", 100, "quadOut", 0);
                modManager.queueEaseP(1312, 1316, "alpha", 100, "quadOut", 1);
                modManager.queueSetP(1312, "noteSpawnTime", 2000, 0);

                modManager.queueSetP(1316, "opponentSwap", 0);
                modManager.queueSetP(1316, "transformY", 0, 1);
                modManager.queueSet(1316, "transform0X", 0, 1);
                modManager.queueSet(1316, "transform1X", 0, 1);
                modManager.queueSet(1316, "transform2X", 0, 1);
                modManager.queueSet(1316, "transform3X", 0, 1);
                modManager.queueSetP(1316, "mini", 0, 1);

                modManager.queueSetP(1440, "noteSpawnTime", 1250, 0);
                modManager.queueEaseP(1440, 1448, "alpha", 0, "quadOut", 0);
                modManager.queueEaseP(1440, 1448, "infinite", 0, "quadOut", 0);
                modManager.queueEaseP(1440, 1448, "alpha", 0, "quadOut");

                for(i in 0...4){
                    modManager.queueEaseP(1696 + i / 2, 1700 + i / 2, "reverse" + i, -25, "quadOut");
                    modManager.queueEaseP(1700 + i / 2, 1702 + i / 2, "reverse" + i, 200, "quadIn");
                }


                // late drums
                
                    var kicks = [
                        1440,
                        1504,
                        1568,
                        1578,
                        1584,
                        1594,
                        1600,
                        1610,
                        1616,
                        1626,
                        1632,
                        1642,
                        1648,
                        1658,
                        1664,
                        1674,
                        1680,
                        1690,
                    ];

                    var m = 1;
                    for (i in 0...kicks.length){
                        m = m * -1;
                        var step = kicks[i];
                        modManager.queueSet(step, 'transformX', 50 * m);
                        modManager.queueSetP(step, 'tipsy', 100 * m);
                        modManager.queueSetP(step, 'drunk', 125 * m);
                        
                        modManager.queueEaseP(step, step + 8, 'tipsy', 0, 'cubeOut');
                        modManager.queueEaseP(step, step + 8, 'drunk', 0, 'elasticOut');
                        modManager.queueEase(step, step + 8, 'transformX', 0, 'cubeOut');
                    }
                
            default:
                
        }
    }
}