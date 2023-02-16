#ifdef __cplusplus
	#pragma once
#endif

#ifdef GLSL
	#extension GL_ARB_shader_clock : enable
	#extension GL_EXT_ray_tracing : require
	#extension GL_EXT_buffer_reference2 : require
#endif

#include "game/graphics/common.inc.glsl"
#include "game/graphics/voxel.inc.glsl"

#define RAY_MAX_RECURSION 8

#define SET1_BINDING_TLAS 0
#define SET1_BINDING_LIGHTS_TLAS 1
#define SET1_BINDING_RENDERER_DATA 2
#define SET1_BINDING_RT_PAYLOAD_IMAGE 3
#define SET1_BINDING_PRIMARY_ALBEDO_ROUGHNESS_IMAGE 4
#define SET1_BINDING_POST_HISTORY_IMAGE 5

#define RENDERER_DEBUG_VIEWMODE_NONE 0
#define RENDERER_DEBUG_VIEWMODE_RAYGEN_TIME 1
#define RENDERER_DEBUG_VIEWMODE_RAYHIT_TIME 2
#define RENDERER_DEBUG_VIEWMODE_RAYINT_TIME 3
#define RENDERER_DEBUG_VIEWMODE_TRACE_RAY_COUNT 4
#define RENDERER_DEBUG_VIEWMODE_NORMALS 5
#define RENDERER_DEBUG_VIEWMODE_MOTION 6
#define RENDERER_DEBUG_VIEWMODE_DISTANCE 7
#define RENDERER_DEBUG_VIEWMODE_UVS 8
#define RENDERER_DEBUG_VIEWMODE_TRANSPARENCY 9
#define RENDERER_DEBUG_VIEWMODE_AIM_RENDERABLE 10
#define RENDERER_DEBUG_VIEWMODE_AIM_GEOMETRY 11
#define RENDERER_DEBUG_VIEWMODE_AIM_PRIMITIVE 12
#define RENDERER_DEBUG_VIEWMODE_SSAO 13
#define RENDERER_DEBUG_VIEWMODE_LIGHTS 14
#define RENDERER_DEBUG_VIEWMODE_GLOBAL_ILLUMINATION 15
#define RENDERER_DEBUG_VIEWMODE_DENOISING_FACTOR 16
#define RENDERER_DEBUG_VIEWMODE_TEST 17

#ifdef __cplusplus
	#define RENDERER_DEBUG_VIEWMODES_STR \
		"NONE",\
		"Ray Gen Time",\
		"Ray Hit Time",\
		"Ray Intersection Time",\
		"Ray Trace Count",\
		"Normals",\
		"Motion Vectors",\
		"Distance",\
		"UVs",\
		"Transparency",\
		"Aim Renderable",\
		"Aim Geometry",\
		"Aim Primitive",\
		"SSAO",\
		"Lights",\
		"Global Illumination",\
		"Denoising Factor",\
		"Test",\
		
#endif

////////////////////////////////////

#define RAYTRACE_MASK_TERRAIN 1u
#define RAYTRACE_MASK_ENTITY 2u
#define RAYTRACE_MASK_VOXEL 4u
#define RAYTRACE_MASK_ATMOSPHERE 8u
#define RAYTRACE_MASK_HYDROSPHERE 16u
#define RAYTRACE_MASK_CLUTTER 32u
#define RAYTRACE_MASK_PLASMA 64u
#define RAYTRACE_MASK_OVERLAY 128u

