package funkin.states.editors;

import openfl.net.FileReference;
import openfl.events.Event;
import openfl.events.IOErrorEvent;

import flixel.util.FlxColor;
import flixel.group.FlxSpriteGroup;
import flixel.addons.ui.FlxUINumericStepper;
import flixel.addons.ui.FlxUI9SliceSprite;
import lime.ui.MouseCursor;
import openfl.ui.Mouse;
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
        var size = 9;
        var bgTexture = FlxGraphic.fromRectangle(size, size, 0x11000000, true);
        bgTexture.bitmap.fillRect(new Rectangle(1,1,size-1,size-1), 0xFF0078D7);
        bgTexture.bitmap.fillRect(new Rectangle(2,2,size-2,size-2),0xFF145080);

        bgTexture.persist = true; // oh no bro

        Layer.bgTexture = bgTexture;
    }

    public function new(parent, data, camera)
    {
        this.parent = parent;
        this.data = data;
        
        super();
        
        // this shit isn't working
        bg = new FlxUI9SliceSprite(0, 0, bgTexture, new Rectangle(0,0, parent.width,44), [2,2,7,7]);
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

        if (laeyr != null && laeyr.data != null)
            trace("selected: "+laeyr.data.name);
        else
			trace("selected: "+laeyr);

        if (parent != null)
			parent.curSelected = laeyr==null ? null : laeyr.data;
        
        return laeyr;
    }

    var topBar:FlxSprite;
    var layerCamera:FlxCamera;
    var layerHitbox:FlxObject;
    var bottomBar:FlxSprite;

    var managmentButtons:Array<FlxSprite> = [];

    public function new(parent:StageBuilderState, camera:FlxCamera, ?Width:Int, ?Height:Int)
    {
        this.parent = parent;
        this.camera = camera;

        super();

        if (Width == null)
            width = 240;
        else
            width = Width;

        if (Height == null)
            height = FlxG.height;
        else
            height = Height;

        topBar = new FlxSprite().makeGraphic(width, 24, 0xFF1A1A1A);
        topBar.scrollFactor.set();
        topBar.camera = camera;
        add(topBar);

        layerCamera = new FlxCamera();
        layerCamera.setSize(width, height - 24*2);
        layerCamera.bgColor = 0xFF404040;
        FlxG.cameras.add(layerCamera, false);

        layerHitbox = new FlxObject(0, 0, layerCamera.width, layerCamera.height);
        layerHitbox.scrollFactor.set();
        layerHitbox.camera = layerCamera;
        add(layerHitbox);

        bottomBar = new FlxSprite().makeGraphic(width, 24, 0xFF282828);
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
            //e.stopImmediatePropagation();
        }
    }

    var holdInfo:Null<{x:Int, y:Int}> = null;
    var clickedHere = false;

    function onMouseDown(e:MouseEvent) {
        clickedHere = (mouseOverlaps(topBar) || mouseOverlaps(layerHitbox) || mouseOverlaps(bottomBar));
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

    function cloneSelectedObj() {
        if (curSelected == null)
            return;

        var pos = parent.objectArray.indexOf(curSelected.data);
        var newObj:ObjectData = {name: curSelected.data.name};

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

        if (!clickedHere)
            return;

        if (FlxG.mouse.overlaps(topBar, topBar.camera)){
            //e.stopImmediatePropagation();
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
        
                    //e.stopImmediatePropagation();
                    return;
                }
            }

            //// You didn't click on any layer.
            selectLayer(null);

            //e.stopImmediatePropagation();
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
                    case 4: cloneSelectedObj();
                    case 5: // modifySelectedObj();
                    default: trace(idx);
                }

                break;
            }

            //e.stopImmediatePropagation();
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

class SowyStepper extends FlxSpriteGroup
{
    public var label:FlxInputText;
    //public var plusButton nahh im  tired of this menu shit i wanna go back to roblox ;_;
    public var callback:Float->Void;

