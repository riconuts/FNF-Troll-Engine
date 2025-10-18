package funkin.objects;

import funkin.states.PlayState;

class Fish extends FlxSprite {
    private var maxX:Float = 0;
    private var maxY:Float = 0;
    private var game:PlayState;

    override public function new(?game:PlayState) {
        super();
        loadGraphic(Paths.image("fish"));
        updateHitbox();
        screenCenter();
        velocity.set(100, 100);

        if ((this.game = game) != null) {
            game.signals.optionsChanged.add(onOptionsChanged);
            exists = ClientPrefs.fish;
            alpha = 0.0;
        }
    }

    private function onOptionsChanged(changed:Array<String>) {
        if (!exists) alpha = 0.0;
        exists = ClientPrefs.fish;
    }

    override function update(elapsed:Float) {
        super.update(elapsed);
        if (game != null) {
            // Only the worthy may see the fish.
            if (game.stats.ratingPercent >= 1)
                alpha += elapsed;
            else
                alpha -= elapsed;
        }
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
