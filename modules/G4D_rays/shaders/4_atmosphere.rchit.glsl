#define SHADER_RCHIT
#define SHADER_ATMOSPHERE
#include "common.inc.glsl"
#include "lighting.inc.glsl"

// https://www.alanzucconi.com/2017/10/10/atmospheric-scattering-1/

const int RAYMARCH_STEPS = 48; // low=16, medium=24, high=48, ultra=64
const int RAYMARCH_LIGHT_STEPS = 5; // low=2, medium=3, high=5, ultra=8
const float sunLuminosityThreshold = LIGHT_LUMINOSITY_VISIBLE_THRESHOLD;

// #define SUN_SHAFTS

bool RaySphereIntersection(in vec3 position, in vec3 rayDir, in float radius, out float t1, out float t2) {
	const vec3 p = -position; // equivalent to cameraPosition - spherePosition (or negative position of sphere in view space)
	const float a = dot(rayDir, rayDir);
	const float b = dot(p, rayDir);
	const float c = dot(p, p) - radius*radius;
	const float discriminant = b * b - a * c;
	if (discriminant < 0) return false;
	const float det = sqrt(discriminant);
	t1 = (-b - det) / a;
	t2 = (-b + det) / a;
	bool inside = t1 < 0 && t2 > 0;
	bool outside = t1 > 0 && t1 < t2;
	return inside || outside;
}

hitAttributeEXT hit {
	float intersectionT2;
};

