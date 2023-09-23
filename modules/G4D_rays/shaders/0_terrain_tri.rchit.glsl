#define SHADER_RCHIT
#include "common.inc.glsl"
#include "lighting.inc.glsl"

hitAttributeEXT vec3 hitAttribs;

float NormalDetail(in vec3 pos) {
	return SimplexFractal(pos, 3);
}

#define APPLY_TERRAIN_BUMP_NOISE(_noiseFunc, _position, _normal, _waveHeight) {\
	mat3 _TBN = mat3(vec3(1,0,0), vec3(0,0,1), _normal);\
	float _altitudeTop = _noiseFunc(_position + vec3(0,0,1)*_waveHeight);\
	float _altitudeBottom = _noiseFunc(_position - vec3(0,0,1)*_waveHeight);\
	float _altitudeRight = _noiseFunc(_position + vec3(1,0,0)*_waveHeight);\
	float _altitudeLeft = _noiseFunc(_position - vec3(1,0,0)*_waveHeight);\
	vec3 _bump = normalize(vec3((_altitudeRight-_altitudeLeft), (_altitudeBottom-_altitudeTop), 2));\
	_normal = normalize(_TBN * _bump);\
}

void main() {
	
	ray.hitDistance = gl_HitTEXT;
	ray.aimID = gl_InstanceCustomIndexEXT;
	ray.renderableIndex = gl_InstanceID;
	ray.geometryIndex = gl_GeometryIndexEXT;
	ray.primitiveIndex = gl_PrimitiveID;
	ray.localPosition = gl_ObjectRayOriginEXT + gl_ObjectRayDirectionEXT * gl_HitTEXT;
	ray.worldPosition = gl_WorldRayOriginEXT + gl_WorldRayDirectionEXT * gl_HitTEXT;
	ray.t2 = 0;
	ray.ssao = 0.75;
	
	vec3 barycentricCoords = vec3(1.0f - hitAttribs.x - hitAttribs.y, hitAttribs.x, hitAttribs.y);
	surface.normal = ComputeSurfaceNormal(barycentricCoords);
	surface.color = ComputeSurfaceColor(barycentricCoords);
	surface.barycentricCoords = barycentricCoords;
	surface.distance = ray.hitDistance;
	surface.localPosition = ray.localPosition;
	surface.metallic = 0;
	surface.roughness = 1;
	surface.emission = vec3(0);
	surface.ior = 1.45;
	surface.renderableData = INSTANCE.data;
	surface.aabbData = 0;
	surface.renderableIndex = gl_InstanceID;
	surface.geometryIndex = gl_GeometryIndexEXT;
	surface.primitiveIndex = gl_PrimitiveID;
	surface.geometries = uint64_t(INSTANCE.geometries);
	surface.geometryInfoData = GEOMETRY.material.data;
	surface.geometryUv1Data = GEOMETRY.material.uv1;
	surface.geometryUv2Data = GEOMETRY.material.uv2;
	surface.uv1 = vec2(0);
	surface.specular = 0;
	
	// Terrain is always fully opaque
	ray.color.a = 1;
	
	if (RAY_IS_SHADOW) {
		return;
	}
	
	// if (OPTION_TEXTURES) {
		executeCallableEXT(GEOMETRY.material.surfaceIndex, SURFACE_CALLABLE_PAYLOAD);
	// }
	
	// Rough terrain
	if (surface.roughness > 0) {
		vec3 scale = vec3(50);
		APPLY_TERRAIN_BUMP_NOISE(NormalDetail, surface.localPosition * scale, surface.normal, surface.roughness * 0.05)
	}
	
	// Debug UV1
	if (xenonRendererData.config.debugViewMode == RENDERER_DEBUG_VIEWMODE_UVS) {
		if (RAY_RECURSIONS == 0) imageStore(img_normal_or_debug, COORDS, vec4(surface.uv1, 0, 1));
		ray.normal = vec3(0);
		ray.color = vec4(0,0,0,1);
		return;
	}
	
	// Fix black specs caused by skirts
	if (dot(surface.normal, vec3(0,1,0)) < 0.15) surface.normal = vec3(0,1,0);

	// Apply world space normal
	ray.normal = normalize(MODEL2WORLDNORMAL * surface.normal);
	
	float giVoxelSize = renderer.globalIlluminationVoxelSize * 2;
	vec3 giPos = ray.worldPosition / giVoxelSize + ray.normal * 0.5001;
	ApplyDefaultLighting(0, giPos, round(giPos) * giVoxelSize, giVoxelSize);
	
	// Store albedo and roughness (may remove this in the future)
	if (RAY_RECURSIONS == 0) {
		imageStore(img_primary_albedo_roughness, COORDS, vec4(surface.color.rgb, surface.roughness));
	}
}
