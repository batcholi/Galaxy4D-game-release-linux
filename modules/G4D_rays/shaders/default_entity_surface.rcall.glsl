#extension GL_EXT_ray_tracing : require
#extension GL_EXT_buffer_reference2 : require

#define SHADER_SURFACE
#include "game/graphics/common.inc.glsl"

void main() {
	if (surface.renderableData != 0) {
		RenderableData data = RenderableData(surface.renderableData)[surface.geometryIndex];
		surface.emission += data.emission;
		surface.color = mix(surface.color, data.color, data.colorMix);
		surface.metallic = mix(surface.metallic, data.pbrMetallic, data.pbrMix);
		surface.roughness = mix(surface.roughness, data.pbrRoughness, data.pbrMix);
	}
}
