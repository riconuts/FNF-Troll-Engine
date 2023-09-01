package shaders;

import flixel.system.FlxAssets.FlxShader;

class LoadShader extends FlxShader {
    @:isVar
    public var loaded(get, set):Float = 0;

    function get_loaded()
        return progress.value[0];    
    

    function set_loaded(val:Float) 
        return progress.value[0] = val;
    

    @:glFragmentSource('
        #pragma header

        uniform float progress;
        void main(){
            vec2 uv = openfl_TextureCoordv;
            gl_FragColor = flixel_texture2D(bitmap, uv);

            float p = progress;
            if(uv.y >= p)
                gl_FragColor = vec4(0.0);
        }
    ')
    public function new() {
        super();
        progress.value = [0];
    }
}