#ifdef __cplusplus
	inline static constexpr uint32_t RAYTRACE_MASKS[] {
		/*RENDERABLE_TYPE_TERRAIN_TRI*/		RAYTRACE_MASK_TERRAIN,
		/*RENDERABLE_TYPE_ENTITY_TRI*/		RAYTRACE_MASK_ENTITY,
		/*RENDERABLE_TYPE_ENTITY_BOX*/		RAYTRACE_MASK_ENTITY,
		/*RENDERABLE_TYPE_ENTITY_SPHERE*/	RAYTRACE_MASK_ENTITY,
		/*RENDERABLE_TYPE_ATMOSPHERE*/		RAYTRACE_MASK_ATMOSPHERE,
		/*RENDERABLE_TYPE_HYDROSPHERE*/		RAYTRACE_MASK_HYDROSPHERE,
		/*RENDERABLE_TYPE_VOXEL*/			RAYTRACE_MASK_VOXEL,
		/*RENDERABLE_TYPE_CLUTTER_TRI*/		RAYTRACE_MASK_CLUTTER,
		/*RENDERABLE_TYPE_PLASMA*/			RAYTRACE_MASK_PLASMA,
		/*RENDERABLE_TYPE_OVERLAY_TRI*/		RAYTRACE_MASK_OVERLAY,
		/*RENDERABLE_TYPE_OVERLAY_BOX*/		RAYTRACE_MASK_OVERLAY,
		/*RENDERABLE_TYPE_OVERLAY_SPHERE*/	RAYTRACE_MASK_OVERLAY,
	};
#endif

// Up to 32 options
#define RENDERER_OPTION_GLASS_REFLECTIONS	(1u<< 0 )
#define RENDERER_OPTION_WATER_REFLECTIONS	(1u<< 1 )
#define RENDERER_OPTION_WATER_TRANSPARENCY	(1u<< 2 )
#define RENDERER_OPTION_WATER_REFRACTION	(1u<< 3 )
#define RENDERER_OPTION_WATER_WAVES			(1u<< 4 )

BUFFER_REFERENCE_STRUCT(16) GlobalIllumination {
	aligned_f32vec4 radiance;
	aligned_int64_t frameIndex;
	aligned_uint32_t iteration;
	aligned_int32_t lock;
};
STATIC_ASSERT_ALIGNED16_SIZE(GlobalIllumination, 32);

BUFFER_REFERENCE_STRUCT_READONLY(16) TLASInstance {
	aligned_f32mat3x4 transform;
	aligned_uint32_t instanceCustomIndex_and_mask; // mask>>24, customIndex&0xffffff
	aligned_uint32_t instanceShaderBindingTableRecordOffset_and_flags; // flags>>24
	aligned_VkDeviceAddress accelerationStructureReference;
};
STATIC_ASSERT_ALIGNED16_SIZE(TLASInstance, 64)

BUFFER_REFERENCE_STRUCT_WRITEONLY(16) MVPBufferCurrent {aligned_f32mat4 mvp;};
BUFFER_REFERENCE_STRUCT_READONLY(16) MVPBufferHistory {aligned_f32mat4 mvp;};
BUFFER_REFERENCE_STRUCT_WRITEONLY(8) RealtimeBufferCurrent {aligned_uint64_t mvpFrameIndex;};
BUFFER_REFERENCE_STRUCT_READONLY(8) RealtimeBufferHistory {aligned_uint64_t mvpFrameIndex;};

BUFFER_REFERENCE_STRUCT_READONLY(8) LightSourceInstanceTable {
	BUFFER_REFERENCE_ADDR(LightSourceInstanceData) instance;
};

