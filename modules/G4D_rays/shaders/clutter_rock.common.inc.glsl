#include "common.inc.glsl"

vec3 _random3(vec3 pos) { // used in FastSimplex
	float j = 4096.0*sin(dot(pos,vec3(17.0, 59.4, 15.0)));
	vec3 r;
	r.z = fract(512.0*j);
	j *= .125;
	r.x = fract(512.0*j);
	j *= .125;
	r.y = fract(512.0*j);
	return r-0.5;
}
float FastSimplex(vec3 pos) {
	const float F3 = 0.3333333;
	const float G3 = 0.1666667;

	vec3 s = floor(pos + dot(pos, vec3(F3)));
	vec3 x = pos - s + dot(s, vec3(G3));

	vec3 e = step(vec3(0.0), x - x.yzx);
	vec3 i1 = e * (1.0 - e.zxy);
	vec3 i2 = 1.0 - e.zxy * (1.0 - e);

	vec3 x1 = x - i1 + G3;
	vec3 x2 = x - i2 + 2.0 * G3;
	vec3 x3 = x - 1.0 + 3.0 * G3;

	vec4 w, d;

	w.x = dot(x, x);
	w.y = dot(x1, x1);
	w.z = dot(x2, x2);
	w.w = dot(x3, x3);

	w = max(0.6 - w, 0.0);

	d.x = dot(_random3(s), x);
	d.y = dot(_random3(s + i1), x1);
	d.z = dot(_random3(s + i2), x2);
	d.w = dot(_random3(s + 1.0), x3);

	w *= w;
	w *= w;
	d *= w;

	return (dot(d, vec4(52.0)));
}
float FastSimplexFractal(vec3 pos, int octaves) {
	float amplitude = 0.5333333333;
	float frequency = 1.0;
	float f = FastSimplex(pos * frequency);
	for (int i = 1; i < octaves; ++i) {
		amplitude /= 2.0;
		frequency *= 2.0;
		f += amplitude * FastSimplex(pos * frequency);
	}
	return f;
}
float GrainyNoise(vec3 pos) {
	return clamp(FastSimplexFractal(pos*500, 2)/2+.5, 0, 1);
}

float sdRoundBox( vec3 p, vec3 b, float r ) {
	vec3 q = abs(p) - b + r;
	return length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0) - r;
}

float sdPlane( vec3 p, vec3 n, float h ) {
	// n must be normalized
	return dot(p,n) + h;
}

float intersectSDF(float distA, float distB) {
	return max(distA, distB);
}
 
float unionSDF(float distA, float distB) {
	return min(distA, distB);
}
 
float differenceSDF(float distA, float distB) {
	return max(distA, -distB);
}

mat3 RotationMatrix(vec3 axis, float angle) {
	axis = normalize(axis);
	float s = sin(angle);
	float c = cos(angle);
	float oc = 1.0 - c;
	return mat3(oc * axis.x * axis.x + c,           oc * axis.x * axis.y - axis.z * s,  oc * axis.z * axis.x + axis.y * s,
				oc * axis.x * axis.y + axis.z * s,  oc * axis.y * axis.y + c,           oc * axis.y * axis.z - axis.x * s,
				oc * axis.z * axis.x - axis.y * s,  oc * axis.y * axis.z + axis.x * s,  oc * axis.z * axis.z + c);
}

const float terrainClutterDetail = 2.0f;

vec3 rockSize = (AABB_MAX - AABB_MIN) * 0.5;
vec3 rockPos = (AABB_MAX + AABB_MIN) * 0.5;
float rockBoundingSize = max(rockSize.x, rockSize.z);
float approxDistanceFromCamera = length((MODELVIEW * vec4(rockPos, 1)).xyz);
float epsilon = 0.0001 * approxDistanceFromCamera;
int detailOctavesHighRes = int(round(5*smoothstep(terrainClutterDetail*5, 0, approxDistanceFromCamera)));
int detailOctavesMediumRes = detailOctavesHighRes / 2;
int detailOctavesLowRes = detailOctavesHighRes / 4;
int detailOctavesTextures = int(ceil(10*smoothstep(2, 0, approxDistanceFromCamera)));

float minDetailSize = 0.004; // +-4mm
float maxDetailSize = 0.01; // +-10mm
float fadeDistance = terrainClutterDetail*10;
float maxDrawDistance = 300;
float drawDistanceFadeFactor = pow(smoothstep(fadeDistance, maxDrawDistance, approxDistanceFromCamera), 0.1); // 0 when closer, 1 when farther
float minSizeInScreen = smoothstep(5.0, 0.01, terrainClutterDetail) + 1;

float GetDetailSize() {
	uint seed_ = uint32_t(AABB.data);
	return mix(minDetailSize, maxDetailSize, RandomFloat(seed_));
}

float Sdf(vec3 p, float detailSize, int detailOctaves) {
	uint seed_ = uint32_t(AABB.data);
	float rnd1 = RandomFloat(seed_);
	float rnd2 = RandomFloat(seed_);
	
	// Detail
	if (detailOctaves > 0 && detailSize > 0) {
		p += normalize(p) * detailSize * FastSimplexFractal(p*39.124+123.9*rnd1, detailOctaves);
	}
	
	// Box
	if (approxDistanceFromCamera > fadeDistance) {
		rockSize *= pow(smoothstep(maxDrawDistance, fadeDistance, approxDistanceFromCamera), 0.1);
	}
	float d = sdRoundBox(p, rockSize, rnd2*max(rockSize.x, rockSize.z));
	
	// Cuts
	for (int x = -1; x <= 1; ++x) {
		for (int z = -1; z <= 1; ++z) if (x != 0 || z != 0) {
			vec3 pt = vec3(x,-1,z) * rockSize;
			float rotation = RandomFloat(seed_) * 2 * PI;
			vec3 plane = vec3(
				pt.x * RandomFloat(seed_),
				pt.y + RandomFloat(seed_) * rockSize.y,
				pt.z * RandomFloat(seed_)
			);
			d = differenceSDF(d, sdPlane(p, normalize(RotationMatrix(vec3(0,1,0), rotation) * normalize(plane)), length(plane)));
		}
	}
	
	return d;
}
