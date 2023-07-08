package;

import flixel.*;
import flixel.math.*;
import flixel.system.FlxSound;
import flixel.text.FlxText;
import flixel.tweens.*;
import flixel.util.FlxColor;

#if discord_rpc
import Discord.DiscordClient;
#end
#if sys
import sys.io.File;
import sys.FileSystem;
#end

using StringTools;

class CreditsState extends MusicBeatState
{	
	var bg:FlxSprite;

    var hintBg:FlxSprite;
	var hintText:FlxText;

	var camFollow = new FlxPoint(FlxG.width * 0.5, FlxG.height * 0.5);
	var camFollowPos = new FlxObject();

    var dataArray:Array<Array<String>> = [];
	var titleArray:Array<Alphabet> = [];
	var iconArray:Array<AttachedSprite> = [];

    var curSelected(default, set):Int = 0;
	
	function set_curSelected(sowy:Int)
    {
        if (dataArray[sowy] == null){ // skip empty spaces and titles
            sowy += (sowy < curSelected) ? -1 : 1;

            // also skip any following spaces
            if (sowy >= titleArray.length)
                sowy = sowy - titleArray.length;
            else if (sowy < 0)
                sowy = titleArray.length + sowy;

            return set_curSelected(sowy); 
        }

		if (sowy >= titleArray.length)
			curSelected = sowy - titleArray.length;
		else if (sowy < 0)
			curSelected = titleArray.length + sowy;
		
		curSelected = sowy;
		updateSelection();

		return curSelected;
	}

	override function switchTo(nextState){
		persistentUpdate = false;
		return super.switchTo(nextState);
	}

	override function create()
	{
		#if discord_rpc
		// Updating Discord Rich Presence
		DiscordClient.changePresence("In the Menus", null);
		#end

		persistentUpdate = true;
		
		Paths.clearStoredMemory();
		
		PlayState.isStoryMode = false;

		FlxG.camera.follow(camFollowPos);
		FlxG.camera.bgColor = FlxColor.BLACK;

		////
		camFollowPos.setPosition(camFollow.x, camFollow.y);

		////
		bg = new FlxSprite().loadGraphic(Paths.image("newmenuu/creditsbg"));
		
		if (FlxG.height < FlxG.width)
			bg.setGraphicSize(0, FlxG.height);
		else
			bg.setGraphicSize(FlxG.width, 0);

		bg.screenCenter().scrollFactor.set();
		add(bg);

		var backdrops = new flixel.addons.display.FlxBackdrop(Paths.image('grid'));
		backdrops.velocity.set(30, -30);
		backdrops.scrollFactor.set();
		backdrops.blend = MULTIPLY;
		backdrops.alpha = 0.25;
		backdrops.x -= 10;
		add(backdrops);

        ////
        function loadLine(line:String, ?folder:String)
			addSong(line.split("::"), folder);

		//// Get credits list
		var rawCredits:String;
		var creditsPath:String;

		function getLocalCredits(){
			#if MODS_ALLOWED
			Paths.currentModDirectory = '';
	
			var modCredits = Paths.modsTxt('credits');
			if (Paths.exists(modCredits)){
				trace('using credits from mod folder');
				creditsPath = modCredits;
			}else
			#end{
				trace('using credits from assets folder');
				creditsPath = Paths.txt('credits');
			}

			rawCredits = Paths.getContent(creditsPath);
		}

		// Just in case we forget someone!!!
		#if final
		trace('checking for updated credits');
		var http = new haxe.Http("https://raw.githubusercontent.com/riconuts/troll-engine/main/assets/data/credits.txt");
		http.onData = function(data:String){
			rawCredits = data;

			#if sys
			try{
				trace('updating credits...');
				if (FileSystem.exists("assets/data/credits.txt")){
					trace("updated credits!!!");
					File.saveContent("assets/data/credits.txt", data);
				}else
					trace("no credits file to write to!");
			}catch(e){
				trace("couldn't update credits: " + e);
			}
			#end

			trace('using credits from github');
		}
		http.onError = function(error){
			trace('error: $error');
			getLocalCredits();
		}

		http.request();
		#else
		getLocalCredits();
		#end

		for (i in CoolUtil.listFromString(rawCredits))
			loadLine(i);

		////
		hintBg = new FlxSprite(0, FlxG.height - 130).makeGraphic(1, 1);
		hintBg.scale.set(FlxG.width - 100, 120);
        hintBg.updateHitbox();
		hintBg.screenCenter(X);
		hintBg.color = 0xFF000000;
		hintBg.alpha = 0.6;
		hintBg.scrollFactor.set();
		add(hintBg);

		hintText = new FlxText(hintBg.x + 25, hintBg.y + hintBg.height * 0.5 - 16, hintBg.width - 50, "asfgh", 32);
		hintText.setFormat(Paths.font("calibri.ttf"), 32, 0xFFFFFFFF, CENTER);
		hintText.scrollFactor.set();
        add(hintText);
		
		super.create();

        updateSelection();
        curSelected = 0;

