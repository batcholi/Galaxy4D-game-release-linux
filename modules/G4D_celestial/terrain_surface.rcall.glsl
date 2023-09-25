#extension GL_EXT_ray_tracing : require

#define SHADER_SURFACE
#include "terrain.common.inc.glsl"
#include "xenon/renderer/shaders/perlint.inc.glsl"

const vec3 sandColor = vec3(224.0/255, 185.0/255, 120.0/255);
const vec3 rockColor = vec3(184.0/255, 175.0/255, 160.0/255);

float Sand(vec3 pos) {
	return SimplexFractal(pos*8, 6) + abs(SimplexFractal(pos*0.2, 3)) * 20;
}

float Rock(vec3 pos) {
	return clamp(
		+ (clamp(pow(abs(SimplexFractal(pos*2, 4)), 0.8), 0.2, 0.4)) * (clamp(abs(SimplexFractal(pos*2+16.26, 3)), 0.2, 0.5)) * 6
		+ SimplexFractal(pos*10, 4) * 0.2
		- 0.5
	, -0.3, 0.8)*10;
}

float NormalDetail(in vec3 pos) {
	return SimplexFractal(pos, 3);
}

// #define BUMP(_noiseFunc, _position, _normal, _waveLength) {\
// 	vec3 _tangentZ = normalize(cross(vec3(1,0,0), _normal));\
// 	vec3 _tangentX = normalize(cross(_normal, _tangentZ));\
// 	mat3 _TBN = mat3(_tangentX, _normal, _tangentZ);\
// 	float _altitudeTop = _noiseFunc(_position + _tangentZ*_waveLength);\
// 	float _altitudeBottom = _noiseFunc(_position - _tangentZ*_waveLength);\
// 	float _altitudeRight = _noiseFunc(_position + _tangentX*_waveLength);\
// 	float _altitudeLeft = _noiseFunc(_position - _tangentX*_waveLength);\
// 	vec3 _bump = normalize(vec3((_altitudeLeft-_altitudeRight), 2, (_altitudeBottom-_altitudeTop)));\
// 	_normal = normalize(_TBN * _bump);\
// }

#define BUMP(_noiseFunc, _position, _normal, _waveLength, _waveHeight) {\
	vec3 _tangentZ = normalize(cross(vec3(1,0,0), _normal));\
	vec3 _tangentX = normalize(cross(_normal, _tangentZ));\
	mat3 _TBN = mat3(_tangentX, _normal, _tangentZ);\
	float _altitudeTop = _noiseFunc(_position + _tangentZ*_waveLength) * _waveHeight;\
	float _altitudeBottom = _noiseFunc(_position - _tangentZ*_waveLength) * _waveHeight;\
	float _altitudeRight = _noiseFunc(_position + _tangentX*_waveLength) * _waveHeight;\
	float _altitudeLeft = _noiseFunc(_position - _tangentX*_waveLength) * _waveHeight;\
	vec3 _bump = normalize(vec3((_altitudeLeft-_altitudeRight), 2, (_altitudeBottom-_altitudeTop)));\
	_normal = normalize(_TBN * _bump);\
}

const float textureMaxDistance = 200;

ChunkBuffer chunk = ChunkBuffer(surface.geometryInfoData);

#define Near 0
#define Far 1
#define Diffuse 0
#define Specular 4
#define Height 2

// vec3 _random3(vec3 pos) { // used in FastSimplex
// 	float j = 4096.0*sin(dot(pos,vec3(17.0, 59.4, 15.0)));
// 	vec3 r;
// 	r.z = fract(512.0*j);
// 	j *= .125;
// 	r.x = fract(512.0*j);
// 	j *= .125;
// 	r.y = fract(512.0*j);
// 	return r-0.5;
// }
// float FastSimplex(vec3 pos) {
// 	const float F3 = 0.3333333;
// 	const float G3 = 0.1666667;

// 	vec3 s = floor(pos + dot(pos, vec3(F3)));
// 	vec3 x = pos - s + dot(s, vec3(G3));

// 	vec3 e = step(vec3(0.0), x - x.yzx);
// 	vec3 i1 = e * (1.0 - e.zxy);
// 	vec3 i2 = 1.0 - e.zxy * (1.0 - e);