struct RendererData {
	aligned_f32mat4 viewMatrix;
	aligned_f32mat4 historyViewMatrix;
	aligned_f32mat4 reprojectionMatrix;
	BUFFER_REFERENCE_ADDR(MVPBufferCurrent) mvpBuffer;
	BUFFER_REFERENCE_ADDR(MVPBufferHistory) mvpBufferHistory;
	BUFFER_REFERENCE_ADDR(RealtimeBufferCurrent) realtimeBuffer;
	BUFFER_REFERENCE_ADDR(RealtimeBufferHistory) realtimeBufferHistory;
	BUFFER_REFERENCE_ADDR(RenderableInstanceData) renderableInstances;
	BUFFER_REFERENCE_ADDR(TLASInstance) tlasInstances;
	BUFFER_REFERENCE_ADDR(AimBuffer) aim;
	BUFFER_REFERENCE_ADDR(GlobalIllumination) globalIllumination;
	BUFFER_REFERENCE_ADDR(LightSourceInstanceTable) lightSources;
	aligned_float64_t timestamp;
	aligned_uint32_t giIteration;
	aligned_float32_t cameraZNear;
	aligned_float32_t globalLightingFactor;
	aligned_uint32_t options; // RENDERER_OPTION_*
	aligned_f32vec3 _unused1;
	aligned_float32_t warp;
	aligned_f32vec3 wireframeColor;
	aligned_float32_t wireframeThickness;
	aligned_i32vec3 worldOrigin;
	aligned_uint32_t globalIlluminationTableCount;
	aligned_uint16_t bluenoise_scalar;
	aligned_uint16_t bluenoise_unitvec1;
	aligned_uint16_t bluenoise_unitvec2;
	aligned_uint16_t bluenoise_unitvec3;
	aligned_uint16_t bluenoise_unitvec3_cosine;
	aligned_uint16_t bluenoise_vec1;
	aligned_uint16_t bluenoise_vec2;
	aligned_uint16_t bluenoise_vec3;
};
STATIC_ASSERT_ALIGNED16_SIZE(RendererData, 3*64 + 9*8 + 8 + 4*16 + 8*2);

