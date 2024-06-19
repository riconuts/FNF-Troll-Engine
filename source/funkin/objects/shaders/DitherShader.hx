package funkin.objects.shaders;

class DitherShader extends FlxShader
{
	@:glFragmentSource('
// https://www.shadertoy.com/view/4sBSDW#

// Scale the width of the dither
#define STEPS 8.0
#define WIDE 1.0

uniform float iTime;
uniform float uScaleFactor;

//-----------------------------------------------------------------------

float Noise(vec2 n,float x){
	n+=x;
	return fract(sin(dot(n.xy,vec2(12.9898, 78.233)))*43758.5453)*2.0-1.0;
}

// Step 1 in generation of the dither source texture.
float Step1(vec2 uv,float n){
	float a=1.0,b=2.0,c=-12.0,t=1.0;   
	return (1.0/(a*4.0+b*4.0-c))*(
	Noise(uv+vec2(-1.0,-1.0)*t,n)*a+
	Noise(uv+vec2( 0.0,-1.0)*t,n)*b+
	Noise(uv+vec2( 1.0,-1.0)*t,n)*a+
	Noise(uv+vec2(-1.0, 0.0)*t,n)*b+
	Noise(uv+vec2( 0.0, 0.0)*t,n)*c+
	Noise(uv+vec2( 1.0, 0.0)*t,n)*b+
	Noise(uv+vec2(-1.0, 1.0)*t,n)*a+
	Noise(uv+vec2( 0.0, 1.0)*t,n)*b+
	Noise(uv+vec2( 1.0, 1.0)*t,n)*a+
	0.0);
}
	
// Step 2 in generation of the dither source texture.
float Step2(vec2 uv,float n)
{
	float a=1.0,b=2.0,c=-2.0,t=1.0;   
	return (4.0/(a*4.0+b*4.0-c))*(
		Step1(uv+vec2(-1.0,-1.0)*t,n)*a+
		Step1(uv+vec2( 0.0,-1.0)*t,n)*b+
		Step1(uv+vec2( 1.0,-1.0)*t,n)*a+
		Step1(uv+vec2(-1.0, 0.0)*t,n)*b+
		Step1(uv+vec2( 0.0, 0.0)*t,n)*c+
		Step1(uv+vec2( 1.0, 0.0)*t,n)*b+
		Step1(uv+vec2(-1.0, 1.0)*t,n)*a+
		Step1(uv+vec2( 0.0, 1.0)*t,n)*b+
		Step1(uv+vec2( 1.0, 1.0)*t,n)*a+
		0.0
	);
}

// Used for temporal dither.
vec3 Step3T(vec2 uv){
	#if 1
	float time = iTime / 250.0;
	time = (fract(time)+1.0);
	#else
	float time = 1.0; 
	#endif
	
	float a = Step2(uv, 0.07 * time);
	float b = Step2(uv, 0.11 * time); 
	float c = Step2(uv, 0.13 * time);
	
	#if 1
	return vec3(a,b,c);
	#else
	return vec3(a);
	#endif
}

vec3 doTheDither(vec2 uv, vec3 color){
	return floor(0.5+color*(STEPS+WIDE-1.0)+(-WIDE*0.5)+Step3T(uv)*WIDE)*(1.0/(STEPS-1.0));
}

#pragma header

void main(){
	vec2 pixUv = openfl_TextureCoordv * openfl_TextureSize;
	vec2 ditUv = pixUv;

	if (uScaleFactor > 0.0){
		ditUv.x = round(pixUv.x / uScaleFactor);
		ditUv.y = round(pixUv.y / uScaleFactor);
		pixUv = ditUv * uScaleFactor;
	}

	vec2 bitUv = pixUv / openfl_TextureSize;

	vec4 color = flixel_texture2D(bitmap, bitUv);
	gl_FragColor = vec4(doTheDither(ditUv, color.rgb), color.a);
}
	')
	public function new(){
		super();

		var iTime = this.iTime.value = [0.0];
		this.uScaleFactor.value = [0.0];
		
        FlxG.signals.preDraw.add(()->{
			iTime[0] += FlxG.elapsed;
		});

        scaleFactor = 2.0;
	}

    public var scaleFactor(get, set):Float;
    function get_scaleFactor()
        return this.uScaleFactor.value[0];
    function set_scaleFactor(val:Float)
        return this.uScaleFactor.value[0] = val;
}

