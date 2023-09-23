#ifdef __cplusplus
	#pragma once
#endif
#include "game/graphics/common.inc.glsl"

BUFFER_REFERENCE_STRUCT(16) ChunkBuffer {
	aligned_f64mat4 transform;
	aligned_f64mat4 inverseTransform;
	aligned_float32_t skirtOffset;
	aligned_float32_t triangleSize;
	aligned_int32_t topSign;
	aligned_int32_t rightSign;
};
