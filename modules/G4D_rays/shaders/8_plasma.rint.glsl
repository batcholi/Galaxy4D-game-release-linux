#define SHADER_RINT
#include "common.inc.glsl"

hitAttributeEXT hit {
	float t2;
};

void main() {
	float density = PlasmaData(AABB.data).density;
	float temperature = PlasmaData(AABB.data).temperature;
	if (density > 0.0 || temperature > 1000.0) {
		COMPUTE_BOX_INTERSECTION // retrieves T1 and T2
		if RAY_STARTS_OUTSIDE_T1_T2 {
			t2 = T2;
			reportIntersectionEXT(T1, 0);
		}
	}
	DEBUG_RAY_INT_TIME
}
