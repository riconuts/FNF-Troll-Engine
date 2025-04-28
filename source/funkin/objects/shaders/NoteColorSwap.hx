package funkin.objects.shaders;

import funkin.objects.shaders.ColorSwap;

class NoteColorSwap {
    public static final shader:NoteColorSwapShader = new NoteColorSwapShader();
    public var hue:Float = 0;
	public var saturation:Float = 0;
	public var brightness:Float = 0;
	public var daAlpha:Float = 1;
	public var flash:Float = 0;

	public var flashR:Float = 1;
	public var flashG:Float = 1;
	public var flashB:Float = 1;
	public var flashA:Float = 1;

    public function new() {}

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

    inline public function copyFrom(colorSwap:NoteColorSwap) {
		setHSB(
			colorSwap.hue,
			colorSwap.saturation,
			colorSwap.brightness	
		);
	}

	inline public function copyFromNormalSwap(colorSwap:ColorSwap) {
		setHSB(
			colorSwap.hue,
			colorSwap.saturation,
			colorSwap.brightness	
		);
	}
}

class NoteColorSwapShader extends ColorSwapShader
{
    @:glVertexSource('
        #pragma header
		'+#if (flixel <= "5.9.0")
		'attribute float alpha;
		attribute vec4 colorMultiplier;
		attribute vec4 colorOffset;
		uniform bool hasColorTransform;
		'#else ''#end+'

		attribute vec3 hsvShift;
		attribute float daAlpha;
		attribute float flash;
		attribute vec4 flashColor;

        varying vec3 hsvShift_v;
		varying float daAlpha_v;
		varying float flash_v;
		varying vec4 flashColor_v;

        void main() {
            #pragma body
			openfl_Alphav = openfl_Alpha * alpha;

			if (hasColorTransform)
			{
				openfl_ColorOffsetv = colorOffset / 255.0;
				openfl_ColorMultiplierv = colorMultiplier;
			}

            hsvShift_v = hsvShift;
            daAlpha_v = daAlpha;
            flash_v = flash;
            flashColor_v = flashColor;
        }
    ')
	@:glFragmentSource('
		#pragma header

		varying vec3 hsvShift_v;
		varying float daAlpha_v;
		varying float flash_v;
		varying vec4 flashColor_v;

		void main()
		{
			vec4 color = texture2D(bitmap, openfl_TextureCoordv);

			vec3 swagColor = rgb2hsv(color.rgb);

			// hue
			swagColor[0] = swagColor[0] + hsvShift_v[0];
			// sat
			swagColor[1] = clamp(swagColor[1] * (1.0 + hsvShift_v[1]), 0.0, 1.0);
			// val
			swagColor[2] = swagColor[2] * (1.0 + hsvShift_v[2]);

			color.rgb = hsv2rgb(swagColor);

			if(flash_v != 0.0){
				color = mix(color, flashColor_v, flash_v) * color.a;
			}
			color *= daAlpha_v;
			gl_FragColor = colorMult(color);
		}')
	public function new()
	{
		super();
	}
}