#define SHADER_RCHIT
#include "common.inc.glsl"

#define ENTITY_COMPUTE_SURFACE \
	surface.normal = ComputeSurfaceNormal(ray.localPosition);\
	surface.color = ComputeSurfaceColor(ray.localPosition) * GEOMETRY.info.color;\
	surface.uv1 = ComputeSurfaceUV1(ray.localPosition);\
	surface.uv2 = ComputeSurfaceUV2(ray.localPosition);\

#include "entity.inc.glsl"
