// #extension GL_EXT_ray_tracing : require

// #define SHADER_SURFACE
// #include "game/graphics/common.inc.glsl"
// #include "xenon/renderer/shaders/perlint.glsl"

// const vec3 sandColor = vec3(224.0/255, 185.0/255, 120.0/255);
// const vec3 rockColor = vec3(184.0/255, 175.0/255, 160.0/255);

// float Sand(vec3 pos) {
// 	return SimplexFractal(pos*8, 6) + abs(SimplexFractal(pos*0.2, 3)) * 20;
// }

// float Rock(vec3 pos) {
// 	return clamp(
// 		+ (clamp(pow(abs(SimplexFractal(pos*2, 4)), 0.8), 0.2, 0.4)) * (clamp(abs(SimplexFractal(pos*2+16.26, 3)), 0.2, 0.5)) * 6
// 		+ SimplexFractal(pos*10, 4) * 0.2
// 		- 0.5
// 	, -0.3, 0.8)*10;
// }

// #define BUMP(_noiseFunc, _position, _normal, _waveLength, _waveHeight) {\
// 	vec3 _tangentZ = normalize(cross(vec3(1,0,0), _normal));\
// 	vec3 _tangentX = normalize(cross(_normal, _tangentZ));\
// 	mat3 _TBN = mat3(_tangentX, _normal, _tangentZ);\
// 	float _altitudeTop = _noiseFunc(_position + _tangentZ*_waveLength) * _waveHeight;\
// 	float _altitudeBottom = _noiseFunc(_position - _tangentZ*_waveLength) * _waveHeight;\
// 	float _altitudeRight = _noiseFunc(_position + _tangentX*_waveLength) * _waveHeight;\
// 	float _altitudeLeft = _noiseFunc(_position - _tangentX*_waveLength) * _waveHeight;\
// 	vec3 _bump = normalize(vec3((_altitudeLeft-_altitudeRight), 2, (_altitudeBottom-_altitudeTop)));\
// 	_normal = normalize(_TBN * _bump);\
// }

// const float textureMaxDistance = 200;

// void main() {
// 	// surface.color.rgb = mix(rockColor, sandColor, 0.5);
// 	// if (surface.distance < textureMaxDistance) {
// 	// 	float strength = smoothstep(textureMaxDistance, 0, surface.distance);
// 	// 	float waveLength = 0.001;
// 	// 	float height = Rock(surface.localPosition);
// 	// 	if (height > 0.0) {
// 	// 		surface.color.rgb = mix(surface.color.rgb, rockColor, strength);
// 	// 		BUMP(Rock, surface.localPosition, surface.normal, waveLength, strength)
// 	// 	} else {
// 	// 		surface.color.rgb = mix(surface.color.rgb, sandColor, strength);
// 	// 		BUMP(Sand, surface.localPosition, surface.normal, waveLength, strength)
// 	// 	}
// 	// }
	
	
// 	// surface.color.rgb = Heatmap(pow(surface.color.r, xenonRendererData.config.debugViewScale));
	
// 	// surface.color.rgb = sandColor;
	
// }
