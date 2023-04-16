package editors;

import flixel.input.keyboard.FlxKey;
import openfl.events.KeyboardEvent;
import openfl.events.FocusEvent;
import flixel.addons.ui.FlxInputText;
import flixel.math.FlxMath;
import openfl.events.MouseEvent;
import flixel.text.FlxText;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.FlxCamera;
import flixel.graphics.FlxGraphic;
import openfl.geom.Rectangle;

using StringTools;

// this is pure spaghetti
// also i should probably make this its own thing rather than embedding it into tgt lol

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
    var ?onForeground:Bool;
    var ?properties:ObjectProperties;
    var ?name:String;

    ////
    var ?editorSprite:StageSprite;
    var ?hideInEditor:Bool;
}

class FocusHelper // lol
{
    static var onUnfocus:Void->Void;

    public static function unFocusCurrent()
    {
        if (onUnfocus != null) onUnfocus();
        onUnfocus = null;
    }

    public static function setFocus(?onFocusLost)
    {
        unFocusCurrent();

        onUnfocus = onFocusLost;
    }
}

class Layer extends flixel.group.FlxSpriteGroup
{
    var parent:LayerWindow;
    public var data:Null<ObjectData> = null;
    public var isSelected:Bool = false;

    public var bg:FlxSprite;
    public var label:FlxInputText;
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

    public function new(parent, data, camera)
    {
        this.parent = parent;
        this.data = data;
        
        super();

        // TODO: use the 9 slice thing whatever
        bg = new FlxSprite(0, 0, bgTexture);
        bg.alpha = 0;
        add(bg);

        label = new FlxInputText(8, (44 - 12) * 0.5, 240 - 8*2, "sowy", 12);
        label.callback = function(text, action)
        {
            if (action == "enter"){
                label.hasFocus = false; 
                data.name = text;
                data.editorSprite.updateImage();
            }
        }
        label.focusGained = FocusHelper.unFocusCurrent;
        label.focusLost = ()->{label.text = data.name;};
        add(label);

        this.camera = camera;

        updateObj();

        FlxG.stage.addEventListener(MouseEvent.MOUSE_MOVE, onMouseMove);
    }

    override public function destroy(){
        FlxG.stage.removeEventListener(MouseEvent.MOUSE_MOVE, onMouseMove);

        super.destroy();
    }

    public function updateObj() 
    {
        if (data.name == null)
            data.name = "unknown";

        label.text = data.name;    
    }

    public function updateAlpha() 
    {
        if (isSelected)
            bg.alpha = 1;    
        else if (isMouseOverlaped())
            bg.alpha = 0.4;
        else
            bg.alpha = 0;
    }

    function onMouseMove(e) 
    {   
        updateAlpha();
    }

    public function isMouseOverlaped()
    {
        return FlxG.mouse.overlaps(this, this.camera);
    }
}

class DragableWindow extends FlxTypedGroup<FlxBasic>
{
    var topBar:FlxSprite;
    var layerCamera:FlxCamera;
}

class LayerWindow extends FlxTypedGroup<FlxBasic>
{
    public var x:Int=0;
    public var y:Int=0;
    public var width:Int=0;
    public var height:Int=0;

    var parent:StageBuilderState;

    var unusedLayers:Array<Layer> = [];
    var layers = new Map<ObjectData, Layer>();

    var curSelected(default, set):Null<Layer>;
    function set_curSelected(laeyr){
        curSelected = laeyr;

        if (parent != null)
            parent.curSelected = laeyr != null ? laeyr.data : null;
        
        return laeyr;
    }

    var topBar:FlxSprite;
    var layerCamera:FlxCamera;
    var layerHitbox:FlxObject;
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

        layerHitbox = new FlxObject(0, 0, layerCamera.width, layerCamera.height);
        layerHitbox.scrollFactor.set();
        layerHitbox.camera = layerCamera;
        add(layerHitbox);

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

        updatePos(FlxG.width-240, 0);

        FlxG.stage.addEventListener(MouseEvent.MOUSE_DOWN, onMouseDown);
        //FlxG.stage.addEventListener(MouseEvent.MOUSE_MOVE, onMouseMove);
        FlxG.stage.addEventListener(MouseEvent.MOUSE_UP, onMouseUp);

