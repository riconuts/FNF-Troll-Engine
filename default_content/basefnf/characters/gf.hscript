function onAnimPlay(animName, force, reversed, frame){
    if(StringTools.startsWith(animName, 'hair'))
        this.skipDance = true;
}

function onUpdate(elapsed){
    if(this.animation.curAnim.name == 'hairFall' && this.animation.curAnim.finished){
        this.skipDance = false;
        this.danced = true;
        this.playAnim("danceRight");
    }
}