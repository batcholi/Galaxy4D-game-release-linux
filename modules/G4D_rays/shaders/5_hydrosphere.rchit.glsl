#define SHADER_RCHIT
#define SHADER_WATER
#include "common.inc.glsl"

#define WATER_MAX_LIGHT_DEPTH 128
#define WATER_MAX_LIGHT_DEPTH_VERTICAL 256
#define WATER_IOR 1.33
#define WATER_OPACITY 0.1
#define WATER_TINT vec3(0.2,0.3,0.4)

hitAttributeEXT hit {
	float t1;
	float t2;
};

void SetHitWater() {
	ray.id = gl_InstanceCustomIndexEXT;
	ray.renderableIndex = gl_InstanceID;
	ray.geometryIndex = gl_GeometryIndexEXT;
	ray.primitiveIndex = gl_PrimitiveID;
	ray.localPosition = gl_ObjectRayOriginEXT + gl_ObjectRayDirectionEXT * gl_HitTEXT;
	ray.worldPosition = gl_WorldRayOriginEXT + gl_WorldRayDirectionEXT * gl_HitTEXT;
	ray.color.a = 1;
}

#define RAIN_DROP_HASHSCALE1 .1031
#define RAIN_DROP_HASHSCALE3 vec3(.1031, .1030, .0973)
#define RAIN_DROP_MAX_RADIUS 2
float hash12(vec2 p) {
	vec3 p3  = fract(vec3(p.xyx) * RAIN_DROP_HASHSCALE1);
	p3 += dot(p3, p3.yzx + 19.19);
	return fract((p3.x + p3.y) * p3.z);
}
vec2 hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * RAIN_DROP_HASHSCALE3);
	p3 += dot(p3, p3.yzx+19.19);
	return fract((p3.xx+p3.yz)*p3.zy);
}
float RainDrops(vec3 pos) {
	float t = float(renderer.timestamp);
	vec2 uv = pos.xz;
	vec2 p0 = floor(uv);
	vec2 circles = vec2(0.);
	for (int j = -RAIN_DROP_MAX_RADIUS; j <= RAIN_DROP_MAX_RADIUS; ++j) {
		for (int i = -RAIN_DROP_MAX_RADIUS; i <= RAIN_DROP_MAX_RADIUS; ++i) {
			vec2 pi = p0 + vec2(i, j);
			vec2 hsh = pi;
			vec2 p = pi + hash22(hsh);
			float t = fract(0.3*t + hash12(hsh));
			vec2 v = p - uv;
			float d = length(v) - (float(RAIN_DROP_MAX_RADIUS) + 1.)*t;
			float h = 1e-3;
			float d1 = d - h;
			float d2 = d + h;
			float p1 = sin(31.*d1) * smoothstep(-0.6, -0.3, d1) * smoothstep(0., -0.3, d1);
			float p2 = sin(31.*d2) * smoothstep(-0.6, -0.3, d2) * smoothstep(0., -0.3, d2);
			circles += 0.5 * normalize(v) * ((p2 - p1) / (2. * h) * (1. - t) * (1. - t));
		}
	}
	circles /= float((RAIN_DROP_MAX_RADIUS*2+1)*(RAIN_DROP_MAX_RADIUS*2+1));
	return dot(circles, circles);
}

const float smallWavesMaxDistance = 10;
const float mediumWavesMaxDistance = 100;
const float bigWavesMaxDistance = 500;
const float giantWavesMaxDistance = 100000;

float smallWavesStrength = smoothstep(smallWavesMaxDistance, 0, gl_HitTEXT);
float mediumWavesStrength = smoothstep(mediumWavesMaxDistance, 0, gl_HitTEXT) * (1-smallWavesStrength);
float bigWavesStrength = smoothstep(bigWavesMaxDistance, smallWavesMaxDistance, gl_HitTEXT) * (1-mediumWavesStrength);
float giantWavesStrength = smoothstep(giantWavesMaxDistance, bigWavesMaxDistance, gl_HitTEXT) * (1-bigWavesStrength);

float WaterWaves(vec3 pos) {
	return 0
		// + smallWavesStrength * RainDrops(pos)*4
		+ smallWavesStrength * Simplex(pos*5 + float(renderer.timestamp - pos.z)*2) * 0.1
		+ mediumWavesStrength * Simplex(pos*vec3(2,0.25, 0.5) + float(renderer.timestamp - pos.z)*0.5)
		+ bigWavesStrength * Simplex(pos*vec3(0.06, 0.01, 0.03) + float(renderer.timestamp - pos.z)*0.2) * 20
	;
}

// float GiantWaterWaves(vec3 pos) {
// 	return Simplex(vec3(pos * vec3(0.003, 0.0002, 0.0005)));
// }

