#extension GL_EXT_ray_tracing : require

#define SHADER_SURFACE
#include "terrain.common.inc.glsl"
#include "xenon/renderer/shaders/perlint.inc.glsl"

float NormalDetail(in vec3 pos) {
	return SimplexFractal(pos, 3);
}

#define BUMP(_noiseFunc, _position, _normal, _waveLength) {\
	vec3 _tangentZ = normalize(cross(vec3(1,0,0), _normal));\
	vec3 _tangentX = normalize(cross(_normal, _tangentZ));\
	mat3 _TBN = mat3(_tangentX, _normal, _tangentZ);\
	float _altitudeTop = _noiseFunc(_position + _tangentZ*_waveLength);\
	float _altitudeBottom = _noiseFunc(_position - _tangentZ*_waveLength);\
	float _altitudeRight = _noiseFunc(_position + _tangentX*_waveLength);\
	float _altitudeLeft = _noiseFunc(_position - _tangentX*_waveLength);\
	vec3 _bump = normalize(vec3((_altitudeLeft-_altitudeRight), 2, (_altitudeBottom-_altitudeTop)));\
	_normal = normalize(_TBN * _bump);\
}

const float textureNearDistance = 8;
const float textureFarDistance = 32;
const float textureMaxDistance = 200;

ChunkBuffer chunk = ChunkBuffer(surface.geometryInfoData);

#define Color 0
#define Height 2
#define Specular 4

vec4 ComputeSplat(in uint64_t geometries, in uint geometryIndex, in uint primitiveID, in vec3 barycentricCoordsOrLocalPosition) {
	GeometryData geometry = GeometryData(geometries)[geometryIndex];
	if (uint64_t(chunk.splats) != 0) {
		uint index0 = primitiveID * 3;
		uint index1 = primitiveID * 3 + 1;
		uint index2 = primitiveID * 3 + 2;
		if (geometry.indices16 != 0) {
			index0 = IndexBuffer16(geometry.indices16).indices[index0];
			index1 = IndexBuffer16(geometry.indices16).indices[index1];
			index2 = IndexBuffer16(geometry.indices16).indices[index2];
		} else if (geometry.indices32 != 0) {
			index0 = IndexBuffer32(geometry.indices32).indices[index0];
			index1 = IndexBuffer32(geometry.indices32).indices[index1];
			index2 = IndexBuffer32(geometry.indices32).indices[index2];
		}
		return clamp(
			+ vec4(chunk.splats[index0].splat) / 255.0 * barycentricCoordsOrLocalPosition.x
			+ vec4(chunk.splats[index1].splat) / 255.0 * barycentricCoordsOrLocalPosition.y
			+ vec4(chunk.splats[index2].splat) / 255.0 * barycentricCoordsOrLocalPosition.z
		, vec4(0), vec4(1));
	} else {
		return vec4(0);
	}
}

float smoothCurve(float x) {
	x = clamp(x,0,1);
	// return x*x*(3-2*x);
	return x*x*x*(x*(x*6-15)+10);
}

void main() {
	if (surface.distance > textureMaxDistance) {
		return;
	}
	
	vec4 splat = ComputeSplat(surface.geometries, surface.geometryIndex, surface.primitiveIndex, surface.barycentricCoords);
	surface.uv1 = ComputeSurfaceUV1(surface.geometries, surface.geometryIndex, surface.primitiveIndex, surface.barycentricCoords);
	vec2 uv = surface.uv1 * max(1,round(chunk.chunkSize / 4));
	vec2 uvFar = surface.uv1 * max(1,round(chunk.chunkSize / 64));
	
	vec3 color = surface.color.rgb;
	vec3 normal = surface.normal;
	
	float normalDistanceRatio = pow(clamp(surface.distance / textureMaxDistance, 0, 1), 0.25);
	
	// Base terrain
	BUMP(NormalDetail, surface.localPosition * 50, surface.normal, 0.05)
	surface.normal = mix(surface.normal, normal, normalDistanceRatio);
	
	float splats[4];
	float blending[4];
	uint colors[4];
	uint heights[4];
	uint speculars[4];
	
	splats[0] = smoothCurve(splat.x);
	blending[0] = splats[0] * texture(textures[nonuniformEXT(chunk.tex.x + Height)], uv).r;
	if (blending[0] > 0) {
		colors[0] = chunk.tex.x + Color;
		heights[0] = chunk.tex.x + Height;
		speculars[0] = chunk.tex.x + Specular;
	}
	
	splats[1] = smoothCurve(splat.y);
	blending[1] = splats[1] * texture(textures[nonuniformEXT(chunk.tex.y + Height)], uv).r;
	if (blending[1] > 0) {
		colors[1] = chunk.tex.y + Color;
		heights[1] = chunk.tex.y + Height;
		speculars[1] = chunk.tex.y + Specular;
	}
	
	splats[2] = smoothCurve(splat.z);
	blending[2] = splats[2] * texture(textures[nonuniformEXT(chunk.tex.z + Height)], uv).r;
	if (blending[2] > 0) {
		colors[2] = chunk.tex.z + Color;
		heights[2] = chunk.tex.z + Height;
		speculars[2] = chunk.tex.z + Specular;
	}
	
	splats[3] = smoothCurve(splat.w);
	blending[3] = splats[3] * texture(textures[nonuniformEXT(chunk.tex.w + Height)], uv).r;
	if (blending[3] > 0) {
		colors[3] = chunk.tex.w + Color;
		heights[3] = chunk.tex.w + Height;
		speculars[3] = chunk.tex.w + Specular;
	}
	
	float maxBlending = 0.01;
	for (int i = 0; i < 4; ++i) {
		if (blending[i] > maxBlending) {
			maxBlending = blending[i] * 0.5;
			vec3 colorNear = texture(textures[nonuniformEXT(colors[i])], uv).rgb;
			float specularNear = texture(textures[nonuniformEXT(speculars[i])], uv).r;
			vec3 colorFar = texture(textures[nonuniformEXT(colors[i] + 1)], uvFar).rgb;
			float specularFar = texture(textures[nonuniformEXT(speculars[i] + 1)], uvFar).r;
			surface.color.rgb = mix(color, mix(colorNear, colorFar, smoothstep(textureNearDistance, textureFarDistance, surface.distance)), splats[i] * (1 - surface.distance / textureMaxDistance));
			surface.specular = mix(surface.specular, mix(specularNear, specularFar, smoothstep(textureNearDistance, textureFarDistance, surface.distance)), splats[i] * (1 - surface.distance / textureMaxDistance));
			float altitudeTop = textureOffset(textures[nonuniformEXT(heights[i])], uv, ivec2(0,-1)).r;
			float altitudeBottom = textureOffset(textures[nonuniformEXT(heights[i])], uv, ivec2(0,+1)).r;
			float altitudeLeft = textureOffset(textures[nonuniformEXT(heights[i])], uv, ivec2(-1,0)).r;
			float altitudeRight = textureOffset(textures[nonuniformEXT(heights[i])], uv, ivec2(+1,0)).r;
			vec3 bump = normalize(vec3((altitudeLeft-altitudeRight), 0.05, (altitudeBottom-altitudeTop)));
			vec3 tangentZ = normalize(cross(vec3(1,0,0), normal));
			vec3 tangentX = normalize(cross(normal, tangentZ));
			mat3 TBN = mat3(tangentX, normal, tangentZ);
			surface.normal = normalize(mix(TBN * bump, surface.normal, normalDistanceRatio));
		}
	}
	
}
