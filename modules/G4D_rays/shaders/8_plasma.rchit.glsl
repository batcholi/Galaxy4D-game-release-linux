#define SHADER_RCHIT
#include "common.inc.glsl"

float sdfLine(in vec3 p, in vec3 start, in vec3 end) {
	vec3 segmentVector = end - start;
	vec3 pointVector = p - start;
	float t = clamp(dot(pointVector, segmentVector) / dot(segmentVector, segmentVector), 0.0, 1.0);
	vec3 closestPoint = start + segmentVector * t;
	return length(closestPoint - p);
}

hitAttributeEXT hit {
	float t2;
};

float t1 = gl_HitTEXT;
float depth = PlasmaData(AABB.data).depth * (1.0 - RandomFloat(temporalSeed) * 0.1);
float radius = PlasmaData(AABB.data).radius;
float aerospikeEffect = 1; // 0 or 1

float density(vec3 pos) {
	float distToCenterLine = length(pos.xz);
	float aerospikeRadius = radius * max(mix(0, 0.8, aerospikeEffect), pow(1.0 - pos.y / depth, aerospikeEffect * 2));
	if (distToCenterLine < aerospikeRadius && pos.y > 0.0 && pos.y < depth) {
		float beginFactor = smoothstep(0, 0.0, pos.y / depth);
		float endFactor = 1.0 - pos.y / depth;
		float centerFactor = 1.0 - distToCenterLine / aerospikeRadius;
		return beginFactor * endFactor * centerFactor;
	}
	return 0;
}

void main() {
	float exaustDensity = PlasmaData(AABB.data).density;
	float exaustTemperature = PlasmaData(AABB.data).temperature;
	
	if (RAY_IS_GI || RAY_IS_SHADOW) {
		ray.hitDistance = t1;
		ray.t2 = t2;
		ray.aimID = gl_InstanceCustomIndexEXT;
		ray.renderableIndex = gl_InstanceID;
		ray.geometryIndex = gl_GeometryIndexEXT;
		ray.primitiveIndex = gl_PrimitiveID;
		ray.localPosition = gl_ObjectRayOriginEXT + gl_ObjectRayDirectionEXT * gl_HitTEXT;
		ray.worldPosition = gl_WorldRayOriginEXT + gl_WorldRayDirectionEXT * gl_HitTEXT;
		ray.ssao = 0;
		ray.color = vec4(0,0,0,1);
		ray.normal = vec3(0);
		ray.plasma.rgb = GetEmissionColor(exaustTemperature) * 0.5;
		ray.plasma.a = 0;
		return;
	}
	
	if (RAY_RECURSIONS + 2 < RAY_MAX_RECURSION) {
		RAY_RECURSION_PUSH
			traceRayEXT(tlas, gl_RayFlagsCullBackFacingTrianglesEXT, RAYTRACE_MASK_TERRAIN|RAYTRACE_MASK_ENTITY|RAYTRACE_MASK_ATMOSPHERE|RAYTRACE_MASK_HYDROSPHERE|RAYTRACE_MASK_CLUTTER|RAYTRACE_MASK_PLASMA, 0/*rayType*/, 0/*nbRayTypes*/, 0/*missIndex*/, gl_WorldRayOriginEXT, t1 + EPSILON * 0.1, gl_WorldRayDirectionEXT, xenonRendererData.config.zFar, 0);
		RAY_RECURSION_POP
	} else {
		ray.hitDistance = t1;
		ray.t2 = t2;
		ray.aimID = gl_InstanceCustomIndexEXT;
		ray.renderableIndex = gl_InstanceID;
		ray.geometryIndex = gl_GeometryIndexEXT;
		ray.primitiveIndex = gl_PrimitiveID;
		ray.localPosition = gl_ObjectRayOriginEXT + gl_ObjectRayDirectionEXT * gl_HitTEXT;
		ray.worldPosition = gl_WorldRayOriginEXT + gl_WorldRayDirectionEXT * gl_HitTEXT;
		ray.ssao = 0;
		ray.color = vec4(1,1,1,0);
		ray.normal = vec3(0);
	}
	
	const float stepSize = 0.005;
	const float maxDist = depth + radius;
	
	float t = 0.0;
	vec3 accumulatedLight = vec3(0);
	float accumulatedDensity = 0.0;
	
	uint thrusterSeed = temporalSeed + uint(gl_InstanceID);
	vec3 offset = RandomInUnitSphere(thrusterSeed) * radius * 0.1;
	
	for (int i = 0; i < 1000; ++i) {
		vec3 pos = gl_ObjectRayOriginEXT + gl_ObjectRayDirectionEXT * (t1 + t);
		pos += offset * pos.y / depth;
		float d = density(pos);
		accumulatedDensity += pow(d, 2.0) * exaustDensity * stepSize;
		accumulatedLight += GetEmissionColor(d * exaustTemperature) * stepSize;
		t += stepSize;
		if (t > maxDist) {
			break;
		}
	}
	
	accumulatedDensity = accumulatedDensity;
	ray.plasma.rgb += max(accumulatedLight, vec3(0.2,0.4,1.0) * accumulatedDensity);
	ray.plasma.a += accumulatedDensity;
	ray.ssao = clamp(ray.ssao - accumulatedDensity * 0.2, 0.0, 1.0);
	
	// Debug Time
	if (xenonRendererData.config.debugViewMode == RENDERER_DEBUG_VIEWMODE_RAYHIT_TIME) {
		if (RAY_RECURSIONS == 0) WRITE_DEBUG_TIME
	}
}
