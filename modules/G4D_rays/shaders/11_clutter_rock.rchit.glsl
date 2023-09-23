#define SHADER_RCHIT
#include "clutter_rock.common.inc.glsl"
#include "lighting.inc.glsl"

void main() {
	ray.hitDistance = gl_HitTEXT;
	ray.t2 = 0;
	ray.aimID = gl_InstanceCustomIndexEXT;
	ray.renderableIndex = gl_InstanceID;
	ray.geometryIndex = gl_GeometryIndexEXT;
	ray.primitiveIndex = gl_PrimitiveID;
	ray.localPosition = gl_ObjectRayOriginEXT + gl_ObjectRayDirectionEXT * gl_HitTEXT;
	ray.worldPosition = gl_WorldRayOriginEXT + gl_WorldRayDirectionEXT * gl_HitTEXT;
	ray.ssao = 1;
	ray.color.a = 1;
	
	if (RAY_IS_SHADOW) {
		return;
	}
	
	vec3 pos = ray.localPosition - rockPos;
	float detailSize = GetDetailSize();
	vec2 e = vec2(epsilon,0);
	vec3 normal = normalize(vec3(
		Sdf(pos+e.xyy, detailSize, detailOctavesHighRes) - Sdf(pos-e.xyy, detailSize, detailOctavesHighRes),
		Sdf(pos+e.yxy, detailSize, detailOctavesHighRes) - Sdf(pos-e.yxy, detailSize, detailOctavesHighRes),
		Sdf(pos+e.yyx, detailSize, detailOctavesHighRes) - Sdf(pos-e.yyx, detailSize, detailOctavesHighRes)
	));
	uint seed_ = uint32_t(AABB.data);
	float rocky = pow(RandomFloat(seed_), 2);
	surface.color = vec4(mix(vec3(0.8, 0.4, 0.15), vec3(0.5,0.4,0.3), rocky), 1);
	surface.color.rgb *= mix(0.3, 1.0, (abs(FastSimplexFractal(ray.localPosition*255.658, detailOctavesTextures)) + (FastSimplexFractal(ray.localPosition*29.123, detailOctavesTextures)*0.5+0.5)) * 0.5);
	surface.color.rgb *= normal.y * 0.5 + 0.5;
	surface.normal = normal;
	surface.metallic = 0;
	surface.roughness = 1;//clamp(FastSimplexFractal(ray.localPosition*223.18, detailOctavesTextures), 0.1, 1);
	surface.emission = vec3(0);
	surface.ior = 1.45;
	surface.specular = rocky*0.5;
	
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
