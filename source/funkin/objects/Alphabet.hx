package funkin.objects;

import flixel.math.FlxPoint.FlxCallbackPoint;
import flixel.util.FlxDestroyUtil;
import flixel.text.FlxText.FlxTextAlign;

import openfl.media.Sound;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.math.FlxMath;
import flixel.util.FlxTimer;

using StringTools;

class Alphabet extends FlxTypedSpriteGroup<AlphaCharacter>
{
	public var text(default, set):String = "";
	public var fieldWidth:Float = 0;
	public var alignment:FlxTextAlign = FlxTextAlign.LEFT;
	public var bold:Bool = false;

	// for menu shit
	public var targetX:Null<Float> = null;
	public var targetY:Null<Float> = null;
	public var xAdd:Float = 0;
	public var yAdd:Float = 0;

	////
	#if ALLOW_DEPRECATION
	@:deprecated public var lettersArray(get, never):Array<AlphaCharacter>;
	@:noCompletion function get_lettersArray():Array<AlphaCharacter> return cast members;

	@:deprecated public var isBold(get, set):Bool;
	@:noCompletion function set_isBold(v):Bool return bold = v;
	@:noCompletion function get_isBold():Bool return bold;

	@:deprecated public function changeText(newText:String, aaaaaaaa)
		this.text = newText;
	#end

	// public function new(x:Float, y:Float, fieldWidth = 0.0, text = "", textScale = 1.0)
	public function new(x:Float = 0, y:Float = 0, text:String = "", bold:Bool = false, ?fuck:Dynamic, ?lol:Dynamic, textScale = 1.0)
	{
		super(x, y);

		this.directAlpha = true;
		
		this.bold = bold;
		//this.fieldWidth = fieldWidth;
		this.scale.set(textScale, textScale);

		this.set_text(text);
	}

	public function set_text(newText:String)
	{
		text = newText;
		updateText();
		return newText;
	}
		
	private function updateText()
	{
		for (obj in this.members)
			obj.kill();

		if (text.trim().length == 0) 
			return;

		var words:Array<Array<AlphaCharacter>> = [];
		var wordWidths:Array<Float> = [];

		var curWord:Array<AlphaCharacter> = [];
		var curWidth:Float = 0;

		inline function newWord() {
			wordWidths.push(curWidth);
			curWidth = 0;

			words.push(curWord);
			curWord = [];
		}

		for (charIndex in 0...text.length) {
			var char = text.charAt(charIndex);

			if (char == " ") {
				curWidth += 40 * this.scale.x;
				newWord();
				continue;
			}
			if (char == "\n") {
				newWord();
				words.push(null);
				wordWidths.push(0);
				continue;
			}
				
			var obj:AlphaCharacter = recycle(AlphaCharacter);
			obj.setPosition(curWidth, 0);
			obj.alpha = this.alpha;
			obj.scale.copyFrom(this.scale);

			var created = (bold ? obj.createBoldCharacter : obj.createCharacter)(char);
			if (created) {
				obj.ID = charIndex;
				curWord.push(obj);
				curWidth = obj.x + obj.width;
			}else {
				obj.kill();
				curWord.push(null);
				curWidth += 40 * this.scale.x;
			}
		}
		wordWidths.push(curWidth);
		words.push(curWord);

		var xPos:Float = 0;
		var yPos:Float = 0;
		var fieldWidth:Float = (fieldWidth > 0) ? (fieldWidth * scale.x) : Math.POSITIVE_INFINITY;
		var alignment:FlxTextAlign = (fieldWidth>0) ? this.alignment : LEFT;

		var lineCharacters:Array<AlphaCharacter> = [];
		var lineWidth:Float = 0;
		inline function newLine() {
			switch(alignment) {
				default:
					for (obj in lineCharacters) {
						this.add(obj);
					}

				case CENTER:
					var offset = (fieldWidth - lineWidth) / 2;
					for (obj in lineCharacters) {
						obj.x += offset;
						this.add(obj);
					}

				case RIGHT:
					var offset = (fieldWidth - lineWidth);
					for (obj in lineCharacters) {
						obj.x += offset;
						this.add(obj);
					}
				
				//case JUSTIFY: // could do it but I DONT CARE
			}

			xPos = 0;
			yPos += 60 * this.scale.y;

			lineCharacters.resize(0);
			lineWidth = 0;
		}

		for (wordIndex => wordObjs in words) {
			if (wordObjs == null) {
				newLine();
				continue;
			}

			var wordWidth = wordWidths[wordIndex];
			if (xPos + wordWidth > fieldWidth) {
				newLine();
			}

			for (obj in wordObjs) {
				if (obj == null)
					continue;
				
				obj.x += xPos;
				obj.y += yPos;

				lineCharacters.push(obj);
			}

			xPos += wordWidth;
			lineWidth += wordWidth;
		}

		newLine();
	}

