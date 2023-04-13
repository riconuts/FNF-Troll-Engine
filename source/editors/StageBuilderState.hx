package editors;

import flixel.math.FlxMath;
import openfl.events.MouseEvent;
import flixel.text.FlxText;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.FlxCamera;
import flixel.graphics.FlxGraphic;
import openfl.geom.Rectangle;

// this is pure spaghetti

typedef ObjectProperties = {
    var ?x:Float;
    var ?y:Float;

    var ?scrollX:Float;
    var ?scrollY:Float;

    var ?scaleX:Float;
    var ?scaleY:Float;
}

typedef ObjectData = {
    //// Real shit
    var ?imagePath:String;
    var ?onForeground:Bool;
    var ?properties:ObjectProperties;
    var ?name:String;

    ////
    var ?editorSprite:StageSprite;
    var ?hideInEditor:Bool;
}

class Layer extends flixel.group.FlxSpriteGroup
{
    var parent:LayerWindow;
    public var object:Null<ObjectData> = null;
    public var isSelected:Bool = false;

    public var bg:FlxSprite;
    public var label:FlxText;
    // public var visSpr:FlxSprite;

    public static var bgTexture:Null<FlxGraphic> = null;
    public static function makeBgTexture()
    {
        var bgTexture = FlxGraphic.fromRectangle(240, 44, 0x0, true);
        bgTexture.bitmap.fillRect(new Rectangle(1,1,240-1,44-1), 0xFF0078D7);
        bgTexture.bitmap.fillRect(new Rectangle(2,2,240-2,44-2),0xFF145080);

        bgTexture.persist = true; // oh no bro

        Layer.bgTexture = bgTexture;
    }

    public function new(parent, object, camera)
    {
        this.parent = parent;
        this.object = object;
        
        super();

        // TODO: use the 9 slice thing whatever
        bg = new FlxSprite(0, 0, bgTexture);
        bg.alpha = 0;
        add(bg);

        label = new FlxText(8, (44 - 12) * 0.5, 240 - 8, "sowy", 12);
        add(label);

        this.camera = camera;

        updateObj();

        FlxG.stage.addEventListener(MouseEvent.MOUSE_MOVE, onMouseMove);
        FlxG.stage.addEventListener(MouseEvent.MOUSE_UP, onMouseUp);
    }

    override public function destroy(){
        FlxG.stage.removeEventListener(MouseEvent.MOUSE_MOVE, onMouseMove);
        FlxG.stage.removeEventListener(MouseEvent.MOUSE_UP, onMouseUp);

        super.destroy();
    }

    public function updateObj() 
    {
        var daName = object.name;
        if (daName == null) daName = object.imagePath;
        if (daName == null) daName = "unknown";

        label.text = daName;    
    }

    public function updateAlpha() 
    {
        if (isSelected)
            bg.alpha = 1;    
        else if (FlxG.mouse.overlaps(this, this.camera))
            bg.alpha = 0.4;
        else
            bg.alpha = 0;
    }

    function onMouseMove(?e) 
    {   
        updateAlpha();
    }

    function onMouseUp(?e) 
    {
        if (FlxG.mouse.overlaps(this, this.camera)){
            parent.selectLayer(this);   
            updateAlpha();
        }
    }
}

class LayerWindow extends FlxTypedGroup<FlxBasic>
{
    var x:Int;
    var y:Int;

    var parent:StageBuilderState;

    var unusedLayers:Array<Layer> = [];
    var layers = new Map<ObjectData, Layer>();

    var curSelected(default, set):Null<Layer>;
    function set_curSelected(laeyr){
        curSelected = laeyr;

        if (parent != null)
            parent.curSelected = laeyr.object;
        
        return laeyr;
    }

    var topBar:FlxSprite;
    var layerCamera:FlxCamera;
    var bottomBar:FlxSprite;

    var managmentButtons:Array<FlxSprite> = [];

