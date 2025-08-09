importClass("flixel.group.FlxTypedSpriteGroup");
importClass("funkin.states.GameOverSubstate");
import funkin.vis.dsp.SpectralAnalyzer;

var analyzer:Null<SpectralAnalyzer> = null;
var volumes:Array<Float> = [];


function onGameOver() {
	if (game.playOpponent) return;
	GameOverSubstate.deathSoundName = "fnf_loss_sfx-pico";
	GameOverSubstate.loopSoundName = "gameOver-pico";
	GameOverSubstate.endSoundName = "gameOverEnd-pico";
}

// a lotta stu copy-pasted from V-Slice.
// tho i removed the custom classes and train functionality.

/**
 * At this amount of life, Nene will raise her knife.
 */
var VULTURE_THRESHOLD = 0.25 * 2;

/**
 * Nene is in her default state. 'danceLeft' or 'danceRight' may be playing right now,
 * or maybe her 'combo' or 'drop' animations are active.
 *
 * Transitions:
 * If player health <= VULTURE_THRESHOLD, transition to STATE_PRE_RAISE.
 * If trainPassing is set to true, transition to STATE_HAIR_BLOWING.
 */
var STATE_DEFAULT = 0;

/**
 * Nene has recognized the player is at low health,
 * but has to wait for the appropriate point in the animation to move on.
 *
 * Transitions:
 * If player health > VULTURE_THRESHOLD, transition back to STATE_DEFAULT without changing animation.
 * If current animation is combo or drop, transition when animation completes.
 * If current animation is danceLeft, wait until frame 14 to transition to STATE_RAISE.
 * If current animation is danceRight, wait until danceLeft starts.
 * If trainPassing is set to true, transition to STATE_HAIR_BLOWING.
 */
var STATE_PRE_RAISE = 1;

/**
 * Nene is raising her knife.
 * When moving to this state, immediately play the 'raiseKnife' animation.
 *
 * Transitions:
 * Once 'raiseKnife' animation completes, transition to STATE_READY.
 * If trainPassing is set to true, transition to STATE_HAIR_BLOWING_RAISE.
 */
var STATE_RAISE = 2;

/**
 * Nene is holding her knife ready to strike.
 * During this state, hold the animation on the first frame, and play it at random intervals.
 * This makes the blink look less periodic.
 *
 * Transitions:
 * If the player runs out of health, move to the GameOverSubState. No transition needed.
 * If player health > VULTURE_THRESHOLD, transition to STATE_LOWER.
 * If trainPassing is set to true, transition to STATE_HAIR_BLOWING_RAISE.
 */
var STATE_READY = 3;

/**
 * Nene is about to lower her knife.
 * When moving to this state, play the 'lowerKnife' animation on the next beat.
 *
 * Transitions:
 * Once 'lowerKnife' animation completes, transition to STATE_DEFAULT.
 * If trainPassing is set to true, transition to STATE_HAIR_BLOWING.
 */
var STATE_LOWER = 4;

/**
 * Nene's animations are tracked in a simple state machine.
 * Given the current state and an incoming event, the state changes.
 */
var currentState:Int = STATE_DEFAULT;

/**
 * Nene blinks every X beats, with X being randomly generated each time.
 * This keeps the animation from looking too periodic.
 */
var MIN_BLINK_DELAY:Int = 3;
var MAX_BLINK_DELAY:Int = 7;
var blinkCountdown:Int = MIN_BLINK_DELAY;

var pupilState:Int = 0;

var PUPIL_STATE_NORMAL = 0;
var PUPIL_STATE_LEFT = 1;

var visOffsetSpeed:Float = 1;
var visOffset:Float = 0;

var abot:FlxAtlasSprite;
//var abotViz:ABotVis;
var abotVis:FlxTypedSpriteGroup;
var stereoBG:FlxSprite;
var eyeWhites:FlxSprite;
var pupil:FlxAtlasSprite;

var members: Array<FlxBasic> = [];

