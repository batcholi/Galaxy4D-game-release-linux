#ifdef __cplusplus
	#pragma once
#endif
#include "game/graphics/common.inc.glsl"

BUFFER_REFERENCE_STRUCT(4) TerrainSplatBuffer {
	u8vec4 splat;
};

BUFFER_REFERENCE_STRUCT(16) ChunkBuffer {
	aligned_f64mat4 transform;
	aligned_f64mat4 inverseTransform;
	aligned_u32vec4 tex;
	aligned_float32_t skirtOffset;
	aligned_float32_t triangleSize;
	aligned_int32_t topSign;
	aligned_int32_t rightSign;
	aligned_float32_t chunkSize;
	aligned_uint32_t vertexSubdivisions;
	BUFFER_REFERENCE_ADDR(TerrainSplatBuffer) splats;
};
