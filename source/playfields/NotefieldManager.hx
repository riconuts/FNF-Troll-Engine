package playfields;

class NotefieldManager extends FlxBasic {
	var notefields:Array<FieldBase> = [];

    public function add(field:FieldBase)notefields.push(field);
	public function remove(field:FieldBase)notefields.remove(field);
    
    override function draw(){
        for(field in notefields)
            field.preDraw();

		for (field in notefields)
			field.draw();
    }

    override function update(elapsed:Float){
        super.update(elapsed);
        for(field in notefields)
            field.update(elapsed);
    }
}