package playfields;

class NotefieldManager extends FlxBasic {
	public var members:Array<FieldBase> = [];

    public function add(field:FieldBase)members.push(field);
	public function remove(field:FieldBase)members.remove(field);
    
    override function draw(){
        for(field in members)
            field.preDraw();

		for (field in members)
			field.draw();
    }

    override function update(elapsed:Float){
        super.update(elapsed);
        for(field in members)
            field.update(elapsed);
    }
}