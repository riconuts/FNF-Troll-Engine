package shaders;

import flixel.util.FlxColor;

/**
    mimics adobe flash's "adjust color" filter
**/
class AdjustColor{
	public var saturation(default, set):Float = 0.0;
	public var contrast(default, set):Float = 0.0;
	public var brightness(default, set):Float = 0.0;

    /*
	public var tintColor(default, set):FlxColor = 0;
	function set_tintColor(val:FlxColor){

		tint[0] = val.redFloat;
		tint[1] = val.greenFloat;			
		tint[2] = val.blueFloat;
		tint[3] = val.alphaFloat;
		
		return tintColor = val;
	}
    */

	function set_saturation(val:Float){
		bcs[2] = 1.0 + val;
		return saturation = val;
	}

	function set_contrast(val:Float){
		bcs[1] = 1.0 + val;
		return contrast = val;
	}

	function set_brightness(val:Float){
		bcs[0] = val;
		return brightness = val;
	}

	public final shader:AdjustColorShader;
    private final bcs:Array<Float> = [0.0, 0.0, 0.0];
	private final tint:Array<Float> = [0.0, 0.0, 0.0, 0.0];

	public function new(){
		shader = new AdjustColorShader();

		shader.uTime.value = bcs;
		shader.tint.value = tint;
	}
}

// saturation, contrast from https://www.shadertoy.com/view/XdcXzn
class AdjustColorShader extends flixel.system.FlxAssets.FlxShader{
	@:glFragmentSource('
		#pragma header

		uniform vec3 uTime;
		uniform vec4 tint;

		mat4 contrastMatrix( float contrast )
		{
			float t = ( 1.0 - contrast ) / 2.0;
			
			return mat4( contrast, 0, 0, 0,
						0, contrast, 0, 0,
						0, 0, contrast, 0,
						t, t, t, 1 );
		}

		mat4 saturationMatrix( float saturation )
		{
			vec3 luminance = vec3( 0.3086, 0.6094, 0.0820 );
			
			float oneMinusSat = 1.0 - saturation;
			
			vec3 red = vec3( luminance.x * oneMinusSat );
			red+= vec3( saturation, 0, 0 );
			
			vec3 green = vec3( luminance.y * oneMinusSat );
			green += vec3( 0, saturation, 0 );
			
			vec3 blue = vec3( luminance.z * oneMinusSat );
			blue += vec3( 0, 0, saturation );
			
			return mat4(red,		0,
						green,		0,
						blue,		0,
						0, 0, 0,	1);
		}

		float lerp(float a, float b, float ratio)
		{
			return a + ratio * (b - a);
		}

		void main()
		{
			vec4 srcColor = texture2D(bitmap, openfl_TextureCoordv);

			vec4 modColor = 
				contrastMatrix( uTime[1] ) * 
				saturationMatrix( uTime[2] ) *
				vec4(
					srcColor[0] + uTime[0],
					srcColor[1] + uTime[0],
					srcColor[2] + uTime[0],
					srcColor[3]
				);

			gl_FragColor = vec4(
				lerp(modColor[0], tint[0], tint[3]),
				lerp(modColor[1], tint[1], tint[3]),
				lerp(modColor[2], tint[2], tint[3]),

				modColor[3]
			);
		}')
	public function new()
	{
		super();
	}
}