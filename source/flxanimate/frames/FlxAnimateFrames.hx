package flxanimate.frames;

import funkin.Paths as Assets;

import flixel.graphics.frames.FlxFramesCollection;
import flxanimate.data.AnimationData.OneOfTwo;
import openfl.geom.Rectangle;
import flxanimate.data.SpriteMapData.Meta;
import haxe.io.Bytes;
import flxanimate.zip.Zip;
import haxe.io.BytesInput;
import flixel.math.FlxMatrix;
import flixel.FlxG;
import flixel.graphics.FlxGraphic;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.graphics.frames.FlxFrame.FlxFrameAngle;
import flixel.math.FlxPoint;
import flixel.math.FlxRect;
import flxanimate.data.SpriteMapData.AnimateAtlas;
import flxanimate.data.SpriteMapData.AnimateSpriteData;
import flxanimate.data.AnimationData.AnimAtlas;
import openfl.display.BitmapData;
import flixel.system.FlxAssets.FlxGraphicAsset;
#if haxe4
import haxe.xml.Access;
#else
import haxe.xml.Fast as Access;
#end
import flixel.graphics.frames.FlxFrame;

using StringTools;

class FlxAnimateFrames extends FlxAtlasFrames
{
    public function new()
    {
        super(null);
        parents = [];
    }
    static var data:AnimateAtlas = null;
    static var zip:Null<List<haxe.zip.Entry>>;

