#define SHADER_RCHIT
#include "common.inc.glsl"
hitAttributeEXT vec3 hitAttribs;
#define ENTITY_COMPUTE_SURFACE_NORMAL surface.normal = ComputeSurfaceNormal(vec3(1.0f - hitAttribs.x - hitAttribs.y, hitAttribs.x, hitAttribs.y));
#include "entity.inc.glsl"