#ifdef GLSL
	#define BLUE_NOISE_NB_TEXTURES 64
	#define INSTANCE renderer.renderableInstances[gl_InstanceID]
	#define GEOMETRY INSTANCE.geometries[gl_GeometryIndexEXT]
	#define AABB GEOMETRY.aabbs[gl_PrimitiveID]
	#define AABB_MIN vec3(AABB.aabb[0], AABB.aabb[1], AABB.aabb[2])
	#define AABB_MAX vec3(AABB.aabb[3], AABB.aabb[4], AABB.aabb[5])
	#define AABB_CENTER ((AABB_MIN + AABB_MAX) * 0.5)
	#define AABB_CENTER_INT ivec3(round(AABB_CENTER))
	#define MODELVIEW (renderer.viewMatrix * mat4(gl_ObjectToWorldEXT))
	#define MODEL2WORLDNORMAL inverse(transpose(mat3(gl_ObjectToWorldEXT)))
	#define MVP (xenonRendererData.config.projectionMatrix * MODELVIEW)
	#define MVP_AA (xenonRendererData.config.projectionMatrixWithTAA * MODELVIEW)
	#define MVP_HISTORY (xenonRendererData.config.projectionMatrix * MODELVIEW_HISTORY)
	#define COMPUTE_BOX_INTERSECTION \
		const vec3 _tbot = (AABB_MIN - gl_ObjectRayOriginEXT) / gl_ObjectRayDirectionEXT;\
		const vec3 _ttop = (AABB_MAX - gl_ObjectRayOriginEXT) / gl_ObjectRayDirectionEXT;\
		const vec3 _tmin = min(_ttop, _tbot);\
		const vec3 _tmax = max(_ttop, _tbot);\
		const float T1 = max(_tmin.x, max(_tmin.y, _tmin.z));\
		const float T2 = min(_tmax.x, min(_tmax.y, _tmax.z));
	#define RAY_STARTS_OUTSIDE_T1_T2 (gl_RayTminEXT <= T1 && T1 < gl_RayTmaxEXT && T2 > T1)
	#define RAY_STARTS_BETWEEN_T1_T2 (T1 <= gl_RayTminEXT && T2 >= gl_RayTminEXT)
	#define COORDS ivec2(gl_LaunchIDEXT.xy)
	#define WRITE_DEBUG_TIME {float elapsedTime = imageLoad(img_normal_or_debug, COORDS).a + float(clockARB() - startTime); imageStore(img_normal_or_debug, COORDS, vec4(0,0,0, elapsedTime));}
	#define DEBUG_RAY_INT_TIME {if (xenonRendererData.config.debugViewMode == RENDERER_DEBUG_VIEWMODE_RAYINT_TIME) WRITE_DEBUG_TIME}
	#define EPSILON 0.0001
	#define PI 3.141592654
	#define traceRayEXT {if (xenonRendererData.config.debugViewMode == RENDERER_DEBUG_VIEWMODE_TRACE_RAY_COUNT) imageStore(img_normal_or_debug, COORDS, imageLoad(img_normal_or_debug, COORDS) + uvec4(0,0,0,1));} traceRayEXT
	#define DEBUG_TEST(color) {if (xenonRendererData.config.debugViewMode == RENDERER_DEBUG_VIEWMODE_TEST) imageStore(img_normal_or_debug, COORDS, color);}
	#define RAY_RECURSIONS imageLoad(rtPayloadImage, COORDS).r
	#define RAY_RECURSION_PUSH imageStore(rtPayloadImage, COORDS, imageLoad(rtPayloadImage, COORDS) + u8vec4(1,0,0,0));
	#define RAY_RECURSION_POP imageStore(rtPayloadImage, COORDS, imageLoad(rtPayloadImage, COORDS) - u8vec4(1,0,0,0));
	#define RAY_IS_SHADOW (imageLoad(rtPayloadImage, COORDS).g > 0)
	#define RAY_SHADOW_PUSH imageStore(rtPayloadImage, COORDS, imageLoad(rtPayloadImage, COORDS) + u8vec4(0,1,0,0));
	#define RAY_SHADOW_POP imageStore(rtPayloadImage, COORDS, imageLoad(rtPayloadImage, COORDS) - u8vec4(0,1,0,0));
	#define RAY_IS_GI (imageLoad(rtPayloadImage, COORDS).b > 0)
	#define RAY_GI_PUSH imageStore(rtPayloadImage, COORDS, imageLoad(rtPayloadImage, COORDS) + u8vec4(0,0,1,0));
	#define RAY_GI_POP imageStore(rtPayloadImage, COORDS, imageLoad(rtPayloadImage, COORDS) - u8vec4(0,0,1,0));
	#define RAY_IS_UNDERWATER (imageLoad(rtPayloadImage, COORDS).a > 0)
	#define RAY_UNDERWATER_PUSH imageStore(rtPayloadImage, COORDS, imageLoad(rtPayloadImage, COORDS) + u8vec4(0,0,0,1));
	#define RAY_UNDERWATER_POP imageStore(rtPayloadImage, COORDS, imageLoad(rtPayloadImage, COORDS) - u8vec4(0,0,0,1));

	layout(set = 1, binding = SET1_BINDING_RENDERER_DATA) buffer RendererDataBuffer { RendererData renderer; };
	layout(set = 1, binding = SET1_BINDING_RT_PAYLOAD_IMAGE, rgba8ui) uniform uimage2D rtPayloadImage; // Recursions, Shadow, Gi, Underwater
	layout(set = 1, binding = SET1_BINDING_PRIMARY_ALBEDO_ROUGHNESS_IMAGE, rgba8) uniform image2D img_primary_albedo_roughness;
	layout(set = 1, binding = SET1_BINDING_POST_HISTORY_IMAGE, rgba8) uniform image2D img_post_history;
	
	layout(buffer_reference, std430, buffer_reference_align = 2) buffer readonly IndexBuffer16 {uint16_t indices[];};
	layout(buffer_reference, std430, buffer_reference_align = 4) buffer readonly IndexBuffer32 {uint32_t indices[];};
	layout(buffer_reference, std430, buffer_reference_align = 4) buffer readonly VertexBuffer {float vertices[];};
	layout(buffer_reference, std430, buffer_reference_align = 4) buffer readonly VertexColorU8 {u8vec4 colors[];};
	layout(buffer_reference, std430, buffer_reference_align = 8) buffer readonly VertexColorU16 {u16vec4 colors[];};
	layout(buffer_reference, std430, buffer_reference_align = 16) buffer readonly VertexColorF32 {f32vec4 colors[];};
	layout(buffer_reference, std430, buffer_reference_align = 4) buffer readonly VertexNormal {float normals[];};
	layout(buffer_reference, std430, buffer_reference_align = 8) buffer readonly VertexUV {vec2 uv[];};

	#define WORLD2VIEWNORMAL transpose(inverse(mat3(renderer.viewMatrix)))
	#define VIEW2WORLDNORMAL transpose(mat3(renderer.viewMatrix))
	
	vec3 ComputeSurfaceNormal(in uint instanceID, in uint geometryID, in uint primitiveID, in vec3 barycentricCoordsOrLocalPosition) {
		GeometryData geometry = renderer.renderableInstances[instanceID].geometries[geometryID];
		if (uint64_t(geometry.aabbs) != 0) {
			const vec3 aabb_min = vec3(geometry.aabbs[primitiveID].aabb[0], geometry.aabbs[primitiveID].aabb[1], geometry.aabbs[primitiveID].aabb[2]);
			const vec3 aabb_max = vec3(geometry.aabbs[primitiveID].aabb[3], geometry.aabbs[primitiveID].aabb[4], geometry.aabbs[primitiveID].aabb[5]);
			const float THRESHOLD = EPSILON ;// * ray.hitDistance;
			const vec3 absMin = abs(barycentricCoordsOrLocalPosition - aabb_min.xyz);
			const vec3 absMax = abs(barycentricCoordsOrLocalPosition - aabb_max.xyz);
				 if (absMin.x < THRESHOLD) return vec3(-1, 0, 0);
			else if (absMin.y < THRESHOLD) return vec3( 0,-1, 0);
			else if (absMin.z < THRESHOLD) return vec3( 0, 0,-1);
			else if (absMax.x < THRESHOLD) return vec3( 1, 0, 0);
			else if (absMax.y < THRESHOLD) return vec3( 0, 1, 0);
			else if (absMax.z < THRESHOLD) return vec3( 0, 0, 1);
			else return normalize(barycentricCoordsOrLocalPosition);
		}
		uint index0 = primitiveID * 3;
		uint index1 = primitiveID * 3 + 1;
		uint index2 = primitiveID * 3 + 2;
		if (geometry.indices16 != 0) {
			index0 = IndexBuffer16(geometry.indices16).indices[index0];
			index1 = IndexBuffer16(geometry.indices16).indices[index1];
			index2 = IndexBuffer16(geometry.indices16).indices[index2];
		} else if (geometry.indices32 != 0) {
			index0 = IndexBuffer32(geometry.indices32).indices[index0];
			index1 = IndexBuffer32(geometry.indices32).indices[index1];
			index2 = IndexBuffer32(geometry.indices32).indices[index2];
		}
		if (geometry.normals != 0) {
			VertexNormal vertexNormals = VertexNormal(geometry.normals);
			return normalize(
				+ vec3(vertexNormals.normals[index0*3], vertexNormals.normals[index0*3+1], vertexNormals.normals[index0*3+2]) * barycentricCoordsOrLocalPosition.x
				+ vec3(vertexNormals.normals[index1*3], vertexNormals.normals[index1*3+1], vertexNormals.normals[index1*3+2]) * barycentricCoordsOrLocalPosition.y
				+ vec3(vertexNormals.normals[index2*3], vertexNormals.normals[index2*3+1], vertexNormals.normals[index2*3+2]) * barycentricCoordsOrLocalPosition.z
			);
		} else if (geometry.vertices != 0) {
			VertexBuffer vertexBuffer = VertexBuffer(geometry.vertices);
			vec3 v0 = vec3(vertexBuffer.vertices[index0*3], vertexBuffer.vertices[index0*3+1], vertexBuffer.vertices[index0*3+2]);
			vec3 v1 = vec3(vertexBuffer.vertices[index1*3], vertexBuffer.vertices[index1*3+1], vertexBuffer.vertices[index1*3+2]);
			vec3 v2 = vec3(vertexBuffer.vertices[index2*3], vertexBuffer.vertices[index2*3+1], vertexBuffer.vertices[index2*3+2]);
			return normalize(cross(v1 - v0, v2 - v0));
		} else {
			return normalize(barycentricCoordsOrLocalPosition);
		}
	}
	vec4 ComputeSurfaceColor(uint instanceID, uint geometryID, uint primitiveID, in vec3 barycentricCoordsOrLocalPosition) {
		GeometryData geometry = renderer.renderableInstances[instanceID].geometries[geometryID];
		if (geometry.colors_u8 != 0) {
			VertexColorU8 vertexColors = VertexColorU8(geometry.colors_u8);
			if (uint64_t(geometry.aabbs) != 0) {
				return clamp(vec4(vertexColors.colors[primitiveID]) / 255.0, vec4(0), vec4(1));
			}
			uint index0 = primitiveID * 3;
			uint index1 = primitiveID * 3 + 1;
			uint index2 = primitiveID * 3 + 2;
			if (geometry.indices16 != 0) {
				index0 = IndexBuffer16(geometry.indices16).indices[index0];
				index1 = IndexBuffer16(geometry.indices16).indices[index1];
				index2 = IndexBuffer16(geometry.indices16).indices[index2];
			} else if (geometry.indices32 != 0) {
				index0 = IndexBuffer32(geometry.indices32).indices[index0];
				index1 = IndexBuffer32(geometry.indices32).indices[index1];
				index2 = IndexBuffer32(geometry.indices32).indices[index2];
			}
			return clamp(
				+ vec4(vertexColors.colors[index0]) / 255.0 * barycentricCoordsOrLocalPosition.x
				+ vec4(vertexColors.colors[index1]) / 255.0 * barycentricCoordsOrLocalPosition.y
				+ vec4(vertexColors.colors[index2]) / 255.0 * barycentricCoordsOrLocalPosition.z
			, vec4(0), vec4(1));
		} else if (geometry.colors_u16 != 0) {
			VertexColorU16 vertexColors = VertexColorU16(geometry.colors_u16);
			if (uint64_t(geometry.aabbs) != 0) {
				return clamp(vec4(vertexColors.colors[primitiveID]) / 65535.0, vec4(0), vec4(1));
			}
			uint index0 = primitiveID * 3;
			uint index1 = primitiveID * 3 + 1;
			uint index2 = primitiveID * 3 + 2;
			if (geometry.indices16 != 0) {
				index0 = IndexBuffer16(geometry.indices16).indices[index0];
				index1 = IndexBuffer16(geometry.indices16).indices[index1];
				index2 = IndexBuffer16(geometry.indices16).indices[index2];
			} else if (geometry.indices32 != 0) {
				index0 = IndexBuffer32(geometry.indices32).indices[index0];
				index1 = IndexBuffer32(geometry.indices32).indices[index1];
				index2 = IndexBuffer32(geometry.indices32).indices[index2];
			}
			return clamp(
				+ vec4(vertexColors.colors[index0]) / 65535.0 * barycentricCoordsOrLocalPosition.x
				+ vec4(vertexColors.colors[index1]) / 65535.0 * barycentricCoordsOrLocalPosition.y
				+ vec4(vertexColors.colors[index2]) / 65535.0 * barycentricCoordsOrLocalPosition.z
			, vec4(0), vec4(1));
		} else if (geometry.colors_f32 != 0) {
			VertexColorF32 vertexColors = VertexColorF32(geometry.colors_f32);
			if (uint64_t(geometry.aabbs) != 0) {
				return clamp(vertexColors.colors[primitiveID], vec4(0), vec4(1));
			}
			uint index0 = primitiveID * 3;
			uint index1 = primitiveID * 3 + 1;
			uint index2 = primitiveID * 3 + 2;
			if (geometry.indices16 != 0) {
				index0 = IndexBuffer16(geometry.indices16).indices[index0];
				index1 = IndexBuffer16(geometry.indices16).indices[index1];
				index2 = IndexBuffer16(geometry.indices16).indices[index2];
			} else if (geometry.indices32 != 0) {
				index0 = IndexBuffer32(geometry.indices32).indices[index0];
				index1 = IndexBuffer32(geometry.indices32).indices[index1];
				index2 = IndexBuffer32(geometry.indices32).indices[index2];
			}
			return clamp(
				+ vertexColors.colors[index0] * barycentricCoordsOrLocalPosition.x
				+ vertexColors.colors[index1] * barycentricCoordsOrLocalPosition.y
				+ vertexColors.colors[index2] * barycentricCoordsOrLocalPosition.z
			, vec4(0), vec4(1));
		} else {
			return vec4(1);
		}
	}
	vec2 ComputeSurfaceUV1(uint instanceID, uint geometryID, uint primitiveID, in vec3 barycentricCoordsOrLocalPosition) {
		GeometryData geometry = renderer.renderableInstances[instanceID].geometries[geometryID];
		if (uint64_t(geometry.aabbs) != 0) {
			return vec2(0);
		}
		uint index0 = primitiveID * 3;
		uint index1 = primitiveID * 3 + 1;
		uint index2 = primitiveID * 3 + 2;
		if (geometry.indices16 != 0) {
			index0 = IndexBuffer16(geometry.indices16).indices[index0];
			index1 = IndexBuffer16(geometry.indices16).indices[index1];
			index2 = IndexBuffer16(geometry.indices16).indices[index2];
		} else if (geometry.indices32 != 0) {
			index0 = IndexBuffer32(geometry.indices32).indices[index0];
			index1 = IndexBuffer32(geometry.indices32).indices[index1];
			index2 = IndexBuffer32(geometry.indices32).indices[index2];
		}
		if (geometry.info.uv1 != 0) {
			VertexUV vertexUV = VertexUV(geometry.info.uv1);
			return (
				+ vertexUV.uv[index0] * barycentricCoordsOrLocalPosition.x
				+ vertexUV.uv[index1] * barycentricCoordsOrLocalPosition.y
				+ vertexUV.uv[index2] * barycentricCoordsOrLocalPosition.z
			);
		} else {
			return vec2(0);
		}
	}
	vec2 ComputeSurfaceUV2(uint instanceID, uint geometryID, uint primitiveID, in vec3 barycentricCoordsOrLocalPosition) {
		GeometryData geometry = renderer.renderableInstances[instanceID].geometries[geometryID];
		if (uint64_t(geometry.aabbs) != 0) {
			return vec2(0);
		}
		uint index0 = primitiveID * 3;
		uint index1 = primitiveID * 3 + 1;
		uint index2 = primitiveID * 3 + 2;
		if (geometry.indices16 != 0) {
			index0 = IndexBuffer16(geometry.indices16).indices[index0];
			index1 = IndexBuffer16(geometry.indices16).indices[index1];
			index2 = IndexBuffer16(geometry.indices16).indices[index2];
		} else if (geometry.indices32 != 0) {
			index0 = IndexBuffer32(geometry.indices32).indices[index0];
			index1 = IndexBuffer32(geometry.indices32).indices[index1];
			index2 = IndexBuffer32(geometry.indices32).indices[index2];
		}
		if (geometry.info.uv2 != 0) {
			VertexUV vertexUV = VertexUV(geometry.info.uv2);
			return (
				+ vertexUV.uv[index0] * barycentricCoordsOrLocalPosition.x
				+ vertexUV.uv[index1] * barycentricCoordsOrLocalPosition.y
				+ vertexUV.uv[index2] * barycentricCoordsOrLocalPosition.z
			);
		} else {
			return vec2(0);
		}
	}
	#ifdef SHADER_RCHIT
		vec3 ComputeSurfaceNormal(in vec3 barycentricCoordsOrLocalPosition) {
			return ComputeSurfaceNormal(gl_InstanceID, gl_GeometryIndexEXT, gl_PrimitiveID, barycentricCoordsOrLocalPosition);
		}
		vec4 ComputeSurfaceColor(in vec3 barycentricCoordsOrLocalPosition) {
			return ComputeSurfaceColor(gl_InstanceID, gl_GeometryIndexEXT, gl_PrimitiveID, barycentricCoordsOrLocalPosition);
		}
		vec2 ComputeSurfaceUV1(in vec3 barycentricCoordsOrLocalPosition) {
			return ComputeSurfaceUV1(gl_InstanceID, gl_GeometryIndexEXT, gl_PrimitiveID, barycentricCoordsOrLocalPosition);
		}
		vec2 ComputeSurfaceUV2(in vec3 barycentricCoordsOrLocalPosition) {
			return ComputeSurfaceUV2(gl_InstanceID, gl_GeometryIndexEXT, gl_PrimitiveID, barycentricCoordsOrLocalPosition);
		}
	#endif
	
	struct RayPayload {
		vec4 color;
		vec3 normal;
		float ssao;
		vec3 localPosition;
		float t2;
		vec3 worldPosition;
		float hitDistance;
		int id;
		int renderableIndex;
		int geometryIndex;
		int primitiveIndex;
	};

	#if defined(SHADER_RGEN) || defined(SHADER_RCHIT)
		layout(set = 1, binding = SET1_BINDING_TLAS) uniform accelerationStructureEXT tlas;
		layout(set = 1, binding = SET1_BINDING_LIGHTS_TLAS) uniform accelerationStructureEXT tlas_lights;
	#endif

	#if defined(SHADER_RGEN) || defined(SHADER_RCHIT) || defined(SHADER_RAHIT) || defined(SHADER_RINT) || defined(SHADER_RMISS)
		uint64_t startTime = clockARB();
		uint stableSeed = InitRandomSeed(gl_LaunchIDEXT.x, gl_LaunchIDEXT.y);
		uint coherentSeed = InitRandomSeed(uint(xenonRendererData.frameIndex),0);
		uint seed = InitRandomSeed(stableSeed, coherentSeed);
	#endif
	
	#ifdef SHADER_RCHIT
		#extension GL_EXT_ray_query : require
		layout(location = 0) rayPayloadInEXT RayPayload ray;
	#endif

	#if defined(SHADER_RCHIT) || defined(SHADER_RAHIT) || defined(SHADER_RINT)
		bool IsValidVoxel(in ivec3 iPos, in vec3 gridOffset) {
			if (iPos.x < 0 || iPos.y < 0 || iPos.z < 0) return false;
			if (iPos.x >= VOXELS_X || iPos.y >= VOXELS_Y || iPos.z >= VOXELS_Z) return false;
			if (iPos.x < AABB_MIN.x - gridOffset.x) return false;
			if (iPos.y < AABB_MIN.y - gridOffset.y) return false;
			if (iPos.z < AABB_MIN.z - gridOffset.z) return false;
			if (iPos.x >= AABB_MAX.x - gridOffset.x) return false;
			if (iPos.y >= AABB_MAX.y - gridOffset.y) return false;
			if (iPos.z >= AABB_MAX.z - gridOffset.z) return false;
			return true;
		}
		bool IsValidVoxelHD(in ivec3 iPos) {
			if (iPos.x < 0 || iPos.y < 0 || iPos.z < 0) return false;
			if (iPos.x >= VOXEL_GRID_SIZE_HD || iPos.y >= VOXEL_GRID_SIZE_HD || iPos.z >= VOXEL_GRID_SIZE_HD) return false;
			return true;
		}
		const vec3[7] BOX_NORMAL_DIRS = {
			vec3(-1,0,0),
			vec3(0,-1,0),
			vec3(0,0,-1),
			vec3(+1,0,0),
			vec3(0,+1,0),
			vec3(0,0,+1),
			vec3(0)
		};
	#endif
#endif
