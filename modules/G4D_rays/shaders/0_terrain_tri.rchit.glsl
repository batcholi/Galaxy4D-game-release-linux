#define SHADER_RCHIT
#include "common.inc.glsl"
#include "lighting.inc.glsl"

hitAttributeEXT vec3 hitAttribs;

// float NormalDetail(in vec3 pos) {
// 	return SimplexFractal(pos * 0.3, 2);
// }

void main() {
	
	ray.hitDistance = gl_HitTEXT;
	ray.id = gl_InstanceCustomIndexEXT;
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
	surface.uv1 = ComputeSurfaceUV1(barycentricCoords);
	surface.uv2 = ComputeSurfaceUV2(barycentricCoords);
	surface.distance = ray.hitDistance;
	surface.localPosition = ray.localPosition;
	surface.metallic = 0;
	surface.roughness = 1;
	surface.emission = vec3(0);
	surface.ior = 1.45;
	surface.geometryInfo = GEOMETRY.info;
	surface.renderableData = INSTANCE.data;
	surface.aabbData = 0;
	surface.renderableIndex = gl_InstanceID;
	surface.geometryIndex = gl_GeometryIndexEXT;
	surface.primitiveIndex = gl_PrimitiveID;
	surface.aimID = gl_InstanceCustomIndexEXT;
	
	// Terrain is always fully opaque
	ray.color.a = 1;
	
	if (RAY_IS_SHADOW) {
		return;
	}
	
	// if (OPTION_TEXTURES) {
		executeCallableEXT(GEOMETRY.info.surfaceIndex, SURFACE_CALLABLE_PAYLOAD);
	// }
	
	// Fix black specs caused by skirts
	if (dot(surface.normal, vec3(0,1,0)) < 0.15) surface.normal = vec3(0,1,0);

	// Apply world space normal
	ray.normal = normalize(MODEL2WORLDNORMAL * surface.normal);

	ApplyDefaultLighting(false);
	
	// Store albedo and roughness (may remove this in the future)
	if (RAY_RECURSIONS == 0) {
		imageStore(img_primary_albedo_roughness, COORDS, vec4(surface.color.rgb, surface.roughness));
	}
}
