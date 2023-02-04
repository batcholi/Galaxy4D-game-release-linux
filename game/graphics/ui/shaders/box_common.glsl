#include "xenon/graphics/interface.glsl"

struct UiElementBoxData {
	aligned_f32vec4 color;
	aligned_float32_t x;
	aligned_float32_t y;
	aligned_float32_t width;
	aligned_float32_t height;
	aligned_uint32_t texture;
	aligned_uint32_t flags;
	uint32_t _padding[22];
	#ifdef __cplusplus
		UiElementBoxData(){}
		UiElementBoxData(const glm::vec4& color_, const glm::vec2& posNDC, const glm::vec2& halfSize, uint16_t texture_ = 0, uint16_t flags_ = 0)
		: color(color_)
		, x(posNDC.x)
		, y(posNDC.y)
		, width(halfSize.x)
		, height(halfSize.y)
		, texture(texture_)
		, flags(flags_)
		{}
	#endif
};

PUSH_CONSTANT_STRUCT UiElementBoxPushConstant {
	UiElementBoxData box;
};
STATIC_ASSERT_ALIGNED16_SIZE(UiElementBoxPushConstant, 128)