function setupCharacter() {
	super();

	stereoBG = new FlxSprite(0, 0, Paths.image('characters/abot/stereoBG'));
	
	eyeWhites = new FlxSprite(0, 0).makeGraphic(1, 1, 0xFFFFFFFF);
	eyeWhites.scale.set(160, 60);
	eyeWhites.updateHitbox();
	
	pupil = new FlxAnimate(0, 0, "images/characters/abot/systemEyes", {
		FrameRate: 24.0,
		Reversed: false,
		ShowPivot: false,
		Antialiasing: true,
		ScrollFactor: null,
	});
	
	abot = new FlxAnimate(0, 0, "images/characters/abot/abotSystem", {
		FrameRate: 24.0,
		Reversed: false,
		ShowPivot: false,
		Antialiasing: true,
		ScrollFactor: new FlxPoint(1, 1),
	});

	// abotViz = new ABotVis(FlxG.sound.music, false);
	var visFrms:FlxAtlasFrames = Paths.getSparrowAtlas('characters/abot/aBotViz');
	var posX = [0, 59, 56, 66, 54, 52, 51];
	var posY = [0, -8, -3.5, -0.4, 0.5, 4.7, 7];
	abotVis = new FlxTypedSpriteGroup();

	var curX = 0;
	var curY = 0;
	for (idx in 0...posX.length) {
		curX += posX[idx];
		curY += posY[idx];

		var bar = new FlxSprite(curX, curY);
		bar.frames = visFrms;
		bar.animation.addByPrefix("vis", "viz" + (idx + 1) + "0", 0, false);
		bar.animation.play("vis", true);
		abotVis.add(bar);
	}

	members.push(eyeWhites);
	members.push(stereoBG);
	members.push(pupil);
	// game.gfGroup.insert(game.gfGroup.members.indexOf(this), abotVis);
	members.push(abotVis);
	members.push(abot);

	copyTransforms();
}

function getDefaultLevels() {
	var result = [];

	for (i in 0...7) {
		result.push({value: 0, peak: 0.0});
	}

	return result;
}

var levels = [];

function onCharacterDraw(){
	for (m in members)
		m.draw();
	if (abotVis == null) return;

	if(analyzer != null){
		for (i in 0...Math.min(abotVis.members.length, levels.length)) {
			var animFrame:Int = Math.round(levels[i].value * 6);

			// don't display if we're at 0 volume from the level
			abotVis.members[i].visible = animFrame > 0;

			// decrement our animFrame, so we can get a value from 0-5 for animation frames
			animFrame -= 1;

			animFrame = Math.floor(Math.min(5, animFrame));
			animFrame = Math.floor(Math.max(0, animFrame));

			animFrame = Std.int(Math.abs(animFrame - 5)); // shitty dumbass flip, cuz dave got da shit backwards lol!

			abotVis.members[i].animation.curAnim.curFrame = animFrame;
		}
	}else{
		for (i in 0...abotVis.members.length) 
			abotVis.members[i].animation.curAnim.curFrame = Math.round(FlxMath.fastSin(visOffset + i) * 2.5 + 2.5);
		
	}
}


var lastX;
var lastY;
var lastA;
var lastV;
function copyTransforms() {
	lastX = this.x;
	lastY = this.y;
	lastA = this.alpha;
	lastV = this.visible;
	
	var abotX = lastX - 100;
	var abotY = lastY + 216 + 100;
	stereoBG.setPosition(abotX + 150, abotY + 30);
	stereoBG.alpha = lastA;
	stereoBG.visible = lastV;

	eyeWhites.setPosition(abotX + 40, abotY + 250);
	eyeWhites.alpha = lastA;
	eyeWhites.visible = lastV;

	pupil.setPosition(abotX - 507, abotY - 492);
	pupil.alpha = lastA;
	pupil.visible = lastV;

	abot.setPosition(abotX, abotY);
	abot.alpha = lastA;
	abot.visible = lastV;

	abotVis.setPosition(abotX + 200, abotY + 84);
	abotVis.alpha = lastA;
	abotVis.visible = lastV;

	for(m in members){
		m.scrollFactor.set(this.scrollFactor.x, this.scrollFactor.y);
	}
}

