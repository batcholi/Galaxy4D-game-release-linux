#include "common.inc.glsl"

layout(local_size_x = XENON_RENDERER_SCREEN_COMPUTE_LOCAL_SIZE_X, local_size_y = XENON_RENDERER_SCREEN_COMPUTE_LOCAL_SIZE_Y) in;
ivec2 compute_coord = ivec2(gl_GlobalInvocationID.xy);

void main() {
	ivec2 compute_size = imageSize(img_resolved);
	if (compute_coord.x >= compute_size.x || compute_coord.y >= compute_size.y) return;
	
	vec4 color = imageLoad(img_resolved, compute_coord);
	
	// Copy to history BEFORE applying Tone Mapping
	imageStore(img_history, compute_coord, color);
	
	ApplyToneMapping(color);
	
	// Dithering (Part 1 of 2) stochastic pre-dither
	if ((xenonRendererData.config.options & RENDER_OPTION_DITHERING) != 0) {
		uint seed = InitRandomSeed(InitRandomSeed(compute_coord.x, compute_coord.y), uint(xenonRendererData.frameIndex % 32ul));
		color.rgb += sign(vec3(RandomFloat(seed), RandomFloat(seed), RandomFloat(seed)) - 0.5) / 384.0;
	}
	
	imageStore(img_resolved, compute_coord, vec4(clamp(color.rgb, vec3(0), vec3(1)), imageLoad(img_composite, compute_coord).a));
}
