#ifdef __cplusplus
	#pragma once
#endif

#include "xenon/renderer/shaders/common.inc.glsl"

#define RENDERABLE_TYPE_TERRAIN_TRI 0
#define RENDERABLE_TYPE_ENTITY_TRI 1
#define RENDERABLE_TYPE_ENTITY_BOX 2
#define RENDERABLE_TYPE_ENTITY_SPHERE 3
#define RENDERABLE_TYPE_ATMOSPHERE 4
#define RENDERABLE_TYPE_HYDROSPHERE 5
#define RENDERABLE_TYPE_VOXEL 6
#define RENDERABLE_TYPE_CLUTTER_TRI 7
#define RENDERABLE_TYPE_PLASMA 8
#define RENDERABLE_TYPE_OVERLAY_TRI 9
#define RENDERABLE_TYPE_OVERLAY_BOX 10
#define RENDERABLE_TYPE_OVERLAY_SPHERE 11

#define SURFACE_CALLABLE_PAYLOAD 0
#define VOXEL_SURFACE_CALLABLE_PAYLOAD 1

#define LIGHT_LUMINOSITY_VISIBLE_THRESHOLD 0.05

BUFFER_REFERENCE_STRUCT_READONLY(16) AabbData {
	aligned_float32_t aabb[6];
	aligned_uint64_t data; // Arbitrary data defined per-shader
};
STATIC_ASSERT_ALIGNED16_SIZE(AabbData, 32)

struct SunData {
	vec3 position;
	float radius;
	vec3 color;
	float temperature;
};
STATIC_ASSERT_ALIGNED16_SIZE(SunData, 32)

BUFFER_REFERENCE_STRUCT_READONLY(16) RenderableData {
	aligned_f32vec3 emission; // always added to output color
	aligned_float32_t colorMix; // 0 means don't use this color, 1 means use this color fully, values between (0-1) means mix between material's color and this custom color
	aligned_f32vec4 color;
	aligned_float32_t pbrMix;
	aligned_float32_t pbrMetallic;
	aligned_float32_t pbrRoughness;
	aligned_float32_t _unused; // reserved for future use
	aligned_f32vec4 customVec4Data; // unused in game, reserved for modules
};
STATIC_ASSERT_ALIGNED16_SIZE(RenderableData, 64)

BUFFER_REFERENCE_STRUCT_READONLY(16) LightSourceInstanceData {
	aligned_float32_t aabb[6];
	aligned_float32_t power; // in watts
	aligned_float32_t maxDistance; // dynamically updated (along with aabb) depending on set power
	aligned_f32vec3 color; // components individually normalized between 0 and 1
	aligned_float32_t innerRadius;
	aligned_f32vec3 direction; // oriented in object space, for spot lights only (must have a non-zero angle set below)
	aligned_float32_t angle; // in radians, used for spotlights only, otherwise set to 0 for a point/sphere light
};
STATIC_ASSERT_ALIGNED16_SIZE(LightSourceInstanceData, 64)

BUFFER_REFERENCE_STRUCT_READONLY(16) AtmosphereData {
	aligned_f32vec4 rayleigh;
	aligned_f32vec4 mie;
	aligned_float32_t innerRadius;
	aligned_float32_t outerRadius;
	aligned_float32_t g;
	aligned_float32_t temperature;
	aligned_f32vec3 _unused;
	aligned_int32_t nbSuns;
	SunData suns[2];
};
STATIC_ASSERT_ALIGNED16_SIZE(AtmosphereData, 128)

BUFFER_REFERENCE_STRUCT_READONLY(16) WaterData {
	aligned_f64vec3 center;
	aligned_float64_t radius;
};
STATIC_ASSERT_ALIGNED16_SIZE(WaterData, 32)

struct GeometryInfo {
	aligned_f32vec4 color;
	aligned_f32vec3 emission;
	aligned_uint32_t surfaceIndex;
	aligned_uint64_t data;
	aligned_float32_t metallic;
	aligned_float32_t roughness;
	aligned_VkDeviceAddress uv1;
	aligned_VkDeviceAddress uv2;
};
STATIC_ASSERT_ALIGNED16_SIZE(GeometryInfo, 64)