    public var parents:Array<FlxGraphic>;
    /**
     * Parses the spritemaps into small sprites to use in the animation.
     * 
     * @param Path          Where the Sprites are, normally you use it once when calling FlxAnimate already
     * @return              new sliced limbs for you to use ;)
     */
    public static function fromTextureAtlas(Path:String):FlxAtlasFrames
    {
        var frames:FlxAnimateFrames = new FlxAnimateFrames();
        
        if (zip != null || haxe.io.Path.extension(Path) == "zip")
        {
            #if html5
            FlxG.log.error("Zip Stuff isn't supported on Html5 since it can't transform bytes into an image");
            return null;
            #end
            var imagemap:Map<String, Bytes> = new Map();
            var jsonMap:Map<String, AnimateAtlas> = new Map();
            var thing = (zip != null) ? zip :  Zip.unzip(Zip.readZip(#if sys sys.io.File.getBytes(Path) #else Assets.getBytes(Path) #end));
			for (list in thing)
			{
                if (haxe.io.Path.extension(list.fileName) == "json")
                {
                    jsonMap.set(list.fileName,haxe.Json.parse(StringTools.replace(list.data.toString(), String.fromCharCode(0xFEFF), "")));
                }
                else if (haxe.io.Path.extension(list.fileName) == "png")
                {
                    var name = list.fileName.split("/");
                    imagemap.set(name[name.length - 1], list.data);
                }
			}
            // Assuming the json has the same stuff as the image stuff
            for (curJson in jsonMap)
            {
                var curImage = BitmapData.fromBytes(imagemap[curJson.meta.image]);
                if (curImage != null)
                {
                    for (sprites in curJson.ATLAS.SPRITES)
                    {
                        frames.pushFrame(textureAtlasHelper(FlxG.bitmap.add(curImage), sprites.SPRITE, curJson.meta));
                    }
                }
                else
                    FlxG.log.error('the Image called "${curJson.meta.image}" isnt in this zip file!');
            }
            zip == null;
        }
        else
        {
            #if sys
            var texts = sys.FileSystem.readDirectory(Path).filter((text) -> text.startsWith('spritemap') && text.toLowerCase().endsWith('.json'));
            for(i in 0...texts.length) texts[i] = '$Path/' + texts[i];
            #else
            var texts = Assets.list(TEXT).filter((text) -> StringTools.startsWith(text, '$Path/spritemap'));
            #end
            if (texts.length > 1)
            {
                texts.sort(function (a, b)
                {
                    var an = Std.parseInt(haxe.io.Path.withoutDirectory(a).charAt(9));
                    var bn = Std.parseInt(haxe.io.Path.withoutDirectory(b).charAt(9));
                    if (Math.isNaN(an) || Math.isNaN(bn))
                        return 0;

                    return an - bn;
                });
            }
            var spritemaps:Array<{image:BitmapData, json:AnimateAtlas}> = [];
            for (text in texts)
            {
                #if sys
                var txt = sys.io.File.getContent(text);
                #else
                var txt = Assets.getText(text);
                #end
                if (txt.charCodeAt(0) == 0xFEFF)
                    txt = txt.substring(1);
                var json:AnimateAtlas = haxe.Json.parse(txt);

                #if sys
                spritemaps.push({image: BitmapData.fromFile('$Path/${json.meta.image}'), json: json});
                #else
                spritemaps.push({image: Assets.getBitmapData('$Path/${json.meta.image}'), json: json});
                #end
            }
            
            for (spritemap in spritemaps)
            {
                if (spritemap.image == null)
                {
                    FlxG.log.error('the image called "${spritemap.json.meta.image}" does not exist in Path $Path, maybe you changed the image Path somewhere else?');
                    continue;
                }
            
                var graphic = FlxG.bitmap.add(spritemap.image);
                var spritemapFrames = FlxAtlasFrames.findFrame(graphic);
                if (spritemapFrames == null)
                {
                    spritemapFrames = new FlxAnimateFrames();
                    for (curSprite in spritemap.json.ATLAS.SPRITES)
                    {
                        spritemapFrames.pushFrame(textureAtlasHelper(graphic, curSprite.SPRITE, spritemap.json.meta));
                    }
                }
                graphic.addFrameCollection(spritemapFrames);
                frames.animateConcat(spritemapFrames);
            }

            if (frames.frames == [])
            {
                FlxG.log.error("the Frames parsing couldn't parse any of the frames, it's completely empty! \n Maybe you misspelled the Path?");
                return null;
            }
        }
        return frames;
    }

    public function animateConcat(frames:FlxFramesCollection)
    {
        if (parents.indexOf(frames.parent) == -1)
            parents.push(frames.parent);
        for (frame in frames.frames)
        {
            this.frames.push(frame);
            framesHash.set(frame.name, frame);
        }
        return this;
    }
    /**
     * Sparrow spritesheet format parser with support of both of the versions and making the image completely optional to you.
     * @param Path The direction of the Xml you want to parse.
     * @param Image (Optional) the image of the Xml.
     * @return A new instance of `FlxAtlasFrames`
     */
    public static function fromSparrow(Path:FlxSparrow, ?Image:FlxGraphicAsset):FlxAtlasFrames
	{
        if (Path is String && #if sys !sys.FileSystem.exists(Path) && #end !Assets.exists(Path))
			return null;

		var data:Access = new Access((Path is String) ? Xml.parse(#if sys sys.io.File.getContent(Path) #else Assets.getText(Path) #end).firstElement() : Path.firstElement());
        if (Image == null)
        {
            if (Path is String)
            {
                Image = haxe.io.Path.directory(Path) + data.att.imagePath;
            }
            else
                return null;
        }
		var graphic:FlxGraphic = FlxG.bitmap.add(Image);
		if (graphic == null)
			return null;

		// No need to parse data again
		var frames:FlxAtlasFrames = FlxAtlasFrames.findFrame(graphic);
		if (frames != null)
			return frames;

		frames = new FlxAtlasFrames(graphic);

		for (texture in data.nodes.SubTexture)
		{
            var version2 = texture.has.width;
			var name = texture.att.name;
			var trimmed = texture.has.frameX;
            var width = (version2) ? texture.att.width : texture.att.w;
            var height = (version2) ? texture.att.height : texture.att.h;
			var rotated = (texture.has.rotated && texture.att.rotated == "true");
			var flipX = (texture.has.flipX && texture.att.flipX == "true");
			var flipY = (texture.has.flipY && texture.att.flipY == "true");
            
			var rect = FlxRect.get(Std.parseFloat(texture.att.x), Std.parseFloat(texture.att.y), Std.parseFloat(width),
				Std.parseFloat(height));

			var size = (trimmed) ? new FlxRect(Std.parseInt(texture.att.frameX), Std.parseInt(texture.att.frameY), Std.parseInt(texture.att.frameWidth),
					Std.parseInt(texture.att.frameHeight)) : new FlxRect(0, 0, (rect.width == 0) ? 1 : rect.width, (rect.height == 0) ? 1 : rect.height);

            if (rect.width == 0 || rect.height == 0)
            {
                frames.addEmptyFrame(size);
                continue;
            }

			var angle = rotated ? FlxFrameAngle.ANGLE_NEG_90 : FlxFrameAngle.ANGLE_0;

			var offset = FlxPoint.get(-size.left, -size.top);
			var ImageSize = FlxPoint.get(size.width, size.height);

			if (rotated && !trimmed)
				ImageSize.set(size.height, size.width);
            
			frames.addAtlasFrame(rect, ImageSize, offset, name, angle, flipX, flipY);
		}

		return frames;
	}

    /**
     * 
     * @param Data the Json/XML file content/string
     * @param Image the image which the file is referencing **WARNING:** if you set the path as a json, it's obligatory to set the image!
     * @return A new instance of `FlxAtlasFrames`
     */
    public static function fromAnimateAtlas(Data:AnimateAtlas, Image:FlxGraphicAsset):FlxAnimateFrames
    {
        var frames:FlxAnimateFrames = new FlxAnimateFrames();
        var graphic = FlxG.bitmap.add(Image);
        var spritemapFrames = FlxAtlasFrames.findFrame(graphic);
        if (spritemapFrames == null)
        {
            spritemapFrames = new FlxAnimateFrames();
            for (curSprite in Data.ATLAS.SPRITES)
            {
                spritemapFrames.pushFrame(textureAtlasHelper(graphic, curSprite.SPRITE, Data.meta));
            }
        }
        graphic.addFrameCollection(spritemapFrames);
        frames.animateConcat(spritemapFrames);

        if (frames.frames == [])
        {
            FlxG.log.error("the Frames parsing couldn't parse any of the frames, it's completely empty! \n Maybe you misspelled the Path?");
            return null;
        }
        return frames;
    }

    /**
     * 
     * @param Path the Json in specific, can be the path of it or the actual json
     * @param Image the image which the file is referencing **WARNING:** if you set the path as a json, it's obligatory to set the image!
     * @return A new instance of `FlxAtlasFrames`
     */
    public static function fromJson(Path:FlxJson, ?Image:FlxGraphicAsset):FlxAtlasFrames
    {
        if (Path is String && !Assets.exists(Path))
            return null;

        var data:JsonNormal = (Path is String) ? haxe.Json.parse(#if sys sys.io.File.getContent(Path) #else Assets.getText(Path) #end) : Path;
        if (Image == null)
        {
            if (Path is String)
            {
                var splitDir = Path.split("/");
                splitDir.pop();
                splitDir.push(data.meta.image);
                Image = splitDir.join("/");
            }
            else
            {
                FlxG.log.error("The Path isn't a String but a Json, you need to set an image if you use Jsons!");
                return null;
            }
        }

        var graphic:FlxGraphic = FlxG.bitmap.add(Image);
		if (graphic == null)
			return null;

		// No need to parse data again
		var frames:FlxAtlasFrames = FlxAtlasFrames.findFrame(graphic);
		if (frames != null)
			return frames;

		frames = new FlxAtlasFrames(graphic);

		// JSON-Array
		if ((data.frames is Array))
		{
			for (frame in Lambda.array(data.frames))
			{
				texturePackerHelper(frame.filename, frame, frames);
			}
		}
		// JSON-Hash
		else
		{
			for (frameName in Reflect.fields(data.frames))
			{
				texturePackerHelper(frameName, Reflect.field(data.frames, frameName), frames);
			}
		}

		return frames;
    }
    /**
     * Edge Animate
     * @param Path the Path of the .eas
     * @param Image (Optional) the Image
     * @return Cute little Frames to use ;)
     */
    public static function fromEdgeAnimate(Path:String, ?Image:FlxGraphicAsset):FlxAtlasFrames
    {
        return fromJson((StringTools.startsWith(Path, "{")) ? haxe.Json.parse(Path) : Path, Image);
    }
    /**
     * Starling spritesheet format parser which uses a preference list from Mac computer shit
     * @param Path the dir of the preference list
     * @param Image (Optional) the Image
     * @return Some recently cooked Frames for you ;)
     */
    public static function fromStarling(Path:FlxPropertyList, ?Image:FlxGraphicAsset):FlxAtlasFrames
    {
        if (Path is String && !Assets.exists(Path))
            return null;
        var data:Plist = (Path is String) ? PropertyList.parse(Assets.getText(Path)) : Path;
        if (Image == null)
        {
            if (Path is String)
            {
                var splitDir = Path.split("/");
                splitDir.pop();
                splitDir.push(data.metadata.textureFileName);
                Image = splitDir.join("/");
            }
            else
            {
                return null;
            }
        }
        

        var graphic:FlxGraphic = FlxG.bitmap.add(Image, false);
		if (graphic == null)
			return null;

		// No need to parse data again
		var frames:FlxAtlasFrames = FlxAtlasFrames.findFrame(graphic);
		if (frames != null)
			return frames;

		frames = new FlxAtlasFrames(graphic);

        for (frameName in Reflect.fields(data.frames))
        {
            starlingHelper(frameName, Reflect.field(data.frames, frameName), frames);
        }

		return frames;
    }
    /**
     * Cocos2D spritesheet format parser, which basically has 2 versions,
     * One is basically Starling (2v) and the other one which is a more fucky and weird (3v)
     * @param Path the Path of the plist
     * @param Image (Optional) the image
     * @return Recently made Frames for your dispose ;)
     */
    public static function fromCocos2D(Path:String, ?Image:FlxGraphicAsset):FlxAtlasFrames
    {
        if (!Assets.exists(Path))
            return null;
        var data:Plist = PropertyList.parse(Assets.getText(Path));
        if (data.metadata.format == 2)
        {
            return fromStarling(Path, Image);
        }
        else
        {
            if (Image == null)
            {
                if (Path is String)
                {
                    var splitDir = Path.split("/");
                    splitDir.pop();
                    splitDir.push(data.metadata.target.name);
                    Image = splitDir.join("/");
                }
                else
                {
                    return null;
                }
            }
            var graphic:FlxGraphic = FlxG.bitmap.add(Image);
            if (graphic == null)
                return null;

            // No need to parse data again
            var frames:FlxAtlasFrames = FlxAtlasFrames.findFrame(graphic);
            if (frames != null)
                return frames;

            frames = new FlxAtlasFrames(graphic);

            for (frameName in Reflect.fields(data.frames))
            {
                cocosHelper(frameName, Reflect.field(data.frames, frameName), frames);
            }

            return frames;
        }
    }
    /**
     * EaselJS spritesheet format parser, pretty weird stuff.
     * @param Path The Path of the jsFile
     * @param Image (optional) the Path of the image
     * @return New frames made for you to use ;)
     */
    public static function fromEaselJS(Path:String, ?Image:FlxGraphicAsset):FlxAtlasFrames
    {
        var hugeFrames:FlxAtlasFrames = new FlxAtlasFrames(null);
        var separatedJS = Assets.getText(Path).split("\n");
        var lines:Array<String> = [];
        for (line in separatedJS)
        {
            if (StringTools.contains(line, "new createjs.SpriteSheet({"))
                lines.push(line);
        }
        var names:Array<String> = [];
        var jsons:Array<JSJson> = [];
        for (line in lines)
        {
            names.push(StringTools.replace(line.split(".")[0], "_", " "));
            var curJson = StringTools.replace(StringTools.replace(line.split("(")[1], ")", ""), ";", "");
            var parsedJson = haxe.Json.parse(~/({|,\s*)(\S+)(\s*:)/g.replace(curJson, '$1\"$2"$3'));
            jsons.push(parsedJson);
        }
        var prevName = "";
        var imagePath = Path.split("/");
        imagePath.pop();
        for (i in 0...names.length)
        {
            var times = 0;
            var name = names[i];
            var json = jsons[i];
            var bitmap = FlxG.bitmap.add(Assets.getBitmapData((Image == null) ? '${imagePath.join("/")}/${json.images[0]}' : Image));
            var frames = new FlxAtlasFrames(bitmap);
            for (frame in json.frames)
            {
                var frameRect:FlxRect = new FlxRect(frame[0], frame[1], frame[2], frame[3]);
                var sourceSize:FlxPoint = new FlxPoint(frameRect.width, frameRect.height);
                var offset = new FlxPoint(-frame[5], -frame[6]);
                frames.addAtlasFrame(frameRect, sourceSize, offset, name + Std.string(times));
                times++;
            }
            for (frame in frames.frames)
            {
                hugeFrames.pushFrame(frame);
            }
        }
        return hugeFrames;
    }

    static function cocosHelper(FrameName:String, FrameData:Dynamic, Frames:FlxAtlasFrames)
    {
        var rotated:Bool = FrameData.textureRotated;
        var name:String = FrameName;
        var sourceSize:FlxPoint = FlxPoint.get(Std.parseFloat(FrameData.spriteSourceSize[0]), Std.parseFloat(FrameData.spriteSourceSize[1]));
        var offset:FlxPoint = FlxPoint.get(-Std.parseFloat(FrameData.spriteOffset[0]), -Std.parseFloat(FrameData.spriteOffset[1]));
        var angle:FlxFrameAngle = FlxFrameAngle.ANGLE_0;
        var frameRect:FlxRect = null;

        var frame = FrameData.textureRect;
        if (rotated)
        {
            frameRect = FlxRect.get(Std.parseFloat(frame[0]), Std.parseFloat(frame[1]), Std.parseFloat(frame[3]), Std.parseFloat(frame[2]));
            angle = FlxFrameAngle.ANGLE_NEG_90;
        }
        else
        {
            frameRect = FlxRect.get(Std.parseFloat(frame[0]), Std.parseFloat(frame[1]), Std.parseFloat(frame[2]), Std.parseFloat(frame[3]));
        }

        Frames.addAtlasFrame(frameRect, sourceSize, offset, name, angle);
    }
    
    static function starlingHelper(FrameName:String, FrameData:Dynamic, Frames:FlxAtlasFrames):Void
    {
        var rotated:Bool = FrameData.rotated;
        var name:String = FrameName;
        var sourceSize:FlxPoint = FlxPoint.get(Std.parseFloat(FrameData.sourceSize[0]), Std.parseFloat(FrameData.sourceSize[1]));
        var offset:FlxPoint = FlxPoint.get(-Std.parseFloat(FrameData.offset[0]), -Std.parseFloat(FrameData.offset[1]));
        var angle:FlxFrameAngle = FlxFrameAngle.ANGLE_0;
        var frameRect:FlxRect = null;

        var frame = FrameData.frame;
        if (rotated)
        {
            frameRect = FlxRect.get(Std.parseFloat(frame[0]), Std.parseFloat(frame[1]), Std.parseFloat(frame[3]), Std.parseFloat(frame[2]));
            angle = FlxFrameAngle.ANGLE_NEG_90;
        }
        else
        {
            frameRect = FlxRect.get(Std.parseFloat(frame[0]), Std.parseFloat(frame[1]), Std.parseFloat(frame[2]), Std.parseFloat(frame[3]));
        }

        Frames.addAtlasFrame(frameRect, sourceSize, offset, name, angle);
    }

    static function textureAtlasHelper(SpriteMap:FlxGraphic, limb:AnimateSpriteData, curMeta:Meta)
    {
        
        var width = (limb.rotated) ? limb.h : limb.w;
        var height = (limb.rotated) ? limb.w : limb.h;

        @:privateAccess
        var curFrame = new FlxFrame(SpriteMap);

        curFrame.name = limb.name;
        curFrame.sourceSize.set(width, height);
        curFrame.frame = new FlxRect(limb.x, limb.y, limb.w, limb.h);

        if (limb.rotated)
        {
            curFrame.angle = ANGLE_NEG_90;
        }

        return curFrame;
    }
    
    static function texturePackerHelper(FrameName:String, FrameData:Dynamic, Frames:FlxAtlasFrames):Void
	{
		var rotated:Bool = FrameData.rotated;
		var name:String = FrameName;
		var sourceSize:FlxPoint = FlxPoint.get(FrameData.sourceSize.w, FrameData.sourceSize.h);
		var offset:FlxPoint = FlxPoint.get(FrameData.spriteSourceSize.x, FrameData.spriteSourceSize.y);
		var angle:FlxFrameAngle = FlxFrameAngle.ANGLE_0;
		var frameRect:FlxRect = null;

		if (rotated)
		{
			frameRect = FlxRect.get(FrameData.frame.x, FrameData.frame.y, FrameData.frame.h, FrameData.frame.w);
			angle = FlxFrameAngle.ANGLE_NEG_90;
		}
		else
		{
			frameRect = FlxRect.get(FrameData.frame.x, FrameData.frame.y, FrameData.frame.w, FrameData.frame.h);
		}

		Frames.addAtlasFrame(frameRect, sourceSize, offset, name, angle);
	}
    static function max(a:Int, b:Int):Int
		return a < b ? b : a;
}
// code made by noonat 11 years ago, not mine lol
class PropertyList 
{
    static var _dateRegex:EReg = ~/(\d{4}-\d{2}-\d{2})(?:T(\d{2}:\d{2}:\d{2})Z)?/;

    /**
     * Parse an Apple property list XML file into a dynamic object. If
     * the property list is empty, an empty object will be returned.
     * @param text Text contents of the property list file.
     */
    static public function parse(text:String):Dynamic 
    {
        var fast = new Access(Xml.parse(text).firstElement());
        return fast.hasNode.dict ? parseDict(fast.node.dict) : {};
    }

    static function parseDate(text:String):Date 
    {
        if (!_dateRegex.match(text)) 
        {
            throw 'Invalid date "' + text + '" (only yyyy-mm-dd and yyyy-mm-ddThh:mm:ssZ supported)';
        }
        text = _dateRegex.matched(1);
        if (_dateRegex.matched(2) != null) 
        {
            text += ' ' + _dateRegex.matched(2);
        }
        return Date.fromString(text);
    }

    static function parseDict(node:Access):Dynamic
    {
        var key:String = null;
        var result:Dynamic = {};
        for (childNode in node.elements) 
        {
            if (childNode.name == 'key') 
            {
                key = childNode.innerData;
            } else if (key != null) 
            {
                Reflect.setField(result, key, parseValue(childNode));
            }
        }
        return result;
    }

    static function parseValue(node:Access):Dynamic
    {
        var value:Dynamic = null;
        switch (node.name) 
        {
            case 'array':
            value = new Array<Dynamic>();
            for (childNode in node.elements) 
            {
                value.push(parseValue(childNode));
            }
            
            case 'dict':
            value = parseDict(node);
            
            case 'date':
            value = parseDate(node.innerData);
            
            case 'string':
            var thing:Dynamic = node.innerData;
            if (thing.charAt(0) == "{")
            {
                thing = StringTools.replace(thing, "{", "");
                thing = StringTools.replace(thing, "}", "");
                thing = thing.split(",");
            }
            value = thing;
            case 'data':
            value = node.innerData;
            
            case 'true':
            value = true;
            
            case 'false':
            value = false;
            
            case 'real':
            value = Std.parseFloat(node.innerData);
            
            case 'integer':
            value = Std.parseInt(node.innerData);
        }
        return value;
    }
}
typedef JSJson =
{
    var images:Array<String>;
    var frames:Array<Array<Int>>; 
}
typedef FlxSparrow = OneOfTwo<String, Xml>;
typedef FlxJson = OneOfTwo<String, JsonNormal>;
typedef FlxPropertyList = OneOfTwo<String, Plist>;
typedef JsonNormal =
{
	frames:Dynamic,
    meta:Meta
}
typedef Plist = 
{
    frames:Dynamic,
    metadata:Dynamic
}