		#if !FLX_NO_MOUSE
		FlxG.mouse.visible = true;
		#end
	}

    var realIndex:Int = 0;
	public function addSong(data:Array<String>, ?folder:String)
	{
		Paths.currentModDirectory = folder == null ? "" : folder;

        var songTitle:Alphabet; 
		var id = realIndex++;

        if (data.length > 1)
        {
            songTitle = new Alphabet(0, 240 * id, data[0], false);
            songTitle.x = 120;
            songTitle.targetX = 90;

            dataArray[id] = data; 

            var songIcon = new AttachedSprite("credits/" + data[1]);

            songIcon.xAdd = songTitle.width + 15; 
            songIcon.yAdd = 15;
            songIcon.sprTracker = songTitle;

            iconArray[id] = songIcon;
            add(songIcon);
        }else if (data[0].trim().length == 0){
            return;
        }else{
            songTitle = new Alphabet(0, 240 * id, data[0], true);
            songTitle.screenCenter(X);
            songTitle.targetX = songTitle.x;
        }

        songTitle.sowyFreeplay = true;
        songTitle.ID = id;
        titleArray[id] = songTitle;
        add(songTitle);
	}

	var moveTween:FlxTween;
	
	function updateSelection(playSound:Bool = true)
	{
		if (playSound)
			FlxG.sound.play(Paths.sound("scrollMenu"), 0.4);

		// selectedSong = titleArray[curSelected];

		for (id in 0...titleArray.length)
		{
			var title:Alphabet = titleArray[id];
            var data = dataArray[id];
			var icon = iconArray[id];

            if (data == null){ // for the category titles, whatevrr !!!
                
            }else if (id == curSelected){
				title.alpha = 1;
                title.targetX = 90;
                title.color = 0xFFFFFFFF;

				icon.color = 0xFFFFFFFF;

                var descText = data[2];
                if (descText == null){
                    hintText.alpha = 0;
                    hintText.text = "";
                }else{
                    hintText.text = descText;

                    hintBg.scale.y = 30 + hintText.height;
                    hintBg.updateHitbox();
                    hintBg.y = FlxG.height - hintBg.height - 10;

                    hintText.y = hintBg.y + hintBg.height * 0.5 - hintText.height * 0.5;

                    //// FUCK
                    var sby = hintBg.y + 15;
                    var eby = hintBg.y;
                    var sty = hintText.y + 15;
                    var ety = hintText.y;
                    var sba = hintBg.alpha;
					if (moveTween != null)
						moveTween.cancel();
                    moveTween = FlxTween.num(0, 1, 0.25, {ease: FlxEase.sineOut}, function(v){
                        hintBg.y = FlxMath.lerp(sby, eby, v);
                        hintText.y = FlxMath.lerp(sty, ety, v);
                        hintBg.alpha = FlxMath.lerp(sba, 0.6, v);
                    });
                }

				camFollow.y = title.y + title.height * 0.5 + 20;
			}else{
				var difference = Math.abs(curSelected - id);
				
				title.targetX = 90 + difference * -20;
				title.alpha = (1 - difference * 0.15);
				title.color = 0xFF000000;
				
				var br = 1-(difference * 0.15 + 0.05);
				icon.color = FlxColor.fromRGBFloat(br,br,br);
			}

			if (icon != null)
				icon.alpha = title.alpha;
		}
	}
	
	var secsHolding:Float = 0;
	override function update(elapsed:Float)
	{
		if (FlxG.sound.music != null && FlxG.sound.music.volume < 0.7)
			FlxG.sound.music.volume += 0.5 * FlxG.elapsed;

		////
		var speed = FlxG.keys.pressed.SHIFT ? 2 : 1;

		var mouseWheel = FlxG.mouse.wheel;
		if (mouseWheel != 0)
			curSelected -= mouseWheel * speed;

		if (controls.UI_DOWN_P){
			curSelected += speed;
			secsHolding = 0;
		}
		if (controls.UI_UP_P){
			curSelected -= speed;
			secsHolding = 0;
		}

		if (controls.UI_UP || controls.UI_DOWN){
			var checkLastHold:Int = Math.floor((secsHolding - 0.5) * 10);
			secsHolding += elapsed;
			var checkNewHold:Int = Math.floor((secsHolding - 0.5) * 10);

			if(secsHolding > 0.5 && checkNewHold - checkLastHold > 0)
				curSelected += (checkNewHold - checkLastHold) * (controls.UI_UP ? -speed : speed);
		}

		//// update camera
		var lerpVal = Math.min(
            1, 
            elapsed * (9.6 + Math.max(0, Math.abs(camFollowPos.y - camFollow.y) - 360) * 0.002)
        );
        
        camFollowPos.setPosition(FlxMath.lerp(camFollowPos.x, camFollow.x, lerpVal), FlxMath.lerp(camFollowPos.y, camFollow.y, lerpVal));

        if (FlxG.keys.justPressed.NINE){
            for (item in titleArray){
                if (item != null && !item.isBold)
                    item.x += 50;
            }

            for (icon in iconArray){
                if (icon != null)
                    icon.loadGraphic(Paths.image('credits/peak'));
            }
        }

		if (controls.BACK){
			FlxG.sound.play(Paths.sound('cancelMenu'));
			MusicBeatState.switchState(new MainMenuState());
		}

		if (controls.ACCEPT){
            CoolUtil.browserLoad(dataArray[curSelected][3]);
		}
		
		super.update(elapsed);
	}
}