// 	vec3 x1 = x - i1 + G3;
// 	vec3 x2 = x - i2 + 2.0 * G3;
// 	vec3 x3 = x - 1.0 + 3.0 * G3;

// 	vec4 w, d;

// 	w.x = dot(x, x);
// 	w.y = dot(x1, x1);
// 	w.z = dot(x2, x2);
// 	w.w = dot(x3, x3);

// 	w = max(0.6 - w, 0.0);

// 	d.x = dot(_random3(s), x);
// 	d.y = dot(_random3(s + i1), x1);
// 	d.z = dot(_random3(s + i2), x2);
// 	d.w = dot(_random3(s + 1.0), x3);

// 	w *= w;
// 	w *= w;
// 	d *= w;

// 	return (dot(d, vec4(52.0)));
// }
// float FastSimplexFractal(vec3 pos, int octaves) {
// 	float amplitude = 0.5333333333;
// 	float frequency = 1.0;
// 	float f = FastSimplex(pos * frequency);
// 	for (int i = 1; i < octaves; ++i) {
// 		amplitude /= 2.0;
// 		frequency *= 2.0;
// 		f += amplitude * FastSimplex(pos * frequency);
// 	}
// 	return f;
// }

// vec4 SumOne(vec4 blending) {
// 	float total = blending.x + blending.y + blending.z + blending.w;
// 	if (total == 0) return vec4(1,0,0,0);
// 	return blending / total;
// }