    public function new(parent:StageBuilderState, camera:FlxCamera)
    {
        this.parent = parent;
        this.camera = camera;

        super();

        layerCamera = new FlxCamera();
        layerCamera.setSize(240, 266);
        layerCamera.bgColor = 0xFF404040;
        FlxG.cameras.add(layerCamera, false);

        topBar = new FlxSprite().makeGraphic(240, 24, 0xFF1A1A1A);
        topBar.scrollFactor.set();
        topBar.camera = camera;
        add(topBar);

        bottomBar = new FlxSprite().makeGraphic(240, 24, 0xFF282828);
        bottomBar.scrollFactor.set();
        bottomBar.camera = camera;
        add(bottomBar);
        
        ////        
        var grafix = Paths.image("stageeditor/layer_management"); 

        for (i in 0...6){
            var button = new FlxSprite().loadGraphic(grafix, true, 16, 16);

            if (i == 3)
                button.animation.add("button", [i-1], 0, true, false, true);
            else
                button.animation.add("button", [i > 3 ? i-1 : i], 0, true);
            
            
            button.animation.play("button", true);
            button.camera = camera;

            managmentButtons.push(button);
            add(button);
        }

        ////
        Layer.makeBgTexture();

        updatePos();

        FlxG.stage.addEventListener(MouseEvent.MOUSE_DOWN, onMouseDown);
        FlxG.stage.addEventListener(MouseEvent.MOUSE_MOVE, onMouseMove);
        FlxG.stage.addEventListener(MouseEvent.MOUSE_UP, onMouseUp);
    }

    override public function destroy(){
        Layer.bgTexture.destroy();
        Layer.bgTexture = null;

        FlxG.stage.removeEventListener(MouseEvent.MOUSE_DOWN, onMouseDown);
        FlxG.stage.removeEventListener(MouseEvent.MOUSE_MOVE, onMouseMove);
        FlxG.stage.removeEventListener(MouseEvent.MOUSE_UP, onMouseUp);

        super.destroy();
    }

    var holdInfo:Null<{mx:Int, my:Int, sx:Int, sy:Int}> = null;

    function onMouseDown(?e) {
        if (FlxG.mouse.overlaps(topBar, this.camera)){
            holdInfo = {mx: FlxG.mouse.screenX, my: FlxG.mouse.screenY, sx: Std.int(this.x), sy: Std.int(this.y)};
            return;
        }

        holdInfo = null;

        for (idx in 0...managmentButtons.length){
            var button = managmentButtons[idx];
            
            if (!FlxG.mouse.overlaps(button, button.camera))
                continue;
            
            switch (idx){
                case 0:  // add new obj
                    var pos = (curSelected == null) ? -1 : parent.objectArray.indexOf(curSelected.object);
                    var newObj:ObjectData = {};

                    if (pos == -1)
                        parent.objectArray.push(newObj);
                    else
                        parent.objectArray.insert(pos, newObj);
                    
                    parent.updateObjects();

                    selectLayer(layers.get(newObj));

                case 1: // remove selected obj
                    if (curSelected != null){
                        var pos = parent.objectArray.indexOf(curSelected.object);

                        parent.objectArray.remove(curSelected.object);

                        if (parent.objectArray.length != 0){
                            pos = FlxMath.minInt(pos+1, parent.objectArray.length-1);
                            selectLayer(layers.get(parent.objectArray[pos]));
                        }

                        parent.updateObjects();
                    }else 
                        trace("noooooi");
                case 3: // move up  
                    if (curSelected != null){       
                        var pos = parent.objectArray.indexOf(curSelected.object);

                        if (pos == 0) pos = parent.objectArray.length;

                        parent.objectArray.remove(curSelected.object);
                        parent.objectArray.insert(pos-1, curSelected.object);
                        parent.updateObjects();
                    }
                case 2: // move down
                    if (curSelected != null){       
                        var pos = parent.objectArray.indexOf(curSelected.object);

                        if (pos == parent.objectArray.length-1) pos = -1;

                        parent.objectArray.remove(curSelected.object);
                        parent.objectArray.insert(pos+1, curSelected.object);
                        parent.updateObjects();
                    }
                case 4: // clone

                case 5: // modify

                default: trace(idx);
            }
            break;
        }
    }

    function onMouseMove(?e){
        if (holdInfo != null){
            var xDiff = FlxG.mouse.screenX - holdInfo.mx;
            var yDiff = FlxG.mouse.screenY - holdInfo.my;

            updatePos(holdInfo.sx + xDiff, holdInfo.sy + yDiff);
        }
    }

    function updatePos(x=0,y=0){
        this.x = x;
        this.y = y;

        topBar.setPosition(x, y);
        layerCamera.setPosition(x, topBar.y + topBar.height);
        bottomBar.setPosition(x, layerCamera.y + layerCamera.height);

        for (idx in 0...managmentButtons.length){
            managmentButtons[idx].setPosition(x+4 + (16+8)*idx, bottomBar.y+4);
        }
    }
        
    function onMouseUp(?e){
        holdInfo = null;
    }