    public function new (X:Float = 0, Y:Float = 0, StepSize:Float = 1, DefaultValue:Float = 0, Min:Float = -999, Max:Float = 999, Decimals:Int = 0)
    {
        super(X, Y);
    
        label = new FlxInputText(X, Y, 40, Std.string(DefaultValue), 12);
        
        var lastVal = DefaultValue;
        
        label.callback = function(text, action)
        {
            if (action == "enter"){
                label.hasFocus = false; 

                var toNumber = Std.parseFloat(text);
                if (toNumber != Math.NaN){
                    lastVal = toNumber;
                    if (callback!=null) callback(toNumber);
                }else
                    label.text = Std.string(lastVal);
            }
        }
        
        label.focusGained = FocusHelper.unFocusCurrent;
        label.focusLost = ()->{label.text = Std.string(lastVal);};
        add(label);

        FlxG.stage.addEventListener(MouseEvent.MOUSE_DOWN, onMouseDown);
        FlxG.stage.addEventListener(MouseEvent.MOUSE_UP, onMouseUp); 
    }
    override function destroy(){
        FlxG.stage.removeEventListener(MouseEvent.MOUSE_DOWN, onMouseDown);
        FlxG.stage.removeEventListener(MouseEvent.MOUSE_UP, onMouseUp);
        super.destroy();
    }

    function mouseOver(what) 
        return FlxG.mouse.overlaps(what, what.camera);    

    function onMouseDown(e:MouseEvent){
        if (mouseOver(label)){
            //e.stopImmediatePropagation();
            return;
        }
    }
    function onMouseUp(e:MouseEvent){
        if (mouseOver(label)){
            label.hasFocus = true;
            //e.stopImmediatePropagation();
            return;
        }
    }
}

class SowyInputText extends FlxInputText{
    public var sowyCallback:Null<String->Void> = null;

    public function new(X:Float = 0, Y:Float = 0, Width:Int = 150, ?Text:Null<String>, size:Int = 8, TextColor:Int = FlxColor.BLACK, BackgroundColor:Int = FlxColor.WHITE, EmbeddedFont:Bool = true){
        super(X, Y, Width, Text, size, TextColor, BackgroundColor, EmbeddedFont);

        var lastVal = Text;
        
        this.callback = function(text, action)
        {
            if (action == "enter"){
                this.hasFocus = false; 

                lastVal = text;
                if (sowyCallback!=null) sowyCallback(text);
            }
        }
        
        this.focusGained = FocusHelper.unFocusCurrent;
        this.focusLost = ()->{this.text = lastVal == null ? "" : Std.string(lastVal);};

        FlxG.stage.addEventListener(MouseEvent.MOUSE_DOWN, onMouseDown);
        FlxG.stage.addEventListener(MouseEvent.MOUSE_UP, onMouseUp); 
    }
    override function destroy(){
        FlxG.stage.removeEventListener(MouseEvent.MOUSE_DOWN, onMouseDown);
        FlxG.stage.removeEventListener(MouseEvent.MOUSE_UP, onMouseUp);
        super.destroy();
    }

    function mouseOver(what) 
        return FlxG.mouse.overlaps(what, what.camera);    

    var clickedHere = false;
    function onMouseDown(e:MouseEvent){
        clickedHere = mouseOver(this);
    }
    function onMouseUp(e:MouseEvent){
        if (clickedHere && mouseOver(this))
            this.hasFocus = true;
    }
}

class PropertyWindow extends FlxTypedGroup<FlxBasic>{
    var parent:StageBuilderState;
    //var camera:FlxCamera;
    
    var width:Int = 240;
    var titleText:FlxText;

    var curSelected:ObjectData;

    public function new(parent:StageBuilderState, camera:FlxCamera) {
        super();

        this.parent = parent;
        this.camera = camera;

        add(new FlxSprite().makeGraphic(width, 44, 0xFF1A1A1A));
        titleText = new FlxText(4, (24 - 12) * 0.5, width - 4*2, "Properties", 12);
        add(titleText);

        add(new FlxSprite(0, 24).makeGraphic(width, FlxG.height - 24, 0xFF404040));
    }

    var stepperGroup:FlxSpriteGroup;

    function addEditorSettings()
    {
        var path = new SowyInputText(10, 10, 220, Paths.currentModDirectory, 12);
        path.sowyCallback = (newPath)->{
            Paths.currentModDirectory = newPath;
            parent.updateObjects();
        };
        stepperGroup.add(path);
    }

