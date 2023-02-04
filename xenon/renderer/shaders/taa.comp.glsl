#include "common.inc.glsl"

layout(local_size_x = XENON_RENDERER_SCREEN_COMPUTE_LOCAL_SIZE_X, local_size_y = XENON_RENDERER_SCREEN_COMPUTE_LOCAL_SIZE_Y) in;
ivec2 imageSize = imageSize(img_composite);
ivec2 computeCoord = ivec2(gl_GlobalInvocationID.xy);

// bool ReprojectHistoryCoord(inout ivec2 coord) {
// 	coord = ivec2(round(vec2(coord) + imageLoad(img_motion, coord).rg * vec2(imageSize) * 0.5));
// 	return coord.x >= 0 && coord.x < imageSize.x && coord.y >= 0 && coord.y < imageSize.y;
// }

bool ReprojectHistoryUV(inout vec2 uv) {
	uv += texture(sampler_motion, uv).rg * 0.5;
	return uv.x > 0 && uv.x < 1 && uv.y > 0 && uv.y < 1;
}

void main() {
	if (computeCoord.x >= imageSize.x || computeCoord.y >= imageSize.y) return;
	
	vec2 uv = (vec2(computeCoord) + 0.5) / vec2(imageSize);
	vec4 color = vec4(texture(sampler_composite, uv).rgb, 0);
	if ((xenonRendererData.config.options & RENDER_OPTION_TAA) != 0 && ((xenonRendererData.config.options & RENDER_OPTION_TEMPORAL_UPSCALING) == 0) && xenonRendererData.frameIndex > 1) {
		vec2 uvHistory = uv;
		if (ReprojectHistoryUV(uvHistory)) {
			vec4 history = texture(sampler_history, uvHistory);
			float accumulation;
			if ((xenonRendererData.config.options & RENDER_OPTION_GROUND_TRUTH) != 0) {
				accumulation = history.a + 1;
			} else {
				history.rgb = VarianceClamp5(history.rgb, sampler_composite, uv);
				accumulation = min(history.a, XENON_RENDERER_TAA_SAMPLES) + 1;
			}
			float blend = clamp(1.0 / accumulation, 0, 1);
			color = vec4(mix(history.rgb, color.rgb, blend), accumulation);
		}
	}
	
	imageStore(img_resolved, computeCoord, color);
}
