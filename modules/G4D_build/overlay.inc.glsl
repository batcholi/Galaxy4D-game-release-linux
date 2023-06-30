#ifdef __cplusplus
	#pragma once
	using namespace glm;
#endif

#include "game/graphics/common.inc.glsl"

PUSH_CONSTANT_STRUCT OverlayPushConstant {
	aligned_f32mat4 modelViewMatrix;
	aligned_f32vec4 color;
	BUFFER_REFERENCE_ADDR(VertexBuffer) vertexBuffer;
	BUFFER_REFERENCE_ADDR(IndexBuffer16) indexBuffer;
	BUFFER_REFERENCE_ADDR(VertexNormal) normalBuffer;
};