BUFFER_REFERENCE_STRUCT_READONLY(16) GeometryData {
	BUFFER_REFERENCE_ADDR(AabbData) aabbs;
	aligned_VkDeviceAddress vertices;
	aligned_VkDeviceAddress indices16;
	aligned_VkDeviceAddress indices32;
	aligned_VkDeviceAddress normals;
	aligned_VkDeviceAddress colors_u8;
	aligned_VkDeviceAddress colors_u16;
	aligned_VkDeviceAddress colors_f32;
	GeometryInfo info;
};
STATIC_ASSERT_ALIGNED16_SIZE(GeometryData, 128)

BUFFER_REFERENCE_STRUCT_READONLY(16) RenderableInstanceData {
	BUFFER_REFERENCE_ADDR(GeometryData) geometries;
	aligned_uint64_t data; // custom data defined per-shader
};
STATIC_ASSERT_ALIGNED16_SIZE(RenderableInstanceData, 16)

BUFFER_REFERENCE_STRUCT(16) AimBuffer {
	aligned_f32vec3 localPosition;
	aligned_uint32_t aimID;
	aligned_f32vec3 worldSpaceHitNormal;
	aligned_uint32_t primitiveIndex;
	aligned_f32vec3 worldSpacePosition; // MUST COMPENSATE FOR ORIGIN RESET
	aligned_float32_t hitDistance;
	aligned_f32vec4 color;
	aligned_f32vec3 viewSpaceHitNormal;
	aligned_uint32_t tlasInstanceIndex;
	aligned_f32vec3 _unused;
	aligned_uint32_t geometryIndex;
};
STATIC_ASSERT_ALIGNED16_SIZE(AimBuffer, 96)

#ifdef GLSL
	struct Surface {
		vec4 color;
		vec3 normal;
		float metallic;
		vec3 emission;
		float roughness;
		vec3 localPosition;
		float ior;
		GeometryInfo geometryInfo;
		uint64_t renderableData;
		uint64_t aabbData;
		uint32_t renderableIndex;
		uint32_t geometryIndex;
		uint32_t primitiveIndex;
		uint32_t aimID;
		vec2 uv1;
		vec2 uv2;
		float distance;
	};
	#if defined(SHADER_RCHIT)
		layout(location = SURFACE_CALLABLE_PAYLOAD) callableDataEXT Surface surface;
	#endif
	#if defined(SHADER_SURFACE)
		layout(location = SURFACE_CALLABLE_PAYLOAD) callableDataInEXT Surface surface;
	#endif
	
#endif

#ifdef __cplusplus
namespace {
#endif

float STEFAN_BOLTZMANN_CONSTANT = 5.670374419184429E-8f;
float GetSunRadiationAtDistanceSqr(float temperature, float radius, float distanceSqr) {
	return radius*radius * STEFAN_BOLTZMANN_CONSTANT * pow(temperature, 4.0f) / distanceSqr;
}
float GetRadiationAtTemperatureForWavelength(float temperature_kelvin, float wavelength_nm) {
	float hcltkb = 14387769.6f / (wavelength_nm * temperature_kelvin);
	float w = wavelength_nm / 1000.0f;
	return 119104.2868f / (w * w * w * w * w * (exp(hcltkb) - 1.0f));
}
vec3 GetEmissionColor(float temperatureKelvin) {
	return vec3(
		GetRadiationAtTemperatureForWavelength(temperatureKelvin, 680.0f),
		GetRadiationAtTemperatureForWavelength(temperatureKelvin, 550.0f),
		GetRadiationAtTemperatureForWavelength(temperatureKelvin, 440.0f)
	);
}
vec3 GetEmissionColor(vec4 emission_temperature) {
	return vec3(emission_temperature.r, emission_temperature.g, emission_temperature.b) + GetEmissionColor(emission_temperature.a);
}

#ifdef __cplusplus
}
#endif
