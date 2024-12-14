package flxanimate.frames;
#if USING_FLXANIMATE
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
import openfl.Assets;
import openfl.display.BitmapData;
import flixel.system.FlxAssets.FlxGraphicAsset;
#if haxe4
import haxe.xml.Access;
#else
import haxe.xml.Fast as Access;
#end
import flixel.graphics.frames.FlxFrame;

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
     * Helper function to parse several Spritemaps from a texture atlas via `fromSpritemap()`
     * 
     * @param Path          The Path of the directory.
     * @return              a new instance of `FlxAnimateFrames`.
     * @see `fromSpriteMap()`
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
            var thing = (zip != null) ? zip :  Zip.unzip(Zip.readZip(funkin.Paths.bytes(Path)));
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
                        // frames.pushFrame(textureAtlasHelper(FlxG.bitmap.add(curImage), sprites.SPRITE, curJson.meta));
                    }
                }
                else
                    FlxG.log.error('the Image called "${curJson.meta.image}" isnt in this zip file!');
            }
            zip == null;
        }
        else
        {
/*             var texts = Assets.list(TEXT).filter((text) -> StringTools.startsWith(text, '$Path/spritemap'));
            */
			var texts:Array<String> = []; // text files
			var idx:Int = 1;
			if (funkin.Paths.exists('$Path/spritemap.json'))
				texts.push('$Path/spritemap');
			else{
				while (funkin.Paths.exists('${Path}/spritemap${idx}.json')){
					texts.push('${Path}/spritemap${idx}');
					idx++;
				}
			}

			if (texts.length > 1) {
				texts.sort(function(a, b) {
					var an = Std.parseInt(haxe.io.Path.withoutDirectory(a).substr(9));
					var bn = Std.parseInt(haxe.io.Path.withoutDirectory(b).substr(9));
					if (Math.isNaN(an) || Math.isNaN(bn))
						return 0;

					return an - bn;
				});
			} 

            var spritemaps:Array<{image:FlxGraphic, json:AnimateAtlas}> = [];
            for (text in texts)
            {
                var txt = funkin.Paths.getContent(text + ".json");
                if (txt.charCodeAt(0) == 0xFEFF)
                    txt = txt.substring(1);
                var json:AnimateAtlas = haxe.Json.parse(txt);

				spritemaps.push({image: funkin.Paths.cacheGraphic('$Path/${json.meta.image}'), json: json});
            }
            
            for (spritemap in spritemaps)
            {
                var spritemapFrames = fromSpriteMap(spritemap.json, spritemap.image);
		if (spritemapFrames != null)
                	frames.addAtlas(spritemapFrames);
            }

            if (frames.frames == [])
            {
                FlxG.log.error("the Frames parsing couldn't parse any of the frames, it's completely empty! \n Maybe you misspelled the Path?");
                return null;
            }
        }
        return frames;
    }

    /**
     * Parses a spritemap, proceeding from a texture atlas export.
     * @param Path 
     * @param Image 
     * @return FlxAtlasFrames
     */
    public static function fromSpriteMap(Path:FlxSpriteMap, ?Image:FlxGraphicAsset):FlxAtlasFrames
    {
        if (Path == null) return null;

        var json:AnimateAtlas = null;
        if (Path is String)
        {
            var str:String = StringTools.replace(cast Path, "\\", "/");
            json = haxe.Json.parse((StringTools.contains(str, "/")) ? funkin.Paths.getContent(str) : str);
        }
        else
            json = Path;

        if (json == null) return null;

        if (Image == null)
        {
            if (Path is String)
            {
                Image = haxe.io.Path.addTrailingSlash(haxe.io.Path.directory(Path)) + json.meta.image;
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

        for (sprite in json.ATLAS.SPRITES)
        {
            frames.pushFrame(textureAtlasHelper(graphic, sprite.SPRITE));
        }

        return frames;
    }

    #if (flixel < "5.4.0")
    public function addAtlas(collection:FlxFramesCollection, overwriteHash:Bool = false):FlxAtlasFrames
    {
        if (collection.parent == null)
            throw "Cannot add atlas with null parent";
        
        if (parents.indexOf(collection.parent) == -1)
            parents.push(collection.parent);
        for (frame in collection.frames)
            pushFrame(frame);
        return this;
    }
    #end
    /**
     * Sparrow spritesheet format parser with support of both of the versions and making the image completely optional to you.
     * @param Path The direction of the Xml you want to parse.
     * @param Image (Optional) the image of the Xml.
     * @return A new instance of `FlxAtlasFrames`
     */
    public static function fromSparrow(Path:FlxSparrow, ?Image:FlxGraphicAsset):FlxAtlasFrames
	{
        if (Path is String && !funkin.Paths.exists(Path))
			return null;

		var data:Access = new Access((Path is String) ? Xml.parse(funkin.Paths.getContent(Path)).firstElement() : Path.firstElement());
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
					Std.parseInt(texture.att.frameHeight)) : new FlxRect(0, 0, rect.width, rect.height);

            if (size.width == 0 || size.height == 0)
            {
                size.setSize(1,1);
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
     * @param Path the Json in specific, can be the path of it or the actual json
     * @param Image the image which the file is referencing **WARNING:** if you set the path as a json, it's obligatory to set the image!
     * @return A new instance of `FlxAtlasFrames`
     */
    public static function fromJson(Path:FlxJson, ?Image:FlxGraphicAsset):FlxAtlasFrames
    {
        if (Path is String && !funkin.Paths.exists(Path))
            return null;
        var data:JsonNormal = (Path is String) ? haxe.Json.parse(funkin.Paths.getContent(Path)) : Path;
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
        if (Path is String && !funkin.Paths.exists(Path))
            return null;
        var data:Plist = (Path is String) ? PropertyList.parse(funkin.Paths.getContent(Path)) : Path;
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
        if (!funkin.Paths.exists(Path))
            return null;
        var data:Plist = PropertyList.parse(funkin.Paths.getContent(Path));
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
        var separatedJS = funkin.Paths.getContent(Path).split("\n");
        var spriteSheetReg = ~/new createjs.SpriteSheet/;
        
        
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
			var bitmap = funkin.Paths.cacheGraphic((Image == null) ? '${imagePath.join("/")}/${json.images[0]}' : Image);
            var frames = new FlxAtlasFrames(bitmap);
            var initialFrame = [json.frames[0][5], json.frames[0][6]];
            for (frame in json.frames)
            {
                var frameRect:FlxRect = new FlxRect(frame[0], frame[1], frame[2], frame[3]);
                var sourceSize:FlxPoint = new FlxPoint(frameRect.width, frameRect.height);
                var offset = new FlxPoint(-frame[5] + initialFrame[0], -frame[6] + initialFrame[1]);
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

    static function textureAtlasHelper(SpriteMap:FlxGraphic, limb:AnimateSpriteData)
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
typedef FlxSpriteMap = OneOfTwo<String, AnimateAtlas>;
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
#else
class FlxAnimateFrames {}
#end