        FlxG.stage.addEventListener(MouseEvent.MOUSE_WHEEL, onMouseWheel);
    }

    override public function destroy(){
        Layer.bgTexture.destroy();
        Layer.bgTexture = null;

        FlxG.stage.removeEventListener(MouseEvent.MOUSE_DOWN, onMouseDown);
        //FlxG.stage.removeEventListener(MouseEvent.MOUSE_MOVE, onMouseMove);
        FlxG.stage.removeEventListener(MouseEvent.MOUSE_UP, onMouseUp);

        FlxG.stage.removeEventListener(MouseEvent.MOUSE_WHEEL, onMouseWheel);

        super.destroy();
    }

    inline static function mouseOverlaps(what)
    {
        return FlxG.mouse.overlaps(what, what.camera);
    }

    function onMouseWheel(e:MouseEvent){
        if (mouseOverlaps(layerHitbox)){
            layerCamera.scroll.y += -FlxG.mouse.wheel * 15;
            e.stopImmediatePropagation();
        }
    }

    var holdInfo:Null<{x:Int, y:Int}> = null;

    function onMouseDown(e:MouseEvent) {
        /* 
        if (FlxG.mouse.overlaps(topBar, this.camera))
            holdInfo = {x: FlxG.mouse.screenX, y: FlxG.mouse.screenY};
        else
            holdInfo = null;
        */

        if (mouseOverlaps(topBar) || mouseOverlaps(layerHitbox) || mouseOverlaps(bottomBar)){
            e.stopImmediatePropagation();
        }
    }

    /*
    function onMouseMove(?e){
        if (holdInfo != null){
            var xDiff = FlxG.mouse.screenX - holdInfo.x;
            var yDiff = FlxG.mouse.screenY - holdInfo.y;

            holdInfo.x = FlxG.mouse.screenX;
            holdInfo.y = FlxG.mouse.screenY;

            updatePos(x + xDiff, y + yDiff);
        }
    }
    */

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

    function addNewObj()
    {
        var pos = (curSelected == null) ? -1 : parent.objectArray.indexOf(curSelected.data);
        var newObj:ObjectData = {};

        if (pos == -1)
            parent.objectArray.push(newObj);
        else
            parent.objectArray.insert(pos, newObj);
        
        parent.updateObjects();

        selectLayer(layers.get(newObj));
    }

    function destroySelectedObj(){
        if (curSelected == null)
            return;

        var pos = parent.objectArray.indexOf(curSelected.data);
        parent.objectArray.remove(curSelected.data);

        if (parent.objectArray.length != 0){
            pos = FlxMath.minInt(pos, parent.objectArray.length-1);
            selectLayer(layers.get(parent.objectArray[pos]));
        }

        parent.updateObjects();
    }

    function moveSelectedObj(sowy:Int) {
        if (curSelected == null)
            return;

        var pos = parent.objectArray.indexOf(curSelected.data)+sowy;

        if (pos < 0)
            pos = parent.objectArray.length+sowy;
        else if (pos >= parent.objectArray.length)
            pos = sowy-1;
        
        parent.objectArray.remove(curSelected.data);
        parent.objectArray.insert(pos, curSelected.data);
        parent.updateObjects();
    }
        
    function onMouseUp(e:MouseEvent){
        holdInfo = null;

        if (FlxG.mouse.overlaps(topBar, topBar.camera)){
            e.stopImmediatePropagation();
            return;
        }

        // Check if you at least clicked on the layer window
        if (FlxG.mouse.overlaps(layerHitbox, layerHitbox.camera)){
            // Check if you clicked on a layer
            for (obj => layer in layers)
            {
                var label = layer.label;
                var labelOverlaped = FlxG.mouse.overlaps(label, label.camera);
    
                label.hasFocus = labelOverlaped;
    
                if (labelOverlaped || layer.isMouseOverlaped())
                {
                    selectLayer(layer);   
                    layer.updateAlpha();
        
                    FocusHelper.unFocusCurrent();
        
                    e.stopImmediatePropagation();
                    return;
                }
            }

            //// You didn't click on any layer.
            selectLayer(null);

            e.stopImmediatePropagation();
            return;
        }

        if (FlxG.mouse.overlaps(bottomBar, bottomBar.camera)){
            for (idx in 0...managmentButtons.length){
                var button = managmentButtons[idx];
                
                if (!FlxG.mouse.overlaps(button, button.camera))
                    continue;
                
                switch (idx){
                    case 0: addNewObj();
                    case 1: destroySelectedObj();
                    case 2: moveSelectedObj(1); // move UP
                    case 3: moveSelectedObj(-1); // move DOWN
                    case 4: // cloneSelectedObj();
                    case 5: // modifySelectedObj();
                    default: trace(idx);
                }

                break;
            }

            e.stopImmediatePropagation();
            return;
        }
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
            lastObj = curSelected.data;

        selectLayer(null);

        for (object => layer in layers)
        {
            remove(layer, true);
            layer.destroy();
        }

        layers.clear();
        
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

        var minY = 0.0;
        var maxY = 0.0;
        for (obj => layer in layers){
            minY = Math.min(minY, layer.y);
            maxY = Math.max(maxY, layer.y + layer.height);
        }
        layerCamera.setScrollBounds(null, null, minY, Math.max(maxY, layerCamera.height));

        while (unusedLayers.length > 0)
            unusedLayers.pop().destroy();
    }
}

class StageSprite extends FlxSprite
{
    public var data:ObjectData;

    public function updateImage(?newName:String)
    {
        var possibleGraphic = Paths.image(newName == null ? data.name : newName);
        loadGraphic(possibleGraphic == null ? "flixel/images/logo/default.png" : possibleGraphic);
    }

