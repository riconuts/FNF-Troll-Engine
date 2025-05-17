package funkin.objects;

class Fish extends FlxSprite {
    override public function new() {
        super();
        loadGraphic(Paths.image("fish"));
        screenCenter();
    }
}