var lastTarget:String = 'bf';
function onMoveCamera(target) {
	if(target != lastTarget){
		pupil.anim.play('');
		pupil.anim.curFrame = (target == "bf") ? 17 : 0;
		pupilState = (target == "bf") ? PUPIL_STATE_NORMAL : PUPIL_STATE_LEFT;
	}
	lastTarget = target;
}

function onCharacterUpdate(e) {
	if (this.x != lastX || this.y != lastY || this.alpha != lastA || this.visible != lastV)
		copyTransforms();

	if (game.inst != null && game.inst._channel != null && analyzer == null){
		// i really need to add more callbacks or playstate signals LOL
		analyzer = new SpectralAnalyzer(game.inst, 7, 0.1, 40);
		
		analyzer.minDb = -65;
		analyzer.maxDb = -25;
		analyzer.maxFreq = 22000;
		analyzer.minFreq = 10;
		#if desktop
		analyzer.fftN = 256;
		#end
		
	}
	if(analyzer != null)
		levels = analyzer.getLevels();

	visOffset += e * visOffsetSpeed;
	visOffsetSpeed = FlxMath.lerp(visOffsetSpeed, game.songSpeed, e * 15);

/* 	if (abotVis != null) {
		for (i in 0...abotVis.members.length) {
			abotVis.members[i].animation.curAnim.curFrame = Math.round(FlxMath.fastSin(visOffset + i) * 2.5 + 2.5);
		}
	} */

	if (pupil != null && pupil.anim != null && pupil.anim.isPlaying) {
		var checkFrame = (pupilState == PUPIL_STATE_LEFT) ? 17 : 30;
		if (pupil.anim.curFrame >= checkFrame)
			pupil.anim.pause();
	}

	var anim = this.animation.name;

	switch (currentState) {
		case STATE_DEFAULT:
			currentState = (game.health <= VULTURE_THRESHOLD) ? STATE_PRE_RAISE : STATE_DEFAULT;
		case STATE_PRE_RAISE:
			if (game.health > VULTURE_THRESHOLD) {
				// trace('NENE: Health went back up, transitioning to STATE_DEFAULT');
				currentState = STATE_DEFAULT;
			} else if (anim == "danceLeft" && this.animation.curAnim != null && this.animation.curAnim.curFrame == 13) {
				// trace('NENE: Animation finished, transitioning to STATE_RAISE');
				currentState = STATE_RAISE;
				this.playAnim('knifeStart');
			}
		case STATE_RAISE:
			if (this.animation.finished)
				currentState = STATE_READY;
		case STATE_READY:
			if (PlayState.instance.health > VULTURE_THRESHOLD)
				currentState = STATE_LOWER;
				// lowerKnife will play on the next beat, so it syncs up properly
		case STATE_LOWER:
			var anim = this.animation.name;
			if (anim != null && anim == 'knifeOut' && this.animation.finished)
				currentState = STATE_DEFAULT;
		default:
			currentState = STATE_DEFAULT;
	}

	for (m in members)
		m.update(e);
}

function onDance() {
	if (abot != null) {
		abot.anim.play("");
		abot.anim.curFrame = 1; // we start on this frame, since from Flash the symbol has a non-bumpin frame on frame 0
	}

	visOffsetSpeed = 25;

	switch(currentState) {
		case STATE_DEFAULT:
			var anim = this.animation.name;
			if (anim != null && (anim == "sad" || anim == "knifeOut") && !this.animation.finished)
				return;

			this.playAnim(this.idleSequence[this.danceIndex], this.shouldForceDance);
			this.danceIndex = (this.danceIndex + 1) % this.idleSequence.length;
		case STATE_PRE_RAISE:
			this.danceIndex = 0;
			this.playAnim(this.idleSequence[this.danceIndex], false);
		case STATE_READY:
			blinkCountdown--;
			if (blinkCountdown < 0) {
				this.playAnim('knife', false);
				blinkCountdown = FlxG.random.int(MIN_BLINK_DELAY, MAX_BLINK_DELAY);
			}
		case STATE_LOWER:
			var anim = this.animation.name;
			if (anim == null || anim != 'knifeOut') {
				this.playAnim('knifeOut');
				this.danceIndex = 0;
			}
		default:
			// In other states, don't interrupt the existing animation.
	}

	return Function_Stop;
}