// // Triplanar Functions
// vec3 TriplanarBlending(vec3 norm, float sharpness) {
// 	vec3 blending = abs(norm);
// 	blending = normalize(max(blending, 0.00001));
// 	blending = pow(blending, vec3(sharpness));
// 	float b = blending.x + blending.y + blending.z;
// 	blending /= vec3(b);
// 	if (blending.x > 0.9) blending = vec3(1,0,0);
// 	if (blending.y > 0.9) blending = vec3(0,1,0);
// 	if (blending.z > 0.9) blending = vec3(0,0,1);
// 	return blending;
// }
// vec4 TriplanarTextureRGBA(sampler2D tex, vec3 coords, vec3 blending) {
// 	vec4 value = vec4(0);
// 	if (blending.x > 0) value += blending.x * texture(tex, coords.zy);
// 	if (blending.y > 0) value += blending.y * texture(tex, coords.xz);
// 	if (blending.z > 0) value += blending.z * texture(tex, coords.xy);
// 	return value;
// }
// vec3 TriplanarTextureRGB(sampler2D tex, vec3 coords, vec3 blending) {
// 	vec3 value = vec3(0);
// 	if (blending.x > 0) value += blending.x * texture(tex, coords.zy).rgb;
// 	if (blending.y > 0) value += blending.y * texture(tex, coords.xz).rgb;
// 	if (blending.z > 0) value += blending.z * texture(tex, coords.xy).rgb;
// 	return value;
// }
// float TriplanarTextureR(sampler2D tex, vec3 coords, vec3 blending) {
// 	float value = 0;
// 	if (blending.x > 0) value += blending.x * texture(tex, coords.zy).r;
// 	if (blending.y > 0) value += blending.y * texture(tex, coords.xz).r;
// 	if (blending.z > 0) value += blending.z * texture(tex, coords.xy).r;
// 	return value;
// }
// float TriplanarTextureA(sampler2D tex, vec3 coords, vec3 blending) {
// 	float value = 0;
// 	if (blending.x > 0) value += blending.x * texture(tex, coords.zy).a;
// 	if (blending.y > 0) value += blending.y * texture(tex, coords.xz).a;
// 	if (blending.z > 0) value += blending.z * texture(tex, coords.xy).a;
// 	return value;
// }
// vec3 TriplanarTextureBump(sampler2D tex, vec3 coords, vec3 blending) {
// 	vec4 value = vec4(0);
// 	if (blending.x > 0) {
// 		value.x += blending.x * textureOffset(tex, coords.zy, ivec2(0,-1)).r;
// 		value.y += blending.x * textureOffset(tex, coords.zy, ivec2(-1,0)).r;
// 		value.z += blending.x * textureOffset(tex, coords.zy, ivec2(+1,0)).r;
// 		value.w += blending.x * textureOffset(tex, coords.zy, ivec2(0,+1)).r;
// 	}
// 	if (blending.y > 0) {
// 		value.x += blending.y * textureOffset(tex, coords.xz, ivec2(0,-1)).r;
// 		value.y += blending.y * textureOffset(tex, coords.xz, ivec2(-1,0)).r;
// 		value.z += blending.y * textureOffset(tex, coords.xz, ivec2(+1,0)).r;
// 		value.w += blending.y * textureOffset(tex, coords.xz, ivec2(0,+1)).r;
// 	}
// 	if (blending.z > 0) {
// 		value.x += blending.z * textureOffset(tex, coords.xy, ivec2(0,-1)).r;
// 		value.y += blending.z * textureOffset(tex, coords.xy, ivec2(-1,0)).r;
// 		value.z += blending.z * textureOffset(tex, coords.xy, ivec2(+1,0)).r;
// 		value.w += blending.z * textureOffset(tex, coords.xy, ivec2(0,+1)).r;
// 	}
// 	return normalize(vec3((value.y-value.z), 1, (value.w-value.x)));
// }
// vec3 TriplanarLocalNormalMap(sampler2D normalTex, vec3 coords, vec3 normal, vec3 blending) {
// 	if (blending.x > 0) normal += blending.x * vec3(0, texture(normalTex, coords.zy).yx * 2 - 1);
// 	if (blending.y > 0) normal += blending.y * vec3(1,0,1) * (texture(normalTex, coords.xz).xzy * 2 - 1);
// 	if (blending.z > 0) normal += blending.z * vec3(texture(normalTex, coords.xy).xy * 2 - 1, 0);
// 	return normalize(normal);
// }
// vec4 TriplanarTextureRGBA(uint texIndex, vec3 coords, vec3 blending) {
// 	if (texIndex == 0) return vec4(0);
// 	return TriplanarTextureRGBA(textures[nonuniformEXT(texIndex)], coords, blending);
// }
// vec3 TriplanarTextureRGB(uint texIndex, vec3 coords, vec3 blending) {
// 	if (texIndex == 0) return vec3(0);
// 	return TriplanarTextureRGB(textures[nonuniformEXT(texIndex)], coords, blending);
// }
// float TriplanarTextureR(uint texIndex, vec3 coords, vec3 blending) {
// 	if (texIndex == 0) return 0;
// 	return TriplanarTextureR(textures[nonuniformEXT(texIndex)], coords, blending);
// }
// float TriplanarTextureA(uint texIndex, vec3 coords, vec3 blending) {
// 	if (texIndex == 0) return 0;
// 	return TriplanarTextureA(textures[nonuniformEXT(texIndex)], coords, blending);
// }
// vec3 TriplanarLocalNormalMap(uint normalTexIndex, vec3 coords, vec3 localFaceNormal, vec3 blending) {
// 	if (normalTexIndex == 0) return vec3(0);
// 	return TriplanarLocalNormalMap(textures[nonuniformEXT(normalTexIndex)], coords, localFaceNormal, blending);
// }
// vec3 TriplanarTextureBump(uint texIndex, vec3 coords, vec3 blending) {
// 	if (texIndex == 0) return vec3(0);
// 	return TriplanarTextureBump(textures[nonuniformEXT(texIndex)], coords, blending);
// }

// mat3 RotationMatrix(vec3 axis, float angle) {
// 	axis = normalize(axis);
// 	float s = sin(angle);
// 	float c = cos(angle);
// 	float oc = 1.0 - c;
// 	return mat3(oc * axis.x * axis.x + c,           oc * axis.x * axis.y - axis.z * s,  oc * axis.z * axis.x + axis.y * s,
// 				oc * axis.x * axis.y + axis.z * s,  oc * axis.y * axis.y + c,           oc * axis.y * axis.z - axis.x * s,
// 				oc * axis.z * axis.x - axis.y * s,  oc * axis.y * axis.z + axis.x * s,  oc * axis.z * axis.z + c);
// }

// const float textureRotationAmount = 0.1;
// const float textureOffsetAmount = 0.7;

// const float tex0_max_slope = 1.0;
// const float tex1_max_slope = 0.5;
// const float tex2_max_slope = 0.1;
// const float tex3_max_slope = 0.2;