void main() {
	uint recursions = RAY_RECURSIONS;
	ray.t2 = 0;
	ray.ssao = 0;
	ray.hitDistance = gl_HitTEXT;
	ray.normal = vec3(0,1,0);
	ray.color = vec4(vec3(0), 1);
	
	if (recursions >= RAY_MAX_RECURSION) {
		ray.id = -1;
		ray.renderableIndex = -1;
		return;
	}
	
	WaterData water = WaterData(AABB.data);
	if (uint64_t(water) == 0) return;
	
	bool rayIsGi = RAY_IS_GI;
	bool rayIsShadow = RAY_IS_SHADOW;
	vec3 worldPosition = gl_WorldRayOriginEXT + gl_WorldRayDirectionEXT * gl_HitTEXT;
	
	// Compute normal
	vec3 surfaceNormal; // in world space
	const vec3 spherePosition = vec3(water.center);// (AABB_MAX + AABB_MIN) / 2;
	const vec3 hitPoint1 = gl_ObjectRayOriginEXT + gl_ObjectRayDirectionEXT * t1;
	const vec3 hitPoint2 = gl_ObjectRayOriginEXT + gl_ObjectRayDirectionEXT * t2;
	if (gl_HitKindEXT == 0) {
		// Outside of sphere
		surfaceNormal = normalize(MODEL2WORLDNORMAL * normalize(hitPoint1 - spherePosition));
	} else if (gl_HitKindEXT == 1) {
		// Inside of sphere
		surfaceNormal = normalize(MODEL2WORLDNORMAL * normalize(spherePosition - hitPoint2));
	}
	
	const float waterWavesStrength = pow(0.5/*water.wavesStrength*/, 2);
	
	if (gl_HitKindEXT == 0) {
		// Above water
		
		vec3 reflection = vec3(0);
		vec3 refraction = vec3(0);
		
		if ((renderer.options & RENDERER_OPTION_WATER_WAVES) != 0 && waterWavesStrength > 0 && gl_HitTEXT < bigWavesMaxDistance) {
			vec3 wavesPosition = hitPoint1;
			APPLY_NORMAL_BUMP_NOISE(WaterWaves, wavesPosition, surfaceNormal, waterWavesStrength * 0.05)
		}
		float fresnel = Fresnel((renderer.viewMatrix * vec4(worldPosition, 1)).xyz, normalize(WORLD2VIEWNORMAL * surfaceNormal), WATER_IOR);
		
		// Reflection on top of water surface
		vec3 reflectDir = normalize(reflect(gl_WorldRayDirectionEXT, surfaceNormal));
		uint reflectionMask = ((renderer.options & RENDERER_OPTION_WATER_REFLECTIONS) != 0)? (~RAYTRACE_MASK_HYDROSPHERE) : RAYTRACE_MASK_ATMOSPHERE;
		RAY_RECURSION_PUSH
			RAY_GI_PUSH
				traceRayEXT(tlas, 0, reflectionMask, 0/*rayType*/, 0/*nbRayTypes*/, 0/*missIndex*/, worldPosition, 0, reflectDir, 10000, 0);
			RAY_GI_POP
		RAY_RECURSION_POP
		reflection = ray.color.rgb;
		
		// See through water (refraction)
		vec3 rayDirection = gl_WorldRayDirectionEXT;
		if ((renderer.options & RENDERER_OPTION_WATER_TRANSPARENCY) != 0) {
			if ((renderer.options & RENDERER_OPTION_WATER_REFRACTION) == 0 || Refract(rayDirection, surfaceNormal, WATER_IOR)) {
				RAY_RECURSION_PUSH
					RAY_UNDERWATER_PUSH
						ray.color = vec4(0);
						traceRayEXT(tlas, 0, ~(RAYTRACE_MASK_HYDROSPHERE), 0/*rayType*/, 0/*nbRayTypes*/, 0/*missIndex*/, worldPosition, xenonRendererData.config.zNear, rayDirection, WATER_MAX_LIGHT_DEPTH, 0);
					RAY_UNDERWATER_POP
				RAY_RECURSION_POP
				if (ray.hitDistance == -1) {
					ray.hitDistance = WATER_MAX_LIGHT_DEPTH;
					ray.color = vec4(0);
				}
				refraction = ray.color.rgb * WATER_TINT * (1-clamp(ray.hitDistance / WATER_MAX_LIGHT_DEPTH, 0, 1));
			}
		}
		
		ray.hitDistance = gl_HitTEXT;
		ray.t2 = WATER_MAX_LIGHT_DEPTH;
		ray.color.rgb = reflection * fresnel + refraction * (1-fresnel);
		ray.normal = surfaceNormal;
		
		// if (gl_HitTEXT < giantWavesMaxDistance) {
		// 	vec3 worldPositionGiantWaves = vec3(-renderer.worldOrigin) + gl_WorldRayOriginEXT + gl_WorldRayDirectionEXT * gl_HitTEXT;
		// 	ray.color.rgb += length(ray.color.rgb) * 0.033 * vec3(GiantWaterWaves(worldPositionGiantWaves)) * giantWavesStrength * 4;
		// }
		
		SetHitWater();
		
	} else {
		// Underwater
		vec3 downDir = normalize(spherePosition);
		float dotUp = dot(gl_WorldRayDirectionEXT, -downDir);
		float maxLightDepth = mix(WATER_MAX_LIGHT_DEPTH, WATER_MAX_LIGHT_DEPTH_VERTICAL, max(0, dotUp));
		
		if (dotUp > 0) {
			// Looking up towards surface

			float distanceToSurface = t2;
			vec3 wavePosition = gl_WorldRayOriginEXT + gl_WorldRayDirectionEXT * distanceToSurface;
			surfaceNormal = downDir;
			if ((renderer.options & RENDERER_OPTION_WATER_WAVES) != 0 && waterWavesStrength > 0) {
				APPLY_NORMAL_BUMP_NOISE(WaterWaves, wavePosition, surfaceNormal, waterWavesStrength * 0.05)
			}
			
			// See through water (underwater looking up, possibly at surface)
			vec3 rayPosition = gl_WorldRayOriginEXT;
			vec3 rayDirection = gl_WorldRayDirectionEXT;
			RAY_RECURSION_PUSH
				RAY_UNDERWATER_PUSH
					ray.color = vec4(0);
					traceRayEXT(tlas, 0, ~(RAYTRACE_MASK_HYDROSPHERE), 0/*rayType*/, 0/*nbRayTypes*/, 0/*missIndex*/, rayPosition, gl_RayTminEXT, rayDirection, distanceToSurface, 0);
				RAY_UNDERWATER_POP
			RAY_RECURSION_POP
			
			if (ray.hitDistance == -1) {
				// Surface refraction seen from underwater
				rayPosition += rayDirection * distanceToSurface;
				float maxRayDistance = xenonRendererData.config.zFar;
				if ((renderer.options & RENDERER_OPTION_WATER_TRANSPARENCY) != 0) {
					if (!Refract(rayDirection, surfaceNormal, 1.0 / WATER_IOR)) {
						maxRayDistance = maxLightDepth;
					}
					RAY_RECURSION_PUSH
						ray.color = vec4(0);
						if ((renderer.options & RENDERER_OPTION_WATER_REFLECTIONS) != 0) {
							traceRayEXT(tlas, 0, ~(RAYTRACE_MASK_HYDROSPHERE), 0/*rayType*/, 0/*nbRayTypes*/, 0/*missIndex*/, rayPosition, gl_RayTminEXT, rayDirection, maxRayDistance, 0);
						} else {
							RAY_GI_PUSH
								traceRayEXT(tlas, 0, RAYTRACE_MASK_ATMOSPHERE, 0/*rayType*/, 0/*nbRayTypes*/, 0/*missIndex*/, rayPosition, gl_RayTminEXT, rayDirection, maxRayDistance, 0);
							RAY_GI_POP
						}
					RAY_RECURSION_POP
				}
				if (maxRayDistance == maxLightDepth) {
					if (ray.hitDistance == -1) {
						ray.hitDistance = maxLightDepth;
					}
					ray.color.rgb *= pow(1.0 - clamp(ray.hitDistance / maxLightDepth, 0, 1), 2);
				}
				ray.hitDistance = distanceToSurface;
				ray.t2 = max(distanceToSurface, maxRayDistance);
				ray.normal = vec3(0,-1,0);
				SetHitWater();
				ray.renderableIndex = -1;
			}
			float falloff = pow(1.0 - clamp(ray.hitDistance / maxLightDepth, 0, 1), 2);
			ray.color.rgb *= falloff;
			
		} else {
			// See through water (underwater looking down)
			
			vec3 rayPosition = gl_WorldRayOriginEXT;
			vec3 rayDirection = gl_WorldRayDirectionEXT;
			RAY_RECURSION_PUSH
				RAY_UNDERWATER_PUSH
					ray.color = vec4(0);
					traceRayEXT(tlas, 0, ~(RAYTRACE_MASK_HYDROSPHERE), 0/*rayType*/, 0/*nbRayTypes*/, 0/*missIndex*/, rayPosition, gl_RayTminEXT, rayDirection, WATER_MAX_LIGHT_DEPTH, 0);
				RAY_UNDERWATER_POP
			RAY_RECURSION_POP
			if (ray.hitDistance == -1) {
				ray.hitDistance = maxLightDepth;
				ray.t2 = maxLightDepth;
				ray.color = vec4(0,0,0,1);
				ray.normal = vec3(0);
				SetHitWater();
			} else {
				float falloff = pow(1.0 - clamp(ray.hitDistance / maxLightDepth, 0, 1), 2);
				ray.color.rgb *= falloff;
			}
			
		}
		
		// Fog
		const vec3 origin = gl_WorldRayOriginEXT;
		const vec3 dir = gl_WorldRayDirectionEXT;
		const float distFactor = clamp(ray.hitDistance / maxLightDepth, 0 ,1);
		const float fogStrength = max(WATER_OPACITY, pow(distFactor, 0.25));
		ray.color.rgb = mix(ray.color.rgb * WATER_TINT, vec3(0), pow(clamp(ray.hitDistance / maxLightDepth, 0, 1), 0.5));
		
		RAY_UNDERWATER_PUSH
	}
	
	// Debug Time
	if (xenonRendererData.config.debugViewMode == RENDERER_DEBUG_VIEWMODE_RAYHIT_TIME) {
		if (recursions == 0) WRITE_DEBUG_TIME
	}
}

