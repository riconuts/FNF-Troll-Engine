package funkin.states.options;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.util.FlxColor;
import funkin.objects.shaders.ColorSwap;

using StringTools;

class NotesSubState extends MusicBeatSubstate
{
	public var changedAnything:Bool = false;

	var curSelected:Int = 0;
	var typeSelected:Int = 0;
	var curValue:Float = 0;
	var holdTime:Float = 0;
	var nextAccept:Int = 5;
	var changingNote:Bool = false;

	private var grpNumbers:FlxTypedGroup<Alphabet>;
	private var grpNotes:FlxTypedGroup<FlxSprite>;
	private var shaderArray:Array<ColorSwap> = [];
	
	var blackBG:FlxSprite;
	var hsbText:Alphabet;

	var posX = 230;
	var daCam:FlxCamera;

	////
	var valuesArray:Array<Array<Int>>; 
	var namesArray:Array<String>;
	var noteFrames:flixel.graphics.frames.FlxAtlasFrames; 
	var noteAnimations:Array<String>;
	var defaults:Array<Array<Int>>;

	public function new() {
		super();

		if (ClientPrefs.noteSkin == "Quants") {
			// fuck you
			valuesArray = ClientPrefs.quantHSV;
			noteFrames = Paths.getSparrowAtlas('QUANTNOTE_assets');
			noteAnimations = ['purple0', 'blue0', 'green0', 'red0'];
			namesArray = [
				"4th",
				"8th",
				"12th",
				"16th",
				"20th",
				"24th",
				"32nd",
				"48th",
				"64th",
				"96th",
				"192nd"
			];
			defaults = [
				[0, -20, 0], // 4th
				[-130, -20, 0], // 8th
				[-80, -20, 0], // 12th
				[128, -30, 0], // 16th
				[-120, -70, -35], // 20th
				[-80, -20, 0], // 24th
				[50, -20, 0], // 32nd
				[-80, -20, 0], // 48th
				[160, -15, 0], // 64th
				[-120, -70, -35], // 96th
				[-120, -70, -35], // 192nd
			];
		} else {
			valuesArray = ClientPrefs.arrowHSV;
			noteFrames = Paths.getSparrowAtlas('NOTE_assets');
			noteAnimations = ['purple0', 'blue0', 'green0', 'red0'];
			namesArray = ["Left", "Down", "Up", "Right"];
			defaults = [[0, 0, 0], [0, 0, 0], [0, 0, 0], [0, 0, 0]];
		}
	}

	override public function create() {
		var camPos = new FlxObject(0,0, 1280, 720);
		add(camPos);

		daCam = new FlxCamera();
		daCam.bgColor = FlxColor.fromRGBFloat(0, 0, 0, 0.6);
		daCam.follow(camPos, NO_DEAD_ZONE);
		FlxG.cameras.add(daCam, false);
		this.cameras = [daCam];

		blackBG = new FlxSprite(posX - 25).makeGraphic(870, 200, FlxColor.BLACK);
		blackBG.alpha = 0.4;
		add(blackBG);

		grpNotes = new FlxTypedGroup<FlxSprite>();
		add(grpNotes);
		grpNumbers = new FlxTypedGroup<Alphabet>();
		add(grpNumbers);
		
		////
		for (i in 0...valuesArray.length) {
			var yPos:Float = (165 * i) + 35;
			for (j in 0...3) {
				var roundedValue:Int = Math.round(valuesArray[i][j]);

				var optionText:Alphabet = new Alphabet(0, yPos + 60, Std.string(roundedValue), true);
				optionText.x = posX + (225 * j) + 250;
				optionText.offset.x = (40 * (optionText.lettersArray.length - 1)) * 0.5;
				if (roundedValue < 0) optionText.offset.x += 10;
				
				grpNumbers.add(optionText);
			}

			var note:FlxSprite = new FlxSprite(posX, yPos);
			note.frames = noteFrames;
			note.animation.addByPrefix('idle', noteAnimations[i % 4]);
			note.animation.play('idle');
			grpNotes.add(note);

			var txt:AttachedText = new AttachedText(namesArray[i], 0, 0, true);
			txt.sprTracker = note;
			txt.copyAlpha = true;
			add(txt);

			var newShader:ColorSwap = new ColorSwap();
			note.shader = newShader.shader;
			newShader.setHSBIntArray(valuesArray[i]);
			shaderArray.push(newShader);
		}

		hsbText = new Alphabet(0, 0, "Hue    Saturation  Brightness", false, false, 0, 0.65);
		hsbText.x = posX + 240;
		for (letter in hsbText.lettersArray)
			letter.setColorTransform(0.0, 0.0, 0.0, 1.0, 255, 255, 255, 0);
		add(hsbText);
		
		////
		changeSelection();
		super.create();
	}

