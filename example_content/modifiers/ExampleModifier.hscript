/* 
	this:Modifier = {
		var modMgr:ModManager;
		var percents:Array<Float> = [0, 0];
		var submods:Map<String, Modifier> = [];
		var parent:Modifier; // for submods	
	}
	
	getValue(player:Int):Float
	getPercent(player:Int):Float
	
	getSubmodValue(modName:String, player:Int):Float
	getSubmodPercent(modName:String, player:Int):Float
	
	setValue(value:Float, player:Int = -1)
	setPercent(percent:Float, player:Int = -1)
	
	setSubmodValue(modName:String, value:Float, player:Int)
	setSubmodPercent(modName:String, percent:Float, player:Int)
*/

function onCreate()
{

}

function onCreatePost()
{

}

function getPos(visualDiff:Float, timeDiff:Float, beat:Float, pos:Vector3, data:Int, player:Int, obj:FlxSprite)
{
	pos.x += getValue(player);
	pos.y += getSubmodValue("exampleY", player);
	
	return pos;
}

function updateReceptor(beat:Float, receptor:StrumNote, player:Int) 
{

}

function updateNote(beat:Float, note:Note, player:Int)
{

}

function modifyVert(beat:Float, vert:Vector3, idx:Int, obj:FlxSprite, pos:Vector3, player:Int, data:Int):Vector3
{
	return vert;
}

/*
typedef RenderInfo = {
	var alpha:Float;
	var glow:Float;
	var scale:FlxPoint;
}
*/
function getExtraInfo(diff:Float, tDiff:Float, beat:Float, info:RenderInfo, obj:FlxSprite, player:Int, data:Int)
{
	return info;
}

function update(elapsed:Float, beat:Float)
{

}
function isRenderMod()
	return false;
	
function getModType()
	return NOTE_MOD; // MISC_MOD
	
function ignorePos()
	return false;

function ignoreUpdateReceptor()
	return true;

function ignoreUpdateNote()
	return true;

function doesUpdate()
	return getModType()==MISC_MOD; // override if you want it to have update(elapsed, beat) called

function shouldExecute(player:Int, value:Float):Bool
{
	return value != 0; // override if your modifier should run, even if percent isn't 0
}

function getOrder()
{
	/*
	FIRST = -1000;
    PRE_REVERSE = -3;
    REVERSE = -2;
    POST_REVERSE = -1;
    DEFAULT = 0;
	LAST = 1000;
	*/

	return DEFAULT;
}
	
function getName()
	return "exampleX";
	
function getSubmods()
	return ["exampleY"];