// vec4 GetTextureBlending(in vec4 in_blending, in vec2 in_uv, in uvec4 in_tex_height, in vec3 in_upDir, in vec3 in_posOnChunk, in bool rotateTextures, in vec3 in_normal, out vec3 triplanarCoords1, out vec4 triplanarCoords2, out vec3 triplanarBlending) {
// 	vec4 blending = SumOne(in_blending);
// 	triplanarBlending = TriplanarBlending(in_normal, 100);
// 	triplanarCoords1 = in_posOnChunk * 0.5;
// 	triplanarCoords2 = vec4(triplanarCoords1, 0);
	
// 	if (rotateTextures) {
// 		vec2 uv = (in_uv * chunk.chunkSize / 8.0) + vec2(FastSimplexFractal(in_posOnChunk*0.7, 3), FastSimplexFractal(in_posOnChunk*0.7+6.9781, 3))*0.333;
// 		uint seed = InitRandomSeed(uint(uv.x), uint(uv.y));
// 		vec2 center = (1.0 - abs(fract(uv) * 2 - 1));
		
// 		// Apply Random Rotation
// 		triplanarCoords2.xyz = RotationMatrix(normalize(triplanarBlending), RandomFloat(seed)*2.0*PI*textureRotationAmount) * triplanarCoords1;
		
// 		// Apply Random Offset
// 		triplanarCoords2.xyz += (vec3(RandomFloat(seed), RandomFloat(seed), RandomFloat(seed))*2-1) * textureOffsetAmount;
		
// 		triplanarCoords2.w = pow(clamp(min(center.x, center.y), 0, 1), 0.333);
// 	}
	
// 	// vec3 posViewSpace = (MODELVIEW * vec4(in_posOnChunk, 1)).xyz;
// 	// float distanceFromCamera = length(posViewSpace);
// 	float slope = 1.0 - clamp(dot(in_upDir, in_normal), 0, 1);
	
// 	if (slope > tex0_max_slope) blending.x = 0;
// 	if (slope > tex1_max_slope) blending.y = 0;
// 	if (slope > tex2_max_slope) blending.z = 0;
// 	if (slope > tex3_max_slope) blending.w = 0;
	
// 	if (blending.x > blending.y+0.1) blending.y = 0;
// 	if (blending.y > blending.x+0.1) blending.x = 0;
// 	if (blending.z > blending.y+0.1) blending.y = 0;
// 	if (blending.w > blending.z+0.1) blending.z = 0;
	
// 	// if (in_tex_height.x <= tex_height_offset) blending.x = 0;
// 	// if (in_tex_height.y <= tex_height_offset) blending.y = 0;
// 	// if (in_tex_height.z <= tex_height_offset) blending.z = 0;
// 	// if (in_tex_height.w <= tex_height_offset) blending.w = 0;
	
// 	return SumOne(blending);
// }

