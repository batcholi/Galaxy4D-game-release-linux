#define SHADER_RGEN
#include "common.inc.glsl"

layout(location = 0) rayPayloadEXT RayPayload ray;

void main() {
	const ivec2 pixelInMiddleOfScreen = ivec2(gl_LaunchSizeEXT.xy) / 2;
	const bool isMiddleOfScreen = (COORDS == pixelInMiddleOfScreen);
	const vec2 pixelCenter = vec2(gl_LaunchIDEXT.xy) + vec2(0.5);
	const vec2 screenSize = vec2(gl_LaunchSizeEXT.xy);
	const vec2 uv = pixelCenter/screenSize;
	const vec3 initialRayPosition = inverse(renderer.viewMatrix)[3].xyz;
	vec3 viewDir = normalize(vec4(inverse(mat4(xenonRendererData.config.projectionMatrixWithTAA)) * vec4(uv*2-1, 1, 1)).xyz);
	
	// Warp drive
	if (renderer.warp > 0) {
		const float centerFactor = length((pixelCenter/screenSize-0.5) * vec2(screenSize.x / screenSize.y, 1));
		viewDir.xy = mix(viewDir.xy, viewDir.xy * pow(clamp(centerFactor, 0.08, 1), 2) , renderer.warp);
	}
	
	vec3 initialRayDirection = normalize(VIEW2WORLDNORMAL * viewDir);
	
	imageStore(rtPayloadImage, COORDS, u8vec4(0));
	imageStore(img_primary_albedo_roughness, COORDS, u8vec4(0));
	if (xenonRendererData.config.debugViewMode != 0) {
		imageStore(img_normal_or_debug, COORDS, vec4(0));
	}
	
	ray.hitDistance = -1;
	ray.t2 = 0;
	ray.color = vec4(0);
	ray.ssao = 0;
	vec3 rayOrigin = initialRayPosition;
	float transparency = 1.0;
	do {
		traceRayEXT(tlas, 0/*flags*/, 0xff/*rayMask*/, 0/*rayType*/, 0/*nbRayTypes*/, 0/*missIndex*/, rayOrigin, renderer.cameraZNear, initialRayDirection, xenonRendererData.config.zFar, 0/*payloadIndex*/);
		rayOrigin += initialRayDirection * ray.hitDistance;
		ray.color.rgb *= clamp(transparency, 0.0, 1.0);
		transparency -= max(ray.color.a, 0.1);
	} while (ray.color.a < 1.0 && transparency > 0.1 && ray.hitDistance > 0.0 && ray.hitDistance < 200.0);
	vec4 color = ray.color;
	
	color.rgb *= pow(renderer.globalLightingFactor, 4);
	color.a = mix(1, color.a, renderer.globalLightingFactor);
	
	bool hitSomething = ray.hitDistance >= 0 && ray.renderableIndex != -1;
	vec3 motion;
	float depth;
	
	// Aim
	if (isMiddleOfScreen) {
		renderer.aim.localPosition = ray.localPosition;
		renderer.aim.geometryIndex = ray.geometryIndex;
		renderer.aim.aimID = ray.id;
		renderer.aim.worldSpaceHitNormal = ray.normal;
		renderer.aim.primitiveIndex = ray.primitiveIndex;
		renderer.aim.worldSpacePosition = ray.worldPosition;
		renderer.aim.hitDistance = ray.hitDistance;
		renderer.aim.color = ray.color;
		renderer.aim.viewSpaceHitNormal = normalize(WORLD2VIEWNORMAL * ray.normal);
		renderer.aim.tlasInstanceIndex = ray.renderableIndex;
	}
	
	// Motion Vectors
	if (hitSomething) {
		mat4 mvp = xenonRendererData.config.projectionMatrix * renderer.viewMatrix * mat4(transpose(renderer.tlasInstances[ray.renderableIndex].transform));
		
		// These two lines may cause problems on AMD if they didn't fix their bugs
		renderer.mvpBuffer[ray.renderableIndex].mvp = mvp;
		renderer.realtimeBuffer[ray.renderableIndex].mvpFrameIndex = xenonRendererData.frameIndex;
		
		vec4 ndc = mvp * vec4(ray.localPosition, 1);
		ndc /= ndc.w;
		mat4 mvpHistory;
		if (renderer.realtimeBufferHistory[ray.renderableIndex].mvpFrameIndex == xenonRendererData.frameIndex - 1) {
			mvpHistory = renderer.mvpBufferHistory[ray.renderableIndex].mvp;
		} else {
			mvpHistory = renderer.reprojectionMatrix * mvp;
		}
		vec4 ndc_history = mvpHistory * vec4(ray.localPosition, 1);
		ndc_history /= ndc_history.w;
		motion = ndc_history.xyz - ndc.xyz;
		vec4 clipSpace = mat4(xenonRendererData.config.projectionMatrixWithTAA) * mat4(renderer.viewMatrix) * vec4(ray.worldPosition, 1);
		depth = clamp(clipSpace.z / clipSpace.w, 0, 1);
	} else {
		vec4 ndc = vec4(uv * 2 - 1, 0, 1);
		vec4 ndc_history = renderer.reprojectionMatrix * ndc;
		ndc_history /= ndc_history.w;
		motion = ndc_history.xyz - ndc.xyz;
		depth = 0;
	}
	
	imageStore(img_composite, COORDS, max(vec4(0), color));
	imageStore(img_depth, COORDS, vec4(depth));
	imageStore(img_motion, COORDS, vec4(motion, 1));
	
	switch (xenonRendererData.config.debugViewMode) {
		default:
		case RENDERER_DEBUG_VIEWMODE_NONE:
		case RENDERER_DEBUG_VIEWMODE_SSAO:
		case RENDERER_DEBUG_VIEWMODE_DENOISING_FACTOR:
			imageStore(img_normal_or_debug, COORDS, vec4(ray.normal, ray.ssao));
			break;
		case RENDERER_DEBUG_VIEWMODE_NORMALS:
			// imageStore(img_normal_or_debug, COORDS, vec4(max(vec3(0), ray.normal), 1));
			imageStore(img_normal_or_debug, COORDS, vec4(normalize(WORLD2VIEWNORMAL * ray.normal), 1));
			break;
		case RENDERER_DEBUG_VIEWMODE_RAYGEN_TIME:
			WRITE_DEBUG_TIME
			// Fallthrough
		case RENDERER_DEBUG_VIEWMODE_RAYHIT_TIME:
		case RENDERER_DEBUG_VIEWMODE_RAYINT_TIME:
			imageStore(img_normal_or_debug, COORDS, vec4(Heatmap(float(imageLoad(img_normal_or_debug, COORDS).a / (1000000 * xenonRendererData.config.debugViewScale))), 1));
			break;
		case RENDERER_DEBUG_VIEWMODE_MOTION:
			imageStore(img_normal_or_debug, COORDS, vec4(abs(motion * 1000 * xenonRendererData.config.debugViewScale), 1));
			break;
		case RENDERER_DEBUG_VIEWMODE_DISTANCE:
			imageStore(img_normal_or_debug, COORDS, vec4(hitSomething? Heatmap(pow(ray.hitDistance / 1000 * xenonRendererData.config.debugViewScale, 0.4)) : vec3(0), 1));
			break;
		case RENDERER_DEBUG_VIEWMODE_REFLECTIVITY:
			// // imageStore(img_normal_or_debug, COORDS, vec4(Heatmap( 0 ), 1));
			break;
		case RENDERER_DEBUG_VIEWMODE_TRANSPARENCY:
			imageStore(img_normal_or_debug, COORDS, vec4(vec3(1 - ray.color.a), 1));
			break;
		case RENDERER_DEBUG_VIEWMODE_AIM_RENDERABLE:
			if (renderer.aim.tlasInstanceIndex == ray.renderableIndex) {
				imageStore(img_normal_or_debug, COORDS, vec4(1,0,1, 0.5));
			}
			break;
		case RENDERER_DEBUG_VIEWMODE_AIM_GEOMETRY: 
			if (renderer.aim.tlasInstanceIndex == ray.renderableIndex && renderer.aim.geometryIndex == ray.geometryIndex) {
				imageStore(img_normal_or_debug, COORDS, vec4(1,0,1, 0.5));
			}
			break;
		case RENDERER_DEBUG_VIEWMODE_AIM_PRIMITIVE:
			if (renderer.aim.tlasInstanceIndex == ray.renderableIndex && renderer.aim.geometryIndex == ray.geometryIndex && renderer.aim.primitiveIndex == ray.primitiveIndex) {
				imageStore(img_normal_or_debug, COORDS, vec4(1,0,1, 0.5));
			}
			break;
		case RENDERER_DEBUG_VIEWMODE_TRACE_RAY_COUNT:
			float nbRays = imageLoad(img_normal_or_debug, COORDS).a;
			imageStore(img_normal_or_debug, COORDS, vec4(nbRays > 0? Heatmap(xenonRendererData.config.debugViewScale * nbRays / 8) : vec3(0), 1));
			break;
		case RENDERER_DEBUG_VIEWMODE_GLOBAL_ILLUMINATION:
		case RENDERER_DEBUG_VIEWMODE_UVS:
		case RENDERER_DEBUG_VIEWMODE_LIGHTS:
		case RENDERER_DEBUG_VIEWMODE_TEST:
			break;
	}
}
