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
		if (data.monitorIndex > 0) {
			surface.emission *= texture(nonuniformEXT(textures[data.monitorIndex]), surface.uv1).rgb;
		}
	}
	if (surface.geometryInfo.data > 0) {
		uint16_t tex_albedo = 				uint16_t((surface.geometryInfo.data) & 0xffff);
		uint16_t tex_normal = 				uint16_t((surface.geometryInfo.data >> 16) & 0xffff);
		uint16_t tex_metallic_roughness = 	uint16_t((surface.geometryInfo.data >> 32) & 0xffff);
		uint16_t tex_emission = 			uint16_t((surface.geometryInfo.data >> 48) & 0xffff);
		if (tex_albedo > 0) surface.color.rgb *= texture(nonuniformEXT(textures[tex_albedo]), surface.uv1).rgb;
		if (tex_normal > 0) {
			//TODO: normal maps using tex_normal
		}
		if (tex_metallic_roughness > 0) {
			vec2 pbr = texture(nonuniformEXT(textures[tex_metallic_roughness]), surface.uv1).rg;
			surface.metallic = pbr.r;
			surface.roughness = pbr.g;
		}
		if (tex_emission > 0) {
			vec3 emissionPower = vec3(10);
			if (surface.renderableData != 0) {
				emissionPower = surface.emission;
			}
			surface.emission = emissionPower * texture(nonuniformEXT(textures[tex_emission]), surface.uv1).rgb;
		}
	}
}
