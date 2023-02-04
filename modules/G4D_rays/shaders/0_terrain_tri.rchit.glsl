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
	
	// Apply world space normal
	ray.normal = normalize(MODEL2WORLDNORMAL * surface.normal);

	// Store albedo and roughness (may remove this in the future)
	if (RAY_RECURSIONS == 0) {
		imageStore(img_primary_albedo_roughness, COORDS, vec4(surface.color.rgb, surface.roughness));
	}
	
	// // Fresnel
	// float fresnel = Fresnel((renderer.viewMatrix * vec4(ray.worldPosition, 1)).xyz, normalize(WORLD2VIEWNORMAL * ray.normal), surface.ior);
	
	vec3 directLighting = vec3(0);
	vec3 ambient = vec3(0);
	
	// Lighting
	if (RAY_RECURSIONS < RAY_MAX_RECURSION) {
		// Direct lighting and shadows
		if (surface.metallic < 1.0) {
			directLighting = GetDirectLighting(ray.worldPosition, ray.normal) * (1.0 - surface.metallic) * (RAY_IS_UNDERWATER? 0.5:1);
		}
		
		// Simple Gi Approx by tracing a ray towards the surface normal for just the Atmosphere
		if (surface.roughness > 0) {
			RayPayload originalRay = ray;
			RAY_RECURSION_PUSH
				RAY_GI_PUSH
					traceRayEXT(tlas, 0, RAYTRACE_MASK_ATMOSPHERE, 0/*rayType*/, 0/*nbRayTypes*/, 0/*missIndex*/, originalRay.worldPosition, 0, originalRay.normal, 10000, 0);
				RAY_GI_POP
			RAY_RECURSION_POP
			ambient += ray.color.rgb * surface.roughness;
			ray = originalRay;
		}
	}
	
	// Apply final color
	ray.color.rgb = 
		+ ambient * surface.color.rgb
		+ directLighting * surface.color.rgb
	;
}