    public function updateSelected(?newSel)
    {
        curSelected = newSel;

        if (stepperGroup != null){
            remove(stepperGroup);
            stepperGroup.destroy();
            stepperGroup = null;
        }

        stepperGroup = new FlxSpriteGroup(0, 24);
        add(stepperGroup);

        if (curSelected == null){
            addEditorSettings()
            ;//stepperGroup.add(new FlxText(10,10,220,"No object selected", 12));
            stepperGroup.camera = camera;
            return;
        }

        var scaleTitle = new FlxText(10, 10, 220, "Scale:", 12);

        var xScaleStepper = new SowyStepper(10, scaleTitle.y + 12, 0.1, curSelected.properties.scaleX, 0, 5, 1);
        xScaleStepper.callback = function(newVal:Float) {
            curSelected.properties.scaleX = newVal;
            curSelected.editorSprite.updateData();
        }
        
        var yScaleStepper = new SowyStepper(xScaleStepper.x + 40, xScaleStepper.y, 0.1, curSelected.properties.scaleY, 0, 5, 1);
        yScaleStepper.callback = function(newVal:Float) {
            curSelected.properties.scaleY = newVal;
            curSelected.editorSprite.updateData();
        }

        var scrollTitle = new FlxText(10, xScaleStepper.y + 40, 220, "Scroll Factor:", 12);

        var xScrollStepper = new SowyStepper(10, scrollTitle.y + 12, 0.1, curSelected.properties.scrollX, 0, 5, 1);
        xScrollStepper.callback = function(newVal:Float) {
            curSelected.properties.scrollX = newVal;
            curSelected.editorSprite.updateData();
        }
        
        var yScrollStepper = new SowyStepper(xScrollStepper.x + 40, xScrollStepper.y, 0.1, curSelected.properties.scrollY, 0, 5, 1);
        yScrollStepper.callback = function(newVal:Float) {
            curSelected.properties.scrollY = newVal;
            curSelected.editorSprite.updateData();
        }

        stepperGroup.add(scaleTitle);
        stepperGroup.add(xScaleStepper);
        stepperGroup.add(yScaleStepper);

        stepperGroup.add(scrollTitle);
        stepperGroup.add(xScrollStepper);
        stepperGroup.add(yScrollStepper);

        stepperGroup.camera = camera;
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
       
        ////
        updateImage();

        var props = data.properties;
        if (props == null){
            trace("nah", data.name);
            return;
        }

        setPosition(props.x, props.y);
        scale.set(props.scaleX, props.scaleY);
        scrollFactor.set(props.scrollX, props.scrollY);

        updateHitbox();
    }
}

class StageBuilderState extends MusicBeatState
{
    var camGame = new FlxCamera();
    var camHUD = new FlxCamera();

    var stage = new FlxTypedGroup<StageSprite>();
    var foreground = new FlxTypedGroup<StageSprite>();

    function makeObjSafe(obj:ObjectData)
    {
        if (obj.name == null) obj.name = "unknown";
        obj.onForeground = obj.onForeground == true;

        var props = obj.properties;

        if (props == null){
            obj.properties = {};
            props = obj.properties;
        }

        if (props.x == null) props.x = 0;
        if (props.y == null) props.y = 0;

        if (props.scaleX == null) props.scaleX = 1;
        if (props.scaleY == null) props.scaleY = 1;

        if (props.scrollX == null) props.scrollX = 1;
        if (props.scrollY == null) props.scrollY = 1;
    }

    public var curSelected(default, set):ObjectData;
    function set_curSelected(to){
        curSelected = to;

        if (to != null)
            makeObjSafe(to);
        
        propertyWindow.updateSelected(to);
        
        return to;
    }

    public var objectArray:Array<ObjectData> = [];
    var layerWindow:LayerWindow;
    var propertyWindow:PropertyWindow;

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

    var realZoom:Float = 1;
    var zoomMult:Float;

    var camFollowPos:FlxObject;