void main() {
	
	
	surface.uv1 = ComputeSurfaceUV1(surface.geometries, surface.geometryIndex, surface.primitiveIndex, surface.barycentricCoords);
	
	
	vec2 uv = surface.uv1 * max(1,round(chunk.chunkSize / 4));
	// vec2 uv = surface.uv1 * round(chunk.chunkSize);
	
	surface.color.rgb = texture(textures[chunk.tex.y + Near+Diffuse], uv).rgb;
	surface.specular = texture(textures[chunk.tex.y + Near+Specular], uv).r;
	uint heightTexIndex = chunk.tex.y + Near+Height;
	
	vec3 tangentZ = vec3(0,0,1);// normalize(cross(vec3(1,0,0), surface.normal));
	vec3 tangentX = vec3(1,0,0);// normalize(cross(surface.normal, tangentZ));
	surface.normal = vec3(0,1,0);
	mat3 TBN = mat3(tangentX, surface.normal, tangentZ);
	float altitudeTop = textureOffset(textures[heightTexIndex], uv, ivec2(0,-1)).r;
	float altitudeBottom = textureOffset(textures[heightTexIndex], uv, ivec2(0,+1)).r;
	float altitudeLeft = textureOffset(textures[heightTexIndex], uv, ivec2(-1,0)).r;
	float altitudeRight = textureOffset(textures[heightTexIndex], uv, ivec2(+1,0)).r;
	vec3 bump = normalize(vec3((altitudeLeft-altitudeRight), 0.05, (altitudeBottom-altitudeTop)));
	surface.normal = normalize(TBN * bump);
	
	
	// Rough terrain
	if (surface.roughness > 0) {
		BUMP(NormalDetail, surface.localPosition * 50, surface.normal, surface.roughness * 0.01, 1)
	}
	
	
	// vec3 pos = surface.localPosition;
	// surface.color.rgb = mix(rockColor, sandColor, 0.5);
	// if (surface.distance < textureMaxDistance) {
	// 	float strength = smoothstep(textureMaxDistance, 0, surface.distance);
	// 	float waveLength = 0.001;
	// 	float height = Rock(pos);
	// 	if (height > 0.0) {
	// 		surface.color.rgb = mix(surface.color.rgb, rockColor, strength);
	// 		BUMP(Rock, pos, surface.normal, waveLength, strength)
	// 		surface.specular = 1;
	// 	} else {
	// 		surface.color.rgb = mix(surface.color.rgb, sandColor, strength);
	// 		BUMP(Sand, pos, surface.normal, waveLength, strength)
			
	// 		// Rough terrain
	// 		if (surface.roughness > 0) {
	// 			BUMP(NormalDetail, surface.localPosition * 50, surface.normal, surface.roughness * 0.02, 1)
	// 		}
			
	// 	}
	// }
	
	
	
	
	
	
	
	
	
	
	// // Blending
	// vec4 in_blending = vec4(1,0,0,0);
	// uvec4 in_tex_albedo = uvec4(
	// 	chunk.tex.x + Near+Diffuse,
	// 	chunk.tex.y + Near+Diffuse,
	// 	chunk.tex.z + Near+Diffuse,
	// 	chunk.tex.w + Near+Diffuse
	// );
	// uvec4 in_tex_height = uvec4(
	// 	chunk.tex.x + Near+Height,
	// 	chunk.tex.y + Near+Height,
	// 	chunk.tex.z + Near+Height,
	// 	chunk.tex.w + Near+Height
	// );
	// vec3 in_posOnChunk = surface.localPosition;
	// vec3 in_normal = surface.normal;
	// vec4 out_color;
	
	// vec3 triplanarCoords1;
	// vec4 triplanarCoords2;
	// vec3 triplanarBlending;
	// vec4 texBlending = GetTextureBlending(in_blending, surface.uv1, in_tex_height, vec3(0,1,0)/*upDir*/, in_posOnChunk, true, in_normal, /*out*/triplanarCoords1, /*out*/triplanarCoords2, /*out*/triplanarBlending);
	
	// // Color
	// out_color = vec4(0);
	// if (texBlending.x > 0) out_color.rgb += texBlending.x * mix(TriplanarTextureRGB(in_tex_albedo.x, triplanarCoords1, triplanarBlending), TriplanarTextureRGB(in_tex_albedo.x, triplanarCoords2.xyz, triplanarBlending), triplanarCoords2.w);
	// if (texBlending.y > 0) out_color.rgb += texBlending.y * mix(TriplanarTextureRGB(in_tex_albedo.y, triplanarCoords1, triplanarBlending), TriplanarTextureRGB(in_tex_albedo.y, triplanarCoords2.xyz, triplanarBlending), triplanarCoords2.w);
	// if (texBlending.z > 0) out_color.rgb += texBlending.z * mix(TriplanarTextureRGB(in_tex_albedo.z, triplanarCoords1, triplanarBlending), TriplanarTextureRGB(in_tex_albedo.z, triplanarCoords2.xyz, triplanarBlending), triplanarCoords2.w);
	// if (texBlending.w > 0) out_color.rgb += texBlending.w * mix(TriplanarTextureRGB(in_tex_albedo.w, triplanarCoords1, triplanarBlending), TriplanarTextureRGB(in_tex_albedo.w, triplanarCoords2.xyz, triplanarBlending), triplanarCoords2.w);
	
	// // // Disturb Color
	// // if (distanceFromEye < textureDisturbanceMaxDistance) {
	// // 	float colorDisturbance = 1;
	// // 	colorDisturbance *= mix(0.7, 1.0, abs(FastSimplexFractal(in_posOnChunk*108.6, 3)));
	// // 	colorDisturbance *= mix(0.7, 1.0, FastSimplexFractal(in_posOnChunk*7.2, 3)*0.5+0.5);
	// // 	colorDisturbance *= mix(0.7, 1.0, FastSimplexFractal(in_posOnChunk*0.32, 2)*0.5+0.5);
	// // 	colorDisturbance *= mix(0.7, 1.0, abs(FastSimplex(in_posOnChunk*726.6)));
	// // 	out_color.rgb *= mix(colorDisturbance, 1, smoothstep(textureDisturbanceFadeDistance, textureDisturbanceMaxDistance, distanceFromEye));
	// // }
	
	// // // Height as ambient occlusion through albedo
	// // #ifdef SHADER_RCHIT
	// // 	float height = 0;
	// // 	if (texBlending.x > 0) height += texBlending.x * mix(TriplanarTextureR(in_tex_height.x, triplanarCoords1, triplanarBlending), TriplanarTextureR(in_tex_height.x, triplanarCoords2.xyz, triplanarBlending), triplanarCoords2.w) * tex0_displacement_factor;
	// // 	if (texBlending.y > 0) height += texBlending.y * mix(TriplanarTextureR(in_tex_height.y, triplanarCoords1, triplanarBlending), TriplanarTextureR(in_tex_height.y, triplanarCoords2.xyz, triplanarBlending), triplanarCoords2.w) * tex1_displacement_factor;
	// // 	if (texBlending.z > 0) height += texBlending.z * mix(TriplanarTextureR(in_tex_height.z, triplanarCoords1, triplanarBlending), TriplanarTextureR(in_tex_height.z, triplanarCoords2.xyz, triplanarBlending), triplanarCoords2.w) * tex2_displacement_factor;
	// // 	if (texBlending.w > 0) height += texBlending.w * mix(TriplanarTextureR(in_tex_height.w, triplanarCoords1, triplanarBlending), TriplanarTextureR(in_tex_height.w, triplanarCoords2.xyz, triplanarBlending), triplanarCoords2.w) * tex3_displacement_factor;
	// // 	out_color = mix(out_color, out_color*0.5, pow(1.0-clamp(height, 0, 1), 2.0));
	// // #endif
	
	// out_color.a = 1;
	
	// // Normal from Bump textures
	// vec3 tangentZ = normalize(cross(vec3(1,0,0), surface.normal));
	// vec3 tangentX = normalize(cross(surface.normal, tangentZ));
	// mat3 TBN = mat3(tangentX, surface.normal, tangentZ);
	// vec3 bump = vec3(0);
	// if (texBlending.x > 0) bump += texBlending.x * mix(TriplanarTextureBump(in_tex_height.x, triplanarCoords1, triplanarBlending), TriplanarTextureBump(in_tex_height.x, triplanarCoords2.xyz, triplanarBlending), triplanarCoords2.w);
	// if (texBlending.y > 0) bump += texBlending.y * mix(TriplanarTextureBump(in_tex_height.y, triplanarCoords1, triplanarBlending), TriplanarTextureBump(in_tex_height.y, triplanarCoords2.xyz, triplanarBlending), triplanarCoords2.w);
	// if (texBlending.z > 0) bump += texBlending.z * mix(TriplanarTextureBump(in_tex_height.z, triplanarCoords1, triplanarBlending), TriplanarTextureBump(in_tex_height.z, triplanarCoords2.xyz, triplanarBlending), triplanarCoords2.w);
	// if (texBlending.w > 0) bump += texBlending.w * mix(TriplanarTextureBump(in_tex_height.w, triplanarCoords1, triplanarBlending), TriplanarTextureBump(in_tex_height.w, triplanarCoords2.xyz, triplanarBlending), triplanarCoords2.w);
	// surface.normal = normalize(TBN * normalize(bump));
	
	// // Rough terrain normal
	// if (surface.roughness > 0) {
	// 	BUMP(NormalDetail, surface.localPosition * 50, surface.normal, surface.roughness * 0.01)
	// }
	
	// surface.color = out_color;
	
	
	
}
