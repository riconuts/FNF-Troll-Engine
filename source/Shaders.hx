package;

// STOLEN FROM TGT V3 LOL

typedef ShaderEffect =
{
	var shader:Dynamic;
}

class HighEffect
{
	public var shader:HighShader = new HighShader();
	public var effectiveness(default, set):Float = 0;
	public var focusDetail(default, set):Int = 6;

	public function new(){
		shader.iTime.value = [0];
		shader.effectiveness.value = [effectiveness];
		shader.focusDetail.value = [focusDetail];
	}
	function set_effectiveness(motherfuckingcocksuckeranalcumfartshit:Float):Float{
		shader.effectiveness.value = [motherfuckingcocksuckeranalcumfartshit];
		return motherfuckingcocksuckeranalcumfartshit;
	}
	function set_focusDetail(sowy:Int):Int{
		shader.focusDetail.value = [sowy];
		return sowy;
	}
	public function update(elapsed:Float)
	{
		shader.iTime.value[0] += elapsed;
	}
}

class HighShader extends flixel.system.FlxAssets.FlxShader
{
	@:glFragmentSource('
		#pragma header
		uniform float iTime;
		uniform float effectiveness;
		uniform int focusDetail;

		void main()
		{
			vec2 fragCoord = gl_FragCoord.xy;
			vec2 iResolution = openfl_TextureSize;

			float focusPower = (20.0 + sin(iTime*4.)*3.) * effectiveness;

			vec2 uv = fragCoord.xy / iResolution.xy;
			vec2 focus = uv - vec2(0.5, 0.5);
			
			vec4 outColor = vec4(0, 0, 0, 0);

			for (int i=0; i<focusDetail; i++) {
				float power = 1.0 - focusPower * (1.0/iResolution.x) * (float(i)*0.75);
				outColor += flixel_texture2D(bitmap, focus * power + vec2(0.5));
			}

			outColor.rgba *= 1.0 / float(focusDetail);

			gl_FragColor = outColor;
		}
	')
	public function new()
	{
		super();
	}
}