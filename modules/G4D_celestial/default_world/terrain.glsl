#include "xenon/renderer/shaders/perlint.glsl"

#define TERRAIN_UNIT_MULTIPLIER 1000
#define M *TERRAIN_UNIT_MULTIPLIER
#define KM *TERRAIN_UNIT_MULTIPLIER*1000

BUFFER_REFERENCE_STRUCT(4) CelestialConfig {
	aligned_float64_t baseRadiusMillimeters;
	aligned_float64_t heightVariationMillimeters;
	aligned_float32_t hydrosphere;
	aligned_float32_t continent_ratio;
};
#ifdef GLSL
	#define config CelestialConfig(celestial_configs) // from the push_constant
#else
	CelestialConfig config;
#endif

double _getPolarity(dvec3 normalizedPos) {
	return clamp(abs(dot(normalizedPos, dvec3(0,0,1))-0.2)-0.2, 0.0, 1.0);
}

double _moutainStep(double start, double end, double value) {
	if (value > start && value < end) return mix(start, value, smoothstep(start, end, value));
	if (value < start && value > end) return mix(start, value, smoothstep(start, end, value));
	return value;
}

double GetHeightMap(dvec3 normalizedPos) {
	u64vec3 pos = u64vec3(normalizedPos * config.baseRadiusMillimeters + 200000000000.0);
	uint64_t variation = uint64_t(config.heightVariationMillimeters);
	double variationf = double(variation);
	
	const uint64_t warpMaximum = 200 KM;
	const uint64_t warpStride = 400 KM;
	const uint warpOctaves = 3;
	const uint64_t continentStride = 2000 KM;
	
	u64vec3 warp = u64vec3(perlint64(pos + uint64_t(6546495), warpStride, warpMaximum, warpOctaves), perlint64(pos + uint64_t(516556), warpStride, warpMaximum, warpOctaves), perlint64(pos - uint64_t(897178), warpStride, warpMaximum, warpOctaves));
	double polarity = _getPolarity(normalizedPos);
	double continentsMax = slerp(perlint64f(pos + warp, continentStride, variation));
	double continentsMed = continentsMax * (slerp(perlint64f(pos + warp, continentStride/2, variation)));
	double continentsMin = continentsMed * (slerp(perlint64f(pos + uint64_t(86576949) + warp, continentStride/3, variation)));
	double continents = slerp(slerp(slerp(mix(mix(continentsMin, continentsMed, smoothstep(0.0, 0.5, double(config.continent_ratio))), mix(continentsMax, 0.7, smoothstep(0.5, 1.0, double(config.continent_ratio))), smoothstep(0.5, 1.0, double(config.continent_ratio))))) + (polarity*polarity));
	double coasts = continents * clamp((1.0-continents)*2.0 * (perlint64f(pos, continentStride, variation, 2) * 4.0 - 2.0) + 0.03, 0.0, 1.0);
	
	double peaks1 = 1.0 - perlint64fRidged(pos + warp/uint64_t(2) + uint64_t(49783892), 50 KM, variation, 4);
	double peaks2 = perlint64f(pos+warp/uint64_t(4) + uint64_t(87457641), 8 KM, variation/8, 2);
	double peaks3 = perlint64f(pos+warp/uint64_t(4) + uint64_t(276537654), 2 KM, variation/32, 2);
	
	double mountains = 0
		+ continents * variationf * 0.5
		- variationf * 0.2
		+ coasts * peaks1 * variation
		+ coasts * peaks2*peaks2 * variation/4
		+ coasts * peaks3*peaks3 * variation/8
		+ perlint64f(pos+warp/uint64_t(4) + uint64_t(176989876), 400 M, 200 M, 3) * 100 M
		+ perlint64f(pos, 50 M, 20 M, 3) * 5 M
	;
	
	mountains = _moutainStep(variationf * 0.2001, variationf * 0.1995, mountains);
	mountains = _moutainStep(variationf * 0.2001, variationf * 0.3, mountains);
	mountains = _moutainStep(variationf * 0.5, variationf * 0.6, mountains);
	mountains = _moutainStep(variationf * 0.8, variationf * 0.85, mountains);
	
	double detail = perlint64f(pos, 1 M, 1 M, 6) * 0.05 M;
	
	double height = config.baseRadiusMillimeters
		+ max(0.0, mountains)
		+ detail
	;
	
	return height / double(TERRAIN_UNIT_MULTIPLIER);
}

#ifdef GLSL
	vec3 GetColor(dvec3 posNorm, double height) {
		double heightRatio = (height - double(config.baseRadiusMillimeters)/TERRAIN_UNIT_MULTIPLIER) / config.heightVariationMillimeters * TERRAIN_UNIT_MULTIPLIER;
		const vec3 snowColor = vec3(0.8, 0.9, 1.0);
		const vec3 rockColor = vec3(0.2, 0.2, 0.2);
		const vec3 dirtColor = vec3(0.2, 0.1, 0.07);
		const vec3 clayColor = vec3(0.8, 0.6, 0.3);
		const vec3 sandColor = vec3(0.9, 0.5, 0.2);
		const vec3 underwaterColor = vec3(0.1, 0.3, 0.2);
		const vec3 floorColor = vec3(0.1, 0.05, 0.03);
		vec3 color = vec3(mix(rockColor, snowColor, smoothstep(0.5, 0.6, heightRatio)));
		color = mix(dirtColor, color, smoothstep(0.4, 0.6, float(heightRatio)));
		color = mix(clayColor, color, smoothstep(0.25, 0.4, float(heightRatio)));
		color = mix(sandColor, color, smoothstep(0.19, 0.25, float(heightRatio)));
		if (config.hydrosphere > 0) color = mix(underwaterColor, color, smoothstep(config.hydrosphere - 0.001, config.hydrosphere + 0.0002, float(heightRatio)));
		color = mix(floorColor, color, smoothstep(0.0, 0.199, float(heightRatio)));
		u64vec3 pos = u64vec3(posNorm * config.baseRadiusMillimeters + 200000000000.0);
		color *= mix(float(perlint64f(pos, 1 M / 8, 1 M / 8, 2)), 1.0, 0.7);
		color = mix(color, snowColor, smoothstep(0.5, 0.7, float(_getPolarity(posNorm))));
		return color;
	}
#endif