	override function get_width():Float
		return (fieldWidth > 0) ? (fieldWidth * scale.x) : super.get_width();

	override function update(elapsed:Float)
	{
		if (targetX != null || targetY != null){
			var lerpVal:Float = Math.exp(-elapsed * 9.6);
			if (targetX != null) x = FlxMath.lerp(targetX + xAdd, x, lerpVal);
			if (targetY != null) y = FlxMath.lerp(targetY + yAdd, y, lerpVal);
		}

		super.update(elapsed);
	}
}

class AlphaCharacter extends FlxSprite
{
	public static var alphabet:String = "abcdefghijklmnopqrstuvwxyz";
	public static var numbers:String = "1234567890";
	public static var symbols:String = "|~#$%()*+-:;<=>@[]^_.,'!?";

	private static function isAlpha(char:String):Bool
		return char.toUpperCase() != char.toLowerCase(); // alphabet.contains(char);

	private static function isNumber(char:String):Bool
		return numbers.contains(char);

	private static function isSymbol(char:String):Bool
		return symbols.contains(char);

	// this fucking sucks

	private static function getCharacterXmlPrefix(char:String):String
		return switch(char) {
			case '#':	'hashtag';
			case '.':	'period';
			case "'":	'apostraphie';
			case "?":	'question mark';
			case "!":	'exclamation point';
			case ",":	'comma';
			default:
				if (isAlpha(char)) {
					var letterCase:String = (char.toLowerCase() != char) ? 'capital' : "lowercase";
					'$char $letterCase';
				}else
					char;
		}

	private static function getBoldCharacterXmlPrefix(char:String):String
		return switch(char) {
			case '.':	'PERIOD bold';
			case "'":	'APOSTRAPHIE bold';
			case "?":	'QUESTION MARK bold';
			case "!":	'EXCLAMATION POINT bold';
			case "(":	'bold (';
			case ")":	'bold )';
			default:
				if (isAlpha(char))
					char.toUpperCase() + ' bold';
				else if (isNumber(char))
					'bold$char';
				else // if (isSymbol(char))
					'bold $char';					
		}

	////
	public var curCharacter = "";

	public function new()
	{
		super(x, y);
		frames = Paths.getSparrowAtlas('alphabet');
	}

	public function createCharacter(character:String) {
		curCharacter = character;

		var prefix = getCharacterXmlPrefix(character);
		
		animation.remove('normal');
		animation.addByPrefix('normal', prefix, 24);
		
		if (animation.exists('normal')) {
			animation.play('normal');
		}else {
			if (Main.showDebugTraces)
				trace('unexistant normal [$character], attempted prefix: [$prefix]');
			return false;			
		}

		updateHitbox();
		y = 60 - height;

		#if tgt
		switch (character)
		{
			case "g" | "j" | "p" | "q" | "y":
				y += 13;
			case "z" | "Z":
				y--;
			case "Q":
				y += 8;
			case "B" | "D" | "E" | "L":
				y--;
		}
		#else
		switch (character)
		{
			case "p" | "q" | "y":
				y += 10;
			case "'":
				y -= 20;
			case '-':
				//x -= 35 - (90 * (1.0 - scale.x));
				y -= 16;
		}
		#end

		return true;
	}

	public function createBoldCharacter(character:String) {
		curCharacter = character;

		var prefix = getBoldCharacterXmlPrefix(character);
		
		animation.remove('bold');
		animation.addByPrefix('bold', prefix, 24);
		
		if (animation.exists('bold')) {
			animation.play('bold');
		}else {
			if (Main.showDebugTraces)
				trace('unexistant bold [$character], attempted prefix: [$prefix]');
			return false;			
		}
		
		updateHitbox();

		switch (character)
		{
			case "'":
				y -= 20 * scale.y;
			case '-':
				//x -= 35 - (90 * (1.0 - scale.x));
				y += 20 * scale.y;
			case '(':
				x -= 65 * scale.x;
				y -= 5 * scale.y;
				offset.x = -58 * scale.x;
			case ')':
				x -= 20 / scale.x;
				y -= 5 * scale.y;
				offset.x = 12 * scale.x;
			case '.':
				y += 45 * scale.y;
				x += 5 * scale.x;
				offset.x += 3 * scale.x;
		}

		return true;
	}
}
