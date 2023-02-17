#include "common.inc.glsl"

layout(local_size_x = XENON_RENDERER_SCREEN_COMPUTE_LOCAL_SIZE_X, local_size_y = XENON_RENDERER_SCREEN_COMPUTE_LOCAL_SIZE_Y) in;
ivec2 compute_coord = ivec2(gl_GlobalInvocationID.xy);

void main() {
	ivec2 compute_size = imageSize(img_post);
	if (compute_coord.x >= compute_size.x || compute_coord.y >= compute_size.y) return;
	
	vec4 color = imageLoad(img_post, compute_coord);
	
	// Dithering (Part 2 of 2) fixed dither (part 1 is in toneMapping.comp.glsl)
	if ((xenonRendererData.config.options & RENDER_OPTION_DITHERING) != 0) {
		uint seed = InitRandomSeed(compute_coord.x, compute_coord.y);
		color.rgb += sign(vec3(RandomFloat(seed), RandomFloat(seed), RandomFloat(seed)) - 0.5) / 384.0;
	}
	
	if (xenonRendererData.config.debugViewMode != 0) {
		vec4 debug = imageLoad(img_normal_or_debug, ivec2(vec2(compute_coord) / vec2(compute_size) * imageSize(img_normal_or_debug)));
		color.rgb = mix(color.rgb, debug.rgb, debug.a);
	}
	
	vec4 swapchain = imageLoad(img_swapchain, compute_coord);
	imageStore(img_swapchain, compute_coord, vec4(swapchain.rgb * (1-color.a) + color.rgb, 1));
}
