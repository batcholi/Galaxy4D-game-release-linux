#define SHADER_RCHIT
#include "common.inc.glsl"
#define ENTITY_COMPUTE_SURFACE_NORMAL surface.normal = ComputeSurfaceNormal(ray.localPosition);
#include "entity.inc.glsl"
