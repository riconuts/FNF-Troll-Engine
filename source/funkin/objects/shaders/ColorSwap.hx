package funkin.objects.shaders;

import funkin.objects.shaders.NoteColorSwap;

class ColorSwap
{
	public var shader(default, null):ColorSwapShader = new ColorSwapShader();
	public var hue(default, set):Float = 0;
	public var saturation(default, set):Float = 0;
	public var brightness(default, set):Float = 0;
	public var daAlpha(default, set):Float = 1;
	public var flash(default, set):Float = 0;

	public var flashR(default, set):Float = 1;
	public var flashG(default, set):Float = 1;
	public var flashB(default, set):Float = 1;
	public var flashA(default, set):Float = 1;

	private function set_flashR(value:Float)
	{
		flashR = value;
		shader.flashColor.value[0] = flashR;
		return flashR;
	}

	private function set_flashG(value:Float)
	{
		flashG = value;
		shader.flashColor.value[1] = flashG;
		return flashG;
	}

	private function set_flashB(value:Float)
	{
		flashB = value;
		shader.flashColor.value[2] = flashB;
		return flashB;
	}

	private function set_flashA(value:Float)
	{
		flashA = value;
		shader.flashColor.value[3] = flashA;
		return flashA;
	}

	private function set_daAlpha(value:Float)
	{
		daAlpha = value;
		shader.daAlpha.value[0] = daAlpha;
		return daAlpha;
	}

	private function set_flash(value:Float)
	{
		flash = value;
		shader.flash.value[0] = flash;
		return flash;
	}

	private function set_hue(value:Float)
	{
		hue = value;
		shader.uTime.value[0] = hue;
		return hue;
	}

	private function set_saturation(value:Float)
	{
		saturation = value;
		shader.uTime.value[1] = saturation;
		return saturation;
	}

	private function set_brightness(value:Float)
	{
		brightness = value;
		shader.uTime.value[2] = brightness;
		return brightness;
	}

	inline public function setHSB(h:Float = 0, s:Float = 0, b:Float = 0) {
		hue=h;
		saturation=s;
		brightness=b;
	}
	
	inline public function setHSBInt(h:Int = 0, s:Int = 0, b:Int = 0) {
		hue=h/360;
		saturation=s/100;
		brightness=b/100;
	}

	inline public function setHSBArray(ray:Array<Float>) {
		ray==null ? setHSB() : setHSB(ray[0], ray[1], ray[2]);
	}
	
	inline public function setHSBIntArray(ray:Array<Int>) {
		ray==null ? setHSB() : setHSBInt(ray[0], ray[1], ray[2]);
	}

	inline public function copyFrom(colorSwap:ColorSwap) {
		setHSB(
			colorSwap.hue,
			colorSwap.saturation,
			colorSwap.brightness	
		);
	}

	inline public function copyFromNoteSwap(colorSwap:NoteColorSwap) {
		setHSB(
			colorSwap.hue,
			colorSwap.saturation,
			colorSwap.brightness	
		);
	}

	public function new()
	{
		shader.uTime.value = [0, 0, 0];
		shader.flashColor.value = [1, 1, 1, 1];
		shader.daAlpha.value = [1];
		shader.flash.value = [0];
	}
}

class ColorSwapShader extends FlxShader
{
	@:glFragmentHeader('
		const float offset = 1.0 / 128.0;
		const vec3 colorNormalizer = vec3(1.0 / 255.0);
		vec3 normalizeColor(vec3 color)
		{
			return color * colorNormalizer;
		}

		vec3 rgb2hsv(vec3 c)
		{
			vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
			vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
			vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));

			float d = q.x - min(q.w, q.y);
			float e = 1.0e-10;
			return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
		}

		vec3 hsv2rgb(vec3 c)
		{
			vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
			vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
			return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
		}

		vec4 colorMult(vec4 color){
			if (!hasTransform)
			{
				return color;
			}

			if (color.a == 0.0)
			{
				return vec4(0.0, 0.0, 0.0, 0.0);
			}

			if (!hasColorTransform)
			{
				return color * openfl_Alphav;
			}

			color = vec4(color.rgb / color.a, color.a);

			color = clamp(openfl_ColorOffsetv + (color * openfl_ColorMultiplierv), 0.0, 1.0);

			if (color.a > 0.0)
			{
				return vec4(color.rgb * color.a * openfl_Alphav, color.a * openfl_Alphav);
			}

			return vec4(0.0, 0.0, 0.0, 0.0);
		}
	')
	@:glFragmentSource('
		#pragma header

		uniform vec3 uTime;
		uniform float daAlpha;
		uniform float flash;
		uniform vec4 flashColor;

		void main()
		{
			vec4 color = texture2D(bitmap, openfl_TextureCoordv);

			vec3 swagColor = rgb2hsv(color.rgb);

			// hue
			swagColor[0] = swagColor[0] + uTime[0];
			// sat
			swagColor[1] = clamp(swagColor[1] * (1.0 + uTime[1]), 0.0, 1.0);
			// val
			swagColor[2] = swagColor[2] * (1.0 + uTime[2]);

			color.rgb = hsv2rgb(swagColor);

			if(flash != 0.0){
				color = mix(color, flashColor, flash) * color.a;
			}
			color *= daAlpha;
			gl_FragColor = colorMult(color);
		}')
	public function new()
	{
		super();
	}
}