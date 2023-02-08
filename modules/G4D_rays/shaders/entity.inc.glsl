#include "lighting.inc.glsl"

void main() {
	
	ray.hitDistance = gl_HitTEXT;
	ray.id = gl_InstanceCustomIndexEXT;
	ray.renderableIndex = gl_InstanceID;
	ray.geometryIndex = gl_GeometryIndexEXT;
	ray.primitiveIndex = gl_PrimitiveID;
	ray.localPosition = gl_ObjectRayOriginEXT + gl_ObjectRayDirectionEXT * gl_HitTEXT;
	ray.worldPosition = gl_WorldRayOriginEXT + gl_WorldRayDirectionEXT * gl_HitTEXT;
	ray.t2 = 0;
	ray.ssao = 1;
	
	ENTITY_COMPUTE_SURFACE_NORMAL
	
	surface.color = ComputeSurfaceColor(ray.localPosition) * GEOMETRY.info.color;
	surface.uv1 = ComputeSurfaceUV1(ray.localPosition);
	surface.uv2 = ComputeSurfaceUV2(ray.localPosition);
	surface.distance = ray.hitDistance;
	surface.localPosition = ray.localPosition;
	surface.metallic = GEOMETRY.info.metallic;
	surface.roughness = GEOMETRY.info.roughness;
	surface.emission = GEOMETRY.info.emission;
	surface.ior = 1.45;
	surface.geometryInfo = GEOMETRY.info;
	surface.renderableData = INSTANCE.data;
	surface.aabbData = 0;
	surface.renderableIndex = gl_InstanceID;
	surface.geometryIndex = gl_GeometryIndexEXT;
	surface.primitiveIndex = gl_PrimitiveID;
	surface.aimID = gl_InstanceCustomIndexEXT;
	
	// if (OPTION_TEXTURES) {
		executeCallableEXT(GEOMETRY.info.surfaceIndex, SURFACE_CALLABLE_PAYLOAD);
	// }
	
	ray.normal = normalize(MODEL2WORLDNORMAL * surface.normal);
	
	if (surface.color.a < 1.0) {
		ray.color = surface.color;
		return;
	}
	
	ApplyDefaultLighting(true);
	
	if (RAY_RECURSIONS == 0) {
		imageStore(img_primary_albedo_roughness, COORDS, vec4(surface.color.rgb, surface.roughness));
	}
}