	function menuUpdate(elapsed:Float) {
		if(changingNote) {
			if(holdTime < 0.5) {
				if(controls.UI_LEFT_P) {
					updateValue(-1);
					FlxG.sound.play(Paths.sound('scrollMenu'));
				} else if(controls.UI_RIGHT_P) {
					updateValue(1);
					FlxG.sound.play(Paths.sound('scrollMenu'));
				} else if(controls.RESET) {
					resetValue(curSelected, typeSelected);
					FlxG.sound.play(Paths.sound('scrollMenu'));
				}
				if(controls.UI_LEFT_R || controls.UI_RIGHT_R) {
					holdTime = 0;
				} else if(controls.UI_LEFT || controls.UI_RIGHT) {
					holdTime += elapsed;
				}
			} else {
				var add:Float = 90;
				switch(typeSelected) {
					case 1 | 2: add = 50;
				}
				if(controls.UI_LEFT) {
					updateValue(elapsed * -add);
				} else if(controls.UI_RIGHT) {
					updateValue(elapsed * add);
				}
				if(controls.UI_LEFT_R || controls.UI_RIGHT_R) {
					FlxG.sound.play(Paths.sound('scrollMenu'));
					holdTime = 0;
				}
			}
		} else {
			if (controls.UI_UP_P) {
				changeSelection(-1);
				FlxG.sound.play(Paths.sound('scrollMenu'));
			}
			if (controls.UI_DOWN_P) {
				changeSelection(1);
				FlxG.sound.play(Paths.sound('scrollMenu'));
			}
			if (controls.UI_LEFT_P) {
				changeType(-1);
				FlxG.sound.play(Paths.sound('scrollMenu'));
			}
			if (controls.UI_RIGHT_P) {
				changeType(1);
				FlxG.sound.play(Paths.sound('scrollMenu'));
			}
			if(controls.RESET) {
				for (i in 0...3) {
					resetValue(curSelected, i);
				}
				FlxG.sound.play(Paths.sound('scrollMenu'));
			}
			if (controls.ACCEPT && nextAccept <= 0) {
				FlxG.sound.play(Paths.sound('scrollMenu'));
				changingNote = true;
				holdTime = 0;
				for (i in 0...grpNumbers.length) {
					var item = grpNumbers.members[i];
					item.alpha = 0;
					if ((curSelected * 3) + typeSelected == i) {
						item.alpha = 1;
					}
				}
				for (i in 0...grpNotes.length) {
					var item = grpNotes.members[i];
					item.alpha = 0;
					if (curSelected == i) {
						item.alpha = 1;
					}
				}
				return;
			}
		}

		if (controls.BACK || (changingNote && controls.ACCEPT)) {
			if(!changingNote) {
				close();
			} else {
				changeSelection();
			}
			changingNote = false;
			FlxG.sound.play(Paths.sound('cancelMenu'));
		}

		if(nextAccept > 0) {
			nextAccept -= 1;
		}

		for (i in 0...grpNotes.length)
		{
			var yIndex = i;
			var item = grpNotes.members[i];
			if (curSelected > 2 && valuesArray.length > 4)
				yIndex -= curSelected - 2;

			var yPos:Float = (165 * yIndex) + 35;
			var lerpVal:Float = (1 - Math.exp(-48 * elapsed));

			item.y += (yPos - item.y) * lerpVal;

			if (i == curSelected){
				hsbText.y += (yPos-70 - hsbText.y) * lerpVal;
				blackBG.y += (yPos-20 - blackBG.y) * lerpVal;
			}
		}

		for (i in 0...grpNumbers.length) {
			var item = grpNumbers.members[i];
			item.y = grpNotes.members[Math.floor(i/3)].y + 60;
		}
	}

	override function update(elapsed:Float) {
		menuUpdate(elapsed);
		super.update(elapsed);
	}

	override function destroy(){
		super.destroy();
		FlxG.cameras.remove(daCam);
	}

	function changeSelection(change:Int = 0) {
		curSelected += change;
		if (curSelected < 0)
			curSelected = valuesArray.length-1;
		if (curSelected > valuesArray.length-1)
			curSelected = 0;

		curValue = valuesArray[curSelected][typeSelected];
		updateValue();

		for (i in 0...grpNumbers.length) {
			var item = grpNumbers.members[i];
			item.alpha = 0.6;
			if ((curSelected * 3) + typeSelected == i) {
				item.alpha = 1;
			}
		}
		for (i in 0...grpNotes.length) {
			var item = grpNotes.members[i];
			item.alpha = 0.6;
			item.scale.set(0.75, 0.75);
			if (curSelected == i) {
				item.alpha = 1;
				item.scale.set(1, 1);
			}
		}
		FlxG.sound.play(Paths.sound('scrollMenu'));
	}

	function changeType(change:Int = 0) {
		typeSelected += change;
		if (typeSelected < 0)
			typeSelected = 2;
		if (typeSelected > 2)
			typeSelected = 0;

		curValue = valuesArray[curSelected][typeSelected];
		updateValue();

		for (i in 0...grpNumbers.length) {
			var item = grpNumbers.members[i];
			item.alpha = 0.6;
			if ((curSelected * 3) + typeSelected == i) {
				item.alpha = 1;
			}
		}
	}

	function changeValue(selected:Int, type:Int, value:Float) {
		var roundedValue = Math.round(value);

		var hsbArray = valuesArray[selected];
		hsbArray[type] = roundedValue;

		shaderArray[selected].setHSBIntArray(hsbArray);

		var item = grpNumbers.members[(selected * 3) + type];
		item.changeText(Std.string(roundedValue));
		item.offset.x = (40 * (item.lettersArray.length - 1))* 0.5;
		if(roundedValue < 0) item.offset.x += 10;

		changedAnything = true;
	}

	function resetValue(selected:Int, type:Int) {
		curValue = defaults[selected][type];
		changeValue(selected, type, curValue);
	}

	function updateValue(change:Float = 0) {
		curValue += change;
		
		var max:Float = switch(typeSelected) {
			case 0: 180;
			default: 100;
		}

		if (curValue < -max) {
			curValue = -max;
		} else if(curValue > max) {
			curValue = max;
		}

		changeValue(curSelected, typeSelected, curValue);
	}
}