void main() {
	bool rayIsShadow = RAY_IS_SHADOW;
	bool rayIsGi = RAY_IS_GI;
	uint recursions = RAY_RECURSIONS;
	
	ray.hitDistance = -1;
	ray.color = vec4(0);
	
	AtmosphereData atmosphere = AtmosphereData(AABB.data);
	vec4 rayleigh = atmosphere.rayleigh;
	vec4 mie = atmosphere.mie;
	float outerRadius = atmosphere.outerRadius;
	float innerRadius = atmosphere.innerRadius - 1000;
	float g = atmosphere.g;
	float temperature = atmosphere.temperature;
	
	vec3 atmospherePosition = gl_ObjectToWorldEXT[3].xyz;
	vec3 origin = gl_WorldRayOriginEXT;
	vec3 viewDir = gl_WorldRayDirectionEXT;
	float t1 = gl_HitTEXT;
	float t2 = intersectionT2;
	
	float startAltitude = distance(origin, atmospherePosition);
	float thickness = outerRadius - innerRadius;
	
	float inner_t1, inner_t2;
	bool hitInnerRadius = RaySphereIntersection(atmospherePosition, viewDir, innerRadius, inner_t1, inner_t2);
	if (hitInnerRadius && inner_t1 > 0) {
		t2 = mix(inner_t1, t2, clamp((innerRadius - startAltitude) / thickness, 0,1));
	}
	
	float nextHitDistance = xenonRendererData.config.zFar;
	if (recursions < RAY_MAX_RECURSION && !rayIsGi) {
		RAY_RECURSION_PUSH
			traceRayEXT(tlas, 0, ~(RAYTRACE_MASK_ATMOSPHERE), 0/*rayType*/, 0/*nbRayTypes*/, 0/*missIndex*/, origin, t1, viewDir, t2, 0);
			if (ray.hitDistance == -1 && !hitInnerRadius) {
				traceRayEXT(tlas, 0, 0xff, 0/*rayType*/, 0/*nbRayTypes*/, 0/*missIndex*/, origin, t2 * 1.0001, viewDir, xenonRendererData.config.zFar, 0);
			}
			if (ray.hitDistance != -1) {
				nextHitDistance = ray.hitDistance;
			}
		RAY_RECURSION_POP
	}
	
	const vec2 scaleHeight = vec2(rayleigh.a, mie.a);
	
	// Ray-marching configuration
	bool hasHitSomethingWithinAtmosphere = nextHitDistance < t2;
	const vec3 startPoint = origin + viewDir * t1;
	const float rayStartAltitude = length(startPoint - atmospherePosition);
	vec3 endPoint = origin + viewDir * min(nextHitDistance, t2);
	float rayDepth = distance(startPoint, endPoint);
	float stepSize = rayDepth / float(RAYMARCH_STEPS);
	
	if (hasHitSomethingWithinAtmosphere) {
		g = 0.0;
	}
	
	// Start Ray-Marching in the atmosphere!
	vec3 rayleighScattering = vec3(0);
	vec3 mieScattering = vec3(0);
	float maxDepth = 0;
	if (atmosphere.nbSuns > 0) {
		for (int sunIndex = 0; sunIndex < atmosphere.nbSuns; ++sunIndex) {
			SunData sun = atmosphere.suns[sunIndex];
			vec3 relativeSunPosition = sun.position - atmospherePosition;
			vec3 lightIntensity = sun.color * GetSunRadiationAtDistanceSqr(sun.temperature, sun.radius, dot(relativeSunPosition, relativeSunPosition)) * 4.0;
			if (length(lightIntensity) > sunLuminosityThreshold) {
				vec3 lightDir = normalize(relativeSunPosition);
				
				// Cache some values related to that light before raymarching in the atmosphere
				float mu = dot(viewDir, -lightDir);
				float mumu = mu * mu;
				float gg = g*g;
				float rayleighPhase = 3.0 / (50.2654824574 /* (16 * pi) */) * (1.0 + mumu);
				float miePhase = 3.0 / (25.1327412287 /* (8 * pi) */) * ((1.0 - gg) * (mumu + 1.0)) / (pow(1.0 + gg - 2.0 * mu * g, 1.5) * (2.0 + gg));
				
				// Init accumulation variables
				vec2 opticalDepth = vec2(0);

				// Ray-March
				vec3 rayPos = startPoint;
				for (int i = 0; i < RAYMARCH_STEPS; ++i) {
					rayPos += viewDir * stepSize;
					vec3 posOnSphere = rayPos - atmospherePosition;
					float rayAltitude = length(posOnSphere);
					float rayAltitudeAboveInnerRadius = rayAltitude - innerRadius;
					vec2 density = exp(-rayAltitudeAboveInnerRadius / scaleHeight) * stepSize;
					opticalDepth += density;
					maxDepth = max(maxDepth, outerRadius - rayAltitude);
					
					// step size for light ray
					float a = dot(lightDir, lightDir);
					float b = 2.0 * dot(lightDir, posOnSphere);
					float c = dot(posOnSphere, posOnSphere) - (outerRadius * outerRadius);
					float d = (b * b) - 4.0 * a * c;
					float lightRayStepSize = (-b + sqrt(d)) / (2.0 * a * float(RAYMARCH_LIGHT_STEPS));
					
					// RayMarch towards light source
					vec2 lightRayOpticalDepth = vec2(0);
					float lightRayDist = 0;
					for (int l = 0; l < RAYMARCH_LIGHT_STEPS; ++l) {
						vec3 posLightRay = posOnSphere + lightDir * (lightRayDist + lightRayStepSize/2.0);
						float lightRayAltitude = length(posLightRay) - innerRadius;
						vec2 lightRayDensity = exp(-lightRayAltitude / scaleHeight) * lightRayStepSize;
						
						lightRayOpticalDepth += lightRayDensity;
						lightRayDist += lightRayStepSize;
					}
					
					vec3 attenuationRayleigh = exp(-rayleigh.rgb * (opticalDepth.x + lightRayOpticalDepth.x));
					vec3 attenuationMie = exp(-mie.rgb * (opticalDepth.y + lightRayOpticalDepth.y));
					rayleighScattering += max(vec3(0),
						+ rayleigh.rgb * attenuationRayleigh * max(0, density.x * rayleighPhase) * lightIntensity
					);
					mieScattering += max(vec3(0),
						+ mie.rgb * attenuationMie * max(0, density.y * miePhase) * lightIntensity
					);
				}
			}
		}
	} else {
		// Ray-March
		vec3 rayPos = startPoint;
		for (int i = 0; i < RAYMARCH_STEPS; ++i) {
			rayPos += viewDir * stepSize;
			vec3 posOnSphere = rayPos - atmospherePosition;
			float rayAltitude = length(posOnSphere);
			maxDepth = max(maxDepth, outerRadius - rayAltitude);
		}
	}
	
	vec4 fog = vec4(rayleighScattering + mieScattering + GetEmissionColor(temperature) * stepSize, pow(clamp(maxDepth/thickness, 0, 1), 2));
	
	// if (rayIsGi) {
	// 	// Desaturate GI
	// 	fog.rgb = mix(fog.rgb, vec3(length(fog.rgb)), 0.7);
	// }
	
	ray.color.rgb += fog.rgb * fog.a * renderer.globalLightingFactor;
	ray.color.a += pow(fog.a, 32);
	
	// Debug Time
	if (xenonRendererData.config.debugViewMode == RENDERER_DEBUG_VIEWMODE_RAYHIT_TIME) {
		if (recursions == 0) WRITE_DEBUG_TIME
	}
}
