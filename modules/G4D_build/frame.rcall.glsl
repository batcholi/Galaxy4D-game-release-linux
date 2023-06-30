#extension GL_EXT_ray_tracing : require

#define SHADER_SURFACE
#include "game/graphics/common.inc.glsl"
// #include "xenon/renderer/shaders/perlint.glsl"

void main() {
	
	surface.metallic = 0;
	surface.roughness = 1;
	surface.color.rgb = vec3(0.04);
	
}