    public function updateData(?newData:ObjectData)
    {
        if (newData != null)
            data = newData;

        if (data == null)
            trace("Attempt to update an object with no data");

        if (data.properties == null)
            data.properties = {};
       
        ////
        updateImage();

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

    /*
    function moveSelectedObject(?x:Float, ?y:Float) {
        if (curSelected == null || curSelected.editorSprite == null){
            return;
        }

        final spr = curSelected.editorSprite;
        
    }

    function moveObjectTool(e:Float){
        final pressed = FlxG.keys.pressed;
        
        if (pressed.ANY)
        {
            final spr = curSelected.editorSprite;

            var spd = e/(1/60) * (pressed.SHIFT ? 15 : 5);

            if (pressed.UP)
                spr.y -= spd;
            if (pressed.DOWN)
                spr.y += spd;

            if (pressed.LEFT)
                spr.x -= spd;
            if (pressed.RIGHT)
                spr.x += spd;

            curSelected.properties.x = spr.x;
            curSelected.properties.y = spr.y;
        }
    } 
    */

    override public function create()
    {
        FlxG.mouse.visible = true;
        
        FlxG.cameras.reset(camGame);
        FlxG.cameras.add(camHUD, false);

        // i think scrollfactor gets affected by the canera size ;_;  
        camGame.width = (FlxG.width - 480);
        camGame.x = 240;

        camGame.bgColor = 0xFF00FF00;
        camHUD.bgColor.alpha = 0;

        FadeTransitionSubstate.nextCamera = camHUD;

        ////
        add(stage);
        add(foreground);
        stage.camera = camGame;
        foreground.camera = camGame;

        objectArray.push({name: "tails", properties: {x: 10, y: 10, scrollX: 0, scrollY: 0, scaleX: 1.1, scaleY: 1.1}});
        objectArray.push({name: "trollface"});
        objectArray.push({});

        layerWindow = new LayerWindow(this, camHUD);
        add(layerWindow);

        updateObjects();

        super.create();

        persistentUpdate = false;

        //toolFunction = moveObjectTool;

        FlxG.stage.addEventListener(MouseEvent.MOUSE_DOWN, onMouseDown, false, -1);
        FlxG.stage.addEventListener(MouseEvent.MOUSE_MOVE, onMouseMove, false, -1);
        FlxG.stage.addEventListener(MouseEvent.MOUSE_UP, onMouseUp, false, -1);
        FlxG.stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyDown, false, -1);
    }
    override public function destroy(){
        FlxG.stage.removeEventListener(MouseEvent.MOUSE_DOWN, onMouseDown, false);
        FlxG.stage.removeEventListener(MouseEvent.MOUSE_MOVE, onMouseMove, false);
        FlxG.stage.removeEventListener(MouseEvent.MOUSE_UP, onMouseUp, false);
        FlxG.stage.removeEventListener(KeyboardEvent.KEY_DOWN, onKeyDown, false);   

        super.destroy();
    }

    function exportStageScript(){
        var script = "function onLoad(){";

        for (obj in objectArray)
        {
            if (obj.name == null){
                trace("ERROR ON OBJ " + obj);
                continue;
            }
            var varName:String = obj.name.replace('/', '_').replace("\\", '_').replace(" ", '_');

            // Positions being null shouldn't be an issue
            script += '\n   var ${varName} = new FlxSprite(${obj.properties.x}, ${obj.properties.y}, Paths.image("${obj.name}"));';
            
            // no scaling or scroll factor YET.
            script += '\n   ${obj.onForeground ? "foreground.add" : "add"}(${varName});';
        }

        script += "\n}";

        Sys.println("STAGE SCRIPT START:");
        Sys.println(script);
        Sys.println("STAGE SCRIPT END.");
    }

    function onKeyDown(e:KeyboardEvent){
        if (e.ctrlKey && e.keyCode == FlxKey.E)
            exportStageScript();
    }

    var holdInfo:Null<{x:Int, y:Int}> = null;
    function onMouseDown(e) {
        holdInfo = {x: FlxG.mouse.screenX, y: FlxG.mouse.screenY};
        //trace("hold");
    }
    function onMouseMove(e) {
        if (holdInfo == null)
            return;

        var xDiff = FlxG.mouse.screenX - holdInfo.x;
        var yDiff = FlxG.mouse.screenY - holdInfo.y;

        holdInfo.x = FlxG.mouse.screenX;
        holdInfo.y = FlxG.mouse.screenY;

        if (curSelected == null || curSelected.editorSprite == null)
        {
            camGame.scroll.x += xDiff;
            camGame.scroll.y += yDiff;
        }
        else
        {
            final spr = curSelected.editorSprite;

            spr.x += xDiff;
            spr.y += yDiff;

            curSelected.properties.x = spr.x;
            curSelected.properties.y = spr.y;
        }
    }
    function onMouseUp(e) {
        holdInfo = null;
    }

    // 
    public function updateObjects()
    {
        var unusedSprites:Array<StageSprite> = [];

        function checkUnused(group:FlxTypedGroup<StageSprite>){
            for (spr in group.members){
                group.remove(spr);

                if (spr == null)
                    continue;
                
                if (spr.data == null || objectArray.indexOf(spr.data) == -1){
                    spr.data = null;
                    unusedSprites.push(spr);
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