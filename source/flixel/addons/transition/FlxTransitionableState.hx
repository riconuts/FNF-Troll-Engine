package flixel.addons.transition;
// modified by Nebula the Zorua for Andromeda Engine 1.0
// replaces the TransitionData bullshit with substates
// the substate should have a start, setStatus and finishCallback property
// after that, how the substate behaves is up to you.


import flixel.FlxState;
import flixel.FlxSubState;

class FlxTransitionableState extends FlxState
{
	/** Default intro transition. Used when `transIn` is null **/
	public static var defaultTransIn:Class<TransitionSubstate> = null;
	/** Default outro transition. Used when `transOut` is null **/
	public static var defaultTransOut:Class<TransitionSubstate> = null;

	public static var skipNextTransIn:Bool = false;
	public static var skipNextTransOut:Bool = false;

	/** Intro transition to use after switching to this state **/
	public var transIn:Class<TransitionSubstate>;
	/** Outro transition to use before switching to another state **/
	public var transOut:Class<TransitionSubstate>;

	public var hasTransIn(get, never):Bool;
	public var hasTransOut(get, never):Bool;

	////
	var transOutFinished:Bool = false;

	var _transSubState:TransitionSubstate;
	var _exiting:Bool = false;
	var _onExit:Void->Void;

	////

	/**
	 * Create a state with the ability to do visual transitions
	 * @param	TransIn		Plays when the state begins
	 * @param	TransOut	Plays when the state ends
	 */
	public function new(?TransIn:Class<TransitionSubstate>, ?TransOut:Class<TransitionSubstate>)
	{
		this.transIn = (TransIn == null) ? defaultTransIn : TransIn;
		this.transOut = (TransOut == null) ? defaultTransOut : TransOut;

		super();
	}

	override public function destroy():Void
	{
		super.destroy();
		transIn = null;
		transOut = null;
		_onExit = null;
	}

	override public function create():Void
	{
		super.create();
		transitionIn();
	}

	override function startOutro(onOutroComplete:() -> Void)
	{
		if (!hasTransOut)
			onOutroComplete();
		else if (!_exiting)
		{
			// play the exit transition, and when it's done call FlxG.switchState
			_exiting = true;
			transitionOut(onOutroComplete);
			
			if (skipNextTransOut)
			{
				skipNextTransOut = false;
				finishTransOut();
			}
		}
	}

	/**
	 * Starts the in-transition. Can be called manually at any time.
	 */
	public function transitionIn():Void
	{
		if (skipNextTransIn || !hasTransIn) {
			skipNextTransIn = false;
			finishTransIn();
			return;
		}

		_transSubState = Type.createInstance(transIn, []);
		openTransitionSubState(_transSubState);

		_transSubState.finishCallback = finishTransIn;
		_transSubState.start(OUT);
	}

	/**
	 * Starts the out-transition. Can be called manually at any time.
	 */
	public function transitionOut(?OnExit:Void->Void):Void
	{
		_onExit = OnExit;

		if (hasTransOut){
			_transSubState = Type.createInstance(transOut, []);
			openTransitionSubState(_transSubState);

			_transSubState.finishCallback = finishTransOut;
			_transSubState.start(IN);
		}else{
			_onExit();
		}
	}

	function openTransitionSubState(_transSubState:TransitionSubstate)
		openSubState(_transSubState);

	function get_hasTransIn():Bool
	{
		return transIn != null;
	}

	function get_hasTransOut():Bool
	{
		return transOut != null;
	}

	function finishTransIn()
	{
		if (_transSubState != null)
			_transSubState.close();
	}

	function finishTransOut()
	{
		transOutFinished = true;

		if (!_exiting)
		{
			_transSubState.close();
		}

		if (_onExit != null)
		{
			_onExit();
		}
	}
}
