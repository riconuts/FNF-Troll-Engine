package funkin.objects.playfields;

class NotefieldManager extends FlxBasic {
	public var members:Array<FieldBase> = [];

    public function add(field:FieldBase){
        if(members.contains(field))return;
        members.push(field);
    }
	public function remove(field:FieldBase){
		if (members.contains(field))
            members.remove(field);
    }
    
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

    override function destroy()
    {
        super.destroy();

        while (members.length > 0)
            members.pop().destroy(); 
        
        members = null;
    }
}