#include "common.inc.glsl"

// Vertical blur pass and apply to swapchain

layout(local_size_x = 16, local_size_y = 16) in;

const float sigma = 3.0;
const int blurSize = int(sigma*3);

void main() {
	const ivec2 compute_coord = ivec2(gl_GlobalInvocationID);

	vec4 color = vec4(0.0);
	float weightSum = 0.0;
	for (int i = -blurSize; i <= blurSize; ++i) {
		float weight = gaussian(float(i), sigma);
		color += imageLoad(img_bloom, compute_coord + ivec2(0, i)) * weight;
		weightSum += weight;
	}
	color /= weightSum;
	
	if (xenonRendererData.config.debugViewMode == 0) {
		vec4 swapchain = imageLoad(img_swapchain, compute_coord);
		imageStore(img_swapchain, compute_coord, vec4(clamp(swapchain.rgb + color.rgb, vec3(0), vec3(1)), 1));
	}
}