    public function selectLayer(?layer:Layer){
        if (curSelected != null){
            curSelected.isSelected = false;
            curSelected.updateAlpha();
        }
        
        curSelected = layer;

        if (layer != null){
            layer.isSelected = true;
            layer.updateAlpha();
        }
    }

    public function updateLayers()
    {
        var lastObj = null;
        if (curSelected != null)
            lastObj = curSelected.object;

        selectLayer(null);

        for (object => layer in layers)
        {
            remove(layer, true);
            layer.destroy();
        }
        
        for (idx in 0...parent.objectArray.length)
        {
            var obj = parent.objectArray[parent.objectArray.length-(idx+1)];
            var layer = new Layer(this, obj, layerCamera);

            layer.y = 44 * idx;
            layer.camera = layerCamera;
            add(layer);

            layers.set(obj, layer);

            if (obj == lastObj)
                selectLayer(layer);
        }

        while (unusedLayers.length > 0)
            unusedLayers.pop().destroy();
    }
}

class StageSprite extends FlxSprite
{
    public var data:ObjectData;

    public function updateData(?data:ObjectData)
    {
        if (data != null)
            this.data = data;

        if (data == null){
            trace("WARNING: No data");
            return;
        }
       
        ////
        loadGraphic(Paths.image(data.imagePath));

        if (data.properties == null){
            trace("no properties?");
            data.properties = {};
        }

        setPosition(
            data.properties.x != null ? data.properties.x : 0,
            data.properties.y != null ? data.properties.y : 0
        );
        scale.set(
            data.properties.scaleX != null ? data.properties.scaleX : 1,
            data.properties.scaleY != null ? data.properties.scaleY : 1            
        );
        scrollFactor.set(
            data.properties.scrollX != null ? data.properties.scrollX : 1,
            data.properties.scrollY != null ? data.properties.scrollY : 1  
        );

        updateHitbox();
    }
}

class StageBuilderState extends MusicBeatState
{
    var camGame = new FlxCamera();
    var camHUD = new FlxCamera();

    var stage = new FlxTypedGroup<StageSprite>();
    var foreground = new FlxTypedGroup<StageSprite>();

    public var curSelected:ObjectData;

    public var objectArray:Array<ObjectData> = [];
    var layerWindow:LayerWindow;

    override public function create()
    {
        FlxG.mouse.visible = true;
        
        FlxG.cameras.reset(camGame);
        FlxG.cameras.add(camHUD, false);

        camGame.bgColor = 0xFF00FF00;
        camHUD.bgColor.alpha = 0;

        FadeTransitionSubstate.nextCamera = camHUD;

        ////
        add(stage);
        add(foreground);
        stage.camera = camGame;
        foreground.camera = camGame;

        objectArray.push({name: "tails", imagePath: "tails", properties: {x: 10, y: 10, scrollX: 0, scrollY: 0, scaleX: 1.1, scaleY: 1.1}});
        objectArray.push({name: "trollface", imagePath: "trollface"});
        objectArray.push({});

        layerWindow = new LayerWindow(this, camHUD);
        add(layerWindow);

        updateObjects();

        super.create();
    }

    public function updateObjects()
    {
        // trace("doing object update");

        var unusedSprites:Array<StageSprite> = [];
        var usedSprites:Map<ObjectData, StageSprite> = []; // i forgot what i wanteed to do twith this

        function checkUnused(group:FlxTypedGroup<StageSprite>){
            for (spr in group.members){
                group.remove(spr);

                if (spr == null)
                    continue;
                
                if (spr.data == null || objectArray.indexOf(spr.data) == -1){
                    spr.data = null;
                    unusedSprites.push(spr);
                }else{
                    usedSprites.set(spr.data, spr);
                }
            }
        }

        checkUnused(stage);
        checkUnused(foreground);

        for (obj in objectArray){
            if (obj.editorSprite == null)
            {
                if (unusedSprites.length > 0){
                    obj.editorSprite = unusedSprites.pop();
                    trace('reused a sprite for ${obj.name}');
                }else{
                    obj.editorSprite = new StageSprite();
                    trace('new sprite for ${obj.name}');
                }
            }

            obj.editorSprite.updateData(obj);
            obj.editorSprite.camera = camGame;
            (obj.onForeground ? foreground : stage).add(obj.editorSprite);
        }

        for (spr in unusedSprites){
            trace('Killed unused sprite ${spr.data == null ? "with no data" : spr.data.name}');
            spr.destroy();
        }

        layerWindow.updateLayers();
    }
}