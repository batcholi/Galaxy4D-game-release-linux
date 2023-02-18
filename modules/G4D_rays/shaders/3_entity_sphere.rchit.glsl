#define SHADER_RCHIT
#include "common.inc.glsl"

struct SphereAttr {
	float t1;
	float t2;
	float radius;
};

hitAttributeEXT SphereAttr sphereAttr;

#define ENTITY_COMPUTE_SURFACE {\
	const vec3 spherePosition = (AABB_MAX + AABB_MIN) / 2;\
	const vec3 hitPoint1 = gl_ObjectRayOriginEXT + gl_ObjectRayDirectionEXT * sphereAttr.t1;\
	const vec3 hitPoint2 = gl_ObjectRayOriginEXT + gl_ObjectRayDirectionEXT * sphereAttr.t2;\
	if (gl_HitKindEXT == 1) /*Inside of sphere*/ {\
		surface.normal = normalize(spherePosition - hitPoint2);\
	} else /*Outside of sphere*/ {\
		surface.normal = normalize(hitPoint1 - spherePosition);\
	}\
	surface.color = ComputeSurfaceColor(ray.localPosition) * GEOMETRY.info.color;\
	surface.uv1 = ComputeSurfaceUV1(ray.localPosition);\
	surface.uv2 = ComputeSurfaceUV2(ray.localPosition);\
}

#include "entity.inc.glsl"
