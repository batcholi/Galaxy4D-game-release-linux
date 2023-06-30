// ALSO INCLUDED IN GLSL

#include "xenon/graphics/interface.glsl"
#ifdef __cplusplus
	#pragma once
	using namespace glm;
	#include <cstring>
#endif

BUFFER_REFERENCE_STRUCT_READONLY(4) BlockColor {
	aligned_uint8_t r;
	aligned_uint8_t g;
	aligned_uint8_t b;
	#ifdef __cplusplus
		uint8_t opacity : 4;
		uint8_t roughness : 3;
		uint8_t metallic : 1;
	#else
		aligned_uint8_t a;
		// opacity = (float(a & 0xf) + 1) / 16.0
		// roughness = float((a >> 4) & 0x7) / 7.0
		// metallic = float(a >> 7)
	#endif
};
STATIC_ASSERT_SIZE(BlockColor, 4)

// 16 bytes (128 bits)
BUFFER_REFERENCE_STRUCT_READONLY(16) Block {
	
	// 8 bytes (64 bits)
	aligned_uint8_t type; // 256 types & orientations
	aligned_uint8_t color[7]; // 256 materials (color + roughness + metallic)
								// 32 metalic
								// 128 matte
								// 96 glossy
	
	#ifdef __cplusplus
		// 4 bytes (32 bits)
		uint32_t damage : 6; // 64 states
		uint32_t dirt : 2; // 4 states
		uint32_t composition : 8; // 256 alloys
		uint32_t extra : 4; // 16 states
		uint32_t size_x : 4; // from 0.25 to 4.0 meter
		uint32_t size_y : 4;
		uint32_t size_z : 4;
	
		// 2 bytes (16 bits)
		union {
			uint16_t id;
			struct {
				uint16_t x : 5; // supports up to 8x8x8 meters frame size on a 25 cm grid
				uint16_t y : 5;
				uint16_t z : 5;
				uint16_t _ : 1;
			} position;
		};
		
		Block(uint16_t id_ = 0) : type(0), color{0,0,0,0,0,0,0}, damage(0), dirt(0), composition(0), extra(0), size_x(0), size_y(0), size_z(0), id(id_) {}
		
		vec3 GetPosition() const {
			return vec3(position.x, position.y, position.z) * 0.25f;
		}
		
		vec3 GetSize() const {
			return vec3(size_x, size_y, size_z) * 0.25f + 0.25f;
		}
		
		void SetOccupancy(const glm::ivec3& a, const glm::ivec3& b) {
			position.x = uint16_t(glm::clamp(glm::min(a.x, b.x), 0, 11));
			position.y = uint16_t(glm::clamp(glm::min(a.y, b.y), 0, 11));
			position.z = uint16_t(glm::clamp(glm::min(a.z, b.z), 0, 11));
			size_x = uint16_t(glm::clamp(glm::max(a.x, b.x) - position.x, 0, 11 - position.x));
			size_y = uint16_t(glm::clamp(glm::max(a.y, b.y) - position.y, 0, 11 - position.y));
			size_z = uint16_t(glm::clamp(glm::max(a.z, b.z) - position.z, 0, 11 - position.z));
		}
		
		bool IsDifferentShapeOrSize (const Block& other) const {
			return type != other.type || id != other.id || size_x != other.size_x || size_y != other.size_y || size_z != other.size_z;
		}
		
		bool IsSameShapeAndSize (const Block& other) const {
			return !IsDifferentShapeOrSize(other);
		}
		
		bool IsDifferent (const Block& other) const {
			return IsDifferentShapeOrSize(other) || damage != other.damage || dirt != other.dirt || extra != other.extra || composition != other.composition || memcmp(color, other.color, sizeof(color)) != 0;
		}
		
	#else
		uint32_t data;
		// damage = float(data&0x3F)/63.0
		// dirt = float((data>>6)&0x3)/3.0
		// extra = float((data>>8)&0xf)/15.0
		uint16_t id;
	#endif
	
	// 2 bytes (16 bits)
	aligned_uint16_t temperature; // 0.0 to 6'553.5 kelvin with a precision of 0.1 degrees
};
STATIC_ASSERT_ALIGNED16_SIZE(Block, 16)
