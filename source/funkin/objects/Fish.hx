package funkin.objects;

class Fish extends FlxSprite {
    private var maxX:Float = 0;
    private var maxY:Float = 0;

    override public function new() {
        super();
        loadGraphic(Paths.image("fish"));
        updateHitbox();
        screenCenter();
        velocity.set(100, 100);
    }

    override function updateHitbox() {
        super.updateHitbox();
        maxX = FlxG.width - width;
        maxY = FlxG.height - height;
    }

    override function updateMotion(elapsed:Float) {
        super.updateMotion(elapsed);
        if (x <= 0) {
            velocity.x = -velocity.x;
            x = 0;
        }
        if (x >= maxX) {
            velocity.x = -velocity.x; 
            x = maxX;
        }
        if (y <= 0) {
            velocity.y = -velocity.y;
            y = 0;
        }
        if (y >= maxY) {
            velocity.y = -velocity.y; 
            y = maxY;
        }
        
    }
}
