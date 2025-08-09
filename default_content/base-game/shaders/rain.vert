#pragma header
// normalized screen coord
//   (0, 0) is the top left of the window
//   (1, 1) is the bottom right of the window
varying vec2 screenCoord;

void main(){
	#pragma body
	screenCoord = vec2(
		openfl_TextureCoord.x > 0.0 ? 1.0 : 0.0,
		openfl_TextureCoord.y > 0.0 ? 1.0 : 0.0
	);
}