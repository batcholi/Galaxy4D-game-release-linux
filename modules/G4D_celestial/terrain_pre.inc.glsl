#ifdef __cplusplus
	#pragma once
#endif
#include "game/graphics/common.inc.glsl"

#define COMPUTE_SIZE_X 16
#define COMPUTE_SIZE_Y 16

BUFFER_REFERENCE_STRUCT(16) ChunkBuffer {
	aligned_f64mat4 transform;
	aligned_f64mat4 inverseTransform;
	aligned_float32_t skirtOffset;
	aligned_float32_t triangleSize;
	aligned_int32_t topSign;
	aligned_int32_t rightSign;
};

BUFFER_REFERENCE_STRUCT(4) VertexBuffer {
	float vertex;
};

BUFFER_REFERENCE_STRUCT(4) NormalBuffer {
	float normal;
};

BUFFER_REFERENCE_STRUCT(4) ColorBuffer {
	u8vec4 color;
};

PUSH_CONSTANT_STRUCT TerrainChunkPushConstant {
	BUFFER_REFERENCE_ADDR(ChunkBuffer) chunk;
	BUFFER_REFERENCE_ADDR(VertexBuffer) vertices;
	BUFFER_REFERENCE_ADDR(NormalBuffer) normals;
	BUFFER_REFERENCE_ADDR(ColorBuffer) colors;
	aligned_uint64_t celestial_configs;
};