    override public function create()
    {
		#if discord_rpc
		// Updating Discord Rich Presence
		funkin.api.Discord.DiscordClient.changePresence("Stage Builder", null);
		#end

        FlxG.mouse.visible = true;
        
        FlxG.cameras.reset(camGame);
        FlxG.cameras.add(camHUD, false);

        // i hope scrollfactor doesn't get affected by the canera size ;_; 
        zoomMult = (FlxG.width - 480) / FlxG.width;
        camGame.width = Std.int(camGame.width * zoomMult);
        camGame.height = Std.int(camGame.height * zoomMult);
        camGame.x = (FlxG.width-camGame.width) * 0.5;
        camGame.y = (FlxG.height-camGame.height) * 0.5;
        camGame.zoom = realZoom * zoomMult;

		camFollowPos = new FlxObject(0, 0, camGame.width, camGame.height);
		camGame.follow(camFollowPos);

        camGame.bgColor = 0xFF00FF00;
        camHUD.bgColor.alpha = 0;

        FadeTransitionSubstate.nextCamera = camHUD;

        ////
        add(stage);
        add(foreground);
        stage.camera = camGame;
        foreground.camera = camGame;

        objectArray.push({name: "trollface"});
        objectArray.push({});
        objectArray.push({name: "tails", properties: {x: 10, y: 10, scrollX: 0, scrollY: 0, scaleX: 1.1, scaleY: 1.1}});

        ////
        propertyWindow = new PropertyWindow(this, camHUD);
        add(propertyWindow);

        layerWindow = new LayerWindow(this, camHUD);
        add(layerWindow);

        updateObjects();

        super.create();

        persistentUpdate = false;

        //toolFunction = moveObjectTool;

        FlxG.stage.addEventListener(MouseEvent.MOUSE_DOWN, onMouseDown, false, -1);
        FlxG.stage.addEventListener(MouseEvent.MOUSE_MOVE, onMouseMove, false, -1);
        FlxG.stage.addEventListener(MouseEvent.MOUSE_UP, onMouseUp, false, -1);
        FlxG.stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyDown, false, 100000);

        /* TODO: sparrow atlas, animations!!!!!!
		var frames = Paths.getSparrowAtlas("an-stage/allnighter_bg");
		@:privateAccess 
        for (sowy in 0...13){
			
            layerWindow.addNewObj();
			var spr = layerWindow.curSelected.data.editorSprite;
            spr.frames = frames;
			spr.animation.addByIndices("sowy", "anlayers", [sowy], "", 0, true);
            spr.animation.play("sowy");

            spr.data.name = ''+sowy;
            spr.updateData();
        }
		*/
    }
    override public function destroy(){
        FlxG.stage.removeEventListener(MouseEvent.MOUSE_DOWN, onMouseDown, false);
        FlxG.stage.removeEventListener(MouseEvent.MOUSE_MOVE, onMouseMove, false);
        FlxG.stage.removeEventListener(MouseEvent.MOUSE_UP, onMouseUp, false);
        FlxG.stage.removeEventListener(KeyboardEvent.KEY_DOWN, onKeyDown, false);   

        super.destroy();
    }

    function onKeyDown(e:KeyboardEvent){
        if (e.ctrlKey && e.keyCode == FlxKey.S){
            e.altKey ? exportLuaStage() : exportHScriptStage();

            e.stopImmediatePropagation();
            e.stopPropagation();
            e.preventDefault();
        }
    }

    function exportHScriptStage(){
        var script = "function onLoad(){";

        var sprNum = 0;
        for (obj in objectArray)
        {
            makeObjSafe(obj);

            ////
            if (sprNum > 0) script += '\n';
            var varName:String = "spr" + ++sprNum; //obj.name.replace('/', '_').replace("\\", '_').replace(" ", '_');

            script += '\n   var $varName = new FlxSprite(${obj.properties.x}, ${obj.properties.y}, Paths.image("${obj.name}"));';
            script += '\n   $varName.scrollFactor.set(${obj.properties.scrollX}, ${obj.properties.scrollY});';
            script += '\n   $varName.scale.set(${obj.properties.scaleX}, ${obj.properties.scaleY});';
            script += '\n   $varName.updateHitbox();';
            script += '\n   ${obj.onForeground ? "foreground.add" : "add"}(${varName});';
        }

        script += "\n}";

        ////
        var print = haxe.Log.trace;
        print("STAGE SCRIPT START:");
        print(script);
        print("STAGE SCRIPT END.");

        saveFile(script, "stage.hscript");     
    }

    function exportLuaStage(){
        var script = "function onCreate()";

        var sprNum = 0;
        for (obj in objectArray)
        {
            makeObjSafe(obj);

            ////
            if (sprNum > 0) script += '\n';
            var varName:String = "spr" + ++sprNum; //obj.name.replace('/', '_').replace("\\", '_').replace(" ", '_');

            var properties = obj.properties;

            script += '\n   makeLuaSprite("$varName", "${obj.name}", ${properties.x}, ${properties.y});';
            script += '\n   setScrollFactor("$varName", ${properties.scrollX}, ${properties.scrollY});';
            script += '\n   scaleObject("$varName", ${properties.scaleX}, ${properties.scaleY}, true);';
            script += '\n   addLuaSprite("$varName", ${obj.onForeground});';
        }

        script += "\nend";

        ////
        var print = haxe.Log.trace;
        print("STAGE SCRIPT START:");
        print(script);
        print("STAGE SCRIPT END.");

        saveFile(script, "stage.lua");       
    }

    static var _file:FileReference;
    static function saveFile(?data:String, ?name:String){
        if (data == null)
            data = "";
        if (name == null)
            name = "unknown";

        _file = new FileReference();
        _file.addEventListener(Event.COMPLETE, onSaveEnd);
        _file.addEventListener(Event.CANCEL, onSaveEnd);
        _file.addEventListener(IOErrorEvent.IO_ERROR, onSaveEnd);
        _file.save(data, name);
    }
    static function onSaveEnd(?e){
        _file.removeEventListener(Event.COMPLETE, onSaveEnd);
		_file.removeEventListener(Event.CANCEL, onSaveEnd);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveEnd);
		_file = null;
    }

    /////
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
            camFollowPos.x += xDiff;
			camFollowPos.y += yDiff;
        }
        else
        {
            final spr = curSelected.editorSprite;

            spr.x += xDiff;
            spr.y += yDiff;

            if (curSelected.properties == null)
                curSelected.properties = {};

            curSelected.properties.x = spr.x;
            curSelected.properties.y = spr.y;
        }
    }
    function onMouseUp(e) {
        holdInfo = null;
    }

    function isMouseOnCamera(/*camera:FlxCamera*/)
    {
        /*
        return  FlxG.mouse.screenX >= camera.x && 
                FlxG.mouse.screenY >= camera.y &&
                FlxG.mouse.screenX <= camera.x+camera.width &&  
                FlxG.mouse.screenY <= camera.y+camera.height;
        */

        // screenX and screenY are relative to the main camera, and not the game window >:(
        return  FlxG.mouse.screenX >= 0 && 
                FlxG.mouse.screenY >= 0 &&
                FlxG.mouse.screenX <= camGame.width &&  
                FlxG.mouse.screenY <= camGame.height;
    }

    override public function update(e:Float){
        /*
        if (curSelected != null && isMouseOnCamera())
            Mouse.cursor = HAND;
        else
            Mouse.cursor = ARROW;
        */

		var pressed = FlxG.keys.pressed;
		var justPressed = FlxG.keys.justPressed;

        //// move camera
		if (curSelected==null && pressed.ANY)
        {
            var spr = camFollowPos;
            var spd = e/(1/60) * (pressed.SHIFT ? 15 : 5);

            //// position
            if (pressed.W)
                spr.y -= spd;
            if (pressed.S)
                spr.y += spd;
            if (pressed.A)
                spr.x -= spd;
            if (pressed.D)
                spr.x += spd;		

            //// zoom
            if (justPressed.Q){
                realZoom-=0.05;
                camGame.zoom = realZoom * zoomMult;
            }
            if (justPressed.E){
                realZoom+=0.05;
                camGame.zoom = realZoom * zoomMult;
            }
            if (justPressed.R){
                realZoom = 1;
                camGame.zoom = realZoom * zoomMult;
            }
        }
        
        if (justPressed.ESCAPE)
            MusicBeatState.switchState(new MasterEditorMenu());

        super.update(e);
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
                    //trace('reused a sprite for ${obj.name}');
                }else{
                    obj.editorSprite = new StageSprite();
                    //trace('new sprite for ${obj.name}');
                }
            }

            obj.editorSprite.updateData(obj);
            obj.editorSprite.camera = camGame;
            (obj.onForeground ? foreground : stage).add(obj.editorSprite);
        }

        for (spr in unusedSprites){
            //trace('Killed unused sprite ${spr.data == null ? "with no data" : spr.data.name}');
            spr.destroy();
        }

        layerWindow.updateLayers();
    }
}